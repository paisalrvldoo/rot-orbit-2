local Catalog = require(game:GetService("ReplicatedStorage"):WaitForChild("Orbit"):WaitForChild("Catalog"))
local SkillService = {}

function SkillService.Update(player, state)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return end
	local sprinting = workspace:GetServerTimeNow() < (state.sprintUntil or 0)
	local skill = Catalog.skills.Sprint
	local speed = sprinting and (state.carry and skill.carrySpeed or skill.speed) or (state.carry and 13 or 16)
	if workspace:GetServerTimeNow() < (state.stunnedUntil or 0) then speed = 6 end
	humanoid.WalkSpeed = speed + 2 * (state.speedLevel or 0)
end

function SkillService.Use(player, state, name)
	local skill = Catalog.skills[name]
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not skill or not root or not humanoid or humanoid.Health <= 0 then return false end
	local now = workspace:GetServerTimeNow()
	if now < (state.stunnedUntil or 0) then return false, "Zap stun ends in a moment." end
	local readyKey = name == "Blink" and "blinkReady" or "sprintReady"
	if now < (state[readyKey] or 0) then
		return false, name .. " recharges in " .. math.ceil(state[readyKey] - now) .. "s."
	end
	if name == "Sprint" then
		state.sprintUntil = now + skill.duration
		state.sprintReady = now + skill.cooldown
		SkillService.Update(player, state)
	else
		local move = humanoid.MoveDirection.Magnitude > .1 and humanoid.MoveDirection or root.CFrame.LookVector
		local direction = Vector3.new(move.X, 0, move.Z)
		if direction.Magnitude < .01 then return false, "Face the direction you want to blink." end
		direction = direction.Unit
		local distance = state.carry and skill.carryDistance or skill.distance
		if state.rebirths >= 2 then distance += state.carry and 4 or 8 end
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = state.carry and { character, state.carry.model } or { character }
		params.RespectCanCollide = true
		local obstacle = workspace:Blockcast(root.CFrame, Vector3.new(3, 5, 2), direction * distance, params)
		if obstacle then distance = math.max(0, obstacle.Distance - 1.5) end
		if distance < 3 then return false, "Blink blocked. Step clear of the obstacle." end
		local destination = root.Position + direction * distance
		local ground = workspace:Raycast(destination + Vector3.yAxis * 6, -Vector3.yAxis * 18, params)
		if not ground or ground.Normal.Y < .5 then return false, "Blink needs a safe landing on the station." end
		destination = Vector3.new(destination.X, ground.Position.Y + math.max(3, humanoid.HipHeight + root.Size.Y / 2), destination.Z)
		root.CFrame = CFrame.lookAt(destination, destination + direction)
		root.AssemblyLinearVelocity = Vector3.zero
		state.blinkReady = now + skill.cooldown
	end
	player:SetAttribute("BlinkReady", state.blinkReady or 0)
	player:SetAttribute("SprintReady", state.sprintReady or 0)
	player:SetAttribute("SprintUntil", state.sprintUntil or 0)
	return true
end

return SkillService
