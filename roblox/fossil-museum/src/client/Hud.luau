-- 화면 위 정보: 코인, 수입, 이벤트 배너, 메뉴 버튼, 알림
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Util = require(ReplicatedStorage.Shared.Util)
local Gui = require(script.Parent.Gui)

local Hud = {}

local player = Players.LocalPlayer
local screen: ScreenGui
local coinsLabel: TextLabel
local incomeLabel: TextLabel
local boostLabel: TextLabel
local eventLabel: TextLabel
local toastHolder: Frame
local badges: { [string]: Frame } = {}

function Hud.Create(onMenu: (string) -> ())
	screen = Gui.new("ScreenGui", {
		Name = "FossilHud",
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})

	-- 코인 표시 (위 가운데)
	local top = Gui.new("Frame", {
		Name = "Top",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(260, 62),
		BackgroundColor3 = Gui.Colors.Panel,
		BackgroundTransparency = 0.15,
		Parent = screen,
	}, { Gui.corner(14), Gui.stroke(Gui.Colors.Gold, 2) })
	coinsLabel = Gui.label({
		Size = UDim2.new(1, -16, 0, 34),
		Position = UDim2.fromOffset(8, 4),
		Font = Enum.Font.FredokaOne,
		TextColor3 = Gui.Colors.Gold,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "💰 0",
		MaxTextSize = 30,
		Parent = top,
	})
	incomeLabel = Gui.label({
		Size = UDim2.new(1, -16, 0, 20),
		Position = UDim2.fromOffset(8, 38),
		TextColor3 = Gui.Colors.SubText,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "🏛️ +0/초",
		MaxTextSize = 16,
		Parent = top,
	})

	boostLabel = Gui.label({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 74),
		Size = UDim2.fromOffset(260, 20),
		TextColor3 = Color3.fromRGB(130, 255, 130),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeTransparency = 0.4,
		Text = "",
		MaxTextSize = 16,
		Visible = false,
		Parent = screen,
	})

	-- 운석 이벤트 배너
	local banner = Gui.new("Frame", {
		Name = "Event",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 8),
		Size = UDim2.fromOffset(210, 40),
		BackgroundColor3 = Color3.fromRGB(45, 25, 70),
		BackgroundTransparency = 0.15,
		Parent = screen,
	}, { Gui.corner(10), Gui.stroke(Color3.fromRGB(180, 120, 255), 2) })
	eventLabel = Gui.label({
		Size = UDim2.new(1, -12, 1, -8),
		Position = UDim2.fromOffset(6, 4),
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "☄️ 운석까지 --:--",
		MaxTextSize = 17,
		Parent = banner,
	})

	-- 왼쪽 메뉴 버튼
	local menu = Gui.new("Frame", {
		Name = "Menu",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 10, 0.5, 0),
		Size = UDim2.fromOffset(120, 4 * 52),
		BackgroundTransparency = 1,
		Parent = screen,
	}, {
		Gui.new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local buttons = {
		{ id = "Collection", text = "📖 도감", color = Color3.fromRGB(200, 140, 60) },
		{ id = "Shop", text = "🛒 상점", color = Gui.Colors.Green },
		{ id = "Museum", text = "🏛️ 내 박물관", color = Gui.Colors.Blue },
		{ id = "Field", text = "⛏️ 발굴장", color = Color3.fromRGB(150, 100, 70) },
	}
	for i, info in buttons do
		local b = Gui.button({
			Name = info.id,
			LayoutOrder = i,
			Size = UDim2.fromOffset(120, 44),
			BackgroundColor3 = info.color,
			Text = info.text,
			MaxTextSize = 18,
			Parent = menu,
		}, function()
			onMenu(info.id)
		end)
		local badge = Gui.new("Frame", {
			Name = "Badge",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(1, -4, 0, 4),
			Size = UDim2.fromOffset(18, 18),
			BackgroundColor3 = Gui.Colors.Red,
			Visible = false,
			ZIndex = 3,
			Parent = b,
		}, { Gui.corner(9) })
		Gui.label({ Size = UDim2.fromScale(1, 1), Text = "!", TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 4, MaxTextSize = 14, Parent = badge })
		badges[info.id] = badge
	end

	-- 알림 목록 (아래 가운데)
	toastHolder = Gui.new("Frame", {
		Name = "Toasts",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -90),
		Size = UDim2.fromOffset(440, 260),
		BackgroundTransparency = 1,
		Parent = screen,
	}, {
		Gui.new("UIListLayout", {
			Padding = UDim.new(0, 6),
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Gui.new("UISizeConstraint", { MaxSize = Vector2.new(440, 260) }),
	})

	return screen
end

function Hud.GetScreen(): ScreenGui
	return screen
end

function Hud.SetCoins(coins: number)
	coinsLabel.Text = "💰 " .. Util.FormatNumber(coins)
end

function Hud.SetIncome(income: number)
	incomeLabel.Text = "🏛️ 관람 수입 +" .. Util.FormatNumber(income) .. "/초"
end

function Hud.SetBoost(secondsLeft: number)
	if secondsLeft > 0 then
		boostLabel.Visible = true
		boostLabel.Text = "🍀 행운 부스트 " .. Util.FormatTime(secondsLeft)
	else
		boostLabel.Visible = false
	end
end

function Hud.SetEvent(text: string)
	eventLabel.Text = text
end

function Hud.SetBadge(id: string, visible: boolean)
	local badge = badges[id]
	if badge then
		badge.Visible = visible
	end
end

local toastOrder = 0
-- big = true 면 크게 표시 (희귀 발견 등)
function Hud.Toast(text: string, color: Color3?, big: boolean?, duration: number?)
	toastOrder += 1
	local height = if big then 52 else 34
	local frame = Gui.new("Frame", {
		LayoutOrder = toastOrder,
		Size = UDim2.new(1, 0, 0, height),
		BackgroundColor3 = Gui.Colors.Panel,
		BackgroundTransparency = 0.15,
		Parent = toastHolder,
	}, { Gui.corner(10), Gui.stroke(color or Gui.Colors.SubText, if big then 3 else 1.5) })
	local label = Gui.label({
		Size = UDim2.new(1, -16, 1, -8),
		Position = UDim2.fromOffset(8, 4),
		Text = text,
		TextColor3 = color or Gui.Colors.Text,
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = if big then Enum.Font.FredokaOne else Enum.Font.GothamBold,
		MaxTextSize = if big then 24 else 17,
		Parent = frame,
	})
	if big then
		local scale = Gui.new("UIScale", { Scale = 0.6, Parent = frame })
		TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end

	-- 너무 많이 쌓이면 오래된 것부터 삭제
	local toasts = {}
	for _, child in toastHolder:GetChildren() do
		if child:IsA("Frame") then
			table.insert(toasts, child)
		end
	end
	table.sort(toasts, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	while #toasts > 6 do
		table.remove(toasts, 1):Destroy()
	end

	task.delay(duration or (if big then 4 else 2.5), function()
		if not frame.Parent then
			return
		end
		local info = TweenInfo.new(0.4)
		TweenService:Create(frame, info, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(label, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		local stroke = frame:FindFirstChildOfClass("UIStroke")
		if stroke then
			TweenService:Create(stroke, info, { Transparency = 1 }):Play()
		end
		task.wait(0.45)
		frame:Destroy()
	end)
end

return Hud
