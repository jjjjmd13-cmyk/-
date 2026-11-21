-- 발굴 조수: 데리고 다니면 플레이어가 서 있는 지역에서 자동으로 흙더미를 팜
-- 조수 모형은 각 클라이언트가 플레이어의 "Helpers" 속성을 보고 그림 (서버 부담 없음)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Economy = require(ReplicatedStorage.Shared.Economy)
local DataService = require(script.Parent.DataService)
local Passes = require(script.Parent.Passes)
local Net = require(script.Parent.Net)
local Rewards = require(script.Parent.Rewards)
local Zones = require(script.Parent.Zones)

local HelperService = {}

local nextDig: { [Player]: { number } } = {}

local function activeHelpers(player: Player, data: any): { string }
	local slots = Economy.GetHelperSlots(Passes.Get(player))
	local list = {}
	for i, id in data.helpersEquipped do
		if i > slots then
			break
		end
		if Config.HelperById[id] then
			table.insert(list, id)
		end
	end
	return list
end

function HelperService.Refresh(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	local list = if Config.Features.Helpers == false then {} else activeHelpers(player, data)
	player:SetAttribute("Helpers", table.concat(list, ","))
end

local function tick()
	if Config.Features.Helpers == false then
		return
	end
	local now = os.clock()
	for _, player in Players:GetPlayers() do
		local data = DataService.Get(player)
		if data then
			local helpers = activeHelpers(player, data)
			if #helpers > 0 then
				local timers = nextDig[player]
				if not timers then
					timers = {}
					nextDig[player] = timers
				end
				local zoneId = Zones.PlayerZone(player)
				local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
				for i, id in helpers do
					local helper = Config.HelperById[id]
					if not timers[i] then
						timers[i] = now + helper.interval * (0.5 + math.random() * 0.5)
					elseif now >= timers[i] then
						timers[i] = now + helper.interval
						if zoneId and root and Zones.IsUnlocked(data, zoneId) then
							local kindId = if math.random() < 0.08 then "Sparkle" else "Dirt"
							local offset = Vector3.new(math.random(-4, 4), 2, math.random(-4, 4))
							Rewards.Dig(player, data, kindId, zoneId, root.Position + offset, { helper = true, helperName = helper.name })
						end
					end
				end
			end
		end
	end
end

function HelperService.Init()
	Net.Changed:Connect(HelperService.Refresh)
	Passes.Changed:Connect(HelperService.Refresh)
	DataService.Loaded:Connect(function(player)
		HelperService.Refresh(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		nextDig[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(0.25)
			tick()
		end
	end)
end

return HelperService
