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
	DoubleSpeed = { id = 0, order = 1, name = "⚡ 발굴 속도 2배", desc = "삽질 속도가 영원히 2배" },
	DoubleLuck = { id = 0, order = 2, name = "🍀 행운 2배", desc = "희귀 화석이 나올 확률 2배" },
	DoubleIncome = { id = 0, order = 3, name = "🏛️ 박물관 수입 2배", desc = "관람객 수입이 영원히 2배" },
	AutoDig = { id = 0, order = 4, name = "🤖 자동 발굴", desc = "삽을 들고 있으면 가까운 흙더미를 알아서 파요" },
	ExtraHelpers = { id = 0, order = 5, name = "🦖 조수 칸 +2", desc = "발굴 조수를 2마리 더 데리고 다녀요" },
}

-- coinsSeconds: 현재 초당 수입 × 이 값 만큼 코인 지급 (최소 minCoins)
Config.Products = {
	CoinsSmall = { id = 0, order = 1, name = "💰 코인 주머니", coinsSeconds = 600, minCoins = 2000 },
	CoinsMedium = { id = 0, order = 2, name = "💰 코인 상자", coinsSeconds = 3000, minCoins = 12000 },
	CoinsLarge = { id = 0, order = 3, name = "💰 코인 금고", coinsSeconds = 12000, minCoins = 60000 },
	LuckBoost = { id = 0, order = 4, name = "🍀 행운 부스트 15분", minutes = 15 },
	ServerLuck = { id = 0, order = 5, name = "🌟 서버 전체 행운 2배 15분", minutes = 15 },
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
	income: number, -- 완성 화석 1개 전시 시 초당 코인 (지역 배수 적용 전)
	sell: number, -- 중복 조각 1개 판매가 (지역 배수 적용 전)
	eventOnly: boolean?,
}

Config.Rarities = {
	{ id = "Common", name = "일반", tier = 1, color = Color3.fromRGB(205, 205, 205), weight = 6000, income = 1, sell = 4 },
	{ id = "Uncommon", name = "고급", tier = 2, color = Color3.fromRGB(95, 210, 95), weight = 2500, income = 4, sell = 15 },
	{ id = "Rare", name = "희귀", tier = 3, color = Color3.fromRGB(70, 145, 255), weight = 1000, income = 15, sell = 60 },
	{ id = "Epic", name = "영웅", tier = 4, color = Color3.fromRGB(175, 85, 255), weight = 400, income = 60, sell = 250 },
	{ id = "Legendary", name = "전설", tier = 5, color = Color3.fromRGB(255, 175, 35), weight = 90, income = 250, sell = 1000 },
	{ id = "Mythic", name = "신화", tier = 6, color = Color3.fromRGB(255, 70, 110), weight = 10, income = 1200, sell = 5000 },
	{ id = "Cosmic", name = "우주", tier = 7, color = Color3.fromRGB(110, 255, 235), weight = 0, income = 900, sell = 3500, eventOnly = true },
} :: { Rarity }

Config.RarityById = {} :: { [string]: Rarity }
for _, r in Config.Rarities do
	Config.RarityById[r.id] = r
end

----------------------------------------------------------------------
-- 발굴 지역
-- incomeMult: 이 지역 화석의 수입/판매가 배수, coinMult: 흙더미 코인 배수, hpMult: 흙더미 체력 배수
----------------------------------------------------------------------
export type Zone = {
	id: string,
	name: string,
	emoji: string,
	price: number,
	incomeMult: number,
	coinMult: number,
	hpMult: number,
	angle: number?, -- 사막(가운데)을 기준으로 놓이는 방향(도)
	groundColor: Color3,
	groundMaterial: Enum.Material,
	moundColor: Color3,
	moundMaterial: Enum.Material,
	barrierColor: Color3,
}

