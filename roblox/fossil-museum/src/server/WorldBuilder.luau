-- 맵 자동 생성: 땅, 발굴 지역 4곳, 박물관 부지 8개, 랭킹 보드
-- 맵을 직접 꾸미고 싶다면 숫자/색을 바꾸거나, 생성된 파트 주변에 장식을 추가하세요.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)

local WorldBuilder = {}

export type ZoneWorld = {
	id: string,
	center: Vector3,
	half: number, -- 이 범위(정사각형) 안에 있으면 이 지역에 있는 것
	spots: { Vector3 },
	meteorRing: { inner: number, outer: number },
	spawn: CFrame,
	field: Folder,
}

export type World = {
	root: Folder,
	zones: { [string]: ZoneWorld },
	plots: { Model },
	boards: { [string]: BasePart },
}

local PLOT_COUNT = Config.PlotCount
local PLOT_RADIUS = 150
local PLOT_SIZE = 48
local ZONE_RADIUS = 330
local SPACING = 9

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

local function label(parent: Instance, face: Enum.NormalId, text: string, color: Color3, name: string?): TextLabel
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = parent
	local tl = Instance.new("TextLabel")
	tl.Name = name or "Text"
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

----------------------------------------------------------------------
-- 박물관 부지
----------------------------------------------------------------------
local function buildPlot(parent: Instance, index: number, cf: CFrame): Model
	local plot = Instance.new("Model")
	plot.Name = "Plot" .. index
	plot:SetAttribute("Index", index)
	plot:SetAttribute("OwnerUserId", 0)

	local half = PLOT_SIZE / 2
	local marble = Color3.fromRGB(235, 230, 220)
	local wall = Color3.fromRGB(215, 205, 190)
	local trim = Color3.fromRGB(180, 150, 100)

	local floor = part({ Name = "Floor", Size = Vector3.new(PLOT_SIZE, 1, PLOT_SIZE), CFrame = cf * CFrame.new(0, 0.5, 0), Material = Enum.Material.Marble, Color = marble, Parent = plot })
	plot.PrimaryPart = floor

	part({ Name = "WallBack", Size = Vector3.new(PLOT_SIZE, 10, 1), CFrame = cf * CFrame.new(0, 6, half - 0.5), Material = Enum.Material.Marble, Color = wall, Parent = plot })
	part({ Name = "WallLeft", Size = Vector3.new(1, 6, PLOT_SIZE), CFrame = cf * CFrame.new(-half + 0.5, 4, 0), Material = Enum.Material.Marble, Color = wall, Parent = plot })
	part({ Name = "WallRight", Size = Vector3.new(1, 6, PLOT_SIZE), CFrame = cf * CFrame.new(half - 0.5, 4, 0), Material = Enum.Material.Marble, Color = wall, Parent = plot })

	for _, x in { -half + 2, -8, 8, half - 2 } do
		part({ Name = "Pillar", Shape = Enum.PartType.Cylinder, Size = Vector3.new(12, 2.4, 2.4), CFrame = cf * CFrame.new(x, 7, -half + 1.5) * CFrame.Angles(0, 0, math.rad(90)), Material = Enum.Material.Marble, Color = marble, Parent = plot })
	end
	part({ Name = "Lintel", Size = Vector3.new(PLOT_SIZE, 1.5, 3), CFrame = cf * CFrame.new(0, 13.75, -half + 1.5), Material = Enum.Material.Marble, Color = trim, Parent = plot })

	local sign = part({ Name = "Sign", Size = Vector3.new(22, 4, 0.6), CFrame = cf * CFrame.new(0, 16.5, -half + 1.5), Material = Enum.Material.Wood, Color = Color3.fromRGB(110, 75, 45), Parent = plot })
	label(sign, Enum.NormalId.Front, "빈 박물관", Color3.fromRGB(255, 240, 200), "Title")

	local likeStand = part({ Name = "LikeStand", Size = Vector3.new(3, 4, 3), CFrame = cf * CFrame.new(-11, 2, -half - 2), Material = Enum.Material.Marble, Color = Color3.fromRGB(255, 120, 150), Parent = plot })
	label(likeStand, Enum.NormalId.Front, "❤️", Color3.new(1, 1, 1), "Likes")
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "LikePrompt"
	prompt.ActionText = "좋아요 ❤️"
	prompt.ObjectText = "박물관"
	prompt.HoldDuration = 0.4
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = likeStand

	local pedestals = Instance.new("Folder")
	pedestals.Name = "Pedestals"
	pedestals.Parent = plot
	for i, offset in WorldBuilder.PedestalOffsets do
		part({ Name = tostring(i), Size = Vector3.new(6, 2, 6), CFrame = cf * CFrame.new(offset + Vector3.new(0, 2, 0)), Material = Enum.Material.Marble, Color = Color3.fromRGB(200, 195, 185), Transparency = 0.6, Parent = pedestals })
	end

	local displays = Instance.new("Folder")
	displays.Name = "Displays"
	displays.Parent = plot

	part({ Name = "Entry", Size = Vector3.new(2, 1, 2), CFrame = cf * CFrame.new(0, 3.5, -half + 6), Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false, Parent = plot })

	plot.Parent = parent
	return plot
