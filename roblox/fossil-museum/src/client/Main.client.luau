-- 클라이언트 시작점: UI, 발굴 입력, 서버 알림 처리
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local Config = require(ReplicatedStorage.Shared.Config)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Util = require(ReplicatedStorage.Shared.Util)

local Client = script.Parent
local Hud = require(Client.Hud)
local Panels = require(Client.Panels)
local Digger = require(Client.Digger)
local Effects = require(Client.Effects)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local actionRemote = remotes:WaitForChild("Action") :: RemoteFunction
local syncRemote = remotes:WaitForChild("Sync") :: RemoteEvent
local notifyRemote = remotes:WaitForChild("Notify") :: RemoteEvent
local effectRemote = remotes:WaitForChild("Effect") :: RemoteEvent

local snapshot: any = nil

local function request(action: string, ...: any)
	local args = table.pack(...)
	task.spawn(function()
		local ok, success, message = pcall(function()
			return actionRemote:InvokeServer(action, table.unpack(args, 1, args.n))
		end)
		if not ok then
			Hud.Toast("서버와 연결이 불안정해요", Color3.fromRGB(255, 120, 120))
			return
		end
		if type(message) == "string" then
			Hud.Toast(message, if success then Color3.fromRGB(140, 255, 140) else Color3.fromRGB(255, 140, 140), success == true)
		end
	end)
end

local function updateBadges()
	if not snapshot then
		return
	end
	local canAssemble = false
	for speciesId in snapshot.pieces do
		if Economy.HasAllPieces(snapshot, speciesId) then
			canAssemble = true
			break
		end
	end
	Hud.SetBadge("Collection", canAssemble)
	local canBuy = false
	for _, def in Config.Tools do
		if not snapshot.ownedTools[def.id] and snapshot.coins >= def.price then
			canBuy = true
			break
		end
	end
	Hud.SetBadge("Shop", canBuy)
end

local function applySnapshot(newSnapshot: any)
	if type(newSnapshot) ~= "table" then
		return
	end
	snapshot = newSnapshot
	Hud.SetCoins(snapshot.coins)
	Hud.SetIncome(snapshot.income)
	Panels.Update(snapshot)
	updateBadges()
end

----------------------------------------------------------------------
Hud.Create(function(id: string)
	if id == "Collection" or id == "Shop" then
		Panels.Toggle(id)
	elseif id == "Museum" or id == "Field" then
		Panels.Close()
		request("Teleport", id)
	end
end)
Panels.Create(Hud.GetScreen(), request)

Digger.Init(function()
	return if snapshot then snapshot.cooldown else 0.55
end, function()
	Hud.Toast("조금 더 가까이 가서 파세요!", Color3.fromRGB(255, 200, 120))
end)

syncRemote.OnClientEvent:Connect(applySnapshot)

-- 코인은 자주 바뀌므로 속성으로 받음
player:GetAttributeChangedSignal("Coins"):Connect(function()
	local coins = player:GetAttribute("Coins") :: number
	if coins then
		Hud.SetCoins(coins)
		Panels.OnCoins(coins)
		updateBadges()
	end
end)

local function systemMessage(text: string)
	pcall(function()
		local channels = TextChatService:FindFirstChild("TextChannels")
		local general = channels and channels:FindFirstChild("RBXGeneral") :: TextChannel?
		if general then
			general:DisplaySystemMessage(text)
		end
	end)
end

notifyRemote.OnClientEvent:Connect(function(payload: any)
	if type(payload) ~= "table" then
		return
	end
	if payload.kind == "Dig" then
		Effects.FloatText(payload.position, "+" .. Util.FormatNumber(payload.coins) .. " 💰", Color3.fromRGB(255, 220, 80))
		if payload.speciesId then
			local species = Config.SpeciesById[payload.speciesId]
			local rarity = Config.RarityById[species.rarity]
			local pieceName = Config.GetPieces(species)[payload.pieceIndex]
			local text = string.format("[%s] %s · %s", rarity.name, species.name, pieceName)
			if payload.isNew then
				text = "✨ NEW! " .. text
			end
			Hud.Toast(text, rarity.color, rarity.tier >= 3 or payload.isNew)
			if payload.complete and payload.isNew then
				Hud.Toast("🦴 " .. species.name .. " 조각을 모두 모았어요! 📖 도감에서 조립하세요", Color3.fromRGB(140, 255, 140), true, 5)
			end
		end
	elseif payload.kind == "Text" then
		Hud.Toast(payload.text, payload.color)
	elseif payload.kind == "Announce" then
		Hud.Toast(payload.text, payload.color or Color3.fromRGB(255, 220, 120), true, 5)
		systemMessage(payload.text)
	elseif payload.kind == "Offline" then
		Hud.Toast(
			string.format("🏛️ 자리를 비운 %s 동안 관람객이 💰 %s 코인을 냈어요!", Util.FormatTime(payload.seconds), Util.FormatNumber(payload.coins)),
			Color3.fromRGB(255, 220, 80),
			true,
			7
		)
	end
end)

effectRemote.OnClientEvent:Connect(function(kind: string, position: Vector3, color: Color3, big: boolean)
	if kind == "Dig" then
		Effects.DirtBurst(position, color, big)
	end
end)

-- 이벤트 배너 / 부스트 타이머
task.spawn(function()
	while true do
		local now = workspace:GetServerTimeNow()
		if ReplicatedStorage:GetAttribute("MeteorActive") then
			local endsAt = ReplicatedStorage:GetAttribute("MeteorEndsAt") or now
			Hud.SetEvent("☄️ 운석 낙하 중! " .. Util.FormatTime(endsAt - now))
		else
			local nextAt = ReplicatedStorage:GetAttribute("NextMeteorAt")
			Hud.SetEvent(if nextAt then "☄️ 다음 운석까지 " .. Util.FormatTime(nextAt - now) else "☄️ 운석 대기 중")
		end
		if snapshot then
			Hud.SetBoost((snapshot.luckBoostUntil or 0) - os.time())
		end
		task.wait(0.5)
	end
end)

-- 처음 데이터 받아오기 (서버가 아직 불러오는 중이면 재시도)
task.spawn(function()
	for _ = 1, 30 do
		local ok, success, data = pcall(function()
			return actionRemote:InvokeServer("GetSnapshot")
		end)
		if ok and success and data then
			applySnapshot(data)
			return
		end
		task.wait(1)
	end
end)

Hud.Toast("⛏️ 삽을 들고 흙더미를 클릭하세요! 화석 조각을 모아 박물관을 채워요", Color3.fromRGB(255, 230, 160), true, 6)
