-- 📖 화석 도감: 지역별 탭, 조각 현황, 조립, 중복 판매
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Util = require(ReplicatedStorage.Shared.Util)
local Gui = require(script.Parent.Parent.Gui)
local PanelKit = require(script.Parent.Parent.PanelKit)

local Collection = {
	id = "Collection",
	title = "📖 화석 도감",
	color = Color3.fromRGB(230, 170, 80),
	tabs = true,
}

local TABS = {}
for _, zone in Config.Zones do
	table.insert(TABS, { id = zone.id, text = zone.emoji .. " " .. zone.name:gsub(" .*", ""), color = zone.barrierColor:Lerp(Color3.new(0, 0, 0), 0.3) })
end
table.insert(TABS, { id = "Event", text = "☄️ 우주", color = Color3.fromRGB(80, 60, 140) })

function Collection.render(panel: PanelKit.Panel, snapshot: any, ctx: any)
	local selected = ctx.state.zone or "Desert"
	PanelKit.SetTabs(panel, TABS, selected, function(id)
		ctx.state.zone = id
		ctx.rerender()
	end)
	PanelKit.Clear(panel)

	local progress = Economy.GetZoneProgress(snapshot)
	local total, done = 0, 0
	for _, entry in progress do
		total += entry.total
		done += entry.done
	end
	panel.subtitle.Text = string.format(
		"완성 %d/%d종 · 전시 %d/%d칸 · 수입 배수 x%.2f · ❤️ %s",
		done,
		total,
		#Economy.GetDisplayed(snapshot),
		snapshot.slots,
		Economy.GetIncomeMultiplier(snapshot, snapshot.passes),
		Util.FormatNumber(snapshot.likes)
	)

	local order = 1
	local dupValue = Economy.GetDuplicateValue(snapshot)
	local sellRow = PanelKit.Row(panel, order, 46)
	Gui.label({
		Position = UDim2.fromOffset(12, 0),
		Size = UDim2.new(1, -210, 1, 0),
		Text = "같은 조각은 1개만 있으면 돼요. 남는 조각은 팔거나 🤝 거래할 수 있어요.",
		TextColor3 = Gui.Colors.SubText,
		MaxTextSize = 15,
		ZIndex = 13,
		Parent = sellRow,
	})
	Gui.button({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.fromOffset(190, 34),
		BackgroundColor3 = if dupValue > 0 then Gui.Colors.Gold else Gui.Colors.Disabled,
		TextColor3 = Color3.fromRGB(40, 30, 10),
		Text = "전체 중복 판매 +" .. Util.FormatNumber(dupValue),
		ZIndex = 13,
		Parent = sellRow,
	}, function()
		ctx.request("SellDuplicates")
	end)

	local zoneInfo = progress[selected] or { done = 0, total = 0 }
	order += 1
	local zone = Config.ZoneById[selected]
	PanelKit.Note(
		panel,
		order,
		string.format(
			"%s 완성 %d/%d종%s · 화석 수입 x%s",
			if zone then zone.name else "운석 이벤트",
			zoneInfo.done,
			zoneInfo.total,
			if zoneInfo.done >= zoneInfo.total and zoneInfo.total > 0 then " ✅ 지역 완성 보너스 +25%" else " (모두 완성하면 수입 +25%)",
			Util.FormatNumber(Economy.ZoneMult(selected))
		)
	)

	local byRarity = Config.SpeciesByZoneRarity[selected] or {}
	for _, rarity in Config.Rarities do
		local list = byRarity[rarity.id]
		if list then
			order += 1
			PanelKit.Header(panel, order, rarity.name, rarity.color)
			for _, sp in list do
				order += 1
				local owned = snapshot.pieces[sp.id] or {}
				local completedCount = snapshot.museum[sp.id] or 0
				local pieces = Config.GetPieces(sp)
				local have = 0
				for i = 1, #pieces do
					if (owned[tostring(i)] or 0) > 0 then
						have += 1
					end
				end
				local discovered = have > 0 or completedCount > 0
				local complete = have == #pieces
				local row = PanelKit.Row(panel, order, 74, if complete then rarity.color else nil)

				Gui.label({
					Position = UDim2.fromOffset(12, 6),
					Size = UDim2.new(0.5, -12, 0, 24),
					Font = Enum.Font.FredokaOne,
					TextColor3 = if discovered then rarity.color else Gui.Colors.Disabled,
					Text = if discovered then sp.name else "???",
					MaxTextSize = 20,
					ZIndex = 13,
					Parent = row,
				})
				Gui.label({
					Position = UDim2.new(0.5, 0, 0, 8),
					Size = UDim2.new(0.5, -150, 0, 20),
					TextColor3 = Gui.Colors.SubText,
					TextXAlignment = Enum.TextXAlignment.Right,
					Text = string.format("%d/%d · 완성 %d개", have, #pieces, completedCount),
					MaxTextSize = 15,
					ZIndex = 13,
					Parent = row,
				})

				local chips = Gui.new("Frame", {
					Position = UDim2.fromOffset(12, 36),
					Size = UDim2.new(1, -160, 0, 30),
					BackgroundTransparency = 1,
					ZIndex = 13,
					Parent = row,
				}, { Gui.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4) }) })
				for i, pieceName in pieces do
					local count = owned[tostring(i)] or 0
					local chip = Gui.new("Frame", {
						Size = UDim2.new(1 / #pieces, -4, 1, 0),
						BackgroundColor3 = if count > 0 then rarity.color else Color3.fromRGB(35, 30, 26),
						BackgroundTransparency = if count > 0 then 0.25 else 0,
						ZIndex = 13,
						Parent = chips,
					}, { Gui.corner(6) })
					Gui.label({
						Size = UDim2.new(1, -6, 1, -4),
						Position = UDim2.fromOffset(3, 2),
						TextXAlignment = Enum.TextXAlignment.Center,
						TextColor3 = if count > 0 then Color3.new(1, 1, 1) else Gui.Colors.Disabled,
						TextStrokeTransparency = if count > 0 then 0.4 else 1,
						Text = if count > 1 then pieceName .. " x" .. count elseif count == 1 then pieceName else "?",
						MaxTextSize = 14,
						ZIndex = 14,
						Parent = chip,
					})
				end

				Gui.button({
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -10, 0.5, 8),
					Size = UDim2.fromOffset(130, 38),
					BackgroundColor3 = if complete then Gui.Colors.Green else Gui.Colors.Disabled,
					Text = if complete then "🦴 조립하기" else string.format("+%s/초", Util.FormatNumber(Economy.SpeciesIncome(sp))),
					AutoButtonColor = complete,
					ZIndex = 13,
					Parent = row,
				}, function()
					if complete then
						ctx.request("Assemble", sp.id)
					end
				end)
			end
		end
	end
end

return Collection
