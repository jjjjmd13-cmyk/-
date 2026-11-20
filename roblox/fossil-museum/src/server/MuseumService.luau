-- 박물관: 부지 배정, 화석 전시, 수입, 좋아요, 조립/판매
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Util = require(ReplicatedStorage.Shared.Util)
local DataService = require(script.Parent.DataService)
local Passes = require(script.Parent.Passes)
local Net = require(script.Parent.Net)
local FossilModel = require(script.Parent.FossilModel)

local MuseumService = {}

local world: any = nil
local playerPlot: { [Player]: Model } = {}
local signatures: { [Player]: string } = {}
local carry: { [Player]: number } = {}

local LOCKED_COLOR = Color3.fromRGB(120, 115, 110)
local OPEN_COLOR = Color3.fromRGB(200, 195, 185)

local function setText(part: Instance?, guiChildName: string, text: string)
	if not part then
		return
	end
	for _, gui in part:GetChildren() do
		if gui:IsA("SurfaceGui") then
			local label = gui:FindFirstChild(guiChildName)
			if label and label:IsA("TextLabel") then
				label.Text = text
			end
		end
	end
end

local function updateSign(plot: Model, player: Player?, data: any?)
	if player and data then
		setText(plot:FindFirstChild("Sign"), "Title", player.DisplayName .. "의 박물관")
		setText(plot:FindFirstChild("LikeStand"), "Likes", "❤️\n" .. Util.FormatNumber(data.likes))
	else
		setText(plot:FindFirstChild("Sign"), "Title", "빈 박물관")
		setText(plot:FindFirstChild("LikeStand"), "Likes", "❤️")
	end
end

local function clearDisplays(plot: Model)
	local displays = plot:FindFirstChild("Displays")
	if displays then
		displays:ClearAllChildren()
	end
end

local function refreshDisplay(player: Player)
	local plot = playerPlot[player]
	local data = DataService.Get(player)
	if not plot or not data then
		return
	end
	local list = Economy.GetDisplayed(data)
	local signature = data.slots .. "|" .. table.concat(list, ",")
	updateSign(plot, player, data)
	if signatures[player] == signature then
		return
	end
	signatures[player] = signature

	clearDisplays(plot)
	local pedestals = plot:FindFirstChild("Pedestals") :: Folder
	local displays = plot:FindFirstChild("Displays") :: Folder
	for i, ped in pedestals:GetChildren() do
		local index = tonumber(ped.Name) or i
		local p = ped :: BasePart
		local speciesId = list[index]
		if index > data.slots then
			p.Transparency = 0.7
			p.Color = LOCKED_COLOR
		elseif speciesId then
			p.Transparency = 0
			p.Color = Config.RarityById[Config.SpeciesById[speciesId].rarity].color
		else
			p.Transparency = 0
			p.Color = OPEN_COLOR
		end
		if speciesId and index <= data.slots then
			local base = p.CFrame * CFrame.new(0, p.Size.Y / 2, 0)
			local model = FossilModel.Build(speciesId, base)
			if model then
				model.Parent = displays
			end
		end
	end
end

local function assignPlot(player: Player)
	for _, plot in world.plots do
		if plot:GetAttribute("OwnerUserId") == 0 then
			plot:SetAttribute("OwnerUserId", player.UserId)
			playerPlot[player] = plot
			signatures[player] = nil
			refreshDisplay(player)
			return
		end
	end
	Net.Tell(player, "빈 박물관 부지가 없어요. 서버 최대 인원을 8명으로 설정해 주세요.")
end

local function releasePlot(player: Player)
	local plot = playerPlot[player]
	if plot then
		clearDisplays(plot)
		updateSign(plot)
		plot:SetAttribute("OwnerUserId", 0)
		local pedestals = plot:FindFirstChild("Pedestals")
		if pedestals then
			for _, ped in pedestals:GetChildren() do
				(ped :: BasePart).Transparency = 0.6;
				(ped :: BasePart).Color = OPEN_COLOR
			end
		end
	end
	playerPlot[player] = nil
	signatures[player] = nil
	carry[player] = nil
end

local function countCompleted(data: any): number
	local total = 0
	for _, count in data.museum do
		total += count
	end
	return total
end

local function setupLeaderstats(player: Player, data: any)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local coins = Instance.new("IntValue")
	coins.Name = "코인"
	coins.Value = math.floor(data.coins)
	coins.Parent = stats
	local fossils = Instance.new("IntValue")
	fossils.Name = "화석"
	fossils.Value = countCompleted(data)
	fossils.Parent = stats
	stats.Parent = player
end

