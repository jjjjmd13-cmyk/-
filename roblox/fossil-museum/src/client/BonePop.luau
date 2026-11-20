-- 화석 조각 발견 연출: 땅에서 뼈가 튀어나와 → 빙글빙글 돌다가 → 주운 사람에게 날아감
-- 조각 종류(두개골, 척추, 다리...)마다 모양이 다르고, 등급이 높을수록 화려해요.
-- 전설 이상은 하늘로 빛기둥이 솟아서 주변 사람도 볼 수 있어요.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)

local BonePop = {}

local player = Players.LocalPlayer
local folder = Instance.new("Folder")
folder.Name = "BonePops"
folder.Parent = workspace

local VIEW_DISTANCE = 120 -- 다른 사람의 연출은 이 거리 안에서만 보여줌
local MAX_ACTIVE = 12

local RISE_TIME = 0.45
local HOVER_TIME = 0.9
local FLY_TIME = 0.45

local active = 0

type Style = { color: Color3, material: Enum.Material, transparency: number }

local function styleFor(rarityId: string): Style
	if rarityId == "Mythic" then
		return { color = Color3.fromRGB(255, 150, 190), material = Enum.Material.Glass, transparency = 0.1 }
	elseif rarityId == "Cosmic" then
		return { color = Color3.fromRGB(120, 255, 240), material = Enum.Material.Neon, transparency = 0 }
	elseif rarityId == "Legendary" then
		return { color = Color3.fromRGB(255, 220, 120), material = Enum.Material.Neon, transparency = 0 }
	elseif rarityId == "Epic" then
		return { color = Color3.fromRGB(235, 215, 255), material = Enum.Material.SmoothPlastic, transparency = 0 }
	end
	return { color = Color3.fromRGB(240, 230, 205), material = Enum.Material.SmoothPlastic, transparency = 0 }
end

----------------------------------------------------------------------
-- 뼈 조각 모형 (모두 원점 기준, 크기 약 2~3 스터드)
----------------------------------------------------------------------
local function piece(model: Model, style: Style, shape: Enum.PartType, size: Vector3, cf: CFrame): Part
	local p = Instance.new("Part")
	p.Shape = shape
	p.Size = size
	p.CFrame = cf
	p.Color = style.color
	p.Material = style.material
	p.Transparency = style.transparency
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Parent = model
	return p
end

-- a → b 를 잇는 원기둥
local function rod(model: Model, style: Style, a: Vector3, b: Vector3, thick: number)
	local dir = b - a
	local up = if math.abs(dir.Unit.Y) > 0.98 then Vector3.xAxis else Vector3.yAxis
	piece(model, style, Enum.PartType.Cylinder, Vector3.new(dir.Magnitude, thick, thick), CFrame.lookAt((a + b) / 2, b, up) * CFrame.Angles(0, math.pi / 2, 0))
end

-- 개뼈다귀 모양 (다리뼈)
local function longBone(model: Model, style: Style, length: number, thick: number)
	local half = length / 2
	rod(model, style, Vector3.new(-half, 0, 0), Vector3.new(half, 0, 0), thick)
	for _, x in { -half, half } do
		for _, z in { -thick * 0.45, thick * 0.45 } do
			piece(model, style, Enum.PartType.Ball, Vector3.one * thick * 1.5, CFrame.new(x, 0, z))
		end
	end
end

