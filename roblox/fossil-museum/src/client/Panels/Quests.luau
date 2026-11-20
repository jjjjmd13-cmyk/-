-- 📜 퀘스트 + 🎁 매일 보상
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local Gui = require(script.Parent.Parent.Gui)
local PanelKit = require(script.Parent.Parent.PanelKit)

local Quests = {
	id = "Quests",
	title = "📜 퀘스트 & 매일 보상",
	color = Color3.fromRGB(255, 200, 90),
	tabs = false,
}

local TIER_NAMES = { "쉬움", "보통", "어려움" }
local TEMPLATE_BY_TYPE = {}
for _, template in Config.QuestTemplates do
	TEMPLATE_BY_TYPE[template.type] = template
end

function Quests.onOpen(_panel: PanelKit.Panel, ctx: any)
	local ok, rewards = ctx.invoke("GetQuestRewards")
	if ok and type(rewards) == "table" then
		ctx.state.rewards = rewards
	end
	ctx.refreshSnapshot()
	ctx.rerender()
end

function Quests.render(panel: PanelKit.Panel, snapshot: any, ctx: any)
	PanelKit.Clear(panel)
	local rewards = ctx.state.rewards or {}
	panel.subtitle.Text = "퀘스트는 매일 새로 바뀌어요 (한국 시간 오전 9시)"

	-- 매일 보상
	local order = 1
	PanelKit.Header(panel, order, "🎁 매일 접속 보상", Gui.Colors.Gold)
	order += 1
	local claimedToday = snapshot.daily.last == snapshot.today
	local streak = snapshot.daily.streak
	local nextStreak = if claimedToday then streak elseif snapshot.daily.last == snapshot.today - 1 then streak + 1 else 1
	local day = ((nextStreak - 1) % #Config.DailyRewards) + 1
	local dailyRow = PanelKit.Row(panel, order, 58, if claimedToday then nil else Gui.Colors.Gold)
	PanelKit.RowText(
		dailyRow,
		string.format("%d일차 보상%s", day, if Config.DailyRewards[day].luckMinutes then " + 🍀 행운 부스트" else ""),
		string.format("연속 접속 %d일 · 7일마다 큰 보상", if claimedToday then streak else nextStreak - 1)
	)
	PanelKit.RowButton(
		dailyRow,
		if claimedToday then "내일 또 와요" else "받기 💰 " .. Util.FormatNumber(rewards.daily or 0),
		if claimedToday then Gui.Colors.Disabled else Gui.Colors.Green,
		function()
			if not claimedToday then
				ctx.request("ClaimDaily")
			end
		end
	)

	-- 일일 퀘스트
	order += 1
	PanelKit.Header(panel, order, "📜 오늘의 퀘스트", Color3.fromRGB(255, 200, 90))
	local list = if snapshot.quests.day == snapshot.today then snapshot.quests.list else {}
	if #list == 0 then
		order += 1
		PanelKit.Note(panel, order, "퀘스트를 불러오는 중...")
	end
	for i, quest in list do
		order += 1
		local template = TEMPLATE_BY_TYPE[quest.type]
		local done = quest.progress >= quest.target
		local row = PanelKit.Row(panel, order, 64, if done and not quest.claimed then Gui.Colors.Green else nil)
		PanelKit.RowText(
			row,
			string.format("[%s] %s", TIER_NAMES[quest.tier] or "?", if template then string.format(template.text, quest.target) else quest.type),
			string.format("진행 %d / %d", quest.progress, quest.target)
		)
		-- 진행 막대
		local bar = Gui.new("Frame", {
			Position = UDim2.new(0, 160, 0, 36),
			Size = UDim2.new(1, -340, 0, 12),
			BackgroundColor3 = Color3.fromRGB(30, 26, 22),
			ZIndex = 13,
			Parent = row,
		}, { Gui.corner(6) })
		Gui.new("Frame", {
			Size = UDim2.fromScale(math.clamp(quest.progress / quest.target, 0, 1), 1),
			BackgroundColor3 = if done then Gui.Colors.Green else Gui.Colors.Gold,
			ZIndex = 14,
			Parent = bar,
		}, { Gui.corner(6) })
		local rewardText = "💰 " .. Util.FormatNumber(rewards.quests and rewards.quests[i] or 0)
		PanelKit.RowButton(
			row,
			if quest.claimed then "받음 ✅" elseif done then "받기 " .. rewardText else rewardText,
			if quest.claimed then Gui.Colors.Disabled elseif done then Gui.Colors.Green else Gui.Colors.PanelLight,
			function()
				if done and not quest.claimed then
					ctx.request("ClaimQuest", i)
				end
			end
		)
	end
	order += 1
	PanelKit.Note(panel, order, string.format("🍀 3개를 모두 끝내면 행운 부스트 %d분 추가!", Config.QuestAllDoneLuckMinutes))
end

return Quests
