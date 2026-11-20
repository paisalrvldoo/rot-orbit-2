local Orbit = game:GetService("ReplicatedStorage"):WaitForChild("Orbit")
local Catalog = require(Orbit.Catalog)
local BayShield = require(script.Parent.BayShield)
local CrewService = require(script.Parent.CrewService)
local EconomyService = require(script.Parent.EconomyService)
local ContractService = require(script.Parent.ContractService)

local GremlinRaid = {}
GremlinRaid.__index = GremlinRaid
local config = {
	firstPatrol = 30, patrolInterval = 45, patrolCap = 2,
	firstWave = 75, waveInterval = 135, telegraph = 6, duration = 48, waveSize = 4,
	health = 4, captainHealth = 18, captainEvery = 3, damage = 2, range = 48,
	speed = 9, stun = 3, killReward = 140, captainReward = 1800, clearReward = 600,
}

local function floor(position, height)
	return Vector3.new(position.X, height, position.Z)
end

function GremlinRaid.new(context)
	local now = workspace:GetServerTimeNow()
	context.enemies = {}
	context.waveNumber = 0
	context.nextPatrol = now + config.firstPatrol
	context.nextWave = now + config.firstWave
	return setmetatable(context, GremlinRaid)
end

function GremlinRaid:Publish()
	local wave = self.wave
	local text, health, deadline = "", 0, 0
	if wave then
		text = wave.captain and "CAPTAIN RAID" or "RIFT RAID"
		if not wave.spawned then
			text ..= " / INBOUND"
		else
			local remaining, captain = 0, nil
			for enemy in pairs(self.enemies) do
				if enemy.wave == wave then
					remaining += 1
					health += enemy.health
					if enemy.captain then captain = enemy.health end
				end
			end
			text ..= " / " .. remaining .. " LEFT"
			health = captain or health
		end
		deadline = wave.endsAt
	else
		for enemy in pairs(self.enemies) do
			text, health, deadline = "RIVAL THIEF / BAY " .. enemy.state.bay.number, enemy.health, enemy.endsAt
			break
		end
	end
	workspace:SetAttribute("RaidHealth", health)
	workspace:SetAttribute("RaidEndsAt", deadline)
	workspace:SetAttribute("Raid", text)
end

function GremlinRaid:Targets(requireCargo)
	local targets = {}
	for player, state in pairs(self.profiles) do
		if not state.loading and not state.closing then
			if not requireCargo then
				table.insert(targets, player)
			else
				for _, slot in ipairs(state.bay.slots) do
					if slot.cargo then table.insert(targets, player); break end
				end
			end
		end
	end
	table.sort(targets, function(a, b) return self.profiles[a].bay.number < self.profiles[b].bay.number end)
	return targets
end