end

----------------------------------------------------------------------
-- 발굴 지역
----------------------------------------------------------------------
local function decorate(root: Instance, zone: Config.Zone, center: Vector3, inner: number, outer: number, avoid: Vector3)
	local rng = Random.new(zone.id:len() * 7919)
	-- 입구(사막 쪽 길) 방향은 비워 둠
	local function ringPos(): Vector3
		for _ = 1, 20 do
			local a = rng:NextNumber() * math.pi * 2
			local dir = Vector3.new(math.cos(a), 0, math.sin(a))
			if dir:Dot(avoid) < 0.8 then
				local r = inner + rng:NextNumber() * (outer - inner)
				return center + dir * r
			end
		end
		return center - avoid * outer
	end
	if zone.id == "Glacier" then
		for _ = 1, 14 do
			local h = rng:NextNumber(8, 16)
			part({ Name = "IceSpike", Size = Vector3.new(3, h, 3), CFrame = CFrame.new(ringPos() + Vector3.new(0, h / 2 - 1, 0)) * CFrame.Angles(rng:NextNumber(-0.25, 0.25), rng:NextNumber(0, 6), rng:NextNumber(-0.25, 0.25)), Material = Enum.Material.Ice, Color = Color3.fromRGB(170, 220, 255), Transparency = 0.2, Parent = root })
		end
	elseif zone.id == "Volcano" then
		for _ = 1, 7 do
			local d = rng:NextNumber(8, 14)
			part({ Name = "Lava", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, d, d), CFrame = CFrame.new(ringPos() + Vector3.new(0, 0.25, 0)) * CFrame.Angles(0, 0, math.rad(90)), Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 100, 20), CanCollide = false, Parent = root })
		end
		for _ = 1, 10 do
			local s = rng:NextNumber(3, 7)
			part({ Name = "Rock", Shape = Enum.PartType.Ball, Size = Vector3.new(s, s, s), CFrame = CFrame.new(ringPos()), Material = Enum.Material.Basalt, Color = Color3.fromRGB(40, 35, 35), Parent = root })
		end
		local fire = Instance.new("Fire")
		fire.Size = 20
		fire.Heat = 15
		fire.Parent = part({ Name = "Vent", Size = Vector3.new(6, 1, 6), CFrame = CFrame.new(center + (center.Unit * (outer + 6)) + Vector3.new(0, 0.5, 0)), Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 120, 30), Parent = root })
	elseif zone.id == "Coast" then
		local out = center.Unit
		local sea = part({ Name = "Sea", Size = Vector3.new(220, 1, 60), CFrame = CFrame.lookAt(center + out * (outer + 30), center + out * (outer + 31)) + Vector3.new(0, -0.3, 0), Material = Enum.Material.Glass, Color = Color3.fromRGB(40, 140, 220), Transparency = 0.25, CanCollide = false, Parent = root })
		sea.CanQuery = false
		for _ = 1, 8 do
			local pos = ringPos()
			part({ Name = "PalmTrunk", Size = Vector3.new(1.2, 12, 1.2), CFrame = CFrame.new(pos + Vector3.new(0, 6, 0)) * CFrame.Angles(0.12, rng:NextNumber(0, 6), 0), Material = Enum.Material.Wood, Color = Color3.fromRGB(130, 95, 60), Parent = root })
			for k = 0, 4 do
				part({ Name = "PalmLeaf", Size = Vector3.new(7, 0.3, 1.6), CFrame = CFrame.new(pos + Vector3.new(0, 12, 0)) * CFrame.Angles(0, k * 1.26, 0) * CFrame.new(3, 0, 0) * CFrame.Angles(0, 0, -0.35), Material = Enum.Material.Grass, Color = Color3.fromRGB(60, 160, 70), CanCollide = false, Parent = root })
			end
		end
	end
