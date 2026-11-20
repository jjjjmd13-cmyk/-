--!strict
-- 화석 박물관: 게임 전체 설정값
-- 숫자(가격, 확률, 수입)를 바꿔서 밸런스를 조정하세요.

local Config = {}

----------------------------------------------------------------------
-- 수익화 (Robux)
-- Creator Dashboard 에서 게임 패스 / 개발자 상품을 만든 뒤 ID 를 넣으세요.
-- ID 가 0 이면 상점에 "준비 중" 으로 표시되고 구매할 수 없습니다.
----------------------------------------------------------------------
Config.GamePasses = {
	DoubleSpeed = { id = 0, name = "⚡ 발굴 속도 2배", desc = "삽질 속도가 영원히 2배" },
	DoubleLuck = { id = 0, name = "🍀 행운 2배", desc = "희귀 화석이 나올 확률 2배" },
	DoubleIncome = { id = 0, name = "🏛️ 박물관 수입 2배", desc = "관람객 수입이 영원히 2배" },
}

-- coinsSeconds: 현재 초당 수입 × 이 값 만큼 코인 지급 (최소 minCoins)
Config.Products = {
	CoinsSmall = { id = 0, name = "💰 코인 주머니", coinsSeconds = 600, minCoins = 2000 },
	CoinsMedium = { id = 0, name = "💰 코인 상자", coinsSeconds = 3000, minCoins = 12000 },
	CoinsLarge = { id = 0, name = "💰 코인 금고", coinsSeconds = 12000, minCoins = 60000 },
	LuckBoost = { id = 0, name = "🍀 행운 부스트 15분", minutes = 15 },
}

----------------------------------------------------------------------
-- 희귀도
----------------------------------------------------------------------
export type Rarity = {
	id: string,
	name: string,
	tier: number,
	color: Color3,
	weight: number, -- 뽑기 가중치 (행운 적용 전)
	income: number, -- 완성 화석 1개 전시 시 초당 코인
	sell: number, -- 중복 조각 1개 판매가
	eventOnly: boolean?,
}

Config.Rarities = {
	{ id = "Common", name = "일반", tier = 1, color = Color3.fromRGB(205, 205, 205), weight = 6000, income = 1, sell = 4 },
	{ id = "Uncommon", name = "고급", tier = 2, color = Color3.fromRGB(95, 210, 95), weight = 2500, income = 4, sell = 15 },
	{ id = "Rare", name = "희귀", tier = 3, color = Color3.fromRGB(70, 145, 255), weight = 1000, income = 15, sell = 60 },
	{ id = "Epic", name = "영웅", tier = 4, color = Color3.fromRGB(175, 85, 255), weight = 400, income = 60, sell = 250 },
	{ id = "Legendary", name = "전설", tier = 5, color = Color3.fromRGB(255, 175, 35), weight = 90, income = 250, sell = 1000 },
	{ id = "Mythic", name = "신화", tier = 6, color = Color3.fromRGB(255, 70, 110), weight = 10, income = 1200, sell = 5000 },
	{ id = "Cosmic", name = "우주", tier = 7, color = Color3.fromRGB(110, 255, 235), weight = 0, income = 700, sell = 3000, eventOnly = true },
} :: { Rarity }

Config.RarityById = {} :: { [string]: Rarity }
for _, r in Config.Rarities do
	Config.RarityById[r.id] = r
end

----------------------------------------------------------------------
-- 뼈대 모양별 조각 이름
----------------------------------------------------------------------
Config.ShapePieces = {
	Quadruped = { "두개골", "척추", "갈비뼈", "앞다리", "뒷다리" },
	Biped = { "두개골", "척추", "갈비뼈", "다리", "꼬리" },
	Flyer = { "두개골", "몸통", "날개", "다리" },
	Swimmer = { "두개골", "척추", "지느러미", "꼬리" },
} :: { [string]: { string } }

----------------------------------------------------------------------
-- 화석 종류
-- look: 모형 모양 (scale 크기, neck 목 길이, tail 꼬리 길이, 장식 옵션)
----------------------------------------------------------------------
export type Look = {
	scale: number?,
	neck: number?,
	tail: number?,
	head: number?,
	horns: boolean?,
	plates: boolean?,
	sail: boolean?,
	tusks: boolean?,
	club: boolean?,
}

