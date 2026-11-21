-- 플레이어 데이터 불러오기 / 저장
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)

local DataService = {}

-- Studio 테스트는 실제 게임과 다른 저장소를 써요 (테스트 메뉴로 만든 코인이 실제 데이터에 섞이지 않게)
local STORE_NAME = if RunService:IsStudio() then "FossilMuseum_StudioTest_v1" else "FossilMuseum_v1"
local AUTOSAVE_INTERVAL = 120

local TEMPLATE = {
	coins = 0,
	tool = "WoodShovel",
	ownedTools = { WoodShovel = true },
	pieces = {}, -- [speciesId] = { ["1"] = 개수, ["2"] = 개수, ... }
	museum = {}, -- [speciesId] = 완성한 개수
	slots = Config.StartSlots,
	likes = 0, -- 사람에게 받은 좋아요
	npcLikes = 0, -- NPC 손님에게 받은 좋아요
	likedGiven = {}, -- [대상 UserId] = 좋아요 누른 날짜 번호
	luckBoostUntil = 0,
	lastOnline = 0,
	purchases = {}, -- 처리한 개발자 상품 PurchaseId (중복 지급 방지)
	unlockedZones = { Desert = true },
	rebirths = 0,
	helpersOwned = {}, -- [helperId] = 가진 개수
	helpersEquipped = {}, -- { helperId, ... }
	daily = { last = 0, streak = 0 }, -- 마지막으로 받은 날짜 번호, 연속 일수
	quests = { day = 0, list = {} },
	weekLikes = { week = 0, count = 0 },
	autoDig = true, -- 자동 발굴 패스가 있을 때 켜짐/꺼짐
	stats = { dug = 0, found = 0, meteors = 0, helperDug = 0, totalEarned = 0 },
	tradeHistory = {}, -- 최근 거래 20개 { time, with, gave, got }
}

-- 저장 형식: { data = 플레이어 데이터, session = { job = 서버 ID, at = 마지막 확인 시각 } | nil }
-- session 이 있으면 "지금 어떤 서버가 이 데이터를 쓰는 중"이라는 뜻 (세션 잠금).
-- 같은 계정이 두 서버에서 동시에 저장해서 조각/코인이 복사되는 버그를 막아요.
local SESSION_TIMEOUT = AUTOSAVE_INTERVAL + 60 -- 이 시간 동안 갱신이 없으면 그 서버가 꺼진 걸로 보고 가져옴
local LOCK_WAIT = 40 -- 다른 서버가 잠그고 있으면 최대 이 시간 동안 기다림

local SERVER_ID = if game.JobId ~= "" then game.JobId else HttpService:GenerateGUID(false)

type Profile = {
	data: any,
	canSave: boolean, -- false 면 저장하지 않음 (Studio 임시 데이터, 다른 서버가 가져간 경우)
	released: boolean,
}

local profiles: { [Player]: Profile } = {}
local loadedEvent = Instance.new("BindableEvent")
DataService.Loaded = loadedEvent.Event -- (player, data, offlineSeconds)

local store: DataStore? = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
	else
		warn("[DataService] DataStore 를 사용할 수 없어요:", result)
	end
end

local function keyFor(player: Player): string
	return "u_" .. player.UserId
end

-- 저장된 데이터에 없는 항목을 기본값으로 채움 (업데이트로 항목이 늘어났을 때)
local function reconcile(data: any, template: any)
	for key, value in template do
		if data[key] == nil then
			data[key] = Util.DeepCopy(value)
		elseif type(value) == "table" and type(data[key]) == "table" and next(value) ~= nil then
			reconcile(data[key], value)
		end
	end
end

function DataService.Today(): number
	return os.time() // 86400
end

