-- 플레이어 데이터 불러오기 / 저장
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)

local DataService = {}

local STORE_NAME = "FossilMuseum_v1"
local AUTOSAVE_INTERVAL = 120

local TEMPLATE = {
	coins = 0,
	tool = "WoodShovel",
	ownedTools = { WoodShovel = true },
	pieces = {}, -- [speciesId] = { ["1"] = 개수, ["2"] = 개수, ... }
	museum = {}, -- [speciesId] = 완성한 개수
	slots = Config.StartSlots,
	likes = 0,
	likedGiven = {}, -- [대상 UserId] = 좋아요 누른 날짜 번호
	luckBoostUntil = 0,
	lastOnline = 0,
	purchases = {}, -- 처리한 개발자 상품 PurchaseId (중복 지급 방지)
	stats = { dug = 0, found = 0 },
}

type Profile = {
	data: any,
	canSave: boolean,
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

local function load(player: Player)
	local data = nil
	local failed = false

	if store then
		for attempt = 1, 3 do
			local ok, result = pcall(function()
				return (store :: DataStore):GetAsync(keyFor(player))
			end)
			if ok then
				data = result
				failed = false
				break
			end
			failed = true
			warn(string.format("[DataService] %s 데이터 불러오기 실패 (%d/3): %s", player.Name, attempt, tostring(result)))
			if RunService:IsStudio() then
				break -- Studio 에서는 기다리지 않고 바로 임시 데이터로 시작
			end
			task.wait(attempt * 1.5)
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
	if player.Parent == nil then
		return
	end

	if type(data) ~= "table" then
		data = Util.DeepCopy(TEMPLATE)
	end
	reconcile(data, TEMPLATE)

	-- 오래된 좋아요 기록 정리
	local today = DataService.Today()
	for target, day in data.likedGiven do
		if day ~= today then
			data.likedGiven[target] = nil
		end
	end
	if not Config.ToolsById[data.tool] then
		data.tool = "WoodShovel"
	end

	local offlineSeconds = 0
	if data.lastOnline > 0 then
		offlineSeconds = math.clamp(os.time() - data.lastOnline, 0, Config.OfflineMaxSeconds)
	end
	data.lastOnline = os.time()

	profiles[player] = { data = data, canSave = not failed }
	loadedEvent:Fire(player, data, offlineSeconds)
end

function DataService.Get(player: Player): any
	local profile = profiles[player]
	return profile and profile.data
end

function DataService.Save(player: Player): boolean
	local profile = profiles[player]
	if not profile or not profile.canSave or not store then
		return false
	end
	profile.data.lastOnline = os.time()
	local ok, err = pcall(function()
		(store :: DataStore):UpdateAsync(keyFor(player), function()
			return profile.data
		end)
	end)
	if not ok then
		warn(string.format("[DataService] %s 저장 실패: %s", player.Name, tostring(err)))
	end
	return ok
end

function DataService.Init()
	Players.PlayerAdded:Connect(load)
	for _, player in Players:GetPlayers() do
		task.spawn(load, player)
	end

	Players.PlayerRemoving:Connect(function(player)
		DataService.Save(player)
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
				DataService.Save(player)
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
