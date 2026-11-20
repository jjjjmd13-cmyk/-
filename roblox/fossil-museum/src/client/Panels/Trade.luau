-- 🤝 거래: 플레이어 목록 → 요청 → 서로 조각/코인 올리기 → 둘 다 준비하면 교환
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local Gui = require(script.Parent.Parent.Gui)
local PanelKit = require(script.Parent.Parent.PanelKit)

local player = Players.LocalPlayer

local Trade = {
	id = "Trade",
	title = "🤝 거래",
	color = Color3.fromRGB(100, 200, 255),
	tabs = false,
}

local function pieceLabel(speciesId: string, pieceIndex: number): (string, Color3)
	local species = Config.SpeciesById[speciesId]
	if not species then
		return "?", Gui.Colors.Text
	end
	local rarity = Config.RarityById[species.rarity]
	return string.format("[%s] %s · %s", rarity.name, species.name, Config.GetPieces(species)[pieceIndex] or "?"), rarity.color
end

local function renderLobby(panel: PanelKit.Panel, ctx: any)
	panel.subtitle.Text = "같은 서버의 친구와 화석 조각, 코인을 바꿀 수 있어요"
	local order = 0
	for _, other in Players:GetPlayers() do
		if other ~= player then
			order += 1
			local row = PanelKit.Row(panel, order, 52)
			PanelKit.RowText(row, other.DisplayName, "@" .. other.Name)
			PanelKit.RowButton(row, "거래 요청", Gui.Colors.Blue, function()
				ctx.request("TradeRequest", other.UserId)
			end)
		end
	end
	if order == 0 then
		PanelKit.Note(panel, 1, "서버에 다른 플레이어가 없어요. 친구를 초대해 보세요!")
	end
	PanelKit.Note(panel, 100, "🛡️ 내용이 바뀌면 '준비'가 풀리고, 둘 다 준비해야만 교환돼요")
end