end

local function buildZone(root: Folder, zone: Config.Zone, center: Vector3, grid: number): ZoneWorld
	local folder = Instance.new("Folder")
	folder.Name = zone.id
	folder.Parent = root

	local span = (grid - 1) * SPACING
	local fieldSize = span + 12
	local fieldHalf = fieldSize / 2
	local wallHalf = fieldHalf + 9
	local patch = wallHalf * 2 + 40

	-- 지역 바닥
	if zone.id ~= "Desert" then
		part({ Name = "ZoneGround", Size = Vector3.new(patch, 0.2, patch), CFrame = CFrame.new(center + Vector3.new(0, 0.05, 0)), Material = zone.groundMaterial, Color = zone.groundColor:Lerp(Color3.new(1, 1, 1), 0.15), CanQuery = false, Parent = folder })
	end
	part({ Name = "FieldFloor", Size = Vector3.new(fieldSize, 0.2, fieldSize), CFrame = CFrame.new(center + Vector3.new(0, 0.12, 0)), Material = zone.groundMaterial, Color = zone.groundColor, Parent = folder })

	local toDesert = if center.Magnitude > 1 then -center.Unit else Vector3.new(0, 0, -1)

	if zone.price <= 0 then
		-- 울타리
		local fenceColor = Color3.fromRGB(120, 85, 50)
		for _, side in { { 0, -1 }, { 0, 1 }, { -1, 0 }, { 1, 0 } } do
			local sx, sz = side[1], side[2]
			local alongX = sz ~= 0
			local size = if alongX then Vector3.new(fieldSize, 1, 0.6) else Vector3.new(0.6, 1, fieldSize)
			part({ Name = "Fence", Size = size, CFrame = CFrame.new(center + Vector3.new(sx * fieldHalf, 2, sz * fieldHalf)), Material = Enum.Material.WoodPlanks, Color = fenceColor, CanCollide = false, Parent = folder })
			for t = -fieldHalf, fieldHalf, 10 do
				local offset = if alongX then Vector3.new(t, 1.5, sz * fieldHalf) else Vector3.new(sx * fieldHalf, 1.5, t)
				part({ Name = "Post", Size = Vector3.new(0.8, 3, 0.8), CFrame = CFrame.new(center + offset), Material = Enum.Material.Wood, Color = fenceColor, CanCollide = false, Parent = folder })
			end
		end
	else
		-- 잠금 벽 (잠긴 플레이어의 화면에서만 단단해짐 → 클라이언트가 처리)
		local barrier = Instance.new("Folder")
		barrier.Name = "Barrier"
		barrier:SetAttribute("Zone", zone.id)
		barrier.Parent = folder
		local text = string.format("🔒 %s %s\n💰 %s 코인으로 열기", zone.emoji, zone.name, Util.FormatNumber(zone.price))
		for _, side in { { 0, -1 }, { 0, 1 }, { -1, 0 }, { 1, 0 } } do
			local sx, sz = side[1], side[2]
			local alongX = sz ~= 0
			local size = if alongX then Vector3.new(wallHalf * 2, 14, 1) else Vector3.new(1, 14, wallHalf * 2)
			local wall = part({ Name = "Wall", Size = size, CFrame = CFrame.new(center + Vector3.new(sx * wallHalf, 7, sz * wallHalf)), Material = Enum.Material.ForceField, Color = zone.barrierColor, Transparency = 0.3, CanCollide = false, CanQuery = false, Parent = barrier })
			for _, face in { Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right } do
				local isLong = (alongX and (face == Enum.NormalId.Front or face == Enum.NormalId.Back)) or (not alongX and (face == Enum.NormalId.Left or face == Enum.NormalId.Right))
				if isLong then
					local gui = Instance.new("SurfaceGui")
					gui.Face = face
					gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
					gui.PixelsPerStud = 12
					gui.Parent = wall
					local tl = Instance.new("TextLabel")
					tl.Size = UDim2.fromScale(1, 0.5)
					tl.Position = UDim2.fromScale(0, 0.25)
					tl.BackgroundTransparency = 1
					tl.TextScaled = true
					tl.Font = Enum.Font.FredokaOne
					tl.TextColor3 = Color3.new(1, 1, 1)
					tl.TextStrokeTransparency = 0.2
					tl.Text = text
					tl.Parent = gui
				end
			end
		end
	end

	-- 지역 간판
	local signPos = center + toDesert * (wallHalf + 5)
	local sign = part({ Name = "ZoneSign", Size = Vector3.new(18, 4, 0.6), CFrame = CFrame.lookAt(signPos + Vector3.new(0, 7, 0), signPos + Vector3.new(0, 7, 0) + toDesert), Material = Enum.Material.Wood, Color = Color3.fromRGB(110, 75, 45), Parent = folder })
	label(sign, Enum.NormalId.Front, zone.emoji .. " " .. zone.name, Color3.fromRGB(255, 230, 160))
	label(sign, Enum.NormalId.Back, zone.emoji .. " " .. zone.name, Color3.fromRGB(255, 230, 160))

	local field = Instance.new("Folder")
	field.Name = "Mounds"
	field.Parent = folder

	local spots = {}
	local start = -span / 2
	for gx = 0, grid - 1 do
		for gz = 0, grid - 1 do
			table.insert(spots, center + Vector3.new(start + gx * SPACING, 0, start + gz * SPACING))
		end
	end

	if zone.id ~= "Desert" then
		decorate(folder, zone, center, wallHalf + 4, patch / 2 - 2, toDesert)
	end

	-- 들어가는 위치: 벽 안쪽, 사막 방향
	local spawnPos = center + toDesert * (fieldHalf + 3) + Vector3.new(0, 3, 0)
	return {
		id = zone.id,
		center = center,
		half = wallHalf,
		spots = spots,
		meteorRing = { inner = fieldHalf + 1.5, outer = wallHalf - 2.5 },
		spawn = CFrame.lookAt(spawnPos, Vector3.new(center.X, spawnPos.Y, center.Z)),
		field = field,
	}