export type Species = {
	id: string,
	name: string,
	rarity: string,
	shape: string,
	look: Look,
}

Config.Species = {
	-- 일반
	{ id = "Protoceratops", name = "프로토케라톱스", rarity = "Common", shape = "Quadruped", look = { scale = 0.75, neck = 0.5, tail = 0.8, horns = true } },
	{ id = "Compsognathus", name = "콤프소그나투스", rarity = "Common", shape = "Biped", look = { scale = 0.6, head = 0.7, tail = 1.2 } },
	{ id = "Dimetrodon", name = "디메트로돈", rarity = "Common", shape = "Quadruped", look = { scale = 0.8, neck = 0.4, tail = 1.1, sail = true } },
	-- 고급
	{ id = "Iguanodon", name = "이구아노돈", rarity = "Uncommon", shape = "Biped", look = { scale = 0.9, head = 0.8, tail = 1.0 } },
	{ id = "Ankylosaurus", name = "안킬로사우루스", rarity = "Uncommon", shape = "Quadruped", look = { scale = 0.95, neck = 0.4, tail = 1.0, plates = true, club = true } },
	{ id = "Pteranodon", name = "프테라노돈", rarity = "Uncommon", shape = "Flyer", look = { scale = 0.9 } },
	-- 희귀
	{ id = "Triceratops", name = "트리케라톱스", rarity = "Rare", shape = "Quadruped", look = { scale = 1.1, neck = 0.5, tail = 0.9, horns = true } },
	{ id = "Stegosaurus", name = "스테고사우루스", rarity = "Rare", shape = "Quadruped", look = { scale = 1.05, neck = 0.6, tail = 1.2, plates = true } },
	{ id = "Velociraptor", name = "벨로키랍토르", rarity = "Rare", shape = "Biped", look = { scale = 0.8, head = 0.8, tail = 1.4 } },
	-- 영웅
	{ id = "Spinosaurus", name = "스피노사우루스", rarity = "Epic", shape = "Biped", look = { scale = 1.15, head = 1.0, tail = 1.3, sail = true } },
	{ id = "Mosasaurus", name = "모사사우루스", rarity = "Epic", shape = "Swimmer", look = { scale = 1.1, neck = 0.6 } },
	{ id = "Mammoth", name = "매머드", rarity = "Epic", shape = "Quadruped", look = { scale = 1.15, neck = 0.3, tail = 0.3, tusks = true } },
	-- 전설
	{ id = "Tyrannosaurus", name = "티라노사우루스", rarity = "Legendary", shape = "Biped", look = { scale = 1.3, head = 1.4, tail = 1.2 } },
	{ id = "Brachiosaurus", name = "브라키오사우루스", rarity = "Legendary", shape = "Quadruped", look = { scale = 1.2, neck = 2.2, tail = 1.2 } },
	{ id = "Megalodon", name = "메갈로돈", rarity = "Legendary", shape = "Swimmer", look = { scale = 1.25, neck = 0.2, head = 1.4 } },
	-- 신화
	{ id = "CrystalDragon", name = "수정 드래곤", rarity = "Mythic", shape = "Flyer", look = { scale = 1.3, horns = true } },
	-- 우주 (운석 이벤트 전용)
	{ id = "StarRaptor", name = "별빛 랩터", rarity = "Cosmic", shape = "Biped", look = { scale = 0.95, head = 0.9, tail = 1.5 } },
	{ id = "VoidWhale", name = "공허 고래", rarity = "Cosmic", shape = "Swimmer", look = { scale = 1.25, neck = 0.3, head = 1.2 } },
	{ id = "MeteorWyvern", name = "운석 와이번", rarity = "Cosmic", shape = "Flyer", look = { scale = 1.15, horns = true } },
} :: { Species }

Config.SpeciesById = {} :: { [string]: Species }
Config.SpeciesByRarity = {} :: { [string]: { Species } }
for _, s in Config.Species do
	Config.SpeciesById[s.id] = s
	local list = Config.SpeciesByRarity[s.rarity]
	if not list then
		list = {}
		Config.SpeciesByRarity[s.rarity] = list
	end
	table.insert(list, s)