local function renderTrade(panel: PanelKit.Panel, snapshot: any, ctx: any, trade: any)
	local now = os.clock()
	panel.subtitle.Text = string.format("%s님과 거래 중 · 둘 다 '준비'를 누르면 교환돼요", trade.them.name)
	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end

	-- 상대가 주는 것
	PanelKit.Header(panel, nextOrder(), string.format("📥 %s님이 줄 것 %s", trade.them.name, if trade.them.ready then "✅ 준비됨" else "⏳"), Color3.fromRGB(140, 220, 255))
	if #trade.them.items == 0 and trade.them.coins == 0 then
		PanelKit.Note(panel, nextOrder(), "아직 아무것도 올리지 않았어요")
	end
	if trade.them.coins > 0 then
		PanelKit.Note(panel, nextOrder(), "💰 " .. Util.FormatNumber(trade.them.coins) .. " 코인")
	end
	for _, item in trade.them.items do
		local text, color = pieceLabel(item.speciesId, item.pieceIndex)
		local row = PanelKit.Row(panel, nextOrder(), 40, color)
		PanelKit.RowText(row, text .. "  x" .. item.count, nil, color, 20)
	end

	-- 내가 주는 것
	PanelKit.Header(panel, nextOrder(), string.format("📤 내가 줄 것 %s", if trade.me.ready then "✅ 준비됨" else ""), Gui.Colors.Gold)
	local myOffer: { [string]: number } = {}
	for _, item in trade.me.items do
		myOffer[item.speciesId .. "|" .. item.pieceIndex] = item.count
		local text, color = pieceLabel(item.speciesId, item.pieceIndex)
		local row = PanelKit.Row(panel, nextOrder(), 44, color)
		PanelKit.RowText(row, text .. "  x" .. item.count, nil, color, 120)
		PanelKit.RowButton(row, "빼기", Gui.Colors.Red, function()
			ctx.request("TradeSetItem", item.speciesId, item.pieceIndex, item.count - 1)
		end, 1, 100)
	end

	local coinRow = PanelKit.Row(panel, nextOrder(), 52)
	PanelKit.RowText(coinRow, "💰 코인 " .. Util.FormatNumber(trade.me.coins), "보유 " .. Util.FormatNumber(snapshot.coins), nil, 300)
	local box = Gui.new("TextBox", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -118, 0.5, 0),
		Size = UDim2.fromOffset(150, 36),
		BackgroundColor3 = Color3.fromRGB(25, 22, 18),
		TextColor3 = Color3.new(1, 1, 1),
		PlaceholderText = "코인 숫자",
		Text = "",
		Font = Enum.Font.GothamBold,
		TextScaled = true,
		ClearTextOnFocus = false,
		ZIndex = 13,
		Parent = coinRow,
	}, { Gui.corner(8), Gui.new("UITextSizeConstraint", { MaxTextSize = 18 }) })
	PanelKit.RowButton(coinRow, "올리기", Gui.Colors.Blue, function()
		local amount = tonumber((box.Text:gsub("[^%d]", "")))
		if amount then
			ctx.request("TradeSetCoins", amount)
		end
	end, 1, 100)

	-- 준비 / 취소
	local actionRow = PanelKit.Row(panel, nextOrder(), 56)
	local locked = now < (trade.lockUntil or 0)
	PanelKit.RowText(actionRow, if trade.me.ready then "상대를 기다리는 중..." else "내용을 확인했으면 준비!", nil, nil, 300)
	PanelKit.RowButton(actionRow, "❌ 취소", Gui.Colors.Red, function()
		ctx.request("TradeCancel")
	end, 1, 120)
	PanelKit.RowButton(actionRow, if trade.me.ready then "✅ 준비됨" elseif locked then "확인 중..." else "✅ 준비", if trade.me.ready or locked then Gui.Colors.Disabled else Gui.Colors.Green, function()
		if not trade.me.ready then
			ctx.request("TradeReady")
		end
	end, 2, 140)
	if locked then
		task.delay((trade.lockUntil or now) - now + 0.05, ctx.rerender)
	end

	-- 내 조각 목록
	PanelKit.Header(panel, nextOrder(), "🦴 내 조각에서 올리기 (누를 때마다 1개씩)", Gui.Colors.SubText)
	local mine = {}
	for speciesId, owned in snapshot.pieces do
		for key, count in owned do
			local pieceIndex = tonumber(key)
			if pieceIndex and count > 0 then
				table.insert(mine, { speciesId = speciesId, pieceIndex = pieceIndex, count = count })
			end
		end
	end
	table.sort(mine, function(a, b)
		local ta = Config.RarityById[Config.SpeciesById[a.speciesId].rarity].tier
		local tb = Config.RarityById[Config.SpeciesById[b.speciesId].rarity].tier
		if ta ~= tb then
			return ta > tb
		end
		return a.speciesId .. a.pieceIndex < b.speciesId .. b.pieceIndex
	end)
	for _, item in mine do
		local offered = myOffer[item.speciesId .. "|" .. item.pieceIndex] or 0
		local text, color = pieceLabel(item.speciesId, item.pieceIndex)
		local row = PanelKit.Row(panel, nextOrder(), 44)
		PanelKit.RowText(row, string.format("%s  (보유 %d)", text, item.count), nil, color, 120)
		PanelKit.RowButton(row, "+1", if offered < item.count then Gui.Colors.Green else Gui.Colors.Disabled, function()
			if offered < item.count then
				ctx.request("TradeSetItem", item.speciesId, item.pieceIndex, offered + 1)
			end
		end, 1, 100)
	end
end

function Trade.render(panel: PanelKit.Panel, snapshot: any, ctx: any)
	PanelKit.Clear(panel)
	if ctx.trade then
		renderTrade(panel, snapshot, ctx, ctx.trade)
	else
		renderLobby(panel, ctx)
	end
end

return Trade
