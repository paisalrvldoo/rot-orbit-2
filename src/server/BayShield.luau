local BayShield = {}
local radius = 16

function BayShield.IsActive(state, now)
	return not state.loading and not state.closing and now < state.lockedUntil
end

function BayShield.Contains(position, bay)
	local offset = position - bay.center
	return math.abs(offset.Y) <= 12 and Vector3.new(offset.X, 0, offset.Z).Magnitude <= radius
end

-- A player already inside can Blink out. Zap checks the segment in both directions.
local function entry(origin, move, center)
	local x, z = origin.X - center.X, origin.Z - center.Z
	local a = move.X * move.X + move.Z * move.Z
	local b = x * move.X + z * move.Z
	local c = x * x + z * z - radius * radius
	if c < 0 or a < 1e-6 or b >= 0 then return nil end
	local discriminant = b * b - a * c
	if discriminant < 0 then return nil end
	local t = (-b - math.sqrt(discriminant)) / a
	return t <= 1 and math.abs(origin.Y + move.Y * t - center.Y) <= 12 and t or nil
end

function BayShield.BlinkDistance(profiles, origin, direction, distance, now)
	for _, state in pairs(profiles) do
		if BayShield.IsActive(state, now) then
			local hit = entry(origin, direction * distance, state.bay.center)
			if hit then distance = math.max(0, hit * distance - 1) end
		end
	end
	return distance
end

function BayShield.BlocksZap(profiles, origin, target, now)
	for _, state in pairs(profiles) do
		if BayShield.IsActive(state, now) then
			local center = state.bay.center
			if entry(origin, target - origin, center) or entry(target, origin - target, center) then return true end
		end
	end
	return false
end

return BayShield
