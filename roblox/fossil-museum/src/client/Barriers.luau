-- 잠긴 지역의 벽: 내 화면에서만 단단하게 (열린 지역은 투명해지고 통과 가능)
-- 캐릭터 물리는 내 컴퓨터가 계산하므로, 여기서 CanCollide 를 바꾸면 나에게만 적용돼요.
local Barriers = {}

local unlocked: { [string]: boolean } = { Desert = true }

local function applyWall(wall: BasePart)
	local barrier = wall.Parent
	if not barrier or barrier.Name ~= "Barrier" then
		return
	end
	local open = unlocked[barrier:GetAttribute("Zone") or ""] == true
	wall.CanCollide = not open
	wall.Transparency = if open then 1 else 0.3
	for _, gui in wall:GetChildren() do
		if gui:IsA("SurfaceGui") then
			gui.Enabled = not open
		end
	end
end

function Barriers.Update(unlockedZones: { [string]: boolean })
	unlocked = unlockedZones
	local root = workspace:FindFirstChild("FossilWorld")
	if not root then
		return
	end
	for _, zoneFolder in root:GetChildren() do
		local barrier = zoneFolder:FindFirstChild("Barrier")
		if barrier then
			for _, wall in barrier:GetChildren() do
				if wall:IsA("BasePart") then
					applyWall(wall)
				end
			end
		end
	end
end

-- 스트리밍으로 벽이 나중에 불러와져도 적용
workspace.DescendantAdded:Connect(function(inst)
	if inst:IsA("BasePart") and inst.Name == "Wall" then
		applyWall(inst)
	elseif inst:IsA("SurfaceGui") and inst.Parent and inst.Parent:IsA("BasePart") and inst.Parent.Name == "Wall" then
		applyWall(inst.Parent :: BasePart)
	end
end)

return Barriers
