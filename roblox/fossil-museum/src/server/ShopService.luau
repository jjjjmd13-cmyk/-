-- 상점: 코인으로 도구/전시대 구매, Robux 개발자 상품 처리
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Util = require(ReplicatedStorage.Shared.Util)
local DataService = require(script.Parent.DataService)
local Passes = require(script.Parent.Passes)
local Net = require(script.Parent.Net)
local DigService = require(script.Parent.DigService)
local Zones = require(script.Parent.Zones)

local ShopService = {}

local MAX_RECEIPTS = 50

Net.Handle("BuyTool", function(player, toolId)
	local data = DataService.Get(player)
	local def = type(toolId) == "string" and Config.ToolsById[toolId]
	if not def then
		return false, "없는 도구예요"
	end
	if data.ownedTools[def.id] then
		return false, "이미 가지고 있어요"
	end
	if data.coins < def.price then
		return false, "코인이 " .. Util.FormatNumber(def.price - data.coins) .. " 부족해요"
	end
	data.coins -= def.price
	data.ownedTools[def.id] = true
	data.tool = def.id
	DigService.GiveTool(player)
	Net.MarkDirty(player)
	return true, def.name .. " 구매 완료! ⛏️"
end)

Net.Handle("EquipTool", function(player, toolId)
	local data = DataService.Get(player)
	if type(toolId) ~= "string" or not data.ownedTools[toolId] or not Config.ToolsById[toolId] then
		return false, "가지고 있지 않은 도구예요"
	end
	data.tool = toolId
	DigService.GiveTool(player)
	Net.MarkDirty(player)
	return true, nil
end)

Net.Handle("BuySlot", function(player)
	local data = DataService.Get(player)
	local price = Economy.GetNextSlotPrice(data)
	if not price then
		return false, "전시대를 모두 열었어요"
	end
	if data.coins < price then
		return false, "코인이 " .. Util.FormatNumber(price - data.coins) .. " 부족해요"
	end
	data.coins -= price
	data.slots = math.min(data.slots + Config.SlotStep, Config.MaxSlots)
	Net.MarkDirty(player)
	return true, "전시대 확장! 이제 " .. data.slots .. "개를 전시할 수 있어요"
end)

----------------------------------------------------------------------
-- 발굴 지역 열기
----------------------------------------------------------------------
Net.Handle("BuyZone", function(player, zoneId)
	local data = DataService.Get(player)
	local zone = type(zoneId) == "string" and Config.ZoneById[zoneId]
	if not zone then
		return false, "없는 지역이에요"
	end
	if data.unlockedZones[zone.id] then
		return false, "이미 열린 지역이에요"
	end
	-- 앞 지역부터 차례로 열어야 함
	local index = (zone :: any).index
	local previous = Config.Zones[index - 1]
	if previous and not data.unlockedZones[previous.id] then
		return false, previous.name .. "을(를) 먼저 열어야 해요"
	end
	if data.coins < zone.price then
		return false, "코인이 " .. Util.FormatNumber(zone.price - data.coins) .. " 부족해요"
	end
	data.coins -= zone.price
	data.unlockedZones[zone.id] = true
	Net.MarkDirty(player)
	Net.Announce(string.format("%s %s님이 %s을(를) 열었어요!", zone.emoji, player.DisplayName, zone.name), Color3.fromRGB(255, 230, 150))
	return true, zone.emoji .. " " .. zone.name .. " 열림! 🗺️ 지역 메뉴에서 이동할 수 있어요"
end)

----------------------------------------------------------------------
-- 발굴 조수
----------------------------------------------------------------------
Net.Handle("BuyHelper", function(player, helperId)
	local data = DataService.Get(player)
	local helper = type(helperId) == "string" and Config.HelperById[helperId]
	if not helper then
		return false, "없는 조수예요"
	end
	if data.coins < helper.price then
		return false, "코인이 " .. Util.FormatNumber(helper.price - data.coins) .. " 부족해요"
	end
	data.coins -= helper.price
	data.helpersOwned[helper.id] = (data.helpersOwned[helper.id] or 0) + 1
	-- 빈 칸이 있으면 바로 데리고 다님
	if #data.helpersEquipped < Economy.GetHelperSlots(Passes.Get(player)) then
		table.insert(data.helpersEquipped, helper.id)
	end
	Net.MarkDirty(player)
	return true, "🦖 " .. helper.name .. " 고용 완료!"
end)