end

function Config.GetPieces(species: Species): { string }
	return Config.ShapePieces[species.shape]
end

----------------------------------------------------------------------
-- 발굴 도구
----------------------------------------------------------------------
export type DigTool = {
	id: string,
	name: string,
	price: number,
	power: number, -- 한 번에 깎는 흙더미 체력
	cooldown: number, -- 삽질 간격(초)
	luck: number, -- 행운 보너스 (+0.1 = +10%)
	color: Color3,
}

Config.Tools = {
	{ id = "WoodShovel", name = "나무 삽", price = 0, power = 1, cooldown = 0.55, luck = 0, color = Color3.fromRGB(150, 105, 60) },
	{ id = "StoneShovel", name = "돌 삽", price = 300, power = 2, cooldown = 0.5, luck = 0.05, color = Color3.fromRGB(130, 130, 135) },
	{ id = "IronShovel", name = "철 삽", price = 2500, power = 3, cooldown = 0.45, luck = 0.15, color = Color3.fromRGB(200, 200, 210) },
	{ id = "GoldShovel", name = "황금 삽", price = 20000, power = 5, cooldown = 0.4, luck = 0.3, color = Color3.fromRGB(255, 200, 40) },
	{ id = "DiamondDrill", name = "다이아 드릴", price = 150000, power = 8, cooldown = 0.32, luck = 0.5, color = Color3.fromRGB(90, 230, 255) },
	{ id = "LaserDrill", name = "레이저 드릴", price = 1000000, power = 14, cooldown = 0.25, luck = 0.9, color = Color3.fromRGB(255, 60, 90) },
} :: { DigTool }

Config.ToolsById = {} :: { [string]: DigTool }
for _, t in Config.Tools do
	Config.ToolsById[t.id] = t
end

Config.DigRange = 16 -- 캐릭터와 흙더미 사이 최대 거리(스터드)

----------------------------------------------------------------------
-- 흙더미 종류
----------------------------------------------------------------------
export type MoundKind = {
	id: string,
	name: string,
	hp: number,
	coins: number,
	pieceChance: number,
	luck: number,
	cosmicChance: number,
	color: Color3,
	spawnWeight: number,
}

Config.Mounds = {
	Dirt = { id = "Dirt", name = "흙더미", hp = 4, coins = 2, pieceChance = 0.55, luck = 0, cosmicChance = 0, color = Color3.fromRGB(125, 88, 58), spawnWeight = 92 },
	Sparkle = { id = "Sparkle", name = "반짝이는 흙더미", hp = 10, coins = 10, pieceChance = 1, luck = 1, cosmicChance = 0, color = Color3.fromRGB(170, 130, 70), spawnWeight = 8 },
	Meteor = { id = "Meteor", name = "운석", hp = 18, coins = 40, pieceChance = 1, luck = 2, cosmicChance = 0.35, color = Color3.fromRGB(80, 40, 120), spawnWeight = 0 },
} :: { [string]: MoundKind }

Config.MoundRespawnTime = 12

----------------------------------------------------------------------
-- 박물관
----------------------------------------------------------------------
Config.StartSlots = 4
Config.MaxSlots = 16
Config.SlotStep = 2
-- 다음 전시대 확장 가격 (4→6, 6→8, ...)
Config.SlotPrices = { 400, 3000, 15000, 60000, 250000, 1000000 }

Config.LikeBonus = 0.01 -- 좋아요 1개당 수입 +1%
Config.MaxLikeBonus = 1.0 -- 최대 +100%
Config.UniqueBonus = 0.03 -- 서로 다른 화석 1종 완성당 수입 +3%

Config.OfflineRate = 0.5 -- 접속하지 않은 동안 수입의 50%
Config.OfflineMaxSeconds = 3 * 60 * 60 -- 최대 3시간

----------------------------------------------------------------------
-- 운석 낙하 이벤트
----------------------------------------------------------------------
Config.MeteorInterval = 8 * 60 -- 이벤트 사이 간격(초)
Config.MeteorDuration = 2 * 60 -- 이벤트 지속시간(초)
Config.MeteorCount = 14

Config.AnnounceTier = 5 -- 이 등급 이상을 찾으면 서버 전체에 알림

return Config
