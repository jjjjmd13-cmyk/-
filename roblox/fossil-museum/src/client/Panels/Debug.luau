-- 🛠️ Studio 전용 테스트 메뉴 (실제 게임에서는 버튼이 보이지 않고, 서버도 거절함)
local Gui = require(script.Parent.Parent.Gui)
local PanelKit = require(script.Parent.Parent.PanelKit)

local Debug = {
	id = "Debug",
	title = "🛠️ 테스트 메뉴 (Studio 전용)",
	color = Color3.fromRGB(255, 120, 60),
	tabs = false,
}

local COMMANDS = {
	{ "Coins", "💰 코인 +1억", "후반 도구, 지역, 조수 사보기" },
	{ "CoinsHuge", "💰 코인 +1조", "블랙홀 드릴, 환생 여러 번 해보기" },
	{ "Zones", "🗺️ 모든 지역 열기", "빙하, 화산, 해안 바로 가보기" },
	{ "Meteor", "☄️ 운석 지금 시작", "8분 안 기다리고 운석 이벤트 확인" },
	{ "Pieces", "🦴 모든 조각 +1개", "조립, 3D 전시, NPC 손님 확인" },
	{ "Luck", "🍀 행운 부스트 15분", "희귀 화석 연출(빛기둥) 확인" },
	{ "Quests", "📜 퀘스트 모두 완료", "퀘스트 보상 받기 확인" },
	{ "NewDay", "📅 하루 지나기", "매일 보상, 새 퀘스트, 좋아요 다시 누르기" },
	{ "Likes", "❤️ 좋아요 늘리기", "좋아요 보너스, 표시 확인" },
	{ "Reset", "🧹 데이터 초기화", "처음 시작하는 사람처럼 다시 해보기" },
}

function Debug.render(panel: PanelKit.Panel, _snapshot: any, ctx: any)
	PanelKit.Clear(panel)
	panel.subtitle.Text = "이 메뉴는 Studio 에서만 보여요. 실제 게임에는 나오지 않아요."
	for i, command in COMMANDS do
		local row = PanelKit.Row(panel, i, 54)
		PanelKit.RowText(row, command[2], command[3])
		PanelKit.RowButton(row, "실행", if command[1] == "Reset" then Gui.Colors.Red else Color3.fromRGB(230, 110, 50), function()
			ctx.request("Debug", command[1])
		end)
	end
end

return Debug
