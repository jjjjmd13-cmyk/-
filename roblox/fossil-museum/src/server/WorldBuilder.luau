-- 맵 자동 생성: 땅, 발굴장, 박물관 부지 8개
-- Studio 에서 맵을 직접 꾸미고 싶다면 이 파일의 숫자/색을 바꾸거나
-- 생성된 파트 주변에 장식을 추가하세요.
local Lighting = game:GetService("Lighting")

local WorldBuilder = {}

export type World = {
	root: Folder,
	field: Folder,
	spots: { Vector3 }, -- 흙더미 위치
	meteorRing: { inner: number, outer: number },
	plots: { Model },
	fieldSpawn: CFrame,
}

local PLOT_COUNT = 8
local PLOT_RADIUS = 150
local PLOT_SIZE = 48
local FIELD_GRID = 10
local FIELD_SPACING = 9

-- 전시대 위치 (박물관 기준 로컬 좌표, 앞쪽 = -Z)
WorldBuilder.PedestalOffsets = {}
for _, z in { -13, -3, 7, 17 } do
	for _, x in { -15, -5, 5, 15 } do
		table.insert(WorldBuilder.PedestalOffsets, Vector3.new(x, 0, z))
	end
end

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if props.Shape then
		p.Shape = props.Shape
	end
	for key, value in props do
		if key ~= "Parent" and key ~= "Shape" then
			(p :: any)[key] = value
		end
	end
	p.Parent = props.Parent
	return p
end

local function label(parent: Instance, face: Enum.NormalId, text: string, color: Color3): TextLabel
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = parent
	local tl = Instance.new("TextLabel")
	tl.Name = "Text"
	tl.Size = UDim2.fromScale(1, 1)
	tl.BackgroundTransparency = 1
	tl.TextScaled = true
	tl.Font = Enum.Font.FredokaOne
	tl.TextColor3 = color
	tl.TextStrokeTransparency = 0.3
	tl.Text = text
	tl.Parent = gui
	return tl
end

