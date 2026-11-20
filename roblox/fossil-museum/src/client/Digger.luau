-- 삽을 들고 클릭/터치(누르고 있기)하면 흙더미를 팜
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

local Digger = {}

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local digRemote = remotes:WaitForChild("Dig") :: RemoteEvent

local getCooldown: () -> number = function()
	return 0.5
end
local onTooFar: () -> () = function() end

local equippedTool: Tool? = nil
local holding = false
local digging = false

local highlight = Instance.new("Highlight")
highlight.FillTransparency = 0.75
highlight.FillColor = Color3.fromRGB(255, 230, 120)
highlight.OutlineColor = Color3.fromRGB(255, 240, 180)
highlight.DepthMode = Enum.HighlightDepthMode.Occluded
highlight.Parent = workspace

local function targetMound(): BasePart?
	local target = mouse.Target
	if target and CollectionService:HasTag(target, "DigMound") and target.Transparency < 1 then
		return target
	end
	return nil
end

local function inRange(part: BasePart): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return root ~= nil and (root.Position - part.Position).Magnitude <= Config.DigRange - 0.5
end

local function digLoop()
	if digging then
		return
	end
	digging = true
	local lastWarn = 0
	while holding and equippedTool and equippedTool.Parent == player.Character do
		local mound = targetMound()
		if mound then
			if inRange(mound) then
				digRemote:FireServer(mound)
				-- 손맛: 도구를 살짝 흔들기
				local tool = equippedTool
				local grip = tool.Grip
				tool.Grip = grip * CFrame.Angles(math.rad(-35), 0, 0)
				task.delay(0.12, function()
					if tool.Parent then
						tool.Grip = grip
					end
				end)
			elseif os.clock() - lastWarn > 2 then
				lastWarn = os.clock()
				onTooFar()
			end
		end
		task.wait(getCooldown())
	end
	digging = false
end

local function hookTool(tool: Tool)
	if tool:GetAttribute("Hooked") then
		return
	end
	tool:SetAttribute("Hooked", true)
	tool.Equipped:Connect(function()
		equippedTool = tool
	end)
	tool.Unequipped:Connect(function()
		if equippedTool == tool then
			equippedTool = nil
		end
		holding = false
	end)
	tool.Activated:Connect(function()
		holding = true
		task.spawn(digLoop)
	end)
	tool.Deactivated:Connect(function()
		holding = false
	end)
end

local function watch(container: Instance)
	container.ChildAdded:Connect(function(child)
		if child:IsA("Tool") and child:GetAttribute("DigTool") then
			hookTool(child)
			if child.Parent == player.Character then
				equippedTool = child
			end
		end
	end)
	for _, child in container:GetChildren() do
		if child:IsA("Tool") and child:GetAttribute("DigTool") then
			hookTool(child)
		end
	end
end

function Digger.Init(cooldownFn: () -> number, tooFarFn: () -> ())
	getCooldown = cooldownFn
	onTooFar = tooFarFn

	local function onCharacter(character: Model)
		equippedTool = nil
		holding = false
		watch(character)
		local backpack = player:WaitForChild("Backpack")
		watch(backpack)
	end
	player.CharacterAdded:Connect(onCharacter)
	player.ChildAdded:Connect(function(child)
		if child:IsA("Backpack") then
			watch(child)
		end
	end)
	if player.Character then
		onCharacter(player.Character)
	end

	-- 마우스를 올린 흙더미 강조
	RunService.RenderStepped:Connect(function()
		if equippedTool and equippedTool.Parent == player.Character then
			local mound = targetMound()
			highlight.Adornee = mound
			if mound then
				highlight.OutlineColor = if inRange(mound) then Color3.fromRGB(255, 240, 180) else Color3.fromRGB(255, 90, 90)
			end
		else
			highlight.Adornee = nil
		end
	end)
end

return Digger
