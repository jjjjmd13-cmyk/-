-- 창(패널) 공통 부품: 틀, 탭, 목록 줄, 버튼
local Gui = require(script.Parent.Gui)

local PanelKit = {}

export type Panel = {
	id: string,
	frame: Frame,
	title: TextLabel,
	subtitle: TextLabel,
	tabs: Frame,
	list: ScrollingFrame,
}

function PanelKit.Create(screen: ScreenGui, id: string, titleText: string, color: Color3, hasTabs: boolean, onClose: () -> ()): Panel
	local frame = Gui.new("Frame", {
		Name = id,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.53),
		Size = UDim2.fromScale(0.66, 0.76),
		BackgroundColor3 = Gui.Colors.Panel,
		BackgroundTransparency = 0.04,
		Visible = false,
		ZIndex = 10,
		Parent = screen,
	}, {
		Gui.corner(16),
		Gui.stroke(color, 3),
		Gui.new("UISizeConstraint", { MaxSize = Vector2.new(780, 580), MinSize = Vector2.new(330, 300) }),
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
	}, onClose)
	local tabs = Gui.new("Frame", {
		Name = "Tabs",
		Position = UDim2.fromOffset(12, 68),
		Size = UDim2.new(1, -24, 0, if hasTabs then 34 else 0),
		BackgroundTransparency = 1,
		Visible = hasTabs,
		ZIndex = 11,
		Parent = frame,
	}, { Gui.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6) }) })
	local top = if hasTabs then 108 else 70
	local list = Gui.new("ScrollingFrame", {
		Position = UDim2.fromOffset(12, top),
		Size = UDim2.new(1, -24, 1, -(top + 12)),
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
	return { id = id, frame = frame, title = title, subtitle = subtitle, tabs = tabs, list = list }
end

function PanelKit.Clear(panel: Panel)
	for _, child in panel.list:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

function PanelKit.SetTabs(panel: Panel, tabs: { { id: string, text: string, color: Color3? } }, selected: string, onSelect: (string) -> ())
	for _, child in panel.tabs:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	for i, tab in tabs do
		Gui.button({
			LayoutOrder = i,
			Size = UDim2.new(1 / #tabs, -6, 1, 0),
			BackgroundColor3 = if tab.id == selected then (tab.color or Gui.Colors.Blue) else Gui.Colors.PanelLight,
			Text = tab.text,
			MaxTextSize = 16,
			ZIndex = 12,
			Parent = panel.tabs,
		}, function()
			onSelect(tab.id)
		end)
	end
end

function PanelKit.Row(panel: Panel, order: number, height: number, strokeColor: Color3?): Frame
	return Gui.new("Frame", {
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, height),
		BackgroundColor3 = Gui.Colors.PanelLight,
		ZIndex = 12,
		Parent = panel.list,
	}, { Gui.corner(10), Gui.stroke(strokeColor or Color3.new(0, 0, 0), 1.5) })
end

function PanelKit.Header(panel: Panel, order: number, text: string, color: Color3)
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

function PanelKit.Note(panel: Panel, order: number, text: string)
	Gui.label({
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 22),
		TextColor3 = Gui.Colors.SubText,
		Text = text,
		MaxTextSize = 15,
		ZIndex = 12,
		Parent = panel.list,
	})
end

-- 줄 왼쪽 위 큰 글씨 + 아래 작은 글씨
function PanelKit.RowText(row: Frame, title: string, sub: string?, titleColor: Color3?, rightSpace: number?)
	local space = rightSpace or 170
	Gui.label({
		Position = UDim2.fromOffset(12, 6),
		Size = UDim2.new(1, -space, 0, 24),
		Font = Enum.Font.FredokaOne,
		TextColor3 = titleColor or Gui.Colors.Text,
		Text = title,
		MaxTextSize = 20,
		ZIndex = 13,
		Parent = row,
	})
	if sub then
		Gui.label({
			Position = UDim2.fromOffset(12, 32),
			Size = UDim2.new(1, -space, 0, 18),
			TextColor3 = Gui.Colors.SubText,
			Text = sub,
			MaxTextSize = 14,
			ZIndex = 13,
			Parent = row,
		})
	end
end

-- 줄 오른쪽 버튼. slot = 오른쪽에서 몇 번째 (1부터)
function PanelKit.RowButton(row: Frame, text: string, color: Color3, onClick: () -> (), slot: number?, width: number?): TextButton
	local w = width or 140
	local index = (slot or 1) - 1
	return Gui.button({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10 - index * (w + 8), 0.5, 0),
		Size = UDim2.fromOffset(w, 38),
		BackgroundColor3 = color,
		Text = text,
		ZIndex = 13,
		Parent = row,
	}, onClick)
end

return PanelKit
