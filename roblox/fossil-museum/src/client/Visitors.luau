-- 🧑 NPC 관람객: 박물관마다 손님들이 돌아다니며 화석을 구경 (내 화면에서만 그림, 서버 부담 없음)
-- 손님 수는 박물관 매력도(전시한 화석 등급의 합)에 따라 늘어나요.
-- 실제 좋아요 판정은 서버가 하고, 여기서는 하트 연출만 보여줘요.
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Visitors = {}

local folder = Instance.new("Folder")
folder.Name = "Visitors"
folder.Parent = workspace

local MAX_PER_PLOT = 6
local WALK_SPEED = 4
local VIEW_DISTANCE = 220 -- 이보다 먼 박물관의 손님은 움직이지 않음

-- 전시대 위치 (WorldBuilder.PedestalOffsets 와 같은 배치, 앞쪽 = -Z)
local PEDESTALS = {}
for _, z in { -13, -3, 7, 17 } do
	for _, x in { -15, -5, 5, 15 } do
		table.insert(PEDESTALS, Vector3.new(x, 0, z))
	end
end

local SHIRTS = {
	Color3.fromRGB(220, 80, 80),
	Color3.fromRGB(80, 140, 220),
	Color3.fromRGB(90, 180, 100),
	Color3.fromRGB(230, 190, 70),
	Color3.fromRGB(160, 100, 200),
	Color3.fromRGB(240, 140, 60),
	Color3.fromRGB(70, 190, 190),
}
local SKINS = {
	Color3.fromRGB(255, 220, 180),
	Color3.fromRGB(230, 185, 140),
	Color3.fromRGB(190, 140, 100),
	Color3.fromRGB(130, 90, 60),
}

type Visitor = {
	model: Model,
	pos: Vector3, -- 박물관 기준 로컬 위치
	target: Vector3,
	waitUntil: number,
	phase: number,
}
type PlotState = { plot: Model, visitors: { Visitor } }
local states: { [Model]: PlotState } = {}

