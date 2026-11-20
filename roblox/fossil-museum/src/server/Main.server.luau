-- 서버 시작점
local Server = script.Parent
local WorldBuilder = require(Server.WorldBuilder)
local DataService = require(Server.DataService)
local Passes = require(Server.Passes)
local Net = require(Server.Net)
local Zones = require(Server.Zones)
local DigService = require(Server.DigService)
local MuseumService = require(Server.MuseumService)
local ShopService = require(Server.ShopService)
local HelperService = require(Server.HelperService)
local TradeService = require(Server.TradeService)
local LeaderboardService = require(Server.LeaderboardService)
require(Server.QuestService) -- 버튼 요청 처리 등록

local world = WorldBuilder.Build()
Zones.Init(world)

Passes.Init()
Passes.Changed:Connect(function(player)
	Net.MarkDirty(player)
end)

-- 순서 중요: 데이터 로드 이벤트를 받는 서비스들을 먼저 연결하고, DataService 는 마지막에
MuseumService.Init(world)
DigService.Init(world)
HelperService.Init()
ShopService.Init()
TradeService.Init()
LeaderboardService.Init(world)
DataService.Init()

print("[FossilMuseum] 서버 준비 완료")