-- 월요일 기준 주 번호
function DataService.Week(): number
	return (os.time() // 86400 + 3) // 7
end

-- 예전 형식(데이터 그대로 저장)도 읽을 수 있게
local function unwrap(record: any): (any, any)
	if type(record) ~= "table" then
		return nil, nil
	end
	if record.data ~= nil or record.session ~= nil then
		return record.data, record.session
	end
	if record.coins ~= nil then
		return record, nil -- 예전 형식
	end
	return nil, nil
end

-- 잠금을 잡으면서 불러오기. 반환: ("ok", data) | ("locked", nil) | ("error", 메시지)
local function tryAcquire(player: Player, steal: boolean): (string, any)
	local result = "error"
	local loaded = nil
	local ok, err = pcall(function()
		(store :: DataStore):UpdateAsync(keyFor(player), function(record)
			local data, session = unwrap(record)
			local now = os.time()
			if session and session.job ~= SERVER_ID and not steal and now - (session.at or 0) < SESSION_TIMEOUT then
				result = "locked"
				return nil -- 바꾸지 않음
			end
			result = "ok"
			loaded = data
			return { data = data, session = { job = SERVER_ID, at = now } }
		end)
	end)
	if not ok then
		return "error", tostring(err)
	end
	return result, loaded
end

local function release(player: Player, data: any)
	pcall(function()
		(store :: DataStore):UpdateAsync(keyFor(player), function(record)
			local _, session = unwrap(record)
			if session and session.job ~= SERVER_ID then
				return nil -- 이미 다른 서버 것
			end
			return { data = data, session = nil }
		end)
	end)
end

local function load(player: Player)
	local data = nil
	local failed = false

	if store then
		local started = os.clock()
		local errors = 0
		while true do
			local elapsed = os.clock() - started
			local status, value = tryAcquire(player, elapsed >= LOCK_WAIT)
			if status == "ok" then
				data = value
				break
			elseif status == "locked" then
				-- 다른 서버가 방금까지 쓰던 중 (보통 서버를 옮길 때). 그 서버가 저장을 끝낼 때까지 기다림
				task.wait(4)
			else
				errors += 1
				warn(string.format("[DataService] %s 데이터 불러오기 실패 (%d/3): %s", player.Name, errors, tostring(value)))
				if errors >= 3 or RunService:IsStudio() then
					failed = true
					break
				end
				task.wait(errors * 1.5)
			end
			if player.Parent == nil then
				return
			end
		end
	else
		failed = true
	end

	if failed and not RunService:IsStudio() then
		player:Kick("데이터를 불러오지 못했어요. 잠시 후 다시 접속해 주세요.")
		return
	end
	if failed then
		warn("[DataService] Studio 테스트: 임시 데이터로 시작합니다 (저장 안 됨). 게임 설정 > 보안 > 'Studio에서 API 서비스 사용'을 켜면 저장돼요.")
	end
	if type(data) ~= "table" then
		data = Util.DeepCopy(TEMPLATE)
	end
	if player.Parent == nil then
		-- 불러오는 동안 나감: 잡은 잠금을 바로 풂
		if not failed then
			release(player, data)
		end
		return
	end
	reconcile(data, TEMPLATE)
	-- 오래된 좋아요 기록 정리
	local today = DataService.Today()
	for target, day in data.likedGiven do
		if day ~= today then
			data.likedGiven[target] = nil
		end
	end
	if not Config.ToolsById[data.tool] or not data.ownedTools[data.tool] then
		data.tool = "WoodShovel"
		data.ownedTools.WoodShovel = true
	end
	-- 없어진 조수 정리
	for i = #data.helpersEquipped, 1, -1 do
		local id = data.helpersEquipped[i]
		if not Config.HelperById[id] or (data.helpersOwned[id] or 0) <= 0 then
			table.remove(data.helpersEquipped, i)
		end
	end

	local offlineSeconds = 0
	if data.lastOnline > 0 then
		offlineSeconds = math.clamp(os.time() - data.lastOnline, 0, Config.OfflineMaxSeconds)
	end
	data.lastOnline = os.time()

	profiles[player] = { data = data, canSave = not failed, released = false }
	loadedEvent:Fire(player, data, offlineSeconds)
end

function DataService.Get(player: Player): any
	local profile = profiles[player]
	return profile and profile.data
end

-- 저장. releaseLock = true 면 잠금도 풂 (나갈 때)
function DataService.Save(player: Player, releaseLock: boolean?): boolean
	local profile = profiles[player]
	if not profile or not profile.canSave or profile.released or not store then
		return false
	end
	profile.data.lastOnline = os.time()
	local stolen = false
	local ok, err = pcall(function()
		(store :: DataStore):UpdateAsync(keyFor(player), function(record)
			local _, session = unwrap(record)
			if session and session.job ~= SERVER_ID then
				-- 다른 서버가 이 계정을 가져감 → 덮어쓰면 복사/손실 버그가 생기므로 저장하지 않음
				stolen = true
				return nil
			end
			return {
				data = profile.data,
				session = if releaseLock then nil else { job = SERVER_ID, at = os.time() },
			}
		end)
	end)
	if not ok then
		warn(string.format("[DataService] %s 저장 실패: %s", player.Name, tostring(err)))
		return false
	end
	if stolen then
		profile.canSave = false
		warn(string.format("[DataService] %s: 다른 서버에서 접속해서 이 서버의 저장을 멈춰요", player.Name))
		if player.Parent then
			player:Kick("다른 서버에서 같은 계정으로 접속했어요.")
		end
		return false
	end
	if releaseLock then
		profile.released = true
	end
	return true
end

-- 데이터 전체 초기화 (Studio 테스트 메뉴 전용)
function DataService.Reset(player: Player): any
	local profile = profiles[player]
	if not profile then
		return nil
	end
	local fresh = Util.DeepCopy(TEMPLATE)
	fresh.lastOnline = os.time()
	-- 같은 테이블을 계속 쓰는 코드가 있어서 내용만 바꿔치기
	table.clear(profile.data)
	for k, v in fresh do
		profile.data[k] = v
	end
	return profile.data
end

function DataService.Init()
	Players.PlayerAdded:Connect(load)
	for _, player in Players:GetPlayers() do
		task.spawn(load, player)
	end

	Players.PlayerRemoving:Connect(function(player)
		DataService.Save(player, true)
		profiles[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL)
			for player in profiles do
				task.spawn(DataService.Save, player)
			end
		end
	end)

	game:BindToClose(function()
		local pending = 0
		for player in profiles do
			pending += 1
			task.spawn(function()
				DataService.Save(player, true)
				pending -= 1
			end)
		end
		local started = os.clock()
		while pending > 0 and os.clock() - started < 25 do
			task.wait(0.1)
		end
	end)
end

return DataService
