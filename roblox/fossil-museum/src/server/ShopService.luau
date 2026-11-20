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
-- Robux 개발자 상품
----------------------------------------------------------------------
local function grantProduct(player: Player, data: any, productId: number): boolean
	for key, product in Config.Products do
		if product.id == productId and product.id ~= 0 then
			if key == "LuckBoost" then
				local start = math.max(data.luckBoostUntil, os.time())
				data.luckBoostUntil = start + (product.minutes or 15) * 60
				Net.Tell(player, "🍀 행운 부스트가 켜졌어요!", Color3.fromRGB(120, 255, 120))
			else
				local income = Economy.GetIncome(data, Passes.Get(player))
				local coins = math.max(product.minCoins or 0, math.floor(income * (product.coinsSeconds or 0)))
				data.coins += coins
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