local function buildPlot(parent: Instance, index: number, cf: CFrame): Model
	local plot = Instance.new("Model")
	plot.Name = "Plot" .. index
	plot:SetAttribute("Index", index)
	plot:SetAttribute("OwnerUserId", 0)

	local half = PLOT_SIZE / 2
	local marble = Color3.fromRGB(235, 230, 220)
	local trim = Color3.fromRGB(180, 150, 100)

	local floor = part({
		Name = "Floor",
		Size = Vector3.new(PLOT_SIZE, 1, PLOT_SIZE),
		CFrame = cf * CFrame.new(0, 0.5, 0),
		Material = Enum.Material.Marble,
		Color = marble,
		Parent = plot,
	})
	plot.PrimaryPart = floor

	-- 뒷벽, 옆벽
	part({ Name = "WallBack", Size = Vector3.new(PLOT_SIZE, 10, 1), CFrame = cf * CFrame.new(0, 6, half - 0.5), Material = Enum.Material.Marble, Color = Color3.fromRGB(215, 205, 190), Parent = plot })
	part({ Name = "WallLeft", Size = Vector3.new(1, 6, PLOT_SIZE), CFrame = cf * CFrame.new(-half + 0.5, 4, 0), Material = Enum.Material.Marble, Color = Color3.fromRGB(215, 205, 190), Parent = plot })
	part({ Name = "WallRight", Size = Vector3.new(1, 6, PLOT_SIZE), CFrame = cf * CFrame.new(half - 0.5, 4, 0), Material = Enum.Material.Marble, Color = Color3.fromRGB(215, 205, 190), Parent = plot })

	-- 입구 기둥
	for _, x in { -half + 2, -8, 8, half - 2 } do
		local pillar = part({ Name = "Pillar", Shape = Enum.PartType.Cylinder, Size = Vector3.new(12, 2.4, 2.4), CFrame = cf * CFrame.new(x, 7, -half + 1.5) * CFrame.Angles(0, 0, math.rad(90)), Material = Enum.Material.Marble, Color = marble, Parent = plot })
		pillar.CastShadow = true
	end
	part({ Name = "Lintel", Size = Vector3.new(PLOT_SIZE, 1.5, 3), CFrame = cf * CFrame.new(0, 13.75, -half + 1.5), Material = Enum.Material.Marble, Color = trim, Parent = plot })

	-- 간판 (입구 위)
	local sign = part({ Name = "Sign", Size = Vector3.new(22, 4, 0.6), CFrame = cf * CFrame.new(0, 16.5, -half + 1.5), Material = Enum.Material.Wood, Color = Color3.fromRGB(110, 75, 45), Parent = plot })
	local title = label(sign, Enum.NormalId.Front, "빈 박물관", Color3.fromRGB(255, 240, 200))
	title.Name = "Title"

	-- 좋아요 받침대 (입구 옆)
	local likeStand = part({ Name = "LikeStand", Size = Vector3.new(3, 4, 3), CFrame = cf * CFrame.new(-11, 2, -half - 2), Material = Enum.Material.Marble, Color = Color3.fromRGB(255, 120, 150), Parent = plot })
	label(likeStand, Enum.NormalId.Front, "❤️", Color3.new(1, 1, 1)).Name = "Likes"
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "LikePrompt"
	prompt.ActionText = "좋아요 ❤️"
	prompt.ObjectText = "박물관"
	prompt.HoldDuration = 0.4
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = likeStand

	-- 전시대
	local pedestals = Instance.new("Folder")
	pedestals.Name = "Pedestals"
	pedestals.Parent = plot
	for i, offset in WorldBuilder.PedestalOffsets do
		local ped = part({
			Name = tostring(i),
			Size = Vector3.new(6, 2, 6),
			CFrame = cf * CFrame.new(offset + Vector3.new(0, 2, 0)),
			Material = Enum.Material.Marble,
			Color = Color3.fromRGB(200, 195, 185),
			Parent = pedestals,
		})
		ped.Transparency = 0.6
	end

	local displays = Instance.new("Folder")
	displays.Name = "Displays"
	displays.Parent = plot

	local entry = part({ Name = "Entry", Size = Vector3.new(2, 1, 2), CFrame = cf * CFrame.new(0, 3.5, -half + 6), Transparency = 1, CanCollide = false, CanQuery = false, Parent = plot })
	entry.CanTouch = false

	plot.Parent = parent
	return plot
end