local BUILDERS: { [string]: (Model, Style) -> () } = {
	["두개골"] = function(model, style)
		piece(model, style, Enum.PartType.Block, Vector3.new(1.8, 1.1, 1.1), CFrame.identity)
		piece(model, style, Enum.PartType.Block, Vector3.new(1.5, 0.3, 0.85), CFrame.new(0.2, -0.7, 0) * CFrame.Angles(0, 0, math.rad(-8)))
		for _, z in { -0.5, 0.5 } do
			local eye = piece(model, style, Enum.PartType.Ball, Vector3.one * 0.38, CFrame.new(0.15, 0.2, z))
			eye.Color = Color3.fromRGB(35, 30, 25)
			eye.Material = Enum.Material.SmoothPlastic
			eye.Transparency = 0
		end
		for i = 0, 3 do
			piece(model, style, Enum.PartType.Block, Vector3.new(0.12, 0.25, 0.12), CFrame.new(0.4 + i * 0.25, -0.62, 0.38))
			piece(model, style, Enum.PartType.Block, Vector3.new(0.12, 0.25, 0.12), CFrame.new(0.4 + i * 0.25, -0.62, -0.38))
		end
	end,
	["척추"] = function(model, style)
		for i = -2, 2 do
			piece(model, style, Enum.PartType.Cylinder, Vector3.new(0.45, 0.65, 0.65), CFrame.new(i * 0.55, 0, 0))
			piece(model, style, Enum.PartType.Block, Vector3.new(0.18, 0.55, 0.18), CFrame.new(i * 0.55, 0.5, 0))
		end
	end,
	["갈비뼈"] = function(model, style)
		rod(model, style, Vector3.new(-1.2, 0.8, 0), Vector3.new(1.2, 0.8, 0), 0.3)
		for i = -1, 1 do
			local x = i * 0.7
			for _, side in { -1, 1 } do
				rod(model, style, Vector3.new(x, 0.8, 0), Vector3.new(x, 0.1, side * 0.7), 0.16)
				rod(model, style, Vector3.new(x, 0.1, side * 0.7), Vector3.new(x, -0.7, side * 0.35), 0.14)
			end
		end
	end,
	["꼬리"] = function(model, style)
		for i = 0, 5 do
			local size = 0.6 - i * 0.07
			piece(model, style, Enum.PartType.Ball, Vector3.one * size, CFrame.new(-1.3 + i * 0.5, math.sin(i * 0.8) * 0.2, 0))
		end
	end,
	["날개"] = function(model, style)
		rod(model, style, Vector3.new(-1.2, 0, 0), Vector3.new(0.2, 0.5, 0), 0.2)
		for i = 0, 3 do
			local a = math.rad(-30 + i * 25)
			rod(model, style, Vector3.new(0.2, 0.5, 0), Vector3.new(0.2 + math.cos(a) * 1.6, 0.5 + math.sin(a) * 1.6, 0), 0.1)
		end
	end,
	["지느러미"] = function(model, style)
		piece(model, style, Enum.PartType.Block, Vector3.new(2.2, 0.15, 0.9), CFrame.Angles(0, 0, math.rad(10)))
		for i = 0, 3 do
			piece(model, style, Enum.PartType.Ball, Vector3.one * 0.32, CFrame.new(-0.8 + i * 0.5, 0.15, 0))
		end
	end,
	["몸통"] = function(model, style)
		piece(model, style, Enum.PartType.Ball, Vector3.new(1.4, 1.4, 1.4), CFrame.identity)
		for i = -1, 1 do
			rod(model, style, Vector3.new(i * 0.4, 0.6, 0), Vector3.new(i * 0.4, -0.5, 0.75), 0.12)
			rod(model, style, Vector3.new(i * 0.4, 0.6, 0), Vector3.new(i * 0.4, -0.5, -0.75), 0.12)
		end
	end,
}

local function buildBone(pieceName: string, style: Style): Model
	local model = Instance.new("Model")
	model.Name = "Bone"
	local builder = BUILDERS[pieceName]
	if builder then
		builder(model, style)
	else
		-- 다리, 앞다리, 뒷다리 등
		longBone(model, style, 2.2, 0.4)
	end
	local center = Instance.new("Part")
	center.Name = "Center"
	center.Size = Vector3.one * 0.2
	center.Transparency = 1
	center.Anchored = true
	center.CanCollide = false
	center.CanQuery = false
	center.CanTouch = false
	center.Parent = model
	model.PrimaryPart = center
	return model
end

----------------------------------------------------------------------
-- 꾸미기
----------------------------------------------------------------------
local function addAura(center: BasePart, rarity: Config.Rarity)
	local light = Instance.new("PointLight")
	light.Color = rarity.color
	light.Range = 6 + rarity.tier * 2
	light.Brightness = 0.6 + rarity.tier * 0.35
	light.Parent = center
	if rarity.tier >= 2 then
		local sparkle = Instance.new("ParticleEmitter")
		sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		sparkle.Color = ColorSequence.new(rarity.color)
		sparkle.Size = NumberSequence.new(0.25 + rarity.tier * 0.08)
		sparkle.Rate = rarity.tier * 6
		sparkle.Lifetime = NumberRange.new(0.5, 1)
		sparkle.Speed = NumberRange.new(1, 3)
		sparkle.SpreadAngle = Vector2.new(180, 180)
		sparkle.LightEmission = 1
		sparkle.Parent = center
	end
end

local function addLabel(center: BasePart, text: string, color: Color3, isNew: boolean)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(220, if isNew then 54 else 32)
	gui.StudsOffset = Vector3.new(0, 2.2, 0)
	gui.AlwaysOnTop = true
	gui.Parent = center
	local layout = Instance.new("UIListLayout")
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = gui
	if isNew then
		local newLabel = Instance.new("TextLabel")
		newLabel.Size = UDim2.new(1, 0, 0, 22)
		newLabel.BackgroundTransparency = 1
		newLabel.Font = Enum.Font.FredokaOne
		newLabel.TextScaled = true
		newLabel.TextColor3 = Color3.fromRGB(255, 240, 90)
		newLabel.TextStrokeTransparency = 0
		newLabel.Text = "✨ NEW! ✨"
		newLabel.Parent = gui
	end
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 0, 30)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.1
	label.Text = text
	label.Parent = gui
end

