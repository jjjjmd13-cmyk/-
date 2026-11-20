-- UI 만들기 도우미
local Gui = {}

Gui.Colors = {
	Panel = Color3.fromRGB(30, 26, 22),
	PanelLight = Color3.fromRGB(52, 45, 38),
	Text = Color3.fromRGB(255, 245, 225),
	SubText = Color3.fromRGB(200, 185, 160),
	Gold = Color3.fromRGB(255, 205, 70),
	Green = Color3.fromRGB(70, 190, 90),
	Blue = Color3.fromRGB(70, 140, 230),
	Red = Color3.fromRGB(220, 70, 70),
	Disabled = Color3.fromRGB(90, 85, 80),
}

-- Gui.new("Frame", { Size = ..., Parent = ... }, { 자식들 })
function Gui.new(className: string, props: { [string]: any }?, children: { Instance }?): any
	local inst = Instance.new(className)
	local parent = nil
	if props then
		for key, value in props do
			if key == "Parent" then
				parent = value
			else
				(inst :: any)[key] = value
			end
		end
	end
	if children then
		for _, child in children do
			child.Parent = inst
		end
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

function Gui.corner(radius: number?): UICorner
	return Gui.new("UICorner", { CornerRadius = UDim.new(0, radius or 10) })
end

function Gui.stroke(color: Color3?, thickness: number?): UIStroke
	return Gui.new("UIStroke", {
		Color = color or Color3.new(0, 0, 0),
		Thickness = thickness or 2,
		Transparency = 0.3,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function Gui.padding(px: number): UIPadding
	return Gui.new("UIPadding", {
		PaddingLeft = UDim.new(0, px),
		PaddingRight = UDim.new(0, px),
		PaddingTop = UDim.new(0, px),
		PaddingBottom = UDim.new(0, px),
	})
end

function Gui.label(props: { [string]: any }): TextLabel
	local defaults = {
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextColor3 = Gui.Colors.Text,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
	}
	for k, v in props do
		defaults[k] = v
	end
	local children = { Gui.new("UITextSizeConstraint", { MaxTextSize = props.MaxTextSize or 22 }) }
	defaults.MaxTextSize = nil
	return Gui.new("TextLabel", defaults, children)
end

function Gui.button(props: { [string]: any }, onClick: () -> ()): TextButton
	local defaults = {
		BackgroundColor3 = Gui.Colors.Blue,
		Font = Enum.Font.FredokaOne,
		TextColor3 = Color3.new(1, 1, 1),
		TextScaled = true,
		AutoButtonColor = true,
	}
	for k, v in props do
		defaults[k] = v
	end
	local maxText = props.MaxTextSize or 20
	defaults.MaxTextSize = nil
	local button = Gui.new("TextButton", defaults, {
		Gui.corner(8),
		Gui.stroke(Color3.new(0, 0, 0), 1.5),
		Gui.new("UITextSizeConstraint", { MaxTextSize = maxText }),
		Gui.new("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6), PaddingTop = UDim.new(0, 3), PaddingBottom = UDim.new(0, 3) }),
	})
	button.Activated:Connect(onClick)
	return button
end

return Gui