end

----------------------------------------------------------------------
-- 랭킹 보드
----------------------------------------------------------------------
local function buildBoard(root: Instance, name: string, title: string, color: Color3, cf: CFrame): BasePart
	local board = part({ Name = name, Size = Vector3.new(14, 16, 1), CFrame = cf, Material = Enum.Material.Wood, Color = Color3.fromRGB(60, 45, 30), Parent = root })
	part({ Name = "Leg", Size = Vector3.new(1, 4, 1), CFrame = cf * CFrame.new(-5, -9, 0), Material = Enum.Material.Wood, Color = Color3.fromRGB(60, 45, 30), Parent = root })
	part({ Name = "Leg", Size = Vector3.new(1, 4, 1), CFrame = cf * CFrame.new(5, -9, 0), Material = Enum.Material.Wood, Color = Color3.fromRGB(60, 45, 30), Parent = root })
	local gui = Instance.new("SurfaceGui")
	gui.Name = "BoardGui"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.Parent = board
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Size = UDim2.fromScale(1, 0.12)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = Enum.Font.FredokaOne
	titleLabel.TextScaled = true
	titleLabel.TextColor3 = color
	titleLabel.Text = title
	titleLabel.Parent = gui
	local list = Instance.new("TextLabel")
	list.Name = "List"
	list.Position = UDim2.fromScale(0.05, 0.14)
	list.Size = UDim2.fromScale(0.9, 0.84)
	list.BackgroundTransparency = 1
	list.Font = Enum.Font.GothamBold
	list.TextScaled = true
	list.TextColor3 = Color3.new(1, 1, 1)
	list.TextXAlignment = Enum.TextXAlignment.Left
	list.TextYAlignment = Enum.TextYAlignment.Top
	list.Text = "불러오는 중..."
	list.Parent = gui
	return board
end

