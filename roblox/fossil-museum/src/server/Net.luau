-- 클라이언트와 통신: 리모트 생성, 알림, 데이터 동기화
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Economy = require(ReplicatedStorage.Shared.Economy)
local DataService = require(script.Parent.DataService)
local Passes = require(script.Parent.Passes)

local Net = {}

local folder = Instance.new("Folder")
folder.Name = "Remotes"

local function make(className: string, name: string): any
	local remote = Instance.new(className)
	remote.Name = name
	remote.Parent = folder
	return remote
end

Net.Dig = make("RemoteEvent", "Dig") :: RemoteEvent -- 클라 → 서버: 흙더미 파기
Net.Notify = make("RemoteEvent", "Notify") :: RemoteEvent -- 서버 → 클라: 알림
Net.Sync = make("RemoteEvent", "Sync") :: RemoteEvent -- 서버 → 클라: 데이터 전체
Net.Effect = make("RemoteEvent", "Effect") :: RemoteEvent -- 서버 → 클라: 연출
Net.Action = make("RemoteFunction", "Action") :: RemoteFunction -- 클라 → 서버: 버튼 요청

folder.Parent = ReplicatedStorage

local changedEvent = Instance.new("BindableEvent")
Net.Changed = changedEvent.Event -- (player) 데이터 구조가 바뀜 (조각, 전시 등)

local handlers: { [string]: (Player, ...any) -> any } = {}
local lastCalls: { [Player]: { number } } = {}

-- 버튼 요청 처리 함수 등록. 반환값: (성공 여부, 메시지)
function Net.Handle(action: string, fn: (Player, ...any) -> any)
	handlers[action] = fn
end

Net.Action.OnServerInvoke = function(player: Player, action: any, ...: any)
	if type(action) ~= "string" or not handlers[action] then
		return false, "알 수 없는 요청"
	end
	-- 초당 10회 제한
	local now = os.clock()
	local calls = lastCalls[player] or {}
	lastCalls[player] = calls
	while calls[1] and now - calls[1] > 1 do
		table.remove(calls, 1)
	end
	if #calls >= 10 then
		return false, "너무 빨라요!"
	end
	table.insert(calls, now)

	if not DataService.Get(player) then
		return false, "데이터를 불러오는 중이에요"
	end
	local ok, success, message = pcall(handlers[action], player, ...)
	if not ok then
		warn("[Net] " .. action .. " 오류:", success)
		return false, "오류가 발생했어요"
	end
	return success, message
end

Players.PlayerRemoving:Connect(function(player)
	lastCalls[player] = nil
end)

function Net.Snapshot(player: Player): any?
	local data = DataService.Get(player)
	if not data then
		return nil
	end
	local passes = Passes.Get(player)
	return {
		coins = data.coins,
		tool = data.tool,
		ownedTools = data.ownedTools,
		pieces = data.pieces,
		museum = data.museum,
		slots = data.slots,
		likes = data.likes,
		luckBoostUntil = data.luckBoostUntil,
		stats = data.stats,
		passes = passes,
		income = Economy.GetIncome(data, passes),
		luck = Economy.GetLuck(data, passes, 0),
		cooldown = Economy.GetDigCooldown(data, passes),
	}
end

-- 코인 숫자만 빠르게 갱신 (자주 호출해도 됨)
function Net.UpdateCoins(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	player:SetAttribute("Coins", data.coins)
	local stats = player:FindFirstChild("leaderstats")
	local coinsValue = stats and stats:FindFirstChild("코인")
	if coinsValue then
		(coinsValue :: IntValue).Value = math.floor(data.coins)
	end
end

-- 데이터 구조가 바뀌었을 때 호출 → 잠시 후 한 번에 전송
local pending: { [Player]: boolean } = {}
function Net.MarkDirty(player: Player)
	Net.UpdateCoins(player)
	if pending[player] then
		return
	end
	pending[player] = true
	task.defer(function()
		pending[player] = nil
		if player.Parent then
			local snapshot = Net.Snapshot(player)
			if snapshot then
				Net.Sync:FireClient(player, snapshot)
				changedEvent:Fire(player)
			end
		end
	end)
end

function Net.Tell(player: Player, text: string, color: Color3?)
	Net.Notify:FireClient(player, { kind = "Text", text = text, color = color })
end

function Net.Announce(text: string, color: Color3?)
	Net.Notify:FireAllClients({ kind = "Announce", text = text, color = color })
end

Net.Handle("GetSnapshot", function(player)
	return true, Net.Snapshot(player)
end)

return Net