Config.Zones = {
	{
		id = "Desert", name = "사막 발굴장", emoji = "🏜️", price = 0, incomeMult = 1, coinMult = 1, hpMult = 1,
		groundColor = Color3.fromRGB(150, 110, 75), groundMaterial = Enum.Material.Ground,
		moundColor = Color3.fromRGB(125, 88, 58), moundMaterial = Enum.Material.Ground, barrierColor = Color3.fromRGB(255, 200, 120),
	},
	{
		id = "Glacier", name = "빙하 지대", emoji = "🧊", price = 40000, incomeMult = 6, coinMult = 5, hpMult = 2.5, angle = 15,
		groundColor = Color3.fromRGB(225, 240, 250), groundMaterial = Enum.Material.Snow,
		moundColor = Color3.fromRGB(170, 205, 230), moundMaterial = Enum.Material.Glacier, barrierColor = Color3.fromRGB(140, 220, 255),
	},
	{
		id = "Volcano", name = "화산 지대", emoji = "🌋", price = 1500000, incomeMult = 40, coinMult = 30, hpMult = 6, angle = 135,
		groundColor = Color3.fromRGB(55, 45, 45), groundMaterial = Enum.Material.Basalt,
		moundColor = Color3.fromRGB(110, 45, 35), moundMaterial = Enum.Material.CrackedLava, barrierColor = Color3.fromRGB(255, 110, 40),
	},
	{
		id = "Coast", name = "해안 절벽", emoji = "🌊", price = 60000000, incomeMult = 250, coinMult = 180, hpMult = 15, angle = 225,
		groundColor = Color3.fromRGB(240, 225, 180), groundMaterial = Enum.Material.Sand,
		moundColor = Color3.fromRGB(160, 150, 130), moundMaterial = Enum.Material.Limestone, barrierColor = Color3.fromRGB(60, 170, 255),
	},
} :: { Zone }

Config.ZoneById = {} :: { [string]: Zone }
for i, z in Config.Zones do
	Config.ZoneById[z.id] = z
	local entry: any = z
	entry.index = i
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
-- zone: 나오는 지역 ("Event" = 운석 이벤트)
-- look: 모형 모양 (scale 크기, neck 목 길이, tail 꼬리 길이, head 머리 크기, 장식 옵션)
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
	zone: string,
	shape: string,
	look: Look,
}

local function S(zone: string, rarity: string, id: string, name: string, shape: string, look: Look): Species
	return { id = id, name = name, rarity = rarity, zone = zone, shape = shape, look = look }
end

