-- 도감 / 상점 창
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Util = require(ReplicatedStorage.Shared.Util)
local Gui = require(script.Parent.Gui)

local Panels = {}

local player = Players.LocalPlayer
local request: (string, ...any) -> () = function() end
local snapshot: any = nil

type Panel = { frame: Frame, title: TextLabel, subtitle: TextLabel, list: ScrollingFrame, top: Frame }
local panels: { [string]: Panel } = {}
local openId: string? = nil

local function makePanel(screen: ScreenGui, id: string, titleText: string, color: Color3): Panel
	local frame = Gui.new("Frame", {
		Name = id,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromScale(0.62, 0.74),
		BackgroundColor3 = Gui.Colors.Panel,
		BackgroundTransparency = 0.05,
		Visible = false,
		ZIndex = 10,
		Parent = screen,
	}, {
		Gui.corner(16),
		Gui.stroke(color, 3),
		Gui.new("UISizeConstraint", { MaxSize = Vector2.new(760, 560), MinSize = Vector2.new(320, 300) }),
	})
	local title = Gui.label({
		Position = UDim2.fromOffset(16, 10),
		Size = UDim2.new(1, -80, 0, 32),
		Font = Enum.Font.FredokaOne,
		TextColor3 = color,
		Text = titleText,
		MaxTextSize = 28,
		ZIndex = 11,
		Parent = frame,
	})
	local subtitle = Gui.label({
		Position = UDim2.fromOffset(16, 42),
		Size = UDim2.new(1, -80, 0, 20),
		TextColor3 = Gui.Colors.SubText,
		Text = "",
		MaxTextSize = 15,
		ZIndex = 11,
		Parent = frame,
	})
	Gui.button({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 10),
		Size = UDim2.fromOffset(40, 40),
		BackgroundColor3 = Gui.Colors.Red,
		Text = "X",
		ZIndex = 11,
		Parent = frame,
	}, function()
		Panels.Close()
	end)
	local top = Gui.new("Frame", {
		Position = UDim2.fromOffset(16, 68),
		Size = UDim2.new(1, -32, 0, 0),
		BackgroundTransparency = 1,
		ZIndex = 11,
		Parent = frame,
	})
	local list = Gui.new("ScrollingFrame", {
		Position = UDim2.fromOffset(12, 70),
		Size = UDim2.new(1, -24, 1, -82),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 8,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ZIndex = 11,
		Parent = frame,
	}, {
		Gui.new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
		Gui.new("UIPadding", { PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4) }),
	})
	local panel = { frame = frame, title = title, subtitle = subtitle, list = list, top = top }
	panels[id] = panel
	return panel
end

local function clearList(panel: Panel)
	for _, child in panel.list:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function row(panel: Panel, order: number, height: number, color: Color3?): Frame
	return Gui.new("Frame", {
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, height),
		BackgroundColor3 = Gui.Colors.PanelLight,
		ZIndex = 12,
		Parent = panel.list,
	}, { Gui.corner(10), Gui.stroke(color or Color3.new(0, 0, 0), 1.5) })
end

local function header(panel: Panel, order: number, text: string, color: Color3)
	Gui.label({
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 28),
		Font = Enum.Font.FredokaOne,
		TextColor3 = color,
		Text = text,
		MaxTextSize = 22,
		ZIndex = 12,
		Parent = panel.list,
	})
end

