-- 게임 패스 보유 여부 (접속 시 확인하고 기억)
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Passes = {}

local owned: { [Player]: { [string]: boolean } } = {}
local changedEvent = Instance.new("BindableEvent")
Passes.Changed = changedEvent.Event -- (player)

local function check(player: Player)
	local result = { DoubleSpeed = false, DoubleLuck = false, DoubleIncome = false }
	for key, pass in Config.GamePasses do
		if pass.id ~= 0 then
			local ok, has = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.id)
			end)
			result[key] = ok and has == true
		end
	end
	owned[player] = result
	changedEvent:Fire(player)
end

function Passes.Get(player: Player): { DoubleSpeed: boolean, DoubleLuck: boolean, DoubleIncome: boolean }
	return (owned[player] or { DoubleSpeed = false, DoubleLuck = false, DoubleIncome = false }) :: any
end

function Passes.Init()
	Players.PlayerAdded:Connect(check)
	for _, player in Players:GetPlayers() do
		task.spawn(check, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		owned[player] = nil
	end)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if not purchased then
			return
		end
		for key, pass in Config.GamePasses do
			if pass.id == passId then
				local current = owned[player]
				if current then
					current[key] = true
				end
				changedEvent:Fire(player)
			end
		end
	end)
end

return Passes