----------------------------------------------------------------------
function WorldBuilder.Build(): World
	local existing = workspace:FindFirstChild("FossilWorld")
	if existing then
		existing:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = "FossilWorld"
	root.Parent = workspace

	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate and baseplate:IsA("BasePart") then
		baseplate.Transparency = 1
		baseplate.CanCollide = false
		baseplate.CanQuery = false
	end

	part({ Name = "Ground", Size = Vector3.new(1100, 4, 1100), CFrame = CFrame.new(0, -2, 0), Material = Enum.Material.Sand, Color = Color3.fromRGB(226, 198, 140), Parent = root })

	-- 발굴 지역
	local zones = {}
	for _, zone in Config.Zones do
		local center = Vector3.zero
		local grid = 10
		if zone.angle then
			local a = math.rad(zone.angle)
			center = Vector3.new(math.cos(a) * ZONE_RADIUS, 0, math.sin(a) * ZONE_RADIUS)
			grid = 8
		end
		zones[zone.id] = buildZone(root, zone, center, grid)
		-- 사막에서 이 지역까지 길
		if zone.angle then
			local dir = center.Unit
			local a0 = dir * (zones.Desert.half + 4)
			local a1 = center - dir * (zones[zone.id].half + 1)
			local len = (a1 - a0).Magnitude
			part({ Name = "ZonePath", Size = Vector3.new(9, 0.2, len), CFrame = CFrame.lookAt((a0 + a1) / 2 + Vector3.new(0, 0.1, 0), a1 + Vector3.new(0, 0.1, 0)), Material = Enum.Material.Cobblestone, Color = Color3.fromRGB(150, 140, 125), CanQuery = false, Parent = root })
		end
	end

	-- 사막 시작 지점 (발굴장 쪽을 바라봄)
	local desert = zones.Desert
	local spawnPos = Vector3.new(0, 0.5, -desert.half - 14)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.CFrame = CFrame.lookAt(spawnPos, Vector3.new(0, 0.5, 0))
	spawn.Material = Enum.Material.Slate
	spawn.Color = Color3.fromRGB(180, 160, 120)
	spawn.Duration = 0
	spawn.Parent = root
	desert.spawn = spawn.CFrame + Vector3.new(0, 3, 0)

	-- 랭킹 보드 (시작 지점 양옆)
	local boards = {}
	for _, info in { { "FossilBoard", "🏆 완성 화석 랭킹", Color3.fromRGB(255, 210, 80), -22 }, { "LikeBoard", "❤️ 이번 주 좋아요 랭킹", Color3.fromRGB(255, 130, 160), 22 } } do
		-- 시작 지점 앞 양옆, 시작 지점 쪽을 바라봄
		local pos = Vector3.new(info[4], 11, spawnPos.Z + 6)
		boards[info[1]] = buildBoard(root, info[1], info[2], info[3], CFrame.lookAt(pos, pos - Vector3.new(0, 0, 10)))
	end

	-- 박물관 부지 + 길
	local plots = {}
	for i = 1, PLOT_COUNT do
		local angle = (i - 1) / PLOT_COUNT * math.pi * 2
		local pos = Vector3.new(math.cos(angle) * PLOT_RADIUS, 0, math.sin(angle) * PLOT_RADIUS)
		local cf = CFrame.lookAt(pos, Vector3.zero) -- 입구(-Z)가 발굴장을 향함
		table.insert(plots, buildPlot(root, i, cf))

		local pathStart = pos.Unit * (desert.half + 2)
		local pathEnd = pos.Unit * (PLOT_RADIUS - PLOT_SIZE / 2 - 1)
		local mid = (pathStart + pathEnd) / 2
		local len = (pathEnd - pathStart).Magnitude
		part({ Name = "Path", Size = Vector3.new(7, 0.2, len), CFrame = CFrame.lookAt(mid + Vector3.new(0, 0.1, 0), pathEnd + Vector3.new(0, 0.1, 0)), Material = Enum.Material.Cobblestone, Color = Color3.fromRGB(170, 160, 145), CanQuery = false, Parent = root })
	end

	Lighting.ClockTime = 14.5
	Lighting.Brightness = 2.5
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 140, 125)

	return {
		root = root,
		zones = zones,
		plots = plots,
		boards = boards,
	}
end

return WorldBuilder
