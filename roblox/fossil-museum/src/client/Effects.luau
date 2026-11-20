-- 흙 튀기기, 코인 숫자 떠오르기 같은 연출 (내 화면에서만)
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local Effects = {}

local folder = Instance.new("Folder")
folder.Name = "LocalEffects"
folder.Parent = workspace

function Effects.DirtBurst(position: Vector3, color: Color3, big: boolean)
	local count = if big then 12 else 4
	for _ = 1, count do
		local chunk = Instance.new("Part")
		chunk.Size = Vector3.one * (0.3 + math.random() * 0.4)
		chunk.Color = color
		chunk.Material = Enum.Material.Ground
		chunk.CanCollide = false
		chunk.CanQuery = false
		chunk.CanTouch = false
		chunk.CastShadow = false
		chunk.Position = position + Vector3.new(math.random() * 2 - 1, 1.5, math.random() * 2 - 1)
		chunk.Parent = folder
		chunk.AssemblyLinearVelocity = Vector3.new(math.random() * 16 - 8, 12 + math.random() * 10, math.random() * 16 - 8)
		Debris:AddItem(chunk, 0.9)
	end
end

function Effects.FloatText(position: Vector3, text: string, color: Color3)
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one * 0.2
	anchor.Position = position + Vector3.new(0, 3, 0)
	anchor.Parent = folder

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(160, 40)
	gui.AlwaysOnTop = true
	gui.Parent = anchor
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.2
	label.Text = text
	label.Parent = gui

	local info = TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(anchor, info, { Position = anchor.Position + Vector3.new(0, 4, 0) }):Play()
	TweenService:Create(label, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	Debris:AddItem(anchor, 1.1)
end

return Effects