----------------------------------------------------------------------
-- 도감
----------------------------------------------------------------------
local function renderCollection()
	local panel = panels.Collection
	clearList(panel)
	if not snapshot then
		return
	end

	local completedKinds = 0
	for _, count in snapshot.museum do
		if count > 0 then
			completedKinds += 1
		end
	end
	local mult = Economy.GetIncomeMultiplier(snapshot, snapshot.passes)
	panel.subtitle.Text = string.format(
		"완성 %d/%d종 · 전시 %d/%d칸 · 수입 배수 x%.2f · ❤️ %s",
		completedKinds,
		#Config.Species,
		#Economy.GetDisplayed(snapshot),
		snapshot.slots,
		mult,
		Util.FormatNumber(snapshot.likes)
	)

	local order = 0
	local dupValue = Economy.GetDuplicateValue(snapshot)
	order += 1
	local sellRow = row(panel, order, 46)
	Gui.label({
		Position = UDim2.fromOffset(12, 0),
		Size = UDim2.new(1, -210, 1, 0),
		Text = "같은 조각은 1개만 있으면 돼요. 남는 조각은 팔 수 있어요.",
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
		Text = "중복 판매 +" .. Util.FormatNumber(dupValue),
		ZIndex = 13,
		Parent = sellRow,
	}, function()
		request("SellDuplicates")
	end)

	for _, rarity in Config.Rarities do
		local species = Config.SpeciesByRarity[rarity.id] or {}
		order += 1
		header(panel, order, string.format("%s%s", rarity.name, if rarity.eventOnly then " (☄️ 운석 이벤트 전용)" else ""), rarity.color)
		for _, sp in species do
			order += 1
			local owned = snapshot.pieces[sp.id] or {}
			local displayedCount = snapshot.museum[sp.id] or 0
			local pieces = Config.GetPieces(sp)
			local have = 0
			for i = 1, #pieces do
				if (owned[tostring(i)] or 0) > 0 then
					have += 1
				end
			end
			local discovered = have > 0 or displayedCount > 0
			local r = row(panel, order, 74, if have == #pieces then rarity.color else nil)

			Gui.label({
				Position = UDim2.fromOffset(12, 6),
				Size = UDim2.new(0.5, -12, 0, 24),
				Font = Enum.Font.FredokaOne,
				TextColor3 = if discovered then rarity.color else Gui.Colors.Disabled,
				Text = if discovered then sp.name else "???",
				MaxTextSize = 20,
				ZIndex = 13,
				Parent = r,
			})
			Gui.label({
				Position = UDim2.new(0.5, 0, 0, 8),
				Size = UDim2.new(0.5, -150, 0, 20),
				TextColor3 = Gui.Colors.SubText,
				TextXAlignment = Enum.TextXAlignment.Right,
				Text = string.format("%d/%d · 완성 %d개", have, #pieces, displayedCount),
				MaxTextSize = 15,
				ZIndex = 13,
				Parent = r,
			})

			-- 조각 칸
			local chips = Gui.new("Frame", {
				Position = UDim2.fromOffset(12, 36),
				Size = UDim2.new(1, -160, 0, 30),
				BackgroundTransparency = 1,
				ZIndex = 13,
				Parent = r,
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

			local complete = have == #pieces
			Gui.button({
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -10, 0.5, 8),
				Size = UDim2.fromOffset(130, 38),
				BackgroundColor3 = if complete then Gui.Colors.Green else Gui.Colors.Disabled,
				Text = if complete then "🦴 조립하기" else string.format("+%s/초", Util.FormatNumber(rarity.income)),
				AutoButtonColor = complete,
				ZIndex = 13,
				Parent = r,
			}, function()
				if complete then
					request("Assemble", sp.id)
				end
			end)
		end
	end
end

----------------------------------------------------------------------
-- 상점
----------------------------------------------------------------------
local function renderShop()
	local panel = panels.Shop
	clearList(panel)
	if not snapshot then
		return
	end
	panel.subtitle.Text = string.format("행운 x%.2f · 삽질 간격 %.2f초", snapshot.luck, snapshot.cooldown)

	local order = 1
	header(panel, order, "⛏️ 발굴 도구", Gui.Colors.Gold)
	for _, def in Config.Tools do
		order += 1
		local owned = snapshot.ownedTools[def.id] == true
		local equipped = snapshot.tool == def.id
		local r = row(panel, order, 58, if equipped then Gui.Colors.Gold else nil)
		Gui.label({
			Position = UDim2.fromOffset(12, 6),
			Size = UDim2.new(1, -170, 0, 24),
			Font = Enum.Font.FredokaOne,
			TextColor3 = def.color,
			Text = def.name,
			MaxTextSize = 20,
			ZIndex = 13,
			Parent = r,
		})
		Gui.label({
			Position = UDim2.fromOffset(12, 32),
			Size = UDim2.new(1, -170, 0, 18),
			TextColor3 = Gui.Colors.SubText,
			Text = string.format("파워 %d · 간격 %.2f초 · 행운 +%d%%", def.power, def.cooldown, math.floor(def.luck * 100 + 0.5)),
			MaxTextSize = 14,
			ZIndex = 13,
			Parent = r,
		})
		local text, color
		if equipped then
			text, color = "사용 중", Gui.Colors.Disabled
		elseif owned then
			text, color = "장착", Gui.Colors.Blue
		else
			text = "💰 " .. Util.FormatNumber(def.price)
			color = if snapshot.coins >= def.price then Gui.Colors.Green else Gui.Colors.Disabled
		end
		Gui.button({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(140, 38),
			BackgroundColor3 = color,
			Text = text,
			ZIndex = 13,
			Parent = r,
		}, function()
			if equipped then
				return
			elseif owned then
				request("EquipTool", def.id)
			else
				request("BuyTool", def.id)
			end
		end)
	end

	order += 1
	header(panel, order, "🏛️ 박물관", Gui.Colors.Blue)
	order += 1
	local slotRow = row(panel, order, 58)
	local nextPrice = Economy.GetNextSlotPrice(snapshot)
	Gui.label({
		Position = UDim2.fromOffset(12, 6),
		Size = UDim2.new(1, -170, 0, 24),
		Font = Enum.Font.FredokaOne,
		Text = string.format("전시대 %d/%d칸", snapshot.slots, Config.MaxSlots),
		MaxTextSize = 20,
		ZIndex = 13,
		Parent = slotRow,
	})
	Gui.label({
		Position = UDim2.fromOffset(12, 32),
		Size = UDim2.new(1, -170, 0, 18),
		TextColor3 = Gui.Colors.SubText,
		Text = "전시한 화석만 관람 수입을 벌어요",
		MaxTextSize = 14,
		ZIndex = 13,
		Parent = slotRow,
	})
	Gui.button({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(140, 38),
		BackgroundColor3 = if nextPrice and snapshot.coins >= nextPrice then Gui.Colors.Green else Gui.Colors.Disabled,
		Text = if nextPrice then "+2칸 💰 " .. Util.FormatNumber(nextPrice) else "최대",
		ZIndex = 13,
		Parent = slotRow,
	}, function()
		if nextPrice then
			request("BuySlot")
		end
	end)

	order += 1
	header(panel, order, "💎 Robux 상점", Color3.fromRGB(120, 230, 120))
	for key, pass in Config.GamePasses do
		order += 1
		local r = row(panel, order, 58)
		local has = snapshot.passes[key] == true
		Gui.label({ Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -170, 0, 24), Font = Enum.Font.FredokaOne, Text = pass.name, MaxTextSize = 20, ZIndex = 13, Parent = r })
		Gui.label({ Position = UDim2.fromOffset(12, 32), Size = UDim2.new(1, -170, 0, 18), TextColor3 = Gui.Colors.SubText, Text = pass.desc .. " (게임 패스)", MaxTextSize = 14, ZIndex = 13, Parent = r })
		Gui.button({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(140, 38),
			BackgroundColor3 = if has or pass.id == 0 then Gui.Colors.Disabled else Color3.fromRGB(60, 180, 75),
			Text = if has then "보유 중" elseif pass.id == 0 then "준비 중" else "구매",
			ZIndex = 13,
			Parent = r,
		}, function()
			if not has and pass.id ~= 0 then
				MarketplaceService:PromptGamePassPurchase(player, pass.id)
			end
		end)
	end
	for key, product in Config.Products do
		order += 1
		local r = row(panel, order, 58)
		local desc
		if key == "LuckBoost" then
			desc = "행운 x1.5 (중복 구매 시 시간 연장)"
		else
			local coins = math.max(product.minCoins or 0, math.floor(snapshot.income * (product.coinsSeconds or 0)))
			desc = "지금 받으면 💰 " .. Util.FormatNumber(coins)
		end
		Gui.label({ Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -170, 0, 24), Font = Enum.Font.FredokaOne, Text = product.name, MaxTextSize = 20, ZIndex = 13, Parent = r })
		Gui.label({ Position = UDim2.fromOffset(12, 32), Size = UDim2.new(1, -170, 0, 18), TextColor3 = Gui.Colors.SubText, Text = desc, MaxTextSize = 14, ZIndex = 13, Parent = r })
		Gui.button({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(140, 38),
			BackgroundColor3 = if product.id == 0 then Gui.Colors.Disabled else Color3.fromRGB(60, 180, 75),
			Text = if product.id == 0 then "준비 중" else "구매",
			ZIndex = 13,
			Parent = r,
		}, function()
			if product.id ~= 0 then
				MarketplaceService:PromptProductPurchase(player, product.id)
			end
		end)
	end
end

----------------------------------------------------------------------
local RENDER = {
	Collection = renderCollection,
	Shop = renderShop,
}

function Panels.Create(screen: ScreenGui, requestFn: (string, ...any) -> ())
	request = requestFn
	makePanel(screen, "Collection", "📖 화석 도감", Color3.fromRGB(230, 170, 80))
	makePanel(screen, "Shop", "🛒 상점", Gui.Colors.Green)
end

function Panels.Toggle(id: string)
	if openId == id then
		Panels.Close()
		return
	end
	Panels.Close()
	local panel = panels[id]
	if panel then
		openId = id
		panel.frame.Visible = true
		RENDER[id]()
	end
end

function Panels.Close()
	if openId then
		panels[openId].frame.Visible = false
	end
	openId = nil
end

function Panels.Update(newSnapshot: any)
	snapshot = newSnapshot
	if openId then
		-- 스크롤 위치 유지
		local list = panels[openId].list
		local pos = list.CanvasPosition
		RENDER[openId]()
		task.defer(function()
			list.CanvasPosition = pos
		end)
	end
end

-- 코인이 바뀌면 상점 버튼 색만 다시 그리기 위해 전체 갱신 (상점이 열려 있을 때)
function Panels.OnCoins(coins: number)
	if snapshot then
		snapshot.coins = coins
	end
end

return Panels
