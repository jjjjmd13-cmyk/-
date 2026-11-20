-- 플레이어끼리 화석 조각 / 코인 거래
-- 흐름: 요청 → 수락 → 양쪽이 물건 올리기 → 둘 다 "준비" → 서버가 한 번에 교환
-- 사기 방지: 내용이 바뀌면 준비가 풀리고, 바뀐 뒤 3초 동안은 준비를 누를 수 없음
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local DataService = require(script.Parent.DataService)
local Net = require(script.Parent.Net)

local TradeService = {}

local READY_LOCK = 3

type Offer = { items: { [string]: number }, coins: number }
type Trade = {
	players: { Player },
	offers: { [Player]: Offer },
	ready: { [Player]: boolean },
	changedAt: number,
}

local trades: { [Player]: Trade } = {}
local requests: { [Player]: { from: Player, at: number } } = {} -- [받는 사람]
local lastRequest: { [Player]: number } = {}

local function itemKey(speciesId: string, pieceIndex: number): string
	return speciesId .. "|" .. pieceIndex
end

local function parseKey(key: string): (string, number)
	local speciesId, index = key:match("^(.+)|(%d+)$")
	return speciesId :: string, tonumber(index) :: number
end

local function other(trade: Trade, player: Player): Player
	return if trade.players[1] == player then trade.players[2] else trade.players[1]
end

local function offerList(offer: Offer): { any }
	local list = {}
	for key, count in offer.items do
		local speciesId, pieceIndex = parseKey(key)
		table.insert(list, { speciesId = speciesId, pieceIndex = pieceIndex, count = count })
	end
	table.sort(list, function(a, b)
		return a.speciesId .. a.pieceIndex < b.speciesId .. b.pieceIndex
	end)
	return list
end

local function sendState(trade: Trade)
	for _, player in trade.players do
		local them = other(trade, player)
		Net.Trade:FireClient(player, {
			type = "State",
			me = { items = offerList(trade.offers[player]), coins = trade.offers[player].coins, ready = trade.ready[player] == true },
			them = { name = them.DisplayName, items = offerList(trade.offers[them]), coins = trade.offers[them].coins, ready = trade.ready[them] == true },
			lockLeft = math.max(0, trade.changedAt + READY_LOCK - os.clock()),
		})
	end
end

local function close(trade: Trade, reason: string)
	for _, player in trade.players do
		trades[player] = nil
		if player.Parent then
			Net.Trade:FireClient(player, { type = "Closed", reason = reason })
		end
	end
end

local function owns(data: any, speciesId: string, pieceIndex: number, count: number): boolean
	local owned = data.pieces[speciesId]
	return owned ~= nil and (owned[tostring(pieceIndex)] or 0) >= count
end

local function validOffer(data: any, offer: Offer): boolean
	if data.coins < offer.coins then
		return false
	end
	for key, count in offer.items do
		local speciesId, pieceIndex = parseKey(key)
		if not owns(data, speciesId, pieceIndex, count) then
			return false
		end
	end
	return true
end

local function moveItems(fromData: any, toData: any, offer: Offer)
	fromData.coins -= offer.coins
	toData.coins += offer.coins
	for key, count in offer.items do
		local speciesId, pieceIndex = parseKey(key)
		local pk = tostring(pieceIndex)
		local fromOwned = fromData.pieces[speciesId]
		fromOwned[pk] -= count
		if fromOwned[pk] <= 0 then
			fromOwned[pk] = nil
		end
		local toOwned = toData.pieces[speciesId]
		if not toOwned then
			toOwned = {}
			toData.pieces[speciesId] = toOwned
		end
		toOwned[pk] = (toOwned[pk] or 0) + count
	end
end

local function execute(trade: Trade)
	local a, b = trade.players[1], trade.players[2]
	local dataA, dataB = DataService.Get(a), DataService.Get(b)
	if not dataA or not dataB then
		close(trade, "상대가 나갔어요")
		return
	end
	if not validOffer(dataA, trade.offers[a]) or not validOffer(dataB, trade.offers[b]) then
		close(trade, "올린 물건이 더 이상 없어서 거래가 취소됐어요")
		return
	end
	moveItems(dataA, dataB, trade.offers[a])
	moveItems(dataB, dataA, trade.offers[b])
	close(trade, "done")
	Net.Tell(a, "🤝 " .. b.DisplayName .. "님과 거래 완료!", Color3.fromRGB(140, 255, 140))
	Net.Tell(b, "🤝 " .. a.DisplayName .. "님과 거래 완료!", Color3.fromRGB(140, 255, 140))
	Net.MarkDirty(a)
	Net.MarkDirty(b)
	task.spawn(DataService.Save, a)
	task.spawn(DataService.Save, b)
