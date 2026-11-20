-- 서버 시작점

local Server = script.Parent
local WorldBuilder = require(Server.WorldBuilder)
local DataService = require(Server.DataService)
local Passes = require(Server.Passes)
local Net = require(Server.Net)
local DigService = require(Server.DigService)
local MuseumService = require(Server.MuseumService)
local ShopService = require(Server.ShopService)

local world = WorldBuilder.Build()

Passes.Init()
Passes.Changed:Connect(function(player)
	Net.MarkDirty(player)
end)

-- 순서 중요: 데이터 로드 이벤트를 받는 서비스들을 먼저 연결
MuseumService.Init(world)
DigService.Init(world)
ShopService.Init()
DataService.Init()

print("[FossilMuseum] 서버 준비 완료")
