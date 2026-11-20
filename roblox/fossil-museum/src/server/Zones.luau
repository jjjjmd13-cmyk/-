-- 발굴 지역: 위치로 지역 찾기, 잠금 확인
local Zones = {}

local world: any = nil

function Zones.Init(builtWorld: any)
	world = builtWorld
end

function Zones.Get(zoneId: string): any
	return world and world.zones[zoneId]
end

-- 이 위치가 어느 지역 안인지 (없으면 nil)
function Zones.At(position: Vector3): string?
	if not world then
		return nil
	end
	for id, zone in world.zones do
		local d = position - zone.center
		if math.abs(d.X) <= zone.half and math.abs(d.Z) <= zone.half then
			return id
		end
	end
	return nil
end

function Zones.PlayerZone(player: Player): string?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return nil
	end
	return Zones.At(root.Position)
end

function Zones.IsUnlocked(data: any, zoneId: string): boolean
	return data.unlockedZones[zoneId] == true
end

return Zones