local function newPart(model: Model, size: Vector3, color: Color3, cf: CFrame, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	if shape then
		p.Shape = shape
	end
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Parent = model
	return p
end

-- 발 아래가 원점인 단순한 사람 모형
local function buildVisitor(): Model
	local model = Instance.new("Model")
	model.Name = "Visitor"
	local shirt = SHIRTS[math.random(1, #SHIRTS)]
	local skin = SKINS[math.random(1, #SKINS)]
	local pants = Color3.fromRGB(math.random(40, 90), math.random(40, 90), math.random(60, 120))
	local root = newPart(model, Vector3.new(0.2, 0.2, 0.2), skin, CFrame.identity)
	root.Name = "Root"
	root.Transparency = 1
	model.PrimaryPart = root
	newPart(model, Vector3.new(0.55, 1.6, 0.6), pants, CFrame.new(-0.32, 0.8, 0)).Name = "LegL"
	newPart(model, Vector3.new(0.55, 1.6, 0.6), pants, CFrame.new(0.32, 0.8, 0)).Name = "LegR"
	newPart(model, Vector3.new(1.3, 1.5, 0.7), shirt, CFrame.new(0, 2.35, 0))
	newPart(model, Vector3.new(0.35, 1.3, 0.4), shirt, CFrame.new(-0.85, 2.4, 0))
	newPart(model, Vector3.new(0.35, 1.3, 0.4), shirt, CFrame.new(0.85, 2.4, 0))
	newPart(model, Vector3.new(0.9, 0.9, 0.9), skin, CFrame.new(0, 3.55, 0), Enum.PartType.Ball)
	-- 가끔 모자
	if math.random() < 0.4 then
		newPart(model, Vector3.new(1, 0.25, 1), shirt:Lerp(Color3.new(0, 0, 0), 0.4), CFrame.new(0, 4.0, 0))
	end
	model.Parent = folder
	return model
end

local function randomTarget(displayed: number): Vector3
	if displayed > 0 and math.random() < 0.8 then
		-- 전시된 화석 앞에 서서 구경
		local ped = PEDESTALS[math.random(1, math.min(displayed, #PEDESTALS))]
		return ped + Vector3.new(math.random(-20, 20) / 10, 0, -4.2)
	end
	return Vector3.new(math.random(-18, 18), 0, math.random(-20, 0))
end

local function syncCount(state: PlotState)
	local plot = state.plot
	local owner = plot:GetAttribute("OwnerUserId")
	local appeal = plot:GetAttribute("Appeal") or 0
	local want = 0
	if owner and owner ~= 0 and appeal > 0 then
		want = math.clamp(1 + appeal // 6, 1, MAX_PER_PLOT)
	end
	while #state.visitors > want do
		table.remove(state.visitors).model:Destroy()
	end
	local displayed = plot:GetAttribute("Displayed") or 0
	while #state.visitors < want do
		-- 입구에서 들어옴
		local start = Vector3.new(math.random(-6, 6), 0, -22)
		table.insert(state.visitors, {
			model = buildVisitor(),
			pos = start,
			target = randomTarget(displayed),
			waitUntil = 0,
			phase = math.random() * 10,
		})
	end
end

local function watchPlot(plot: Model)
	if states[plot] then
		return
	end
	local state = { plot = plot, visitors = {} }
	states[plot] = state
	for _, attr in { "OwnerUserId", "Appeal", "Displayed" } do
		plot:GetAttributeChangedSignal(attr):Connect(function()
			syncCount(state)
		end)
	end
	syncCount(state)
end

-- 서버가 NPC 좋아요를 줬을 때 하트 연출
function Visitors.Heart(plotIndex: number)
	for plot, state in states do
		if plot:GetAttribute("Index") == plotIndex then
			local floor = plot:FindFirstChild("Floor") :: BasePart?
			local visitor = state.visitors[math.random(1, math.max(1, #state.visitors))]
			local position
			if visitor then
				position = visitor.model:GetPivot().Position + Vector3.new(0, 5, 0)
			elseif floor then
				position = floor.Position + Vector3.new(0, 6, 0)
			else
				return
			end
			local anchor = Instance.new("Part")
			anchor.Anchored = true
			anchor.CanCollide = false
			anchor.CanQuery = false
			anchor.CanTouch = false
			anchor.Transparency = 1
			anchor.Size = Vector3.one * 0.2
			anchor.Position = position
			anchor.Parent = folder
			local gui = Instance.new("BillboardGui")
			gui.Size = UDim2.fromOffset(60, 60)
			gui.MaxDistance = 150
			gui.Parent = anchor
			local label = Instance.new("TextLabel")
			label.Size = UDim2.fromScale(1, 1)
			label.BackgroundTransparency = 1
			label.TextScaled = true
			label.Text = "❤️"
			label.Parent = gui
			local info = TweenInfo.new(1.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			TweenService:Create(anchor, info, { Position = position + Vector3.new(0, 5, 0) }):Play()
			TweenService:Create(label, info, { TextTransparency = 1 }):Play()
			task.delay(1.7, function()
				anchor:Destroy()
			end)
			return
		end
	end
end

function Visitors.Init()
	task.spawn(function()
		local root = workspace:WaitForChild("FossilWorld")
		for _, child in root:GetChildren() do
			if child:IsA("Model") and child:GetAttribute("OwnerUserId") ~= nil then
				watchPlot(child)
			end
		end
		root.ChildAdded:Connect(function(child)
			if child:IsA("Model") and child:GetAttribute("OwnerUserId") ~= nil then
				watchPlot(child)
			end
		end)
	end)

	RunService.Heartbeat:Connect(function(dt)
		local camera = workspace.CurrentCamera
		local camPos = if camera then camera.CFrame.Position else Vector3.zero
		local now = os.clock()
		for plot, state in states do
			local floor = plot:FindFirstChild("Floor") :: BasePart?
			if floor and #state.visitors > 0 then
				local base = floor.CFrame * CFrame.new(0, floor.Size.Y / 2, 0)
				local near = (base.Position - camPos).Magnitude < VIEW_DISTANCE
				local displayed = plot:GetAttribute("Displayed") or 0
				for _, v in state.visitors do
					local walking = false
					if near then
						local toTarget = v.target - v.pos
						if now < v.waitUntil then
							walking = false
						elseif toTarget.Magnitude < 0.2 then
							v.waitUntil = now + 2 + math.random() * 4 -- 화석 앞에서 잠깐 구경
							v.target = randomTarget(displayed)
						else
							walking = true
							v.pos += toTarget.Unit * math.min(toTarget.Magnitude, WALK_SPEED * dt)
						end
					end
					-- 바라보는 방향: 걸을 때는 가는 쪽, 서 있을 때는 전시대 쪽(+Z)
					local face = if walking then (v.target - v.pos) else Vector3.new(0, 0, 1)
					if face.Magnitude < 0.01 then
						face = Vector3.new(0, 0, 1)
					end
					local localCf = CFrame.lookAt(v.pos, v.pos + Vector3.new(face.X, 0, face.Z))
					local bob = if walking then math.abs(math.sin(now * 8 + v.phase)) * 0.15 else 0
					v.model:PivotTo(base * localCf * CFrame.new(0, bob, 0))
					-- 다리 흔들기
					local swing = if walking then math.sin(now * 8 + v.phase) * 0.5 else 0
					local legL = v.model:FindFirstChild("LegL") :: BasePart?
					local legR = v.model:FindFirstChild("LegR") :: BasePart?
					local pivot = v.model:GetPivot()
					if legL and legR then
						legL.CFrame = pivot * CFrame.new(-0.32, 1.6, 0) * CFrame.Angles(swing, 0, 0) * CFrame.new(0, -0.8, 0)
						legR.CFrame = pivot * CFrame.new(0.32, 1.6, 0) * CFrame.Angles(-swing, 0, 0) * CFrame.new(0, -0.8, 0)
					end
				end
			end
		end
	end)
end

return Visitors
