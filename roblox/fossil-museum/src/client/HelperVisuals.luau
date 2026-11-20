-- 발굴 조수 모형: 모든 플레이어의 조수를 내 화면에 그림 (서버 부담 없음)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

local HelperVisuals = {}

local folder = Instance.new("Folder")
folder.Name = "HelperVisuals"
folder.Parent = workspace

type Buddy = { model: Model, body: BasePart, offset: Vector3, phase: number, hop: number }
local buddies: { [Player]: { Buddy } } = {}

local function newPart(parent: Instance, shape: Enum.PartType, size: Vector3, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Shape = shape
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Parent = parent
	return p
end

local function buildBuddy(helper: Config.Helper): (Model, BasePart)
	local model = Instance.new("Model")
	model.Name = helper.id
	local glow = helper.price >= 25000000
	local body = newPart(model, Enum.PartType.Ball, Vector3.new(1.6, 1.6, 1.6), helper.color, if glow then Enum.Material.Neon else nil)
	body.Name = "Body"
	model.PrimaryPart = body
	local head = newPart(model, Enum.PartType.Ball, Vector3.new(1.1, 1.1, 1.1), helper.color:Lerp(Color3.new(1, 1, 1), 0.2), if glow then Enum.Material.Neon else nil)
	head.Name = "Head"
	for _, side in { -1, 1 } do
		local eye = newPart(model, Enum.PartType.Ball, Vector3.new(0.25, 0.25, 0.25), Color3.new(0.05, 0.05, 0.05))
		eye.Name = "Eye" .. side
	end
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(120, 20)
	gui.StudsOffset = Vector3.new(0, 2.2, 0)
	gui.MaxDistance = 50
	gui.Parent = body
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = helper.color
	label.TextStrokeTransparency = 0.3
	label.Text = helper.name
	label.Parent = gui
	model.Parent = folder
	return model, body
end

local function rebuild(player: Player)
	local old = buddies[player]
	if old then
		for _, buddy in old do
			buddy.model:Destroy()
		end
	end
	local list = {}
	local raw = player:GetAttribute("Helpers")
	if type(raw) == "string" and raw ~= "" then
		local ids = string.split(raw, ",")
		for i, id in ids do
			local helper = Config.HelperById[id]
			if helper then
				local model, body = buildBuddy(helper)
				-- 플레이어 뒤쪽 반원에 줄 세우기
				local angle = math.rad(180 + (i - (#ids + 1) / 2) * 35)
				table.insert(list, {
					model = model,
					body = body,
					offset = Vector3.new(math.sin(angle) * 5, 0, -math.cos(angle) * 5),
					phase = i * 1.3,
					hop = 0,
				})
			end
		end
	end
	buddies[player] = list
end

-- 조수가 흙더미를 팠을 때 깡충
function HelperVisuals.Hop(player: Player)
	local list = buddies[player]
	if list and #list > 0 then
		list[math.random(1, #list)].hop = 1
	end
end

local function watch(player: Player)
	player:GetAttributeChangedSignal("Helpers"):Connect(function()
		rebuild(player)
	end)
	rebuild(player)
end

function HelperVisuals.Init()
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		local list = buddies[player]
		if list then
			for _, buddy in list do
				buddy.model:Destroy()
			end
		end
		buddies[player] = nil
	end)

	RunService.RenderStepped:Connect(function(dt)
		local t = os.clock()
		for player, list in buddies do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root then
				local base = root.CFrame
				for _, buddy in list do
					buddy.hop = math.max(0, buddy.hop - dt * 3)
					local bob = math.sin(t * 4 + buddy.phase) * 0.25 + math.sin(buddy.hop * math.pi) * 2
					local targetPos = (base * CFrame.new(buddy.offset)).Position - Vector3.new(0, 1.8, 0) + Vector3.new(0, bob, 0)
					local current = buddy.body.Position
					local pos = current:Lerp(targetPos, math.clamp(dt * 6, 0, 1))
					if (pos - targetPos).Magnitude > 40 then
						pos = targetPos -- 순간이동했을 때 따라붙기
					end
					local look = base.LookVector * Vector3.new(1, 0, 1)
					local cf = CFrame.lookAt(pos, pos + (if look.Magnitude > 0.01 then look else Vector3.zAxis))
					buddy.body.CFrame = cf
					local head = buddy.model:FindFirstChild("Head") :: BasePart
					head.CFrame = cf * CFrame.new(0, 0.9, -0.6)
					for _, side in { -1, 1 } do
						local eye = buddy.model:FindFirstChild("Eye" .. side) :: BasePart
						eye.CFrame = head.CFrame * CFrame.new(side * 0.25, 0.15, -0.48)
					end
				end
			end
		end
	end)
end

return HelperVisuals