end

local function changed(trade: Trade)
	trade.ready = {}
	trade.changedAt = os.clock()
	sendState(trade)
end

----------------------------------------------------------------------
Net.Handle("TradeRequest", function(player, targetUserId)
	local target = type(targetUserId) == "number" and Players:GetPlayerByUserId(targetUserId)
	if not target or target == player then
		return false, "그 플레이어를 찾을 수 없어요"
	end
	if trades[player] then
		return false, "이미 거래 중이에요"
	end
	if trades[target] then
		return false, target.DisplayName .. "님은 다른 사람과 거래 중이에요"
	end
	if not DataService.Get(target) then
		return false, "상대가 아직 불러오는 중이에요"
	end
	local now = os.clock()
	if now - (lastRequest[player] or -100) < Config.TradeRequestCooldown then
		return false, "조금 뒤에 다시 요청해 주세요"
	end
	lastRequest[player] = now
	requests[target] = { from = player, at = now }
	Net.Trade:FireClient(target, { type = "Request", fromName = player.DisplayName, fromId = player.UserId })
	return true, target.DisplayName .. "님에게 거래를 요청했어요"
end)

Net.Handle("TradeRespond", function(player, fromUserId, accept)
	local request = requests[player]
	if not request or request.from.UserId ~= fromUserId or not request.from.Parent then
		requests[player] = nil
		return false, "요청이 만료됐어요"
	end
	requests[player] = nil
	local from = request.from
	if accept ~= true then
		Net.Tell(from, player.DisplayName .. "님이 거래를 거절했어요")
		return true, nil
	end
	if os.clock() - request.at > 60 then
		return false, "요청이 만료됐어요"
	end
	if trades[from] or trades[player] then
		return false, "상대가 이미 다른 거래 중이에요"
	end
	local trade: Trade = {
		players = { from, player },
		offers = { [from] = { items = {}, coins = 0 }, [player] = { items = {}, coins = 0 } },
		ready = {},
		changedAt = os.clock(),
	}
	trades[from] = trade
	trades[player] = trade
	sendState(trade)
	return true, nil
end)

Net.Handle("TradeSetItem", function(player, speciesId, pieceIndex, count)
	local trade = trades[player]
	local data = DataService.Get(player)
	if not trade then
		return false, nil
	end
	if type(speciesId) ~= "string" or not Config.SpeciesById[speciesId] or type(pieceIndex) ~= "number" or type(count) ~= "number" then
		return false, nil
	end
	count = math.floor(count)
	pieceIndex = math.floor(pieceIndex)
	local offer = trade.offers[player]
	local key = itemKey(speciesId, pieceIndex)
	if count <= 0 then
		offer.items[key] = nil
	else
		if not owns(data, speciesId, pieceIndex, count) then
			return false, "그만큼 가지고 있지 않아요"
		end
		if offer.items[key] == nil then
			local n = 0
			for _ in offer.items do
				n += 1
			end
			if n >= Config.TradeMaxItems then
				return false, "한 번에 " .. Config.TradeMaxItems .. "종류까지 올릴 수 있어요"
			end
		end
		offer.items[key] = count
	end
	changed(trade)
	return true, nil
end)

Net.Handle("TradeSetCoins", function(player, amount)
	local trade = trades[player]
	local data = DataService.Get(player)
	if not trade or type(amount) ~= "number" then
		return false, nil
	end
	amount = math.clamp(math.floor(amount), 0, math.floor(data.coins))
	trade.offers[player].coins = amount
	changed(trade)
	return true, "💰 " .. Util.FormatNumber(amount) .. " 코인을 올렸어요"
end)

Net.Handle("TradeReady", function(player)
	local trade = trades[player]
	if not trade then
		return false, nil
	end
	if os.clock() - trade.changedAt < READY_LOCK then
		return false, "내용이 방금 바뀌었어요. 잠시 확인한 뒤 눌러 주세요"
	end
	trade.ready[player] = true
	local them = other(trade, player)
	if trade.ready[them] then
		execute(trade)
	else
		sendState(trade)
	end
	return true, nil
end)

Net.Handle("TradeCancel", function(player)
	local trade = trades[player]
	if trade then
		close(trade, player.DisplayName .. "님이 거래를 취소했어요")
	end
	return true, nil
end)

function TradeService.Init()
	Players.PlayerRemoving:Connect(function(player)
		local trade = trades[player]
		if trade then
			close(trade, "상대가 게임을 나갔어요")
		end
		requests[player] = nil
		lastRequest[player] = nil
	end)
end

return TradeService
