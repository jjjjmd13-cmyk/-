-- 발굴: 흙더미 생성, 삽질 처리, 운석 이벤트, 도구 지급
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Util = require(ReplicatedStorage.Shared.Util)
local DataService = require(script.Parent.DataService)
local Passes = require(script.Parent.Passes)
local Net = require(script.Parent.Net)
local Rewards = require(script.Parent.Rewards)
local Zones = require(script.Parent.Zones)

local DigService = {}

local TAG = "DigMound"
local MOUND_SIZE = Vector3.new(6, 3, 6)
local METEOR_SIZE = 5

local world: any = nil
local lastDig: { [Player]: number } = {}
local lastLockedWarn: { [Player]: number } = {}
-- 흙더미별로 누가 체력을 얼마나 깎았는지: [흙더미] = { [플레이어] = 깎은 체력 }
local contributions: { [BasePart]: { [Player]: number } } = {}

-- 흙더미가 부서졌을 때 판 사람 모두에게 판 만큼 보상 (2명 이상이면 보너스)
local function rewardContributors(mound: BasePart, kindId: string, zoneId: string)
	local list = contributions[mound] or {}
	contributions[mound] = nil
	local total = 0
	local count = 0
	for contributor, damage in list do
		if contributor.Parent and DataService.Get(contributor) then
			total += damage
			count += 1
		end
	end
	if total <= 0 then
		return
	end
	local coop = count >= 2
	local bonus = if coop then 1 + Config.CoopBonus else 1
	for contributor, damage in list do
		local data = contributor.Parent and DataService.Get(contributor)
		if data then
			Rewards.Dig(contributor, data, kindId, zoneId, mound.Position, { share = damage / total * bonus, coop = coop })
		end
	end
end

----------------------------------------------------------------------
-- 도구
----------------------------------------------------------------------
local function buildTool(def: Config.DigTool): Tool
	local tool = Instance.new("Tool")
	tool.Name = def.name
	tool.CanBeDropped = false
	tool.ToolTip = "흙더미를 클릭하거나 누르고 있으면 파요"
	tool:SetAttribute("DigTool", def.id)
	-- 손잡이 끝을 쥐고, 삽날이 앞쪽으로
	tool.Grip = CFrame.fromMatrix(Vector3.new(0, 0, -1.5), Vector3.new(0, 1, 0), Vector3.new(0, 0, 1))

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.3, 0.3, 4)
	handle.Material = Enum.Material.Wood
	handle.Color = Color3.fromRGB(120, 85, 50)
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool

	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(1.3, 0.2, 1.4)
	local glowing = def.power >= 14
	head.Material = if glowing then Enum.Material.Neon else Enum.Material.Metal
	head.Color = def.color
	head.CanCollide = false
	head.Massless = true
	head.CFrame = handle.CFrame * CFrame.new(0, 0, 2.5)
	head.Parent = tool
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = head
	weld.Parent = handle
	if glowing then
		local light = Instance.new("PointLight")
		light.Color = def.color
		light.Range = 6
		light.Parent = head
	end
	return tool
end