function WorldBuilder.Build(): World
	local existing = workspace:FindFirstChild("FossilWorld")
	if existing then
		existing:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = "FossilWorld"
	root.Parent = workspace

	-- 기본 Baseplate 는 숨김
	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate and baseplate:IsA("BasePart") then
		baseplate.Transparency = 1
		baseplate.CanCollide = false
		baseplate.CanQuery = false
	end

	part({ Name = "Ground", Size = Vector3.new(800, 4, 800), CFrame = CFrame.new(0, -2, 0), Material = Enum.Material.Sand, Color = Color3.fromRGB(226, 198, 140), Parent = root })

	-- 발굴장 바닥 (어두운 흙)
	local fieldSize = FIELD_GRID * FIELD_SPACING + 12
	part({ Name = "FieldFloor", Size = Vector3.new(fieldSize, 0.2, fieldSize), CFrame = CFrame.new(0, 0.1, 0), Material = Enum.Material.Ground, Color = Color3.fromRGB(150, 110, 75), Parent = root })

	-- 울타리
	local fenceColor = Color3.fromRGB(120, 85, 50)
	local halfField = fieldSize / 2
	for _, side in { { 0, -1 }, { 0, 1 }, { -1, 0 }, { 1, 0 } } do
		local sx, sz = side[1], side[2]
		local alongX = sz ~= 0
		local size = if alongX then Vector3.new(fieldSize, 1, 0.6) else Vector3.new(0.6, 1, fieldSize)
		part({ Name = "Fence", Size = size, CFrame = CFrame.new(sx * halfField, 2, sz * halfField), Material = Enum.Material.WoodPlanks, Color = fenceColor, CanCollide = false, Parent = root })
		for t = -halfField, halfField, 10 do
			local pos = if alongX then Vector3.new(t, 1.5, sz * halfField) else Vector3.new(sx * halfField, 1.5, t)
			part({ Name = "Post", Size = Vector3.new(0.8, 3, 0.8), CFrame = CFrame.new(pos), Material = Enum.Material.Wood, Color = fenceColor, CanCollide = false, Parent = root })
		end
	end

	-- 발굴장 간판
	local fieldSign = part({ Name = "FieldSign", Size = Vector3.new(16, 4, 0.6), CFrame = CFrame.new(0, 6, -halfField - 4), Material = Enum.Material.Wood, Color = Color3.fromRGB(110, 75, 45), Parent = root })
	label(fieldSign, Enum.NormalId.Front, "⛏️ 발굴장 ⛏️", Color3.fromRGB(255, 230, 160))
	label(fieldSign, Enum.NormalId.Back, "⛏️ 발굴장 ⛏️", Color3.fromRGB(255, 230, 160))
	part({ Name = "SignPost", Size = Vector3.new(0.8, 4, 0.8), CFrame = CFrame.new(-6, 2, -halfField - 4), Material = Enum.Material.Wood, Color = fenceColor, Parent = root })
	part({ Name = "SignPost", Size = Vector3.new(0.8, 4, 0.8), CFrame = CFrame.new(6, 2, -halfField - 4), Material = Enum.Material.Wood, Color = fenceColor, Parent = root })

	local field = Instance.new("Folder")
	field.Name = "DigField"
	field.Parent = root

	local spots = {}
	local start = -(FIELD_GRID - 1) * FIELD_SPACING / 2
	for gx = 0, FIELD_GRID - 1 do
		for gz = 0, FIELD_GRID - 1 do
			table.insert(spots, Vector3.new(start + gx * FIELD_SPACING, 0, start + gz * FIELD_SPACING))
		end
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "FieldSpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.CFrame = CFrame.new(0, 0.5, -halfField - 12)
	spawn.Material = Enum.Material.Slate
	spawn.Color = Color3.fromRGB(180, 160, 120)
	spawn.Duration = 0
	spawn.Parent = root

	-- 박물관 부지 + 길
	local plots = {}
	for i = 1, PLOT_COUNT do
		local angle = (i - 1) / PLOT_COUNT * math.pi * 2
		local pos = Vector3.new(math.cos(angle) * PLOT_RADIUS, 0, math.sin(angle) * PLOT_RADIUS)
		local cf = CFrame.lookAt(pos, Vector3.zero) -- 입구(-Z)가 발굴장을 향함
		table.insert(plots, buildPlot(root, i, cf))

		local pathStart = pos.Unit * (halfField + 2)
		local pathEnd = pos.Unit * (PLOT_RADIUS - PLOT_SIZE / 2 - 1)
		local mid = (pathStart + pathEnd) / 2
		local len = (pathEnd - pathStart).Magnitude
		part({ Name = "Path", Size = Vector3.new(7, 0.2, len), CFrame = CFrame.lookAt(mid + Vector3.new(0, 0.1, 0), pathEnd + Vector3.new(0, 0.1, 0)), Material = Enum.Material.Cobblestone, Color = Color3.fromRGB(170, 160, 145), CanQuery = false, Parent = root })
	end

	-- 분위기
	Lighting.ClockTime = 14.5
	Lighting.Brightness = 2.5
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 140, 125)

	return {
		root = root,
		field = field,
		spots = spots,
		meteorRing = { inner = halfField + 18, outer = halfField + 40 },
		plots = plots,
		fieldSpawn = spawn.CFrame + Vector3.new(0, 3, 0),
	}
end

return WorldBuilder
