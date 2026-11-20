-- 🗺️ 발굴 지역: 열기, 이동
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Util = require(ReplicatedStorage.Shared.Util)
local Gui = require(script.Parent.Parent.Gui)
local PanelKit = require(script.Parent.Parent.PanelKit)

local Zones = {
	id = "Zones",
	title = "🗺️ 발굴 지역",
	color = Color3.fromRGB(110, 190, 255),
	tabs = false,
}

function Zones.render(panel: PanelKit.Panel, snapshot: any, ctx: any)
	PanelKit.Clear(panel)
	panel.subtitle.Text = "지역이 멀수록 흙더미가 단단하지만, 화석 수입과 코인이 훨씬 많아요"
	local progress = Economy.GetZoneProgress(snapshot)

	local museumRow = PanelKit.Row(panel, 0, 58, Gui.Colors.Blue)
	PanelKit.RowText(museumRow, "🏛️ 내 박물관", "완성한 화석이 전시된 곳")
	PanelKit.RowButton(museumRow, "이동", Gui.Colors.Blue, function()
		ctx.close()
		ctx.request("Teleport", "Museum")
	end)

	for i, zone in Config.Zones do
		local unlocked = snapshot.unlockedZones[zone.id] == true
		local previous = Config.Zones[i - 1]
		local canUnlock = not previous or snapshot.unlockedZones[previous.id] == true
		local info = progress[zone.id] or { done = 0, total = 0 }
		local row = PanelKit.Row(panel, i, 74, if unlocked then zone.barrierColor else nil)
		local sub = string.format(
			"화석 수입 x%s · 코인 x%s · 흙더미 체력 x%s · 완성 %d/%d종",
			Util.FormatNumber(zone.incomeMult),
			Util.FormatNumber(zone.coinMult),
			tostring(zone.hpMult),
			info.done,
			info.total
		)
		PanelKit.RowText(row, zone.emoji .. " " .. zone.name, sub, if unlocked then zone.barrierColor else Gui.Colors.Text)
		if unlocked then
			PanelKit.RowButton(row, "이동", Gui.Colors.Blue, function()
				ctx.close()
				ctx.request("Teleport", zone.id)
			end)
		elseif not canUnlock then
			PanelKit.RowButton(row, "🔒 이전 지역 먼저", Gui.Colors.Disabled, function() end)
		else
			PanelKit.RowButton(row, "열기 💰 " .. Util.FormatNumber(zone.price), if snapshot.coins >= zone.price then Gui.Colors.Green else Gui.Colors.Disabled, function()
				ctx.request("BuyZone", zone.id)
			end)
		end
	end
	PanelKit.Note(panel, 100, "💡 환생하면 지역이 다시 잠기지만, 영구 보너스로 훨씬 빨리 다시 열 수 있어요")
end

return Zones
