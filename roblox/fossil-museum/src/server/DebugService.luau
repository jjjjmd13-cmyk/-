-- 🛠️ Studio 전용 테스트 명령 (실제 게임 서버에서는 전부 거절)
-- 혼자서 후반 지역, 환생, 운석, 퀘스트까지 빠르게 확인하는 용도
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local Net = require(script.Parent.Net)
local DigService = require(script.Parent.DigService)
local Zones = require(script.Parent.Zones)

local DebugService = {}

local COMMANDS: { [string]: (Player, any) -> string } = {
	Coins = function(_, data)
		data.coins += 100000000
		return "💰 +1억 코인"
	end,
	CoinsHuge = function(_, data)
		data.coins += 1000000000000
		return "💰 +1조 코인"
	end,
	Zones = function(_, data)
		for _, zone in Config.Zones do
			data.unlockedZones[zone.id] = true
		end
		return "🗺️ 모든 지역 열림"
	end,
	Meteor = function()
		DigService.StartMeteorNow()
		return "☄️ 운석이 곧 떨어져요"
	end,
	Pieces = function(_, data)
		for _, species in Config.Species do
			local owned = data.pieces[species.id]
			if not owned then
				owned = {}
				data.pieces[species.id] = owned
			end
			for i = 1, #Config.GetPieces(species) do
				owned[tostring(i)] = (owned[tostring(i)] or 0) + 1
			end
		end
		return "🦴 모든 화석 조각 +1개씩 (도감에서 조립해 보세요)"
	end,
	Luck = function(_, data)
		data.luckBoostUntil = math.max(data.luckBoostUntil, os.time()) + 15 * 60
		return "🍀 행운 부스트 15분"
	end,
	Quests = function(_, data)
		for _, quest in data.quests.list do
			quest.progress = quest.target
		end
		return "📜 오늘 퀘스트 모두 완료 상태 (보상 받기를 눌러 보세요)"
	end,
	NewDay = function(_, data)
		data.daily.last = DataService.Today() - 1
		data.quests.day = 0
		data.likedGiven = {}
		return "📅 하루가 지난 것처럼: 매일 보상, 퀘스트, 좋아요 초기화 (퀘스트 창을 다시 열어 보세요)"
	end,
	Likes = function(_, data)
		data.likes += 10
		data.npcLikes += 50
		return "❤️ 좋아요 +10, 🧑 손님 좋아요 +50"
	end,
	Reset = function(player)
		DataService.Reset(player)
		DigService.GiveTool(player)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local desert = Zones.Get("Desert")
		if root and desert then
			root.CFrame = desert.spawn
		end
		return "🧹 데이터를 처음 상태로 초기화했어요"
	end,
}

Net.Handle("Debug", function(player, command)
	if not RunService:IsStudio() then
		return false, "테스트 메뉴는 Studio 에서만 쓸 수 있어요"
	end
	local fn = type(command) == "string" and COMMANDS[command]
	if not fn then
		return false, "없는 명령이에요"
	end
	local data = DataService.Get(player)
	local message = fn(player, data)
	Net.MarkDirty(player)
	return true, "🛠️ " .. message
end)

return DebugService
