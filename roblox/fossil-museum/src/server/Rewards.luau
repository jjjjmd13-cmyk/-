-- 흙더미를 부쉈을 때 보상 (플레이어 삽질 + 조수 자동 발굴 공통)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Passes = require(script.Parent.Passes)
local Net = require(script.Parent.Net)
local QuestService = require(script.Parent.QuestService)

local Rewards = {}

export type Options = {
	helper: boolean?,
	helperName: string?,
	share: number?, -- 같이 팠을 때 내 몫 (0~1+, 보너스 포함). 없으면 1
	coop: boolean?, -- 2명 이상이 같이 팠는지
}

function Rewards.Dig(player: Player, data: any, kindId: string, zoneId: string, position: Vector3, options: Options?)
	local opts = options or {}
	local kind = Config.Mounds[kindId] or Config.Mounds.Dirt
	local zone = Config.ZoneById[zoneId] or Config.Zones[1]
	local passes = Passes.Get(player)
	local tool = Config.ToolsById[data.tool] or Config.Tools[1]

	local share = opts.share or 1
	local coins = math.floor(kind.coins * zone.coinMult * (1 + tool.power * 0.1) * Economy.GetCoinMultiplier(data) * share)
	data.coins += coins
	data.stats.totalEarned += coins

	if opts.helper then
		data.stats.helperDug += 1
		QuestService.Progress(player, "HelperDig")
	else
		data.stats.dug += 1
		QuestService.Progress(player, "Dig")
	end
	if kindId == "Meteor" then
		data.stats.meteors += 1
		QuestService.Progress(player, "Meteor")
	end

	local result: { [string]: any } = { kind = "Dig", coins = coins, position = position, helper = opts.helper == true, coop = opts.coop == true }
	local pieceChance = math.min(1, kind.pieceChance * (if opts.helper then Config.HelperPieceChance else 1) * share)
	local foundPiece = false

	if math.random() < pieceChance then
		foundPiece = true
		local luck = Economy.GetLuck(data, passes, kind.luck)
		local speciesId, pieceIndex = Economy.RollPiece(luck, kind.cosmicChance, zone.id)
		local owned = data.pieces[speciesId]
		if not owned then
			owned = {}
			data.pieces[speciesId] = owned
		end
		local key = tostring(pieceIndex)
		local before = owned[key] or 0
		owned[key] = before + 1
		data.stats.found += 1

		result.speciesId = speciesId
		result.pieceIndex = pieceIndex
		result.isNew = before == 0
		result.complete = Economy.HasAllPieces(data, speciesId)
		-- 뼈 튀어나오는 연출 (주변 사람들도 봄)
		Net.Effect:FireAllClients("Bone", position, speciesId, pieceIndex, player.UserId, result.isNew)

		local species = Config.SpeciesById[speciesId]
		local rarity = Config.RarityById[species.rarity]
		QuestService.Progress(player, "Find")
		if rarity.tier >= 3 then
			QuestService.Progress(player, "FindRare")
		end
		if rarity.tier >= Config.AnnounceTier then
			local pieceName = Config.GetPieces(species)[pieceIndex]
			local who = if opts.helper then string.format("%s님의 조수 %s(이)가", player.DisplayName, opts.helperName or "") else player.DisplayName .. "님이"
			Net.Announce(string.format("🦴 %s [%s] %s %s 조각을 발견했어요!", who, rarity.name, species.name, pieceName), rarity.color)
		end
	end

	Net.Notify:FireClient(player, result)
	if foundPiece or kindId == "Meteor" then
		Net.MarkDirty(player)
	else
		Net.UpdateCoins(player)
	end
end

return Rewards