Config.Species = {
	-- 🏜️ 사막
	S("Desert", "Common", "Protoceratops", "프로토케라톱스", "Quadruped", { scale = 0.75, neck = 0.5, tail = 0.8, horns = true }),
	S("Desert", "Common", "Compsognathus", "콤프소그나투스", "Biped", { scale = 0.6, head = 0.7, tail = 1.2 }),
	S("Desert", "Common", "Dimetrodon", "디메트로돈", "Quadruped", { scale = 0.8, neck = 0.4, tail = 1.1, sail = true }),
	S("Desert", "Uncommon", "Iguanodon", "이구아노돈", "Biped", { scale = 0.9, head = 0.8, tail = 1.0 }),
	S("Desert", "Uncommon", "Ankylosaurus", "안킬로사우루스", "Quadruped", { scale = 0.95, neck = 0.4, tail = 1.0, plates = true, club = true }),
	S("Desert", "Uncommon", "Pteranodon", "프테라노돈", "Flyer", { scale = 0.9 }),
	S("Desert", "Rare", "Triceratops", "트리케라톱스", "Quadruped", { scale = 1.1, neck = 0.5, tail = 0.9, horns = true }),
	S("Desert", "Rare", "Stegosaurus", "스테고사우루스", "Quadruped", { scale = 1.05, neck = 0.6, tail = 1.2, plates = true }),
	S("Desert", "Rare", "Velociraptor", "벨로키랍토르", "Biped", { scale = 0.8, head = 0.8, tail = 1.4 }),
	S("Desert", "Epic", "Spinosaurus", "스피노사우루스", "Biped", { scale = 1.15, head = 1.0, tail = 1.3, sail = true }),
	S("Desert", "Epic", "Parasaurolophus", "파라사우롤로푸스", "Biped", { scale = 1.05, head = 0.9, tail = 1.1, horns = true }),
	S("Desert", "Legendary", "Tyrannosaurus", "티라노사우루스", "Biped", { scale = 1.3, head = 1.4, tail = 1.2 }),
	S("Desert", "Legendary", "Brachiosaurus", "브라키오사우루스", "Quadruped", { scale = 1.2, neck = 2.2, tail = 1.2 }),
	S("Desert", "Mythic", "CrystalDragon", "수정 드래곤", "Flyer", { scale = 1.3, horns = true }),

	-- 🧊 빙하
	S("Glacier", "Common", "CaveBear", "동굴곰", "Quadruped", { scale = 0.8, neck = 0.3, tail = 0.2, head = 1.1 }),
	S("Glacier", "Common", "Megaloceros", "큰뿔사슴", "Quadruped", { scale = 0.85, neck = 0.9, tail = 0.2, horns = true }),
	S("Glacier", "Common", "ArcticFox", "북극여우", "Quadruped", { scale = 0.6, neck = 0.5, tail = 1.1 }),
	S("Glacier", "Uncommon", "WoollyRhino", "털코뿔소", "Quadruped", { scale = 1.0, neck = 0.3, tail = 0.3, horns = true }),
	S("Glacier", "Uncommon", "GiantPenguin", "거대 펭귄", "Biped", { scale = 0.8, head = 0.7, tail = 0.2 }),
	S("Glacier", "Rare", "Smilodon", "검치호", "Quadruped", { scale = 0.95, neck = 0.4, tail = 0.4, tusks = true }),
	S("Glacier", "Rare", "Glyptodon", "글립토돈", "Quadruped", { scale = 0.95, neck = 0.2, tail = 0.8, plates = true, club = true }),
	S("Glacier", "Epic", "Mammoth", "매머드", "Quadruped", { scale = 1.15, neck = 0.3, tail = 0.3, tusks = true }),
	S("Glacier", "Epic", "Megatherium", "메가테리움", "Biped", { scale = 1.15, head = 0.9, tail = 0.9 }),
	S("Glacier", "Legendary", "Paraceratherium", "파라케라테리움", "Quadruped", { scale = 1.3, neck = 1.4, tail = 0.4 }),
	S("Glacier", "Legendary", "FrostTyrant", "서리 티라노", "Biped", { scale = 1.3, head = 1.4, tail = 1.3, horns = true }),
	S("Glacier", "Mythic", "FrostWyrm", "서리 와이번", "Flyer", { scale = 1.35, horns = true }),

	-- 🌋 화산
	S("Volcano", "Common", "Oviraptor", "오비랍토르", "Biped", { scale = 0.7, head = 0.8, tail = 1.0, horns = true }),
	S("Volcano", "Common", "Coelophysis", "코엘로피시스", "Biped", { scale = 0.75, head = 0.7, tail = 1.4 }),
	S("Volcano", "Uncommon", "Pachycephalosaurus", "파키케팔로사우루스", "Biped", { scale = 0.9, head = 1.2, tail = 1.0 }),
	S("Volcano", "Uncommon", "Dilophosaurus", "딜로포사우루스", "Biped", { scale = 0.95, head = 0.9, tail = 1.2, horns = true }),
	S("Volcano", "Rare", "Carnotaurus", "카르노타우루스", "Biped", { scale = 1.05, head = 1.0, tail = 1.2, horns = true }),
	S("Volcano", "Rare", "Quetzalcoatlus", "케찰코아틀루스", "Flyer", { scale = 1.2, horns = true }),
	S("Volcano", "Epic", "Allosaurus", "알로사우루스", "Biped", { scale = 1.15, head = 1.2, tail = 1.2 }),
	S("Volcano", "Epic", "Therizinosaurus", "테리지노사우루스", "Biped", { scale = 1.15, head = 0.7, tail = 1.0 }),
	S("Volcano", "Legendary", "Giganotosaurus", "기가노토사우루스", "Biped", { scale = 1.35, head = 1.5, tail = 1.3 }),
	S("Volcano", "Legendary", "Argentinosaurus", "아르겐티노사우루스", "Quadruped", { scale = 1.3, neck = 2.4, tail = 1.4 }),
	S("Volcano", "Mythic", "MagmaPhoenix", "용암 불사조", "Flyer", { scale = 1.35, horns = true }),

	-- 🌊 해안
	S("Coast", "Common", "Ichthyosaurus", "이크티오사우루스", "Swimmer", { scale = 0.8, neck = 0.3 }),
	S("Coast", "Common", "Helicoprion", "헬리코프리온", "Swimmer", { scale = 0.85, neck = 0.2, head = 1.1 }),
	S("Coast", "Uncommon", "Archelon", "아르켈론", "Swimmer", { scale = 0.95, neck = 0.6, head = 0.8 }),
	S("Coast", "Uncommon", "Elasmosaurus", "엘라스모사우루스", "Swimmer", { scale = 0.95, neck = 2.0, head = 0.7 }),
	S("Coast", "Rare", "Plesiosaurus", "플레시오사우루스", "Swimmer", { scale = 1.0, neck = 1.4, head = 0.8 }),
	S("Coast", "Rare", "Tylosaurus", "틸로사우루스", "Swimmer", { scale = 1.1, neck = 0.4, head = 1.2 }),
	S("Coast", "Epic", "Mosasaurus", "모사사우루스", "Swimmer", { scale = 1.15, neck = 0.6 }),
	S("Coast", "Epic", "Liopleurodon", "리오플레우로돈", "Swimmer", { scale = 1.15, neck = 0.3, head = 1.4 }),
	S("Coast", "Legendary", "Megalodon", "메갈로돈", "Swimmer", { scale = 1.3, neck = 0.2, head = 1.4 }),
	S("Coast", "Legendary", "Dunkleosteus", "둔클레오스테우스", "Swimmer", { scale = 1.25, neck = 0.2, head = 1.6, horns = true }),
	S("Coast", "Mythic", "Kraken", "크라켄", "Swimmer", { scale = 1.4, neck = 0.8, head = 1.6, horns = true }),

	-- ☄️ 운석 이벤트 전용
	S("Event", "Cosmic", "StarRaptor", "별빛 랩터", "Biped", { scale = 0.95, head = 0.9, tail = 1.5 }),
	S("Event", "Cosmic", "VoidWhale", "공허 고래", "Swimmer", { scale = 1.25, neck = 0.3, head = 1.2 }),
	S("Event", "Cosmic", "MeteorWyvern", "운석 와이번", "Flyer", { scale = 1.15, horns = true }),
	S("Event", "Cosmic", "NebulaRex", "성운 렉스", "Biped", { scale = 1.3, head = 1.4, tail = 1.3, horns = true }),
} :: { Species }