----------------------------------------------------------------------
-- 좋아요
----------------------------------------------------------------------
local function onLike(liker: Player, plot: Model)
	local ownerId = plot:GetAttribute("OwnerUserId") :: number
	if not ownerId or ownerId == 0 then
		return
	end
	if ownerId == liker.UserId then
		Net.Tell(liker, "내 박물관에는 좋아요를 누를 수 없어요 😅")
		return
	end
	local owner = Players:GetPlayerByUserId(ownerId)
	local likerData = DataService.Get(liker)
	local ownerData = owner and DataService.Get(owner)
	if not owner or not likerData or not ownerData then
		return
	end
	local key = tostring(ownerId)
	local today = DataService.Today()
	if likerData.likedGiven[key] == today then
		Net.Tell(liker, "오늘은 이미 이 박물관에 좋아요를 눌렀어요. 내일 또 와주세요!")
		return
	end
	likerData.likedGiven[key] = today
	ownerData.likes += 1
	Net.Tell(liker, owner.DisplayName .. "님의 박물관에 좋아요를 눌렀어요 ❤️", Color3.fromRGB(255, 130, 160))
	Net.Tell(owner, liker.DisplayName .. "님이 내 박물관에 좋아요를 눌렀어요! ❤️ (수입 +1%)", Color3.fromRGB(255, 130, 160))
	Net.MarkDirty(owner)
end

----------------------------------------------------------------------
-- 버튼 요청
----------------------------------------------------------------------
Net.Handle("Assemble", function(player, speciesId)
	local data = DataService.Get(player)
	if type(speciesId) ~= "string" or not Economy.HasAllPieces(data, speciesId) then
		return false, "조각이 모자라요"
	end
	local species = Config.SpeciesById[speciesId]
	local owned = data.pieces[speciesId]
	for i = 1, #Config.GetPieces(species) do
		local key = tostring(i)
		owned[key] -= 1
		if owned[key] <= 0 then
			owned[key] = nil
		end
	end
	data.museum[speciesId] = (data.museum[speciesId] or 0) + 1
	local rarity = Config.RarityById[species.rarity]
	if rarity.tier >= Config.AnnounceTier then
		Net.Announce(string.format("🏛️ %s님이 [%s] %s 화석을 완성했어요!", player.DisplayName, rarity.name, species.name), rarity.color)
	end
	Net.MarkDirty(player)
	return true, species.name .. " 화석 완성! 박물관에 전시했어요 🦖"
end)

Net.Handle("SellDuplicates", function(player)
	local data = DataService.Get(player)
	local value = Economy.GetDuplicateValue(data)
	if value <= 0 then
		return false, "판매할 중복 조각이 없어요"
	end
	for _, owned in data.pieces do
		for key, count in owned do
			if count > 1 then
				owned[key] = 1
			end
		end
	end
	data.coins += value
	Net.MarkDirty(player)
	return true, "중복 조각을 팔아서 " .. Util.FormatNumber(value) .. " 코인을 받았어요"
end)

Net.Handle("Teleport", function(player, target)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return false, nil
	end
	if target == "Museum" then
		local plot = playerPlot[player]
		local entry = plot and plot:FindFirstChild("Entry") :: BasePart?
		if not entry then
			return false, "박물관이 없어요"
		end
		-- 입구에서 안쪽(전시대 방향)을 바라보도록
		root.CFrame = entry.CFrame * CFrame.Angles(0, math.pi, 0) + Vector3.new(0, 2, 0)
		return true, nil
	elseif target == "Field" then
		root.CFrame = world.fieldSpawn
		return true, nil
	end
	return false, nil
end)

----------------------------------------------------------------------
function MuseumService.Init(builtWorld: any)
	world = builtWorld

	for _, plot in world.plots do
		local stand = plot:FindFirstChild("LikeStand")
		local prompt = stand and stand:FindFirstChild("LikePrompt") :: ProximityPrompt?
		if prompt then
			prompt.Triggered:Connect(function(liker)
				onLike(liker, plot)
			end)
		end
	end

	DataService.Loaded:Connect(function(player: Player, data: any, offlineSeconds: number)
		setupLeaderstats(player, data)
		assignPlot(player)
		if offlineSeconds > 60 then
			local earned = math.floor(Economy.GetIncome(data, Passes.Get(player)) * Config.OfflineRate * offlineSeconds)
			if earned > 0 then
				data.coins += earned
				task.delay(3, function()
					if player.Parent then
						Net.Notify:FireClient(player, { kind = "Offline", coins = earned, seconds = offlineSeconds })
					end
				end)
			end
		end
		Net.MarkDirty(player)
	end)

	Net.Changed:Connect(function(player: Player)
		refreshDisplay(player)
		local data = DataService.Get(player)
		local stats = player:FindFirstChild("leaderstats")
		local fossils = stats and stats:FindFirstChild("화석") :: IntValue?
		if data and fossils then
			fossils.Value = countCompleted(data)
		end
	end)

	Players.PlayerRemoving:Connect(releasePlot)

	-- 박물관 수입 (1초마다)
	task.spawn(function()
		while true do
			task.wait(1)
			for player, _ in playerPlot do
				local data = DataService.Get(player)
				if data then
					local income = Economy.GetIncome(data, Passes.Get(player))
					local total = (carry[player] or 0) + income
					local whole = math.floor(total)
					carry[player] = total - whole
					if whole > 0 then
						data.coins += whole
						Net.UpdateCoins(player)
					end
				end
			end
		end
	end)
end

return MuseumService
