-- 랭킹 보드: 완성 화석 수(전체 기간), 이번 주 받은 좋아요
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)

local LeaderboardService = {}

local UPDATE_INTERVAL = 90
local names: { [number]: string } = {}

local function nameOf(userId: number): string
	if names[userId] then
		return names[userId]
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	names[userId] = if ok then name else "???"
	return names[userId]
end

local function completed(data: any): number
	local total = 0
	for _, count in data.museum do
		total += count
	end
	return total
end

local function setBoard(board: BasePart, text: string)
	local gui = board:FindFirstChild("BoardGui")
	local list = gui and gui:FindFirstChild("List")
	if list and list:IsA("TextLabel") then
		list.Text = text
	end
end

local function refresh(board: BasePart, storeName: string, getValue: (any) -> number)
	local ok, store = pcall(function()
		return DataStoreService:GetOrderedDataStore(storeName)
	end)
	if not ok then
		setBoard(board, "게임을 게시하면 랭킹이 표시돼요")
		return
	end
	-- Studio 테스트 기록은 실제 랭킹에 올리지 않음 (보기만)
	local writers = if RunService:IsStudio() then {} else Players:GetPlayers()
	for _, player in writers do
		local data = DataService.Get(player)
		if data then
			local value = math.floor(getValue(data))
			if value > 0 then
				pcall(function()
					store:SetAsync(tostring(player.UserId), value)
				end)
			end
		end
	end
	local pageOk, page = pcall(function()
		return store:GetSortedAsync(false, 10):GetCurrentPage()
	end)
	if not pageOk then
		setBoard(board, "게임을 게시하면 랭킹이 표시돼요\n(Studio: API 서비스 사용 켜기)")
		return
	end
	local lines = {}
	for rank, entry in page do
		local medal = if rank == 1 then "🥇" elseif rank == 2 then "🥈" elseif rank == 3 then "🥉" else rank .. "."
		table.insert(lines, string.format("%s %s  -  %d", medal, nameOf(tonumber(entry.key) or 0), entry.value))
	end
	setBoard(board, if #lines > 0 then table.concat(lines, "\n") else "아직 기록이 없어요")
end

function LeaderboardService.Init(world: any)
	if Config.Features.Leaderboards == false then
		for _, board in world.boards do
			setBoard(board, "🔧 점검 중이에요")
		end
		return
	end
	task.spawn(function()
		task.wait(10)
		while true do
			local week = DataService.Week()
			if world.boards.FossilBoard then
				refresh(world.boards.FossilBoard, "FossilsCompleted_v1", completed)
			end
			if world.boards.LikeBoard then
				refresh(world.boards.LikeBoard, "WeeklyLikes_" .. week, function(data)
					return if data.weekLikes.week == week then data.weekLikes.count else 0
				end)
			end
			task.wait(UPDATE_INTERVAL)
		end
	end)
end

return LeaderboardService