Config.SpeciesById = {} :: { [string]: Species }
-- [zoneId][rarityId] = { Species }
Config.SpeciesByZoneRarity = {} :: { [string]: { [string]: { Species } } }
for _, s in Config.Species do
	Config.SpeciesById[s.id] = s
	local byRarity = Config.SpeciesByZoneRarity[s.zone]
	if not byRarity then
		byRarity = {}
		Config.SpeciesByZoneRarity[s.zone] = byRarity
	end
	local list = byRarity[s.rarity]
	if not list then
		list = {}
		byRarity[s.rarity] = list
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
	{ id = "PlasmaDrill", name = "플라즈마 굴착기", price = 8000000, power = 25, cooldown = 0.22, luck = 1.3, color = Color3.fromRGB(190, 90, 255) },
	{ id = "QuantumDrill", name = "양자 굴착기", price = 60000000, power = 45, cooldown = 0.2, luck = 1.8, color = Color3.fromRGB(80, 255, 170) },
	{ id = "BlackHoleDrill", name = "블랙홀 드릴", price = 500000000, power = 80, cooldown = 0.18, luck = 2.5, color = Color3.fromRGB(30, 20, 60) },
} :: { DigTool }

Config.ToolsById = {} :: { [string]: DigTool }
for _, t in Config.Tools do
	Config.ToolsById[t.id] = t
