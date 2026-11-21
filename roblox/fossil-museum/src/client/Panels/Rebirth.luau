-- 🔁 환생
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local Gui = require(script.Parent.Parent.Gui)
local PanelKit = require(script.Parent.Parent.PanelKit)

local Rebirth = {
	id = "Rebirth",
	title = "🔁 환생",
	color = Color3.fromRGB(255, 140, 255),
	tabs = false,
	feature = "Rebirth",
}

function Rebirth.render(panel: PanelKit.Panel, snapshot: any, ctx: any)
	PanelKit.Clear(panel)
	local r = snapshot.rebirths
	panel.subtitle.Text = string.format("지금까지 %d번 환생했어요", r)

	local function bonusLine(count: number): string
		return string.format(
			"박물관 수입 +%d%% · 발굴 코인 +%d%% · 행운 +%d%%",
			math.floor(count * Config.Rebirth.incomeBonus * 100),
			math.floor(count * Config.Rebirth.coinBonus * 100),
			math.floor(count * Config.Rebirth.luckBonus * 100 + 0.5)
		)
	end

	PanelKit.Header(panel, 1, "지금 보너스", Color3.fromRGB(255, 140, 255))
	PanelKit.Note(panel, 2, bonusLine(r))
	PanelKit.Header(panel, 3, "다음 환생 후 보너스", Color3.fromRGB(255, 200, 255))
	PanelKit.Note(panel, 4, bonusLine(r + 1))

	PanelKit.Header(panel, 5, "⚠️ 환생하면", Gui.Colors.Red)
	PanelKit.Note(panel, 6, "초기화: 코인, 발굴 도구, 열린 지역, 전시대 칸 수")
	PanelKit.Note(panel, 7, "유지: 화석 조각, 완성한 화석, 좋아요, 발굴 조수, 게임 패스")

	local price = snapshot.rebirthPrice
	local can = snapshot.coins >= price
	local row = PanelKit.Row(panel, 8, 64, if can then Color3.fromRGB(255, 140, 255) else nil)
	PanelKit.RowText(row, string.format("%d번째 환생", r + 1), string.format("필요한 코인 💰 %s (지금 %s)", Util.FormatNumber(price), Util.FormatNumber(snapshot.coins)), nil, 220)
	local button: TextButton
	button = PanelKit.RowButton(row, if can then "환생하기" else "코인 부족", if can then Color3.fromRGB(200, 80, 220) else Gui.Colors.Disabled, function()
		if not can then
			return
		end
		-- 두 번 눌러야 환생 (실수 방지)
		if ctx.state.confirm then
			ctx.state.confirm = false
			ctx.request("Rebirth")
		else
			ctx.state.confirm = true
			button.Text = "정말요? 한 번 더!"
			task.delay(3, function()
				ctx.state.confirm = false
				if button.Parent then
					button.Text = "환생하기"
				end
			end)
		end
	end, 1, 180)
end

return Rebirth
