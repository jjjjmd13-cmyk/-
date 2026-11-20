-- 창 관리: 열기/닫기, 데이터가 바뀌면 다시 그리기
local PanelKit = require(script.Parent.PanelKit)

local PanelFolder = script.Parent:WaitForChild("Panels")
local MODULES = {
	require(PanelFolder:WaitForChild("Collection")),
	require(PanelFolder:WaitForChild("Shop")),
	require(PanelFolder:WaitForChild("Zones")),
	require(PanelFolder:WaitForChild("Helpers")),
	require(PanelFolder:WaitForChild("Quests")),
	require(PanelFolder:WaitForChild("Rebirth")),
	require(PanelFolder:WaitForChild("Trade")),
}

local PanelManager = {}

type Entry = { module: any, panel: PanelKit.Panel, ctx: any }
local entries: { [string]: Entry } = {}
local openId: string? = nil
local snapshot: any = nil
local tradeState: any = nil

local function render(id: string)
	local entry = entries[id]
	if not entry or not snapshot then
		return
	end
	local list = entry.panel.list
	local pos = list.CanvasPosition
	entry.ctx.trade = tradeState
	entry.module.render(entry.panel, snapshot, entry.ctx)
	task.defer(function()
		list.CanvasPosition = pos
	end)
end

function PanelManager.Create(screen: ScreenGui, request: (string, ...any) -> (), invoke: (string, ...any) -> (boolean, any), refreshSnapshot: () -> ())
	for _, module in MODULES do
		local panel = PanelKit.Create(screen, module.id, module.title, module.color, module.tabs == true, function()
			PanelManager.Close()
		end)
		local ctx = {
			state = {},
			request = request,
			invoke = invoke,
			refreshSnapshot = refreshSnapshot,
			rerender = function()
				if openId == module.id then
					render(module.id)
				end
			end,
			close = function()
				PanelManager.Close()
			end,
		}
		entries[module.id] = { module = module, panel = panel, ctx = ctx }
	end
end

function PanelManager.Open(id: string)
	if openId == id then
		return
	end
	PanelManager.Close()
	local entry = entries[id]
	if not entry then
		return
	end
	openId = id
	entry.panel.frame.Visible = true
	render(id)
	if entry.module.onOpen then
		task.spawn(entry.module.onOpen, entry.panel, entry.ctx)
	end
end

function PanelManager.Toggle(id: string)
	if openId == id then
		PanelManager.Close()
	else
		PanelManager.Open(id)
	end
end

function PanelManager.Close()
	if openId and entries[openId] then
		entries[openId].panel.frame.Visible = false
	end
	openId = nil
end

function PanelManager.Update(newSnapshot: any)
	snapshot = newSnapshot
	if openId then
		render(openId)
	end
end

function PanelManager.OnCoins(coins: number)
	if snapshot then
		snapshot.coins = coins
	end
end

-- 거래 상태 (nil = 거래 안 함)
function PanelManager.SetTrade(state: any)
	if state then
		state.lockUntil = os.clock() + (state.lockLeft or 0)
	end
	tradeState = state
	if state then
		PanelManager.Open("Trade")
	end
	if openId == "Trade" then
		render("Trade")
	end
end

return PanelManager