function DigService.GiveTool(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	local def = Config.ToolsById[data.tool] or Config.Tools[1]
	local wasEquipped = false
	for _, container in { player:FindFirstChildOfClass("Backpack"), player.Character } do
		if container then
			for _, child in container:GetChildren() do
				if child:IsA("Tool") and child:GetAttribute("DigTool") then
					if child.Parent == player.Character then
						wasEquipped = true
					end
					child:Destroy()
				end
			end
		end
	end
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then
		return
	end
	local tool = buildTool(def)
	tool.Parent = backpack
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if wasEquipped and humanoid then
		humanoid:EquipTool(tool)
	end
end

----------------------------------------------------------------------
-- 흙더미
----------------------------------------------------------------------
local function rollMoundKind(): string
	local total = 0
	for _, kind in Config.Mounds do
		total += kind.spawnWeight
	end
	local roll = math.random() * total
	for id, kind in Config.Mounds do
		if kind.spawnWeight > 0 then
			roll -= kind.spawnWeight
			if roll <= 0 then
				return id
			end
		end
	end
	return "Dirt"
end

local function addSparkle(mound: BasePart, color: Color3)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Sparkle"
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(color)
	emitter.Size = NumberSequence.new(0.5)
	emitter.Rate = 6
	emitter.Lifetime = NumberRange.new(0.8, 1.5)
	emitter.Speed = NumberRange.new(1, 2)
	emitter.SpreadAngle = Vector2.new(60, 60)
	emitter.Parent = mound
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 8
	light.Brightness = 1
	light.Parent = mound
end

local function setupMound(mound: BasePart, kindId: string, zoneId: string)
	local kind = Config.Mounds[kindId]
	local zone = Config.ZoneById[zoneId] or Config.Zones[1]
	local hp = math.ceil(kind.hp * zone.hpMult)
	mound.Name = kindId
	if kindId == "Meteor" then
		mound.Color = Color3.fromRGB(80, 40, 120)
	elseif kindId == "Sparkle" then
		mound.Color = zone.moundColor:Lerp(Color3.fromRGB(255, 210, 90), 0.35)
	else
		mound.Color = zone.moundColor
	end
	mound:SetAttribute("Kind", kindId)
	mound:SetAttribute("Zone", zone.id)
	mound:SetAttribute("HP", hp)
	mound:SetAttribute("MaxHP", hp)
	for _, child in mound:GetChildren() do
		if child:IsA("ParticleEmitter") or child:IsA("PointLight") then
			child:Destroy()
		end
	end
	if kindId == "Sparkle" then
		addSparkle(mound, Color3.fromRGB(255, 220, 90))
	end
end

local function makeMound(zoneWorld: any, position: Vector3, kindId: string): Part
	local zone = Config.ZoneById[zoneWorld.id]
	local mound = Instance.new("Part")
	mound.Anchored = true
	mound.Size = MOUND_SIZE
	mound.CFrame = CFrame.new(position + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, math.random() * math.pi * 2, 0)
	mound.Material = zone.moundMaterial
	mound.CanCollide = true
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = mound
	setupMound(mound, kindId, zone.id)
	mound.Parent = zoneWorld.field
	CollectionService:AddTag(mound, TAG)
	return mound
end

local function updateMoundSize(mound: BasePart)
	local hp = mound:GetAttribute("HP") :: number
	local maxHp = mound:GetAttribute("MaxHP") :: number
	local ratio = 0.35 + 0.65 * math.clamp(hp / maxHp, 0, 1)
	if mound:GetAttribute("Kind") == "Meteor" then
		mound.Size = Vector3.one * METEOR_SIZE * (0.5 + 0.5 * ratio)
	else
		mound.Size = Vector3.new(MOUND_SIZE.X * (0.7 + 0.3 * ratio), MOUND_SIZE.Y * ratio, MOUND_SIZE.Z * (0.7 + 0.3 * ratio))
	end
end

local function hideMound(mound: BasePart)
	mound.Transparency = 1
	mound.CanCollide = false
	mound.CanQuery = false
	for _, child in mound:GetChildren() do
		if child:IsA("ParticleEmitter") or child:IsA("PointLight") or child:IsA("Fire") then
			(child :: any).Enabled = false
		end
	end
end

local function respawnMound(mound: Part)
	setupMound(mound, rollMoundKind(), mound:GetAttribute("Zone") :: string)
	mound.Size = Vector3.new(MOUND_SIZE.X, 0.2, MOUND_SIZE.Z)
	mound.Transparency = 0
	mound.CanCollide = true
	mound.CanQuery = true
	TweenService:Create(mound, TweenInfo.new(0.6, Enum.EasingStyle.Back), { Size = MOUND_SIZE }):Play()
end

----------------------------------------------------------------------
-- 삽질 요청 처리
----------------------------------------------------------------------
local function onDig(player: Player, mound: any)
	if typeof(mound) ~= "Instance" or not mound:IsA("BasePart") or not CollectionService:HasTag(mound, TAG) then
		return
	end
	local data = DataService.Get(player)
	if not data then
		return
	end
	local now = os.clock()
	local cooldown = Economy.GetDigCooldown(data, Passes.Get(player))
	if now - (lastDig[player] or 0) < cooldown * 0.85 then
		return
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or not character then
		return
	end
	if (root.Position - mound.Position).Magnitude > Config.DigRange then
		return
	end
	local held = character:FindFirstChildOfClass("Tool")
	if not held or not held:GetAttribute("DigTool") then
		return
	end
	local zoneId = mound:GetAttribute("Zone") :: string
	if not Zones.IsUnlocked(data, zoneId) then
		if now - (lastLockedWarn[player] or 0) > 3 then
			lastLockedWarn[player] = now
			local zone = Config.ZoneById[zoneId]
			Net.Tell(player, string.format("🔒 %s은(는) 아직 잠겨 있어요 (💰 %s)", zone.name, Util.FormatNumber(zone.price)), Color3.fromRGB(255, 150, 150))
		end
		return
	end
	local hp = mound:GetAttribute("HP") :: number
	if not hp or hp <= 0 then
		return
	end
	lastDig[player] = now

	local tool = Config.ToolsById[data.tool] or Config.Tools[1]
	local damage = math.min(tool.power, hp) -- 남은 체력보다 많이 친 건 기록하지 않음
	local list = contributions[mound]
	if not list then
		list = {}
		contributions[mound] = list
	end
	list[player] = (list[player] or 0) + damage
	hp -= tool.power
	mound:SetAttribute("HP", hp)
	local kindId = mound:GetAttribute("Kind") :: string
	Net.Effect:FireAllClients("Dig", mound.Position, mound.Color, hp <= 0)

	if hp > 0 then
		updateMoundSize(mound)
		return
	end

	hideMound(mound)
	rewardContributors(mound, kindId, zoneId)
	if kindId == "Meteor" then
		task.delay(1, function()
			mound:Destroy()
		end)
	else
		task.delay(Config.MoundRespawnTime, function()
			if mound.Parent then
				respawnMound(mound :: Part)
			end
		end)
	end
end

----------------------------------------------------------------------
-- 운석 이벤트 (모든 지역에 떨어짐)
----------------------------------------------------------------------
local meteors = {}

local function spawnMeteor(zoneWorld: any)
	local ring = zoneWorld.meteorRing
	local angle = math.random() * math.pi * 2
	local radius = ring.inner + math.random() * (ring.outer - ring.inner)
	local ground = zoneWorld.center + Vector3.new(math.cos(angle) * radius, METEOR_SIZE * 0.35, math.sin(angle) * radius)

	local meteor = Instance.new("Part")
	meteor.Shape = Enum.PartType.Ball
	meteor.Anchored = true
	meteor.Size = Vector3.one * METEOR_SIZE
	meteor.Material = Enum.Material.Basalt
	meteor.CanQuery = false
	meteor.CanCollide = false
	meteor.Position = ground + Vector3.new(30, 200, 20)
	setupMound(meteor, "Meteor", zoneWorld.id)
	addSparkle(meteor, Color3.fromRGB(180, 90, 255))
	local fire = Instance.new("Fire")
	fire.Color = Color3.fromRGB(170, 90, 255)
	fire.SecondaryColor = Color3.fromRGB(80, 200, 255)
	fire.Size = 8
	fire.Parent = meteor
	meteor.Parent = zoneWorld.field
	table.insert(meteors, meteor)

	local tween = TweenService:Create(meteor, TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = ground })
	tween:Play()
	tween.Completed:Wait()
	if not meteor.Parent then
		return
	end
	fire.Size = 3
	local boom = Instance.new("Explosion")
	boom.BlastPressure = 0
	boom.BlastRadius = 0
	boom.DestroyJointRadiusPercent = 0
	boom.Position = ground
	boom.Parent = workspace
	meteor.CanQuery = true
	meteor.CanCollide = true
	CollectionService:AddTag(meteor, TAG)
