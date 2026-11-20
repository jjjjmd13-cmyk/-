-- 클라이언트 시작점: UI, 발굴 입력, 서버 알림 처리
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TextChatService = game:GetService("TextChatService")

local Config = require(ReplicatedStorage.Shared.Config)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Util = require(ReplicatedStorage.Shared.Util)

local Client = script.Parent
local Hud = require(Client.Hud)
local PanelManager = require(Client.PanelManager)
local Digger = require(Client.Digger)
local Effects = require(Client.Effects)
local Barriers = require(Client.Barriers)
local HelperVisuals = require(Client.HelperVisuals)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local actionRemote = remotes:WaitForChild("Action") :: RemoteFunction
local syncRemote = remotes:WaitForChild("Sync") :: RemoteEvent
local notifyRemote = remotes:WaitForChild("Notify") :: RemoteEvent
local effectRemote = remotes:WaitForChild("Effect") :: RemoteEvent
local tradeRemote = remotes:WaitForChild("Trade") :: RemoteEvent

local snapshot: any = nil

----------------------------------------------------------------------
-- 효과음 (Roblox 기본 내장 소리)
----------------------------------------------------------------------
local function makeSound(id: string, volume: number): Sound
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = volume
	sound.Parent = SoundService
	return sound
end
local sounds = {
	dig = makeSound("rbxasset://sounds/action_footsteps_plastic.mp3", 0.5),
	find = makeSound("rbxasset://sounds/electronicpingshort.wav", 0.6),
}
local function play(name: string, pitch: number?)
	local sound = sounds[name]
	if sound then
		sound.PlaybackSpeed = pitch or 1
		SoundService:PlayLocalSound(sound)
	end
end

----------------------------------------------------------------------
-- 서버 요청
----------------------------------------------------------------------
local function invoke(action: string, ...: any): (boolean, any)
	local args = table.pack(...)
	local ok, success, message = pcall(function()
		return actionRemote:InvokeServer(action, table.unpack(args, 1, args.n))
	end)
	if not ok then
		return false, "서버와 연결이 불안정해요"
	end
	return success == true, message
end

local function request(action: string, ...: any)
	local args = table.pack(...)
	task.spawn(function()
		local success, message = invoke(action, table.unpack(args, 1, args.n))
		if type(message) == "string" then
			Hud.Toast(message, if success then Color3.fromRGB(140, 255, 140) else Color3.fromRGB(255, 140, 140), success)
		end
	end)
end

