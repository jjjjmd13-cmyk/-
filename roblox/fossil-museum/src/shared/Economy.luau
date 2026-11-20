-- 뽑기 확률, 수입, 가격 계산 (서버와 클라이언트가 같이 사용)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(script.Parent.Config)

local Economy = {}

export type Passes = {
	DoubleSpeed: boolean,
	DoubleLuck: boolean,
	DoubleIncome: boolean,
	AutoDig: boolean,
	ExtraHelpers: boolean,
}

function Economy.ZoneMult(zoneId: string): number
	local zone = Config.ZoneById[zoneId]
	return if zone then zone.incomeMult else 1
end

-- 완성 화석 1개의 초당 수입 (배수 적용 전)
function Economy.SpeciesIncome(species: Config.Species): number
	return Config.RarityById[species.rarity].income * Economy.ZoneMult(species.zone)
end

-- 중복 조각 1개 판매가
function Economy.SpeciesSell(species: Config.Species): number
	return Config.RarityById[species.rarity].sell * Economy.ZoneMult(species.zone)
end

function Economy.ServerLuckActive(): boolean
	local untilTime = ReplicatedStorage:GetAttribute("ServerLuckUntil")
	return type(untilTime) == "number" and untilTime > os.time()
end

-- 행운 배수: 1 = 기본. 높을수록 희귀 등급 확률이 크게 증가
function Economy.GetLuck(data: any, passes: Passes, moundLuck: number): number
	local tool = Config.ToolsById[data.tool] or Config.Tools[1]
	local luck = 1 + tool.luck + moundLuck + (data.rebirths or 0) * Config.Rebirth.luckBonus
	if passes.DoubleLuck then
		luck *= 2
	end
	if (data.luckBoostUntil or 0) > os.time() then
		luck *= 1.5
	end
	if Economy.ServerLuckActive() then
		luck *= 2
	end
	return luck
end

function Economy.GetCoinMultiplier(data: any): number
	return 1 + (data.rebirths or 0) * Config.Rebirth.coinBonus
end

local function pickWeighted<T>(items: { T }, weightOf: (T) -> number): T
	local total = 0
	for _, item in items do
		total += weightOf(item)
	end
	local roll = math.random() * total
	for _, item in items do
		roll -= weightOf(item)
		if roll <= 0 then
			return item
		end
	end
	return items[#items]
end

-- 조각 하나 뽑기. 반환: speciesId, pieceIndex
function Economy.RollPiece(luck: number, cosmicChance: number, zoneId: string): (string, number)
	local zoneId2 = zoneId
	local rarity
	if cosmicChance > 0 and math.random() < cosmicChance then
		rarity = Config.RarityById.Cosmic
		zoneId2 = "Event"
	else
		local byRarity = Config.SpeciesByZoneRarity[zoneId] or Config.SpeciesByZoneRarity.Desert
		local pool = {}
		for _, r in Config.Rarities do
			if not r.eventOnly and r.weight > 0 and byRarity[r.id] then
				table.insert(pool, r)
			end
		end
		rarity = pickWeighted(pool, function(r)
			-- 등급이 높을수록 행운의 영향을 크게 받음
			return r.weight * luck ^ ((r.tier - 1) * 0.6)
		end)
	end
	local byRarity = Config.SpeciesByZoneRarity[zoneId2] or Config.SpeciesByZoneRarity.Desert
	local speciesList = byRarity[rarity.id]
	local species = speciesList[math.random(1, #speciesList)]
	return species.id, math.random(1, #Config.GetPieces(species))
end

-- 전시 중인 화석 목록 (수입 높은 순, 전시대 개수만큼)
function Economy.GetDisplayed(data: any): { string }
	local list = {}
	for speciesId, count in data.museum do
		if Config.SpeciesById[speciesId] then
			for _ = 1, math.min(count, data.slots) do
				table.insert(list, speciesId)
			end
		end
	end
	table.sort(list, function(a, b)
		local ia = Economy.SpeciesIncome(Config.SpeciesById[a])
		local ib = Economy.SpeciesIncome(Config.SpeciesById[b])
		if ia ~= ib then
			return ia > ib
		end
		return a < b
	end)
	while #list > data.slots do
		table.remove(list)
	end
	return list
end

-- 지역별 완성 현황: { [zoneId] = { done = n, total = n } }
function Economy.GetZoneProgress(data: any): { [string]: { done: number, total: number } }
	local result = {}
	for _, species in Config.Species do
		local entry = result[species.zone]
		if not entry then
			entry = { done = 0, total = 0 }
			result[species.zone] = entry
		end
		entry.total += 1
		if (data.museum[species.id] or 0) > 0 then
			entry.done += 1
		end
	end
	return result
end

function Economy.GetIncomeMultiplier(data: any, passes: Passes): number
	local unique = 0
	for speciesId, count in data.museum do
		if count > 0 and Config.SpeciesById[speciesId] then
			unique += 1
		end
	end
	local zonesDone = 0
	for _, entry in Economy.GetZoneProgress(data) do
		if entry.done >= entry.total then
			zonesDone += 1
		end
	end
	local mult = 1
	mult += math.min(data.likes * Config.LikeBonus, Config.MaxLikeBonus)
	mult += unique * Config.UniqueBonus
	mult += zonesDone * Config.ZoneCompleteBonus
	mult += (data.rebirths or 0) * Config.Rebirth.incomeBonus
	if passes.DoubleIncome then
		mult *= 2
	end
	return mult
end

-- 초당 수입
function Economy.GetIncome(data: any, passes: Passes): number
	local base = 0
	for _, speciesId in Economy.GetDisplayed(data) do
		base += Economy.SpeciesIncome(Config.SpeciesById[speciesId])
	end
	return base * Economy.GetIncomeMultiplier(data, passes)
end

function Economy.HasAllPieces(data: any, speciesId: string): boolean
	local species = Config.SpeciesById[speciesId]
	local owned = data.pieces[speciesId]
	if not species or not owned then
		return false
	end
	for i = 1, #Config.GetPieces(species) do
		if (owned[tostring(i)] or 0) < 1 then
			return false
		end
	end
	return true
end

-- 중복 조각(각 조각 1개씩 남기고) 판매 가격
function Economy.GetDuplicateValue(data: any): number
	local total = 0
	for speciesId, owned in data.pieces do
		local species = Config.SpeciesById[speciesId]
		if species then
			local price = Economy.SpeciesSell(species)
			for _, count in owned do
				if count > 1 then
					total += (count - 1) * price
				end
			end
		end
	end
	return total
end

function Economy.GetNextSlotPrice(data: any): number?
	if data.slots >= Config.MaxSlots then
		return nil
	end
	local index = (data.slots - Config.StartSlots) // Config.SlotStep + 1
	return Config.SlotPrices[index]
end

function Economy.GetDigCooldown(data: any, passes: Passes): number
	local tool = Config.ToolsById[data.tool] or Config.Tools[1]
	return tool.cooldown * (if passes.DoubleSpeed then 0.5 else 1)
end

function Economy.GetRebirthPrice(data: any): number
	return Config.Rebirth.basePrice * Config.Rebirth.growth ^ (data.rebirths or 0)
end

function Economy.GetHelperSlots(passes: Passes): number
	return Config.HelperSlots + (if passes.ExtraHelpers then 2 else 0)
end

function Economy.CountEquipped(data: any, helperId: string): number
	local n = 0
	for _, id in data.helpersEquipped do
		if id == helperId then
			n += 1
		end
	end
	return n
end

return Economy