end

Config.DigRange = 16 -- 캐릭터와 흙더미 사이 최대 거리(스터드)

----------------------------------------------------------------------
-- 흙더미 종류 (지역 배수가 곱해짐)
----------------------------------------------------------------------
export type MoundKind = {
	id: string,
	name: string,
	hp: number,
	coins: number,
	pieceChance: number,
	luck: number,
	cosmicChance: number,
	spawnWeight: number,
}

Config.Mounds = {
	Dirt = { id = "Dirt", name = "흙더미", hp = 4, coins = 2, pieceChance = 0.55, luck = 0, cosmicChance = 0, spawnWeight = 92 },
	Sparkle = { id = "Sparkle", name = "반짝이는 흙더미", hp = 10, coins = 10, pieceChance = 1, luck = 1, cosmicChance = 0, spawnWeight = 8 },
	Meteor = { id = "Meteor", name = "운석", hp = 18, coins = 40, pieceChance = 1, luck = 2, cosmicChance = 0.35, spawnWeight = 0 },
} :: { [string]: MoundKind }

Config.MoundRespawnTime = 12
Config.CoopBonus = 0.2 -- 2명 이상이 같이 판 흙더미는 보상 +20% (각자 판 만큼 나눠 받은 뒤 적용)

----------------------------------------------------------------------
-- 발굴 조수: 데리고 다니면 서 있는 지역에서 자동으로 발굴
----------------------------------------------------------------------
export type Helper = {
	id: string,
	name: string,
	price: number,
	interval: number, -- 몇 초마다 흙더미 하나를 파는지
	color: Color3,
}

Config.Helpers = {
	{ id = "BabyRaptor", name = "아기 랩터", price = 1500, interval = 8, color = Color3.fromRGB(120, 200, 90) },
	{ id = "DigMole", name = "두더지 일꾼", price = 12000, interval = 6.5, color = Color3.fromRGB(140, 100, 80) },
	{ id = "PteroDrone", name = "프테라 드론", price = 120000, interval = 5, color = Color3.fromRGB(230, 200, 120) },
	{ id = "RoboDigger", name = "굴착 로봇", price = 1500000, interval = 4, color = Color3.fromRGB(170, 180, 200) },
	{ id = "GoldGolem", name = "황금 골렘", price = 25000000, interval = 3, color = Color3.fromRGB(255, 205, 60) },
	{ id = "StarSpirit", name = "별의 정령", price = 400000000, interval = 2.2, color = Color3.fromRGB(140, 240, 255) },
} :: { Helper }

Config.HelperById = {} :: { [string]: Helper }
for _, h in Config.Helpers do
	Config.HelperById[h.id] = h
end

Config.HelperSlots = 3
Config.HelperPieceChance = 0.5 -- 조수는 조각이 나올 확률이 흙더미 기본값의 50%

----------------------------------------------------------------------
-- 박물관
----------------------------------------------------------------------
Config.StartSlots = 4
Config.MaxSlots = 16
Config.SlotStep = 2
-- 다음 전시대 확장 가격 (4→6, 6→8, ...)
Config.SlotPrices = { 400, 3000, 15000, 60000, 250000, 1000000 }