end

local function meteorLoop()
	local first = true
	while true do
		local waitTime = Config.MeteorInterval
		if first and RunService:IsStudio() then
			waitTime = 45 -- Studio 테스트 때는 빨리 시작
		end
		first = false
		ReplicatedStorage:SetAttribute("MeteorActive", false)
		ReplicatedStorage:SetAttribute("NextMeteorAt", workspace:GetServerTimeNow() + waitTime)
		task.wait(waitTime)

		ReplicatedStorage:SetAttribute("MeteorActive", true)
		ReplicatedStorage:SetAttribute("MeteorEndsAt", workspace:GetServerTimeNow() + Config.MeteorDuration)
		Net.Announce("☄️ 운석이 떨어지고 있어요! 모든 발굴 지역에서 우주 화석을 찾아보세요!", Color3.fromRGB(180, 120, 255))
		for _, zoneWorld in world.zones do
			for _ = 1, Config.MeteorsPerZone do
				task.delay(math.random() * 8, spawnMeteor, zoneWorld)
			end
		end
		task.wait(Config.MeteorDuration)

		for _, meteor in meteors do
			contributions[meteor] = nil
			if meteor.Parent then
				meteor:Destroy()
			end
		end
		table.clear(meteors)
		Net.Announce("운석 낙하가 끝났어요. 다음 운석을 기다려 주세요!", Color3.fromRGB(200, 200, 200))
	end
end

----------------------------------------------------------------------
function DigService.Init(builtWorld: any)
	world = builtWorld
	for _, zoneWorld in world.zones do
		for _, spot in zoneWorld.spots do
			makeMound(zoneWorld, spot, rollMoundKind())
		end
	end

	Net.Dig.OnServerEvent:Connect(onDig)

	local function onCharacter(player: Player)
		-- 데이터가 준비될 때까지 기다렸다가 도구 지급
		task.spawn(function()
			local started = os.clock()
			while not DataService.Get(player) and player.Parent and os.clock() - started < 30 do
				task.wait(0.2)
			end
			if player.Parent then
				DigService.GiveTool(player)
			end
		end)
	end
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function()
			onCharacter(player)
		end)
		if player.Character then
			onCharacter(player)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastDig[player] = nil
		lastLockedWarn[player] = nil
		for _, list in contributions do
			list[player] = nil
		end
	end)

	task.spawn(meteorLoop)
end

return DigService