----------------------------------------------------------------------
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

	local canZone = false
	for i, zone in Config.Zones do
		local previous = Config.Zones[i - 1]
		if not snapshot.unlockedZones[zone.id] and (not previous or snapshot.unlockedZones[previous.id]) and snapshot.coins >= zone.price then
			canZone = true
		end
	end
	Hud.SetBadge("Zones", canZone)

	local questReady = snapshot.daily.last ~= snapshot.today
	if snapshot.quests.day == snapshot.today then
		for _, quest in snapshot.quests.list do
			if quest.progress >= quest.target and not quest.claimed then
				questReady = true
			end
		end
	end
	Hud.SetBadge("Quests", questReady)
	Hud.SetBadge("Rebirth", snapshot.coins >= snapshot.rebirthPrice)
	Hud.SetBadge("Helpers", #snapshot.helpersEquipped < snapshot.helperSlots and snapshot.coins >= Config.Helpers[1].price)
end

local function applySnapshot(newSnapshot: any)
	if type(newSnapshot) ~= "table" then
		return
	end
	local first = snapshot == nil
	snapshot = newSnapshot
	Hud.SetCoins(snapshot.coins)
	Hud.SetIncome(snapshot.income)
	PanelManager.Update(snapshot)
	Barriers.Update(snapshot.unlockedZones)
	updateBadges()
	if first and snapshot.daily.last ~= snapshot.today then
		task.delay(2, function()
			Hud.Toast("🎁 오늘의 접속 보상이 있어요! 📜 퀘스트 메뉴에서 받으세요", Color3.fromRGB(255, 220, 100), true, 6)
		end)
	end
end

local function refreshSnapshot()
	local ok, data = invoke("GetSnapshot")
	if ok and data then
		applySnapshot(data)
	end
end

----------------------------------------------------------------------
Hud.Create(function(id: string)
	if id == "Museum" then
		PanelManager.Close()
		request("Teleport", "Museum")
	else
		PanelManager.Toggle(id)
	end
end)
PanelManager.Create(Hud.GetScreen(), request, invoke, refreshSnapshot)
HelperVisuals.Init()

Digger.Init(function()
	return if snapshot then snapshot.cooldown else 0.55
end, function()
	Hud.Toast("조금 더 가까이 가서 파세요!", Color3.fromRGB(255, 200, 120))
end, function()
	if snapshot and snapshot.passes.AutoDig and snapshot.autoDig then
		return true, snapshot.unlockedZones
	end
	return false, {}
end)

syncRemote.OnClientEvent:Connect(applySnapshot)

player:GetAttributeChangedSignal("Coins"):Connect(function()
	local coins = player:GetAttribute("Coins") :: number
	if coins then
		Hud.SetCoins(coins)
		PanelManager.OnCoins(coins)
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
		if payload.helper then
			HelperVisuals.Hop(player)
		end
		Effects.FloatText(payload.position, "+" .. Util.FormatNumber(payload.coins) .. " 💰", Color3.fromRGB(255, 220, 80))
		if payload.coop then
			Effects.FloatText(payload.position + Vector3.new(0, 1.5, 0), "🤝 함께 발굴! +20%", Color3.fromRGB(140, 230, 255))
		end
		if payload.speciesId then
			local species = Config.SpeciesById[payload.speciesId]
			local rarity = Config.RarityById[species.rarity]
			local pieceName = Config.GetPieces(species)[payload.pieceIndex]
			local text = string.format("%s[%s] %s · %s", if payload.helper then "🦖 " else "", rarity.name, species.name, pieceName)
			if payload.isNew then
				text = "✨ NEW! " .. text
			end
			local big = rarity.tier >= 3 or payload.isNew
			Hud.Toast(text, rarity.color, big)
			if big then
				play("find", 0.8 + rarity.tier * 0.1)
			end
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
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root and (root.Position - position).Magnitude < 30 then
			play("dig", if big then 0.8 else 1 + math.random() * 0.2)
		end
	end
end)

tradeRemote.OnClientEvent:Connect(function(payload: any)
	if type(payload) ~= "table" then
		return
	end
	if payload.type == "Request" then
		Hud.Prompt(payload.fromName .. "님이 거래를 요청했어요!", "수락", "거절", function(accept)
			request("TradeRespond", payload.fromId, accept)
		end, 30)
	elseif payload.type == "State" then
		PanelManager.SetTrade(payload)
	elseif payload.type == "Closed" then
		PanelManager.SetTrade(nil)
		if payload.reason ~= "done" then
			Hud.Toast("🤝 " .. tostring(payload.reason), Color3.fromRGB(255, 200, 140))
		end
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
		local serverLuck = ReplicatedStorage:GetAttribute("ServerLuckUntil")
		Hud.SetServerLuck(if type(serverLuck) == "number" then serverLuck - os.time() else 0)
		task.wait(0.5)
	end
end)

-- 처음 데이터 받아오기 (서버가 아직 불러오는 중이면 재시도)
task.spawn(function()
	for _ = 1, 30 do
		local ok, data = invoke("GetSnapshot")
		if ok and data then
			applySnapshot(data)
			return
		end
		task.wait(1)
	end
end)

Hud.Toast("⛏️ 삽을 들고 흙더미를 클릭하세요! 화석 조각을 모아 박물관을 채워요", Color3.fromRGB(255, 230, 160), true, 6)