Net.Handle("EquipHelper", function(player, helperId)
	local data = DataService.Get(player)
	local helper = type(helperId) == "string" and Config.HelperById[helperId]
	if not helper then
		return false, "없는 조수예요"
	end
	if Economy.CountEquipped(data, helper.id) >= (data.helpersOwned[helper.id] or 0) then
		return false, "데리고 다닐 수 있는 " .. helper.name .. "이(가) 없어요"
	end
	if #data.helpersEquipped >= Economy.GetHelperSlots(Passes.Get(player)) then
		return false, "조수 칸이 가득 찼어요"
	end
	table.insert(data.helpersEquipped, helper.id)
	Net.MarkDirty(player)
	return true, nil
end)

Net.Handle("UnequipHelper", function(player, helperId)
	local data = DataService.Get(player)
	local index = type(helperId) == "string" and table.find(data.helpersEquipped, helperId)
	if not index then
		return false, nil
	end
	table.remove(data.helpersEquipped, index)
	Net.MarkDirty(player)
	return true, nil
end)

----------------------------------------------------------------------
-- 환생
----------------------------------------------------------------------
Net.Handle("Rebirth", function(player)
	local data = DataService.Get(player)
	local price = Economy.GetRebirthPrice(data)
	if data.coins < price then
		return false, "환생하려면 코인이 " .. Util.FormatNumber(price - data.coins) .. " 더 필요해요"
	end
	data.rebirths += 1
	data.coins = 0
	data.tool = "WoodShovel"
	data.ownedTools = { WoodShovel = true }
	data.unlockedZones = { Desert = true }
	data.slots = Config.StartSlots
	DigService.GiveTool(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local desert = Zones.Get("Desert")
	if root and desert then
		root.CFrame = desert.spawn
	end
	Net.MarkDirty(player)
	Net.Announce(string.format("🔁 %s님이 %d번째 환생을 했어요!", player.DisplayName, data.rebirths), Color3.fromRGB(255, 160, 255))
	return true, string.format("🔁 환생 완료! 수입 +%d%%, 코인 +%d%%, 행운 +%d%%", math.floor(data.rebirths * Config.Rebirth.incomeBonus * 100), math.floor(data.rebirths * Config.Rebirth.coinBonus * 100), math.floor(data.rebirths * Config.Rebirth.luckBonus * 100 + 0.5))
end)

Net.Handle("ToggleAutoDig", function(player)
	local data = DataService.Get(player)
	data.autoDig = not data.autoDig
	Net.MarkDirty(player)
	return true, if data.autoDig then "🤖 자동 발굴 켜짐" else "🤖 자동 발굴 꺼짐"
end)

----------------------------------------------------------------------
-- Robux 개발자 상품
----------------------------------------------------------------------
local function grantProduct(player: Player, data: any, productId: number): boolean
	for key, product in Config.Products do
		if product.id == productId and product.id ~= 0 then
			if key == "LuckBoost" then
				local start = math.max(data.luckBoostUntil, os.time())
				data.luckBoostUntil = start + (product.minutes or 15) * 60
				Net.Tell(player, "🍀 행운 부스트가 켜졌어요!", Color3.fromRGB(120, 255, 120))
			elseif key == "ServerLuck" then
				local current = ReplicatedStorage:GetAttribute("ServerLuckUntil")
				local start = math.max(if type(current) == "number" then current else 0, os.time())
				ReplicatedStorage:SetAttribute("ServerLuckUntil", start + (product.minutes or 15) * 60)
				Net.Announce(string.format("🌟 %s님 덕분에 %d분 동안 서버 전체 행운 2배!", player.DisplayName, product.minutes or 15), Color3.fromRGB(255, 235, 120))
			else
				local income = Economy.GetIncome(data, Passes.Get(player))
				local coins = math.max(product.minCoins or 0, math.floor(income * (product.coinsSeconds or 0)))
				data.coins += coins
				data.stats.totalEarned += coins
				Net.Tell(player, "💰 " .. Util.FormatNumber(coins) .. " 코인을 받았어요! 감사합니다!", Color3.fromRGB(255, 220, 90))
			end
			return true
		end
	end
	return false
end

local function processReceipt(receipt)
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local data = DataService.Get(player)
	if not data then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if table.find(data.purchases, receipt.PurchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	if not grantProduct(player, data, receipt.ProductId) then
		warn("[ShopService] 알 수 없는 상품 ID:", receipt.ProductId)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	table.insert(data.purchases, receipt.PurchaseId)
	while #data.purchases > MAX_RECEIPTS do
		table.remove(data.purchases, 1)
	end
	Net.MarkDirty(player)
	-- 바로 저장해서 서버가 꺼져도 지급 기록이 남도록
	DataService.Save(player)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function ShopService.Init()
	MarketplaceService.ProcessReceipt = processReceipt
end

return ShopService
