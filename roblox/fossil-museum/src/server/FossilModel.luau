-- 완성 화석의 3D 뼈대 모형을 파트로 만들어 줌 (에셋 없이 동작)
-- 모형은 로컬 +X 방향이 머리, 원점은 전시대 윗면 중앙입니다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)

local FossilModel = {}

local BONE = Color3.fromRGB(236, 226, 200)

type Style = { color: Color3, material: Enum.Material, transparency: number }

local function styleFor(rarityId: string): Style
	if rarityId == "Mythic" then
		return { color = Color3.fromRGB(255, 150, 190), material = Enum.Material.Glass, transparency = 0.15 }
	elseif rarityId == "Cosmic" then
		return { color = Color3.fromRGB(120, 255, 240), material = Enum.Material.Neon, transparency = 0 }
	elseif rarityId == "Legendary" then
		return { color = Color3.fromRGB(245, 225, 170), material = Enum.Material.SmoothPlastic, transparency = 0 }
	end
	return { color = BONE, material = Enum.Material.SmoothPlastic, transparency = 0 }
end

type Builder = {
	model: Model,
	base: CFrame,
	style: Style,
}

local function newPart(b: Builder, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	if shape then
		p.Shape = shape
	end
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = true
	p.Color = b.style.color
	p.Material = b.style.material
	p.Transparency = b.style.transparency
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = b.model
	return p
end

-- a 에서 c 까지 이어지는 원기둥 뼈
local function bone(b: Builder, a: Vector3, c: Vector3, thick: number)
	local wa = b.base:PointToWorldSpace(a)
	local wc = b.base:PointToWorldSpace(c)
	local dir = wc - wa
	local len = dir.Magnitude
	if len < 0.05 then
		return
	end
	local up = b.base:VectorToWorldSpace(Vector3.yAxis)
	if math.abs(dir.Unit:Dot(up)) > 0.98 then
		up = b.base:VectorToWorldSpace(Vector3.xAxis)
	end
	local p = newPart(b, Enum.PartType.Cylinder)
	p.Size = Vector3.new(len + thick * 0.5, thick, thick)
	p.CFrame = CFrame.lookAt((wa + wc) / 2, wc, up) * CFrame.Angles(0, math.pi / 2, 0)
end

local function ball(b: Builder, at: Vector3, size: number)
	local p = newPart(b, Enum.PartType.Ball)
	p.Size = Vector3.new(size, size, size)
	p.CFrame = b.base * CFrame.new(at)
end

local function block(b: Builder, at: Vector3, size: Vector3, rot: CFrame?)
	local p = newPart(b)
	p.Size = size
	p.CFrame = b.base * CFrame.new(at) * (rot or CFrame.identity)
end

local function stand(b: Builder, height: number)
	local p = newPart(b, Enum.PartType.Cylinder)
	p.Color = Color3.fromRGB(60, 60, 65)
	p.Material = Enum.Material.Metal
	p.Transparency = 0
	p.Size = Vector3.new(height, 0.3, 0.3)
	p.CFrame = b.base * CFrame.new(0, height / 2, 0) * CFrame.Angles(0, 0, math.pi / 2)
end

local function ribs(b: Builder, from: Vector3, to: Vector3, count: number, depth: number, width: number, thick: number)
	for i = 1, count do
		local t = i / (count + 1)
		local p = from:Lerp(to, t)
		local d = depth * (1 - math.abs(t - 0.5) * 0.8)
		for _, side in { -1, 1 } do
			local mid = p + Vector3.new(0, -d * 0.45, side * width)
			bone(b, p, mid, thick)
			bone(b, mid, p + Vector3.new(0, -d, side * width * 0.4), thick)
		end
	end
end

local function skull(b: Builder, at: Vector3, s: number, look: Config.Look)
	local h = (look.head or 1) * s
	block(b, at, Vector3.new(1.3 * h, 0.8 * h, 0.8 * h))
	-- 아래턱
	block(b, at + Vector3.new(0.15 * h, -0.5 * h, 0), Vector3.new(1.1 * h, 0.22 * h, 0.6 * h), CFrame.Angles(0, 0, math.rad(-8)))
	-- 눈구멍
	for _, side in { -1, 1 } do
		local eye = newPart(b, Enum.PartType.Ball)
		eye.Color = Color3.fromRGB(40, 35, 30)
		eye.Material = Enum.Material.SmoothPlastic
		eye.Transparency = 0
		eye.Size = Vector3.new(0.28, 0.28, 0.28) * h
		eye.CFrame = b.base * CFrame.new(at + Vector3.new(0.1 * h, 0.15 * h, side * 0.38 * h))
	end
	if look.horns then
		for _, side in { -1, 1 } do
			bone(b, at + Vector3.new(0.1 * h, 0.35 * h, side * 0.3 * h), at + Vector3.new(0.7 * h, 1.0 * h, side * 0.45 * h), 0.14 * h)
		end
		bone(b, at + Vector3.new(0.6 * h, 0.3 * h, 0), at + Vector3.new(0.9 * h, 0.7 * h, 0), 0.12 * h)
	end
	if look.tusks then
		for _, side in { -1, 1 } do
			local root = at + Vector3.new(0.5 * h, -0.3 * h, side * 0.3 * h)
			local mid = root + Vector3.new(0.6 * h, -0.8 * h, side * 0.2 * h)
			bone(b, root, mid, 0.18 * h)
			bone(b, mid, mid + Vector3.new(0.6 * h, 0.5 * h, side * 0.1 * h), 0.15 * h)
		end
	end
end

local function quadruped(b: Builder, s: number, look: Config.Look)
	local shoulder = Vector3.new(1.6 * s, 2.6 * s, 0)
	local hip = Vector3.new(-1.6 * s, 2.5 * s, 0)
	bone(b, shoulder, hip, 0.42 * s)
	ribs(b, hip, shoulder, 5, 1.2 * s, 0.6 * s, 0.14 * s)
	for _, side in { -0.6, 0.6 } do
		local z = side * s
		bone(b, shoulder + Vector3.new(0, 0, z), Vector3.new(1.8 * s, 1.2 * s, z), 0.32 * s)
		bone(b, Vector3.new(1.8 * s, 1.2 * s, z), Vector3.new(1.7 * s, 0, z), 0.28 * s)
		bone(b, hip + Vector3.new(0, 0, z), Vector3.new(-1.3 * s, 1.2 * s, z), 0.36 * s)
		bone(b, Vector3.new(-1.3 * s, 1.2 * s, z), Vector3.new(-1.6 * s, 0, z), 0.3 * s)
	end
	local neck = math.clamp(look.neck or 0.6, 0.2, 2.4)
	local neckDir = Vector3.new(1, neck * 0.9, 0).Unit
	local neckEnd = shoulder + neckDir * (0.8 + neck * 1.6) * s
	bone(b, shoulder, neckEnd, 0.3 * s)
	skull(b, neckEnd + Vector3.new(0.6 * s * (look.head or 1), 0, 0), s, look)

	local tail = (look.tail or 1) * s
	local tailMid = hip + Vector3.new(-1.3 * tail, -0.4 * s, 0)
	local tailEnd = hip + Vector3.new(-2.6 * tail, -1.0 * s, 0)
	bone(b, hip, tailMid, 0.3 * s)
	bone(b, tailMid, tailEnd, 0.18 * s)
	if look.club then
		ball(b, tailEnd, 0.8 * s)
	end
	if look.plates then
		local plateStart = hip:Lerp(tailMid, 0.5)
		for i = 0, 5 do
			local p = plateStart:Lerp(shoulder, i / 6)
			block(b, p + Vector3.new(0, 0.55 * s, 0), Vector3.new(0.7 * s, 0.7 * s, 0.12 * s), CFrame.Angles(0, 0, math.rad(45)))
		end
	end
	if look.sail then
		block(b, (shoulder + hip) / 2 + Vector3.new(0, 1.0 * s, 0), Vector3.new(3.0 * s, 1.6 * s, 0.1 * s))
	end
end

local function biped(b: Builder, s: number, look: Config.Look)
	local hip = Vector3.new(-0.3 * s, 3.0 * s, 0)
	local chest = hip + Vector3.new(1.6 * s, 0.6 * s, 0)
	bone(b, hip, chest, 0.42 * s)
	ribs(b, hip, chest, 4, 1.1 * s, 0.5 * s, 0.13 * s)
	for _, side in { -0.5, 0.5 } do
		local z = side * s
		local knee = hip + Vector3.new(0.6 * s, -1.5 * s, z)
		local ankle = Vector3.new(-0.3 * s, 0.4 * s, z)
		bone(b, hip + Vector3.new(0, 0, z), knee, 0.4 * s)
		bone(b, knee, ankle, 0.3 * s)
		bone(b, ankle, Vector3.new(0.4 * s, 0.05 * s, z), 0.22 * s)
		local shoulder = chest + Vector3.new(0, -0.3 * s, z * 0.8)
		bone(b, shoulder, shoulder + Vector3.new(0.4 * s, -0.7 * s, 0), 0.14 * s)
		bone(b, shoulder + Vector3.new(0.4 * s, -0.7 * s, 0), shoulder + Vector3.new(0.75 * s, -0.6 * s, 0), 0.11 * s)
	end
	local neckEnd = chest + Vector3.new(0.5 * s, 0.6 * s, 0)
	bone(b, chest, neckEnd, 0.3 * s)
	skull(b, neckEnd + Vector3.new(0.65 * s * (look.head or 1), 0.1 * s, 0), s, look)

	local tail = (look.tail or 1) * s
	local tailMid = hip + Vector3.new(-1.5 * tail, -0.15 * s, 0)
	local tailEnd = hip + Vector3.new(-3.0 * tail, -0.6 * s, 0)
	bone(b, hip, tailMid, 0.32 * s)
	bone(b, tailMid, tailEnd, 0.18 * s)
	if look.sail then
		block(b, (hip + chest) / 2 + Vector3.new(0, 1.0 * s, 0), Vector3.new(2.0 * s, 1.8 * s, 0.1 * s), CFrame.Angles(0, 0, math.rad(20)))
	end
end

local function flyer(b: Builder, s: number, look: Config.Look)
	stand(b, 2.8 * s)
	local back = Vector3.new(-0.8 * s, 3.0 * s, 0)
	local front = Vector3.new(0.8 * s, 3.25 * s, 0)
	bone(b, back, front, 0.5 * s)
	for _, side in { -1, 1 } do
		local root = front + Vector3.new(-0.3 * s, 0, side * 0.2 * s)
		local elbow = Vector3.new(0.3 * s, 3.9 * s, side * 1.8 * s)
		local tip = Vector3.new(-0.7 * s, 3.5 * s, side * 3.4 * s)
		bone(b, root, elbow, 0.22 * s)
		bone(b, elbow, tip, 0.16 * s)
		bone(b, tip, back + Vector3.new(-0.2 * s, 0, side * 0.3 * s), 0.08 * s)
		bone(b, elbow, back + Vector3.new(0, 0, side * 0.3 * s), 0.08 * s)
		bone(b, back + Vector3.new(0, 0, side * 0.25 * s), back + Vector3.new(-0.2 * s, -0.9 * s, side * 0.35 * s), 0.12 * s)
	end
	local neckEnd = front + Vector3.new(0.6 * s, 0.4 * s, 0)
	bone(b, front, neckEnd, 0.22 * s)
	local head = neckEnd + Vector3.new(0.7 * s, 0.05 * s, 0)
	block(b, head, Vector3.new(1.0, 0.5, 0.45) * s)
	block(b, head + Vector3.new(0.9 * s, -0.08 * s, 0), Vector3.new(1.2, 0.18, 0.2) * s) -- 부리
	if look.horns then
		bone(b, head + Vector3.new(-0.3 * s, 0.2 * s, 0), head + Vector3.new(-1.1 * s, 0.9 * s, 0), 0.14 * s)
	else
		bone(b, head + Vector3.new(-0.3 * s, 0.2 * s, 0), head + Vector3.new(-0.9 * s, 0.5 * s, 0), 0.12 * s)
	end
	bone(b, back, back + Vector3.new(-0.7 * s, -0.3 * s, 0), 0.1 * s)
end

local function swimmer(b: Builder, s: number, look: Config.Look)
	stand(b, 2.4 * s)
	local tailBase = Vector3.new(-1.9 * s, 2.6 * s, 0)
	local chest = Vector3.new(1.3 * s, 2.7 * s, 0)
	bone(b, tailBase, chest, 0.45 * s)
	ribs(b, tailBase:Lerp(chest, 0.15), chest, 5, 1.0 * s, 0.55 * s, 0.13 * s)
	local neck = (look.neck or 0.5) * s
	local neckEnd = chest + Vector3.new(0.4 * s + neck * 1.5, 0.1 * s, 0)
	bone(b, chest, neckEnd, 0.32 * s)
	skull(b, neckEnd + Vector3.new(0.6 * s * (look.head or 1), 0, 0), s, look)
	for _, side in { -1, 1 } do
		local f = chest + Vector3.new(-0.3 * s, -0.25 * s, side * 0.3 * s)
		bone(b, f, f + Vector3.new(0.5 * s, -0.5 * s, side * 1.4 * s), 0.2 * s)
		local r = tailBase + Vector3.new(0.7 * s, -0.25 * s, side * 0.3 * s)
		bone(b, r, r + Vector3.new(-0.3 * s, -0.4 * s, side * 1.2 * s), 0.18 * s)
	end
	local tailEnd = tailBase + Vector3.new(-1.4 * s, 0.05 * s, 0)
	bone(b, tailBase, tailEnd, 0.25 * s)
	bone(b, tailEnd, tailEnd + Vector3.new(-0.6 * s, 0.9 * s, 0), 0.16 * s)
	bone(b, tailEnd, tailEnd + Vector3.new(-0.6 * s, -0.7 * s, 0), 0.16 * s)
end

local BUILDERS = {
	Quadruped = quadruped,
	Biped = biped,
	Flyer = flyer,
	Swimmer = swimmer,
}

-- base: 전시대 윗면 중앙 CFrame
function FossilModel.Build(speciesId: string, base: CFrame): Model?
	local species = Config.SpeciesById[speciesId]
	if not species then
		return nil
	end
	local rarity = Config.RarityById[species.rarity]
	local model = Instance.new("Model")
	model.Name = species.id
	local b: Builder = { model = model, base = base, style = styleFor(species.rarity) }
	local s = species.look.scale or 1
	BUILDERS[species.shape](b, s, species.look)

	-- 이름표
	local anchor = Instance.new("Part")
	anchor.Name = "LabelAnchor"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.CFrame = base * CFrame.new(0, 6.2 * s, 0)
	anchor.Parent = model

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(200, 50)
	gui.MaxDistance = 70
	gui.AlwaysOnTop = false
	gui.Parent = anchor
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.fromScale(1, 0.6)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.FredokaOne
	nameLabel.TextScaled = true
	nameLabel.TextColor3 = rarity.color
	nameLabel.TextStrokeTransparency = 0.2
	nameLabel.Text = species.name
	nameLabel.Parent = gui
	local info = Instance.new("TextLabel")
	info.Size = UDim2.fromScale(1, 0.4)
	info.Position = UDim2.fromScale(0, 0.6)
	info.BackgroundTransparency = 1
	info.Font = Enum.Font.GothamBold
	info.TextScaled = true
	info.TextColor3 = Color3.new(1, 1, 1)
	info.TextStrokeTransparency = 0.3
	info.Text = string.format("%s · +%s/초", rarity.name, Util.FormatNumber(rarity.income))
	info.Parent = gui

	if rarity.tier >= 5 then
		local light = Instance.new("PointLight")
		light.Color = rarity.color
		light.Range = 10
		light.Brightness = 1.5
		light.Parent = anchor
		local sparkle = Instance.new("ParticleEmitter")
		sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		sparkle.Color = ColorSequence.new(rarity.color)
		sparkle.Size = NumberSequence.new(0.3)
		sparkle.Rate = 3
		sparkle.Lifetime = NumberRange.new(1, 2)
		sparkle.Speed = NumberRange.new(0.5, 1)
		sparkle.SpreadAngle = Vector2.new(180, 180)
		sparkle.Parent = anchor
	end

	return model
end

return FossilModel