function GremlinRaid:Spawn(owner, start, now, wave, captain)
	local state = self.profiles[owner]
	if not state or state.loading or state.closing then return end
	local model = self.world.gremlin()
	model.Name = captain and "Captain Gremlin" or (wave and "Rift Gremlin" or "Rival Thief")
	if captain then model:ScaleTo(2) end
	model:PivotTo(CFrame.new(start))
	local rank = math.min(state.rebirths, 6)
	local health = captain and config.captainHealth + (#wave.targets - 1) * 4 + rank * 2
		or config.health + rank
	local enemy = {
		owner = owner, state = state, model = model, position = start, origin = start,
		entrance = floor(state.bay.spawn.Position, start.Y), phase = "Enter", ready = now,
		health = health, endsAt = wave and wave.endsAt or now + config.duration,
		wave = wave, captain = captain,
	}
	local gui = model.PrimaryPart:FindFirstChildWhichIsA("BillboardGui")
	enemy.label = gui and gui:FindFirstChildWhichIsA("TextLabel")
	self.enemies[enemy] = true
	self:Label(enemy)
end

function GremlinRaid:Label(enemy)
	if enemy.label then
		enemy.label.Text = (enemy.cargo and "HAS CARGO" or enemy.model.Name:upper()) .. " / " .. enemy.health .. " HP"
	end
end

function GremlinRaid:Release(enemy, position, secured)
	local cargo = enemy.cargo
	if not cargo then return end
	enemy.cargo = nil
	self.steals:Drop(cargo, position, secured)
	self.message(enemy.owner, secured and "Raid cargo dropped. Recover it with E." or "The attacker escaped and dropped your cargo. Recover it before it expires.")
end

function GremlinRaid:Remove(enemy, restore)
	self.enemies[enemy] = nil
	if enemy.cargo then
		if restore then self.returnCargo(enemy.cargo); enemy.cargo = nil
		else self:Release(enemy, enemy.position, false) end
	end
	enemy.model:Destroy()
	if enemy.wave then enemy.wave.remaining -= 1 end
end

function GremlinRaid:Clear()
	for enemy in pairs(self.enemies) do self:Remove(enemy, true) end
	self.wave = nil
	self:Publish()
end

function GremlinRaid:Settle(state)
	for enemy in pairs(self.enemies) do
		if enemy.state == state then self:Remove(enemy, true) end
	end
	self:Publish()
end

function GremlinRaid:StartWave(now)
	local targets = self:Targets(false)
	if #targets == 0 then return false end
	self.waveNumber += 1
	self.wave = {
		targets = targets, captain = self.waveNumber % config.captainEvery == 0,
		spawnAt = now + config.telegraph, endsAt = now + config.telegraph + config.duration,
		outcomes = {}, remaining = 0, defeated = 0,
	}
	self.announce(self.wave.captain and "Captain raid inbound. Seal your bay or fight together!"
		or "Rift raid inbound. Seal your bay or zap the incoming gremlins!")
	self:Publish()
	return true
end

function GremlinRaid:Patrol(now)
	local count, rivals = 0, {}
	for enemy in pairs(self.enemies) do
		if not enemy.wave then count += 1 end
	end
	for _, bay in ipairs(self.bays) do
		if bay.rival and not bay.owner then table.insert(rivals, bay) end
	end
	if count >= config.patrolCap or #rivals == 0 then return end
	local targets = self:Targets(true)
	if #targets == 0 then return end
	local owner = targets[self.random:NextInteger(1, #targets)]
	local rival = rivals[self.random:NextInteger(1, #rivals)]
	self:Spawn(owner, floor(rival.spawn.Position, self.world.portal.Y), now)
	self.message(owner, "Rival thief inbound. Lock your bay or get ready to zap.")
	self:Publish()
end

function GremlinRaid:Advance(enemy, delta, now)
	if now >= enemy.endsAt then self:Remove(enemy, false); return true end
	if self.profiles[enemy.owner] ~= enemy.state or enemy.state.closing or enemy.state.loading then
		self:Remove(enemy, true)
		return true
	end
	if now < enemy.ready then return end
	local phase = enemy.phase
	local goal = enemy.entrance
	if phase == "Home" then
		goal = enemy.origin
	elseif phase == "Grab" then
		local slot = enemy.slot
		if not slot.cargo then enemy.phase = "Leave"; return end
		goal = floor(slot.pad.Position, enemy.origin.Y)
	end
	local direction = goal - enemy.position
	if direction.Magnitude > .65 then
		local step = math.min(direction.Magnitude, delta * config.speed)
		enemy.position += direction.Unit * step
		local cf = CFrame.lookAt(enemy.position, enemy.position + direction)
		enemy.model:PivotTo(cf)
		if enemy.cargo then enemy.cargo.model:PivotTo(cf * CFrame.new(0, enemy.captain and 3 or 1.4, 2)) end
		return
	end
	if phase == "Home" then self:Remove(enemy, false); return true end
	if phase == "Leave" then enemy.phase = "Home"; return end
	if BayShield.IsActive(enemy.state, now) then
		if enemy.wave then
			enemy.wave.defeated += 1
			enemy.wave.outcomes[enemy.owner] = true
		end
		self:Remove(enemy, true)
		EconomyService.Credit(enemy.state, 25)
		self.crews:Award(enemy.state, 5)
		self.sync(enemy.owner, enemy.state)
		self.message(enemy.owner, "Shield repelled an attacker / +$25.")
		return true
	end
	if phase == "Enter" then
		local choices = {}
		for _, slot in ipairs(enemy.state.bay.slots) do
			if slot.cargo then table.insert(choices, slot) end
		end
		if #choices == 0 then enemy.phase = "Home"; return end
		enemy.slot = choices[self.random:NextInteger(1, #choices)]
		enemy.phase = "Grab"
		return
	end
	enemy.cargo = self.take(enemy.slot)
	enemy.phase = "Leave"
	self:Label(enemy)
	self.sync(enemy.owner, enemy.state)
	self.message(enemy.owner, "An attacker took " .. Catalog.name(enemy.cargo) .. ". Zap it to recover your cargo!")
end

function GremlinRaid:Nearest(origin, limit, now)
	local target, distance = nil, math.min(limit, config.range)
	for enemy in pairs(self.enemies) do
		local gap = (origin - enemy.position).Magnitude
		if gap <= distance and not BayShield.BlocksZap(self.profiles, origin, enemy.position, now) then
			target, distance = enemy, gap
		end
	end
	return target
end

function GremlinRaid:Zap(player, state, enemy, now)
	self.world.flash(enemy.position + Vector3.yAxis * 2, self.world.gold, 6)
	ContractService.Activity(state, "Zap")
	enemy.health = math.max(0, enemy.health - config.damage)
	self:Release(enemy, enemy.position, true)
	if enemy.health > 0 then
		enemy.ready = now + config.stun
		enemy.phase = enemy.phase == "Home" and "Home" or "Leave"
		self:Label(enemy)
		self.message(player, "Attacker stunned / " .. enemy.health .. " HP left.")
	else
		local wave = enemy.wave
		if wave then
			wave.defeated += 1
			wave.outcomes[player] = true
			wave.outcomes[enemy.owner] = true
		end
		local reward = enemy.captain and config.captainReward or config.killReward
		EconomyService.Credit(state, reward)
		self.crews:Award(state, enemy.captain and 150 or 10)
		for member, memberState in pairs(self.profiles) do
			if member ~= player and not memberState.loading and not memberState.closing
				and CrewService.Same(state, memberState) and self.near(member, enemy.position, 45) then
				local assist = enemy.captain and 500 or 50
				EconomyService.Credit(memberState, assist)
				self.sync(member, memberState)
				self.message(member, "Squad defence assist / +$" .. assist)
			end
		end
		local name = enemy.model.Name
		self:Remove(enemy, false)
		self.message(player, name .. " defeated / +$" .. reward)
	end
	self.sync(player, state)
	self:Publish()
end

function GremlinRaid:Step(delta, now)
	if not self.wave and now >= self.nextWave then
		self.nextWave = now + (self:StartWave(now) and config.waveInterval or 10)
	end
	if now >= self.nextPatrol then
		self.nextPatrol = now + config.patrolInterval
		if not self.wave then self:Patrol(now) end
	end
	local wave, changed = self.wave, false
	if wave and not wave.spawned and now >= wave.spawnAt then
		wave.spawned = true
		local count = config.waveSize + math.min(4, #wave.targets - 1)
		for index = 1, count do
			local owner = wave.targets[(index - 1) % #wave.targets + 1]
			local spawn = self.world.portal + Vector3.zAxis * ((index - (count + 1) / 2) * 2)
			if self.profiles[owner] and not self.profiles[owner].closing and not self.profiles[owner].loading then
				self:Spawn(owner, spawn, now, wave, wave.captain and index == 1)
				wave.remaining += 1
			end
		end
		wave.total = wave.remaining
		changed = true
	end
	for enemy in pairs(self.enemies) do
		if self:Advance(enemy, delta, now) then changed = true end
	end
	if wave and wave.spawned and wave.remaining == 0 then
		self.wave = nil
		changed = true
		if wave.total > 0 and wave.defeated == wave.total then
			for player in pairs(wave.outcomes) do
				local state = self.profiles[player]
				if state and not state.loading and not state.closing and self.near(player, state.bay.center, 90) then
					EconomyService.Credit(state, config.clearReward)
					self.crews:Award(state, 100)
					self.sync(player, state)
					self.message(player, "Raid cleared / +$" .. config.clearReward)
				end
			end
		end
	end
	if changed then self:Publish() end
end

return GremlinRaid