Config.PlotCount = 12 -- 박물관 부지 수 = 서버 최대 인원
Config.LikeBonus = 0.01 -- 좋아요 1개당 수입 +1% (LikeSoftCap 개까지)
Config.LikeSoftCap = 100
Config.LikeBonusAfterCap = 0.002 -- 그 뒤로는 1개당 +0.2% (한도 없음)
Config.NpcLikeWeight = 0.2 -- NPC 손님 좋아요 1개 = 사람 좋아요 0.2개 (랭킹에는 안 들어감)
Config.NpcLikeInterval = 30 -- 몇 초마다 NPC 손님이 좋아요를 남길지 확인
Config.NpcLikeAppealDivisor = 60 -- 확률 = 매력도 / 이 값 (최대 80%)
Config.LikerRewardSeconds = 60 -- 좋아요를 누른 사람 보상 = 내 초당 수입 × 60초
Config.LikerRewardMin = 200
Config.UniqueBonus = 0.03 -- 서로 다른 화석 1종 완성당 수입 +3%
Config.ZoneCompleteBonus = 0.25 -- 한 지역의 화석을 모두 완성하면 수입 +25%

Config.OfflineRate = 0.5 -- 접속하지 않은 동안 수입의 50%
Config.OfflineMaxSeconds = 3 * 60 * 60 -- 최대 3시간

----------------------------------------------------------------------
-- 환생: 코인, 도구, 지역, 전시대가 초기화되는 대신 영구 보너스
-- (화석 조각과 완성 화석, 좋아요, 조수는 유지)
----------------------------------------------------------------------
Config.Rebirth = {
	basePrice = 5000000,
	growth = 4, -- 환생할 때마다 가격 ×4
	incomeBonus = 0.5, -- 환생 1회당 박물관 수입 +50%
	coinBonus = 0.5, -- 환생 1회당 발굴 코인 +50%
	luckBonus = 0.1, -- 환생 1회당 행운 +10%
}

----------------------------------------------------------------------
-- 매일 접속 보상 (7일 주기). coinsSeconds × 초당 수입, 최소 minCoins
----------------------------------------------------------------------
Config.DailyRewards = {
	{ coinsSeconds = 300, minCoins = 500 },
	{ coinsSeconds = 450, minCoins = 800 },
	{ coinsSeconds = 600, minCoins = 1200 },
	{ coinsSeconds = 900, minCoins = 2000 },
	{ coinsSeconds = 1200, minCoins = 3000 },
	{ coinsSeconds = 1500, minCoins = 5000 },
	{ coinsSeconds = 2400, minCoins = 10000, luckMinutes = 30 },
}

----------------------------------------------------------------------
-- 일일 퀘스트 (매일 3개)
----------------------------------------------------------------------
Config.QuestTemplates = {
	{ type = "Dig", text = "흙더미 %d개 파기", amounts = { 40, 90, 160 } },
	{ type = "Find", text = "화석 조각 %d개 찾기", amounts = { 20, 45, 90 } },
	{ type = "FindRare", text = "희귀 등급 이상 조각 %d개 찾기", amounts = { 2, 5, 10 } },
	{ type = "Assemble", text = "화석 %d개 조립하기", amounts = { 1, 2, 4 } },
	{ type = "Like", text = "다른 박물관에 좋아요 %d번 누르기", amounts = { 1, 2, 3 } },
	{ type = "Meteor", text = "운석 %d개 부수기", amounts = { 1, 3, 5 } },
	{ type = "HelperDig", text = "조수가 흙더미 %d개 파기", amounts = { 20, 50, 100 } },
}
Config.QuestRewardSeconds = { 300, 700, 1500 } -- 난이도별 보상 (초당 수입 × 초)
Config.QuestMinReward = { 800, 2000, 5000 }
Config.QuestAllDoneLuckMinutes = 10 -- 3개 다 끝내면 행운 부스트

----------------------------------------------------------------------
-- 거래
----------------------------------------------------------------------
Config.TradeMaxItems = 12 -- 한쪽이 올릴 수 있는 조각 종류 수
Config.TradeRequestCooldown = 10

----------------------------------------------------------------------
-- 운석 낙하 이벤트
----------------------------------------------------------------------
Config.MeteorInterval = 8 * 60 -- 이벤트 사이 간격(초)
Config.MeteorDuration = 2 * 60 -- 이벤트 지속시간(초)
Config.MeteorsPerZone = 6

Config.AnnounceTier = 5 -- 이 등급 이상을 찾으면 서버 전체에 알림

return Config
