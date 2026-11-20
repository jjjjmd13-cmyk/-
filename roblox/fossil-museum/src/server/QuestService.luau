-- 일일 퀘스트 + 매일 접속 보상
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Util = require(ReplicatedStorage.Shared.Util)
local DataService = require(script.Parent.DataService)
local Passes = require(script.Parent.Passes)
local Net = require(script.Parent.Net)

local QuestService = {}

-- 오늘의 퀘스트가 없으면 새로 만듦 (날짜 + UserId 로 정해짐)
local function ensureQuests(player: Player, data: any): boolean
	local today = DataService.Today()
	if data.quests.day == today and #data.quests.list > 0 then
		return false
	end
	local rng = Random.new(today * 1000003 + player.UserId % 1000003)
	local pool = {}
	for i = 1, #Config.QuestTemplates do
		table.insert(pool, i)
	end
	local list = {}
	for slot = 1, 3 do
		local pick = table.remove(pool, rng:NextInteger(1, #pool))
		local template = Config.QuestTemplates[pick]
		local tier = slot -- 쉬움, 보통, 어려움 하나씩
		table.insert(list, {
			type = template.type,
			tier = tier,
			target = template.amounts[tier],
			progress = 0,
			claimed = false,
		})
	end
	data.quests = { day = today, list = list, bonusClaimed = false }
	return true
end

function QuestService.Progress(player: Player, questType: string, amount: number?)
	local data = DataService.Get(player)
	if not data then
		return
	end
	ensureQuests(player, data)
	local completed = false
	for _, quest in data.quests.list do
		if quest.type == questType and quest.progress < quest.target then
			quest.progress = math.min(quest.target, quest.progress + (amount or 1))
			if quest.progress >= quest.target then
				completed = true
				Net.Tell(player, "📜 퀘스트 완료! 퀘스트 창에서 보상을 받으세요", Color3.fromRGB(140, 255, 140))
			end
		end
	end
	-- 진행도만 바뀌었을 때는 전송하지 않음 (퀘스트 창을 열면 새로 받아감)
	if completed then
		Net.MarkDirty(player)
	end
end

local function rewardFor(player: Player, data: any, tier: number): number
	local income = Economy.GetIncome(data, Passes.Get(player))
	return math.max(Config.QuestMinReward[tier], math.floor(income * Config.QuestRewardSeconds[tier]))
end

function QuestService.RewardFor(player: Player, data: any, tier: number): number
	return rewardFor(player, data, tier)
end

local function addCoins(data: any, coins: number)
	data.coins += coins
	data.stats.totalEarned += coins
end

Net.Handle("ClaimQuest", function(player, index)
	local data = DataService.Get(player)
	ensureQuests(player, data)
	local quest = type(index) == "number" and data.quests.list[index]
	if not quest then
		return false, "없는 퀘스트예요"
	end
	if quest.claimed then
		return false, "이미 받았어요"
	end
	if quest.progress < quest.target then
		return false, "아직 완료하지 않았어요"
	end
	quest.claimed = true
	local coins = rewardFor(player, data, quest.tier)
	addCoins(data, coins)
	local message = "📜 퀘스트 보상 💰 " .. Util.FormatNumber(coins)

	local allDone = true
	for _, q in data.quests.list do
		if not q.claimed then
			allDone = false
		end
	end
	if allDone and not data.quests.bonusClaimed then
		data.quests.bonusClaimed = true
		data.luckBoostUntil = math.max(data.luckBoostUntil, os.time()) + Config.QuestAllDoneLuckMinutes * 60
		message ..= string.format(" + 🍀 행운 부스트 %d분!", Config.QuestAllDoneLuckMinutes)
	end
	Net.MarkDirty(player)
	return true, message
end)

----------------------------------------------------------------------
-- 매일 접속 보상
----------------------------------------------------------------------
function QuestService.DailyState(data: any): (boolean, number)
	local today = DataService.Today()
	local canClaim = data.daily.last ~= today
	local nextStreak = if data.daily.last == today - 1 then data.daily.streak + 1 else 1
	if not canClaim then
		nextStreak = data.daily.streak
	end
	return canClaim, ((nextStreak - 1) % #Config.DailyRewards) + 1
end

Net.Handle("ClaimDaily", function(player)
	local data = DataService.Get(player)
	local today = DataService.Today()
	if data.daily.last == today then
		return false, "오늘 보상은 이미 받았어요. 내일 또 와요!"
	end
	local streak = if data.daily.last == today - 1 then data.daily.streak + 1 else 1
	data.daily.last = today
	data.daily.streak = streak
	local day = ((streak - 1) % #Config.DailyRewards) + 1
	local reward = Config.DailyRewards[day]
	local income = Economy.GetIncome(data, Passes.Get(player))
	local coins = math.max(reward.minCoins, math.floor(income * reward.coinsSeconds))
	addCoins(data, coins)
	local message = string.format("🎁 %d일차 보상 💰 %s", day, Util.FormatNumber(coins))
	if reward.luckMinutes then
		data.luckBoostUntil = math.max(data.luckBoostUntil, os.time()) + reward.luckMinutes * 60
		message ..= string.format(" + 🍀 행운 부스트 %d분", reward.luckMinutes)
	end
	Net.MarkDirty(player)
	return true, message
end)

Net.Handle("GetQuestRewards", function(player)
	local data = DataService.Get(player)
	if ensureQuests(player, data) then
		Net.MarkDirty(player)
	end
	local rewards = {}
	for i, quest in data.quests.list do
		rewards[i] = rewardFor(player, data, quest.tier)
	end
	local _, day = QuestService.DailyState(data)
	local reward = Config.DailyRewards[day]
	local income = Economy.GetIncome(data, Passes.Get(player))
	return true, { quests = rewards, daily = math.max(reward.minCoins, math.floor(income * reward.coinsSeconds)), dailyDay = day }
end)

function QuestService.OnLoaded(player: Player, data: any)
	ensureQuests(player, data)
end

return QuestService