-- 전설 이상: 하늘로 솟는 빛기둥
local function lightBeam(position: Vector3, color: Color3)
	local beam = Instance.new("Part")
	beam.Shape = Enum.PartType.Cylinder
	beam.Size = Vector3.new(60, 2.5, 2.5)
	beam.CFrame = CFrame.new(position + Vector3.new(0, 30, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	beam.Color = color
	beam.Material = Enum.Material.Neon
	beam.Transparency = 0.3
	beam.Anchored = true
	beam.CanCollide = false
	beam.CanQuery = false
	beam.CanTouch = false
	beam.CastShadow = false
	beam.Parent = folder
	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.3, 2, 2)
	ring.CFrame = CFrame.new(position + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	ring.Color = color
	ring.Material = Enum.Material.Neon
	ring.Transparency = 0.2
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.Parent = folder
	local info = TweenInfo.new(2.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(beam, info, { Transparency = 1, Size = Vector3.new(60, 0.5, 0.5) }):Play()
	TweenService:Create(ring, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(0.3, 22, 22), Transparency = 1 }):Play()
	task.delay(2.3, function()
		beam:Destroy()
		ring:Destroy()
	end)
end

-- 주웠을 때 반짝 터지는 효과
local function pickupBurst(position: Vector3, color: Color3)
	local anchor = Instance.new("Part")
	anchor.Size = Vector3.one * 0.2
	anchor.Transparency = 1
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Position = position
	anchor.Parent = folder
	local burst = Instance.new("ParticleEmitter")
	burst.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	burst.Color = ColorSequence.new(color)
	burst.Size = NumberSequence.new(0.6, 0)
	burst.Lifetime = NumberRange.new(0.3, 0.6)
	burst.Speed = NumberRange.new(6, 12)
	burst.SpreadAngle = Vector2.new(180, 180)
	burst.LightEmission = 1
	burst.Enabled = false
	burst.Parent = anchor
	burst:Emit(18)
	task.delay(0.8, function()
		anchor:Destroy()
	end)
end

----------------------------------------------------------------------
local function easeOutBack(t: number): number
	local c1, c3 = 1.70158, 2.70158
	return 1 + c3 * (t - 1) ^ 3 + c1 * (t - 1) ^ 2
end

local function rootOf(userId: number): BasePart?
	local owner = Players:GetPlayerByUserId(userId)
	local character = owner and owner.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- position: 흙더미 위치, ownerId: 주운 사람
function BonePop.Play(position: Vector3, speciesId: string, pieceIndex: number, ownerId: number, isNew: boolean)
	local species = Config.SpeciesById[speciesId]
	if not species then
		return
	end
	local rarity = Config.RarityById[species.rarity]
	local mine = ownerId == player.UserId

	-- 다른 사람 것은 가까이 있을 때만 (전설 이상은 빛기둥만이라도 멀리서 보임)
	local myRoot = rootOf(player.UserId)
	local far = myRoot ~= nil and (myRoot.Position - position).Magnitude > VIEW_DISTANCE
	if not mine and rarity.tier >= Config.AnnounceTier then
		lightBeam(position, rarity.color)
	end
	if not mine and (far or active >= MAX_ACTIVE) then
		return
	end
	if mine and rarity.tier >= Config.AnnounceTier then
		lightBeam(position, rarity.color)
	end

	local pieceName = Config.GetPieces(species)[pieceIndex] or "다리"
	local model = buildBone(pieceName, styleFor(species.rarity))
	local center = model.PrimaryPart :: BasePart
	addAura(center, rarity)
	if mine then
		addLabel(center, string.format("[%s] %s · %s", rarity.name, species.name, pieceName), rarity.color, isNew)
	end
	local scale = 0.9 + rarity.tier * 0.12
	local ground = position - Vector3.new(0, 1, 0)
	model:PivotTo(CFrame.new(ground))
	model:ScaleTo(0.2)
	model.Parent = folder
	active += 1

	local started = os.clock()
	local spinSpeed = 2.5 + rarity.tier * 0.6
	local flyFrom: Vector3? = nil
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		local t = os.clock() - started
		local angle = t * spinSpeed
		local pos: Vector3
		local s: number
		if t < RISE_TIME then
			-- 1) 땅에서 튀어나옴
			local k = easeOutBack(t / RISE_TIME)
			pos = ground + Vector3.new(0, 5.5 * k, 0)
			s = 0.2 + (scale - 0.2) * math.clamp(k, 0, 1.15)
		elseif t < RISE_TIME + HOVER_TIME then
			-- 2) 둥실둥실 돌기
			local h = t - RISE_TIME
			pos = ground + Vector3.new(0, 5.5 + math.sin(h * 6) * 0.3, 0)
			s = scale
		elseif t < RISE_TIME + HOVER_TIME + FLY_TIME then
			-- 3) 주운 사람에게 날아감
			local k = (t - RISE_TIME - HOVER_TIME) / FLY_TIME
			if not flyFrom then
				flyFrom = center.Position
			end
			local target = rootOf(ownerId)
			local targetPos = if target then target.Position + Vector3.new(0, 1, 0) else ground + Vector3.new(0, 8, 0)
			local from = flyFrom :: Vector3
			local arc = Vector3.new(0, math.sin(k * math.pi) * 3, 0)
			pos = from:Lerp(targetPos, k * k) + arc
			s = scale * (1 - 0.8 * k)
		else
			connection:Disconnect()
			pickupBurst(center.Position, rarity.color)
			model:Destroy()
			active -= 1
			return
		end
		model:ScaleTo(math.max(0.05, s))
		model:PivotTo(CFrame.new(pos) * CFrame.Angles(math.rad(15), angle, math.rad(10)))
	end)
end

return BonePop
