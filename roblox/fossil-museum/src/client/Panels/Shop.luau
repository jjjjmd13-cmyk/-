-- 🛒 상점: 도구, 전시대, Robux
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Util = require(ReplicatedStorage.Shared.Util)
local Gui = require(script.Parent.Parent.Gui)
local PanelKit = require(script.Parent.Parent.PanelKit)

local player = Players.LocalPlayer

local Shop = {
	id = "Shop",
	title = "🛒 상점",
	color = Color3.fromRGB(70, 190, 90),
	tabs = true,
}

local TABS = {
	{ id = "Tools", text = "⛏️ 도구" },
	{ id = "Museum", text = "🏛️ 박물관" },
	{ id = "Robux", text = "💎 Robux", color = Color3.fromRGB(60, 160, 75) },
}

local function sorted(map: { [string]: any }): { { key: string, value: any } }
	local list = {}
	for key, value in map do
		table.insert(list, { key = key, value = value })
	end
	table.sort(list, function(a, b)
		return (a.value.order or 0) < (b.value.order or 0)
	end)
	return list
end

local function renderTools(panel: PanelKit.Panel, snapshot: any, ctx: any)
	local order = 0
	for _, def in Config.Tools do
		order += 1
		local owned = snapshot.ownedTools[def.id] == true
		local equipped = snapshot.tool == def.id
		local row = PanelKit.Row(panel, order, 58, if equipped then Gui.Colors.Gold else nil)
		PanelKit.RowText(row, def.name, string.format("파워 %d · 간격 %.2f초 · 행운 +%d%%", def.power, def.cooldown, math.floor(def.luck * 100 + 0.5)), def.color)
		local text, color
		if equipped then
			text, color = "사용 중", Gui.Colors.Disabled
		elseif owned then
			text, color = "장착", Gui.Colors.Blue
		else
			text = "💰 " .. Util.FormatNumber(def.price)
			color = if snapshot.coins >= def.price then Gui.Colors.Green else Gui.Colors.Disabled
		end
		PanelKit.RowButton(row, text, color, function()
			if equipped then
				return
			elseif owned then
				ctx.request("EquipTool", def.id)
			else
				ctx.request("BuyTool", def.id)
			end
		end)
	end
end

local function renderMuseum(panel: PanelKit.Panel, snapshot: any, ctx: any)
	local row = PanelKit.Row(panel, 1, 58)
	local nextPrice = Economy.GetNextSlotPrice(snapshot)
	PanelKit.RowText(row, string.format("전시대 %d/%d칸", snapshot.slots, Config.MaxSlots), "전시한 화석만 관람 수입을 벌어요 (수입이 높은 화석부터 자동 전시)")
	PanelKit.RowButton(row, if nextPrice then "+2칸 💰 " .. Util.FormatNumber(nextPrice) else "최대", if nextPrice and snapshot.coins >= nextPrice then Gui.Colors.Green else Gui.Colors.Disabled, function()
		if nextPrice then
			ctx.request("BuySlot")
		end
	end)

	PanelKit.Header(panel, 2, "📈 지금 내 수입 보너스", Gui.Colors.Gold)
	local unique, zonesDone = 0, 0
	for _, count in snapshot.museum do
		if count > 0 then
			unique += 1
		end
	end
	for _, entry in Economy.GetZoneProgress(snapshot) do
		if entry.done >= entry.total then
			zonesDone += 1
		end
	end
	local lines = {
		string.format("❤️ 좋아요 %d개 + 🧑 손님 좋아요 %d개 → +%d%% (100개 넘으면 천천히, 한도 없음)", snapshot.likes, snapshot.npcLikes or 0, math.floor(Economy.GetLikeBonus(snapshot) * 100)),
		string.format("🦴 완성한 화석 %d종 → +%d%%", unique, math.floor(unique * Config.UniqueBonus * 100)),
		string.format("🗺️ 완성한 지역 %d곳 → +%d%%", zonesDone, math.floor(zonesDone * Config.ZoneCompleteBonus * 100)),
		string.format("🔁 환생 %d회 → +%d%%", snapshot.rebirths, math.floor(snapshot.rebirths * Config.Rebirth.incomeBonus * 100)),
		if snapshot.passes.DoubleIncome then "🏛️ 수입 2배 패스 → x2" else "🏛️ 수입 2배 패스 없음",
	}
	for i, line in lines do
		PanelKit.Note(panel, 2 + i, line)
	end
end

local function renderRobux(panel: PanelKit.Panel, snapshot: any, ctx: any)
	local order = 1
	PanelKit.Header(panel, order, "게임 패스 (한 번 사면 영원히)", Color3.fromRGB(120, 230, 120))
	for _, entry in sorted(Config.GamePasses) do
		order += 1
		local key, pass = entry.key, entry.value
		local row = PanelKit.Row(panel, order, 58)
		local has = snapshot.passes[key] == true
		PanelKit.RowText(row, pass.name, pass.desc)
		if key == "AutoDig" and has then
			PanelKit.RowButton(row, if snapshot.autoDig then "켜짐 ✅" else "꺼짐", if snapshot.autoDig then Gui.Colors.Green else Gui.Colors.Disabled, function()
				ctx.request("ToggleAutoDig")
			end)
		else
			PanelKit.RowButton(row, if has then "보유 중" elseif pass.id == 0 then "준비 중" else "구매", if has or pass.id == 0 then Gui.Colors.Disabled else Color3.fromRGB(60, 180, 75), function()
				if not has and pass.id ~= 0 then
					MarketplaceService:PromptGamePassPurchase(player, pass.id)
				end
			end)
		end
	end
	order += 1
	PanelKit.Header(panel, order, "아이템", Color3.fromRGB(120, 230, 120))
	for _, entry in sorted(Config.Products) do
		order += 1
		local key, product = entry.key, entry.value
		local row = PanelKit.Row(panel, order, 58)
		local desc
		if key == "LuckBoost" then
			desc = "내 행운 x1.5 (여러 번 사면 시간이 늘어나요)"
		elseif key == "ServerLuck" then
			desc = "이 서버 모든 사람의 행운 x2! 다들 고마워해요"
		else
			local coins = math.max(product.minCoins or 0, math.floor(snapshot.income * (product.coinsSeconds or 0)))
			desc = "지금 받으면 💰 " .. Util.FormatNumber(coins)
		end
		PanelKit.RowText(row, product.name, desc)
		PanelKit.RowButton(row, if product.id == 0 then "준비 중" else "구매", if product.id == 0 then Gui.Colors.Disabled else Color3.fromRGB(60, 180, 75), function()
			if product.id ~= 0 then
				MarketplaceService:PromptProductPurchase(player, product.id)
			end
		end)
	end
end

function Shop.render(panel: PanelKit.Panel, snapshot: any, ctx: any)
	local selected = ctx.state.tab or "Tools"
	PanelKit.SetTabs(panel, TABS, selected, function(id)
		ctx.state.tab = id
		ctx.rerender()
	end)
	PanelKit.Clear(panel)
	panel.subtitle.Text = string.format("행운 x%.2f · 삽질 간격 %.2f초 · 💰 %s", snapshot.luck, snapshot.cooldown, Util.FormatNumber(snapshot.coins))
	if selected == "Tools" then
		renderTools(panel, snapshot, ctx)
	elseif selected == "Museum" then
		renderMuseum(panel, snapshot, ctx)
	else
		renderRobux(panel, snapshot, ctx)
	end
end

return Shop
