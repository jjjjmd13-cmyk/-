-- 뽑기 확률, 박물관 수입 계산 (서버와 클라이언트가 같이 사용)
local Config = require(script.Parent.Config)

local Economy = {}

export type Passes = { DoubleSpeed: boolean, DoubleLuck: boolean, DoubleIncome: boolean }

-- 행운 배수: 1 = 기본, 2 = 희귀 이상 확률이 크게 증가
function Economy.GetLuck(data: any, passes: Passes, moundLuck: number): number
	local tool = Config.ToolsById[data.tool] or Config.Tools[1]
	local luck = 1 + tool.luck + moundLuck
	if passes.DoubleLuck then
		luck *= 2
	end
	if (data.luckBoostUntil or 0) > os.time() then
		luck *= 1.5
	end
	return luck
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
function Economy.RollPiece(luck: number, cosmicChance: number): (string, number)
	local rarity
	if cosmicChance > 0 and math.random() < cosmicChance then
		rarity = Config.RarityById.Cosmic
	else
		local pool = {}
		for _, r in Config.Rarities do
			if not r.eventOnly and r.weight > 0 then
				table.insert(pool, r)
			end
		end
		rarity = pickWeighted(pool, function(r)
			-- 등급이 높을수록 행운의 영향을 크게 받음
			return r.weight * luck ^ ((r.tier - 1) * 0.6)
		end)
	end
	local speciesList = Config.SpeciesByRarity[rarity.id]
	local species = speciesList[math.random(1, #speciesList)]
	local pieceCount = #Config.GetPieces(species)
	return species.id, math.random(1, pieceCount)
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
		local ra = Config.RarityById[Config.SpeciesById[a].rarity]
		local rb = Config.RarityById[Config.SpeciesById[b].rarity]
		if ra.income ~= rb.income then
			return ra.income > rb.income
		end
		return a < b
	end)
	while #list > data.slots do
		table.remove(list)
	end
	return list
end

function Economy.GetIncomeMultiplier(data: any, passes: Passes): number
	local unique = 0
	for speciesId, count in data.museum do
		if count > 0 and Config.SpeciesById[speciesId] then
			unique += 1
		end
	end
	local mult = 1
	mult += math.min(data.likes * Config.LikeBonus, Config.MaxLikeBonus)
	mult += unique * Config.UniqueBonus
	if passes.DoubleIncome then
		mult *= 2
	end
	return mult
end

-- 초당 수입
function Economy.GetIncome(data: any, passes: Passes): number
	local base = 0
	for _, speciesId in Economy.GetDisplayed(data) do
		base += Config.RarityById[Config.SpeciesById[speciesId].rarity].income
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
			local price = Config.RarityById[species.rarity].sell
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

return Economy
