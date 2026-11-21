-- 🦖 발굴 조수: 고용, 데리고 다니기
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Util = require(ReplicatedStorage.Shared.Util)
local Gui = require(script.Parent.Parent.Gui)
local PanelKit = require(script.Parent.Parent.PanelKit)

local Helpers = {
	id = "Helpers",
	title = "🦖 발굴 조수",
	color = Color3.fromRGB(120, 210, 100),
	tabs = false,
	feature = "Helpers",
}

function Helpers.render(panel: PanelKit.Panel, snapshot: any, ctx: any)
	PanelKit.Clear(panel)
	local slots = snapshot.helperSlots
	panel.subtitle.Text = string.format("데리고 다니는 조수 %d/%d마리 · 내가 서 있는 지역에서 알아서 흙더미를 파요", #snapshot.helpersEquipped, slots)

	local order = 1
	PanelKit.Header(panel, order, "함께 다니는 조수", Gui.Colors.Gold)
	if #snapshot.helpersEquipped == 0 then
		order += 1
		PanelKit.Note(panel, order, "아직 없어요. 아래에서 고용해 보세요!")
	end
	for _, id in snapshot.helpersEquipped do
		local helper = Config.HelperById[id]
		if helper then
			order += 1
			local row = PanelKit.Row(panel, order, 50, helper.color)
			PanelKit.RowText(row, helper.name, nil, helper.color)
			PanelKit.RowButton(row, "쉬게 하기", Gui.Colors.Red, function()
				ctx.request("UnequipHelper", id)
			end)
		end
	end

	order += 1
	PanelKit.Header(panel, order, "고용하기", Color3.fromRGB(120, 210, 100))
	for _, helper in Config.Helpers do
		order += 1
		local owned = snapshot.helpersOwned[helper.id] or 0
		local equipped = Economy.CountEquipped(snapshot, helper.id)
		local row = PanelKit.Row(panel, order, 58)
		PanelKit.RowText(
			row,
			helper.name .. (if owned > 0 then string.format("  (보유 %d)", owned) else ""),
			string.format("%.1f초마다 흙더미 1개 · 조각 확률 %d%%", helper.interval, math.floor(Config.HelperPieceChance * 100)),
			helper.color,
			320
		)
		PanelKit.RowButton(row, "💰 " .. Util.FormatNumber(helper.price), if snapshot.coins >= helper.price then Gui.Colors.Green else Gui.Colors.Disabled, function()
			ctx.request("BuyHelper", helper.id)
		end)
		if owned > equipped then
			PanelKit.RowButton(row, "데리고 다니기", if #snapshot.helpersEquipped < slots then Gui.Colors.Blue else Gui.Colors.Disabled, function()
				ctx.request("EquipHelper", helper.id)
			end, 2)
		end
	end
	order += 1
	PanelKit.Note(panel, order, if snapshot.passes.ExtraHelpers then "✅ 조수 칸 +2 패스 적용 중" else "💎 상점의 '조수 칸 +2' 패스로 조수를 더 데리고 다닐 수 있어요")
end

return Helpers
