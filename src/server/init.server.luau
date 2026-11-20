local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Orbit = ReplicatedStorage:WaitForChild("Orbit")
local Catalog = require(Orbit:WaitForChild("Catalog"))
local Remotes = require(Orbit:WaitForChild("Remotes"))
local network = Remotes.Get()
local actions = Remotes.Actions
local World = require(script:WaitForChild("World"))
local CrewService = require(script:WaitForChild("CrewService"))
local DataService = require(script:WaitForChild("DataService"))
local SkillService = require(script:WaitForChild("SkillService"))
local BayShield = require(script:WaitForChild("BayShield"))
local EconomyService = require(script:WaitForChild("EconomyService"))
local MeteorSolarEvents = require(script:WaitForChild("MeteorSolarEvents"))
local RivalService = require(script:WaitForChild("RivalService"))
local GuideService = require(script:WaitForChild("GuideService"))
local ConveyorService = require(script:WaitForChild("ConveyorService"))
local ScreenshotService = require(script:WaitForChild("ScreenshotService"))
local ScreenshotMode = require(Orbit:WaitForChild("ScreenshotMode"))
local data = DataService.new()

local rng = Random.new()
local bays = World.build()
local profiles = {}
local crews = CrewService.new(profiles)
local waiting = {}
local drops = {}
local raid
local raidCount = 0
local finishRaid
local serverClosing = false
local action = network.Action
local screenshotService

local function message(player, words)
	player:SetAttribute("OrbitMessage", words)
	player:SetAttribute("OrbitMessageId", (player:GetAttribute("OrbitMessageId") or 0) + 1)
end

local function announce(words)
	for player in pairs(profiles) do message(player, words) end
end

local function rootOf(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid and humanoid.Health > 0 and character:FindFirstChild("HumanoidRootPart")
end

local function near(player, position, distance)
	local root = rootOf(player)
	return root and (root.Position - position).Magnitude <= distance
end

local function sync(player, state)
	state.guide = GuideService.Stage(state)
	local rate = EconomyService.Rate(state, workspace:GetAttribute("IncomeMultiplier") or 1)
	player:SetAttribute("Cash", state.cash)
	player:SetAttribute("Unclaimed", state.bank)
	player:SetAttribute("Income", rate)
	player:SetAttribute("Carry", state.carry and Catalog.name(state.carry) or "")
	player:SetAttribute("Bay", state.bay.number)
	player:SetAttribute("Guide", state.loading and 0 or state.guide)
	player:SetAttribute("Loading", state.loading == true)
	player:SetAttribute("SaveStatus", state.saveStatus or "Loading")
	player:SetAttribute("LockedUntil", state.lockedUntil)
	state.bay.header:SetAttribute("LockedUntil", state.lockedUntil)
	player:SetAttribute("LockReady", state.lockReady)
	player:SetAttribute("LockDuration", Catalog.lockDuration(state))
	player:SetAttribute("Upgrade", state.level)
	player:SetAttribute("SpeedUpgrade", state.speedLevel or 0)
	player:SetAttribute("ShieldUpgrade", state.shieldLevel or 0)
	player:SetAttribute("IndexMilestone", state.milestone or 0)
	player:SetAttribute("Rebirths", state.rebirths)
	player:SetAttribute("Contract", state.contract)
	player:SetAttribute("ContractProgress", state.progress)
	player:SetAttribute("CrewId", state.crew or 0)
	player:SetAttribute("CrewReady", state.crewReady or 0)
	player:SetAttribute("PersonalScore", state.score or 0)
	for _, slot in ipairs(state.bay.slots) do
		slot.prompt:SetAttribute("Crew", state.crew or 0)
		slot.prompt:SetAttribute("LockedUntil", state.lockedUntil)
	end
	return rate
end

local function setCarry(player, state, cargo)
	state.carry = cargo
	SkillService.Update(player, state)
	if not cargo then
		sync(player, state)
		return
	end
	local root = rootOf(player)
	if root then cargo.model:PivotTo(root.CFrame * CFrame.new(0, -.85, -2.6)) end
	sync(player, state)
end

local function updateSlot(slot)
	local cargo = slot.cargo
	slot.prompt.ActionText = cargo and "Steal" or "Dock Cargo"
	slot.prompt.ObjectText = cargo and Catalog.name(cargo) or "Bay " .. slot.bay.number
	slot.prompt.HoldDuration = cargo and .85 or .18
	slot.prompt.Enabled = slot.reserved == nil
	slot.prompt:SetAttribute("Occupied", cargo ~= nil)
end

local function dockCargo(slot, cargo)
	slot.cargo = cargo
	cargo.model:PivotTo(slot.cf)
	updateSlot(slot)
end

local function take(slot)
	local cargo = slot.cargo
	slot.cargo = nil
	slot.reserved = cargo
	cargo.source = slot
	updateSlot(slot)
	return cargo
end

local function clearSource(cargo)
	local source = cargo.source
	if source then
		source.reserved = nil
		cargo.source = nil
		updateSlot(source)
	end
	return source
end

local function returnCargo(cargo)
	local source = clearSource(cargo)
	if source then
		dockCargo(source, cargo)
		local owner = source.bay.owner
		if owner and profiles[owner] then
			sync(owner, profiles[owner])
			message(owner, Catalog.name(cargo) .. " recovered at your bay.")
		end
	else
		cargo.model:Destroy()
	end
end

local rivals = RivalService.new({ bays = bays, profiles = profiles, world = World, random = rng,
	clearSource = clearSource, updateSlot = updateSlot, dockCargo = dockCargo })

local function dropCargo(cargo, position, secured)
	if not position or Vector3.new(position.X, 0, position.Z).Magnitude > 75 then
		returnCargo(cargo)
		return
	end
	cargo.model:PivotTo(CFrame.new(position.X, .55, position.Z))
	local prompt = World.prompt(cargo.model.PrimaryPart, "Recover Cargo", Catalog.name(cargo), Enum.KeyCode.E, .32)
	drops[cargo] = prompt
	local claimUntil = workspace:GetServerTimeNow() + 6
	prompt.Triggered:Connect(function(player)
		if World.root:GetAttribute("ScreenshotFrozen") then return end
		local state = profiles[player]
		if drops[cargo] ~= prompt or not state or state.loading or state.closing or state.carry
			or not near(player, cargo.model.PrimaryPart.Position, 10) then return end
		local now = workspace:GetServerTimeNow()
		if now < (state.stunnedUntil or 0) then return end
		if cargo.source and cargo.source.bay == state.bay then
			drops[cargo] = nil
			prompt:Destroy()
			returnCargo(cargo)
			message(player, "Your cargo was recovered and returned to its dock.")
			return
		end
		local owner = cargo.source and cargo.source.bay.owner
		if owner and CrewService.Same(state, profiles[owner]) then
			drops[cargo] = nil
			prompt:Destroy()
			returnCargo(cargo)
			message(player, "Squad cargo recovered and returned to its owner's bay.")
			return
		end
		if owner and (secured or now < claimUntil) then
			message(player, "The owning squad has first claim on this cargo.")
			return
		end
		if not EconomyService.FreeSlot(state) then
			message(player, "Bay full. Recycle cargo before recovering another brainrot.")
			return
		end
		drops[cargo] = nil
		prompt:Destroy()
		setCarry(player, state, cargo)
		state.guide = math.max(state.guide, 2)
		sync(player, state)
		message(player, "Cargo recovered. Bring it to your bay.")
	end)
	task.delay(25, function()
		if drops[cargo] ~= prompt then return end
		drops[cargo] = nil
		prompt:Destroy()
		if secured then
			returnCargo(cargo)
			return
		end
		local source = clearSource(cargo)
		if source and source.bay.owner then message(source.bay.owner, "Rift recovery window expired. Your slot is available again.") end
		cargo.model:Destroy()
	end)
end

local meteorMutation = 2
local weather = MeteorSolarEvents.new({
	world = World, profiles = profiles, random = rng, network = network,
	rootOf = rootOf, message = message, announce = announce, activity = EconomyService.Activity,
	refresh = function()
		for player, state in pairs(profiles) do if not state.loading and not state.closing then sync(player, state) end end
	end,
	drop = function(player, state, position)
		local cargo = state.carry
		setCarry(player, state, nil)
		dropCargo(cargo, position)
	end,
	onShowerEnd = function()
		local cargo = { id = rng:NextInteger(8, 21), mutation = meteorMutation }
		meteorMutation = meteorMutation == #Catalog.mutations and 2 or meteorMutation + 1
		cargo.model = World.figure(cargo, World.root)
		dropCargo(cargo, Vector3.zero)
		announce("Shower cleared. Mutated meteor salvage is available at the reactor.")
	end,
})

local function assign(player)
	local bay
	for _, candidate in ipairs(bays) do
		if not candidate.owner then bay = candidate break end
	end
	if not bay then return false end
	rivals:Clear(bay)
	bay.owner = player
	local state = {
		bay = bay, cash = 90, bank = 0, guide = 1, lockedUntil = 0, lockReady = 0, zapReady = 0,
		level = 0, rebirths = 0, contract = 1, progress = 0, index = {}, crew = 0, score = 0, loading = true,
	}
	profiles[player] = state
	crews:Refresh()
	player:SetAttribute("Index", "")
	bay.header:SetAttribute("Owner", player.UserId)
	for _, slot in ipairs(bay.slots) do slot.prompt:SetAttribute("Owner", player.UserId) end
	bay.collectPrompt:SetAttribute("Owner", player.UserId)
	bay.lockPrompt:SetAttribute("Owner", player.UserId)
	World.title(bay, "BAY " .. bay.number .. "  /  " .. player.DisplayName)
	local root = rootOf(player)
	if root then player.Character:PivotTo(bay.spawn) end
	sync(player, state)
	task.spawn(function()
		local saved, reason = data:Load(player, state)
		if not saved then
			state.loading = false
			if player.Parent then player:Kick(reason) end
			return
		end
		if profiles[player] ~= state or state.closing or not player.Parent then
			state.loading = false
			data:Abandon(player)
			return
		end
		for _, key in ipairs({ "cash", "bank", "level", "rebirths", "guide", "crew", "contract", "progress", "index", "speedLevel", "shieldLevel", "milestone" }) do state[key] = saved[key] end
		for position, record in ipairs(saved.inventory) do
			local cargo = { id = record.id, mutation = record.mutation }
			cargo.model = World.figure(cargo, World.root)
			dockCargo(bay.slots[position], cargo)
			state.index[Catalog.discoveryKey(cargo)] = true
		end
		local keys = {}
		for found in pairs(state.index) do table.insert(keys, found) end
		table.sort(keys)
		player:SetAttribute("Index", table.concat(keys, ","))
		state.loading = false
		SkillService.Update(player, state)
		crews:Refresh()
		sync(player, state)
		message(player, state.saveStatus == "Saved" and "Bay ready. Credits, cargo and discoveries saved." or "Saving unavailable. This session is playable; progress is session only.")
	end)
	return true
end

for i, bay in ipairs(bays) do
	bay.number = i
	local collect = World.prompt(bay.bank, "Collect Credits", "Bay " .. i)
	bay.collectPrompt = collect
	collect:SetAttribute("OrbitPrompt", "Owner")
	collect.Triggered:Connect(function(player)
		if World.root:GetAttribute("ScreenshotFrozen") then return end
		local state = profiles[player]
		if not state or state.loading or state.closing or state.bay ~= bay or not near(player, bay.bank.Position, 10) then return end
		if state.bank <= 0 then message(player, "Dock a brainrot to start earning.") return end
		local value = state.bank
		state.cash += value
		state.bank = 0
		EconomyService.Activity(state, "Collect", nil, value)
		state.guide = math.max(state.guide, 4)
		sync(player, state)
		message(player, "+ " .. value .. " credits collected")
	end)
	local lock = World.prompt(bay.lock, "Lock Bay", "Bay " .. i)
	bay.lockPrompt = lock
	lock:SetAttribute("OrbitPrompt", "Owner")
	lock.Triggered:Connect(function(player)
		if World.root:GetAttribute("ScreenshotFrozen") then return end
		local state = profiles[player]
		if not state or state.loading or state.closing or state.bay ~= bay or not near(player, bay.lock.Position, 10) then return end
		local now = workspace:GetServerTimeNow()
		if now < state.lockReady then
			message(player, "Lock recharges in " .. math.ceil(state.lockReady - now) .. "s.")
			return
		end
		local duration = Catalog.lockDuration(state)
		state.lockedUntil = now + duration
		state.lockReady = now + duration + 24
		bay.lockLabel.Text = "BAY SEALED"
		bay.lockLabel.TextColor3 = World.gold
		sync(player, state)
		crews:Refresh()
		message(player, "Bay sealed for " .. duration .. " seconds. It repels inbound raids.")
	end)
	for _, slot in ipairs(bay.slots) do
		local prompt = World.prompt(slot.pad, "Dock Cargo", "Bay " .. i)
		slot.prompt = prompt
		slot.bay = bay
		prompt:SetAttribute("OrbitPrompt", "Slot")
		updateSlot(slot)
		prompt.Triggered:Connect(function(player)
			if World.root:GetAttribute("ScreenshotFrozen") then return end
			local state = profiles[player]
			if not state or state.loading or state.closing or not near(player, slot.pad.Position, 10) then return end
			if state.bay ~= bay then
				local owner = bay.owner
				local ownerState = owner and profiles[owner]
				if not slot.cargo or state.carry then return end
				if not bay.rival and (not ownerState or ownerState.loading or ownerState.closing) then return end
				local now = workspace:GetServerTimeNow()
				if now < (state.stunnedUntil or 0) then message(player, "Wait for the stun to end before stealing.") return end
				if CrewService.Same(state, ownerState) then message(player, "Squad cargo is protected.") return end
				if not EconomyService.FreeSlot(state) then message(player, "Recycle cargo to free a docking slot first.") return end
				if now < (state.stealReady or 0) then message(player, "Your theft scanner is recharging.") return end
				if ownerState and BayShield.IsActive(ownerState, now) then
					message(player, "That bay is sealed.")
					return
				end
				local cargo = take(slot)
				EconomyService.Activity(state, "Steal", cargo)
				setCarry(player, state, cargo)
				if ownerState then
					sync(owner, ownerState)
					message(owner, player.DisplayName .. " stole " .. Catalog.name(cargo) .. ". Zap them to recover it!")
				end
				message(player, "Stolen cargo. Dock it before you get zapped!")
				return
			end
			if not state.carry or slot.cargo or slot.reserved then return end
			local cargo = state.carry
			local source = clearSource(cargo)
			state.carry = nil
			SkillService.Update(player, state)
			dockCargo(slot, cargo)
			local discovered, bonus = EconomyService.Discover(state, cargo)
			if discovered then
				crews:Award(state, 2)
				local keys = {}
				for found in pairs(state.index) do table.insert(keys, found) end
				player:SetAttribute("Index", table.concat(keys, ","))
			end
			EconomyService.Activity(state, "Dock", cargo)
			if cargo.mutation > 1 then EconomyService.Activity(state, "Mutation", cargo) end
			state.guide = math.max(state.guide, 3)
			sync(player, state)
			message(player, Catalog.name(cargo) .. " docked  /  +" .. Catalog.rate(cargo) .. "/s" .. (bonus > 0 and ("  •  Index bonus +$" .. bonus) or ""))
			if source and source.bay.owner and profiles[source.bay.owner] then
				sync(source.bay.owner, profiles[source.bay.owner])
				message(source.bay.owner, "The thief docked your cargo. Keep your bay sealed during the next run.")
				local owner = source.bay.owner
				task.spawn(function() data:Save(owner, false) end)
			end
		end)
	end
end

rivals:Restock()
task.spawn(function()
	while not serverClosing do
		task.wait(45)
		if not World.root:GetAttribute("ScreenshotFrozen") then rivals:Restock() end
	end
end)

local function join(player)
	if not assign(player) then
		table.insert(waiting, player)
		player:SetAttribute("Guide", 0)
	end
	local function spawned(character)
		local root = character:WaitForChild("HumanoidRootPart", 10)
		if not root or player.Character ~= character then return end
		local state = profiles[player]
		character:PivotTo(state and state.bay.spawn or CFrame.new(0, 4, 12))
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			if state then SkillService.Update(player, state) end
			humanoid.Died:Connect(function()
				local state = profiles[player]
				if state then state.sprintUntil = 0 end
				if state and state.carry then
					local cargo = state.carry
					setCarry(player, state, nil)
					if cargo.source then returnCargo(cargo) else dropCargo(cargo, root.Position) end
				end
			end)
		end
	end
	player.CharacterAdded:Connect(spawned)
	if player.Character then task.spawn(spawned, player.Character) end
end

Players.PlayerAdded:Connect(join)
for _, player in ipairs(Players:GetPlayers()) do task.spawn(join, player) end
local function settleCargo(player, state)
	if raid and (raid.target.bay == state.bay or (raid.cargo and raid.cargo.source and raid.cargo.source.bay == state.bay)) then finishRaid(true) end
	for other, otherState in pairs(profiles) do
		local cargo = otherState.carry
		if cargo and cargo.source and cargo.source.bay == state.bay then
			setCarry(other, otherState, nil)
			returnCargo(cargo)
		end
	end
	for _, slot in ipairs(state.bay.slots) do
		local cargo = slot.reserved
		if cargo then
			local prompt = drops[cargo]
			if prompt then drops[cargo] = nil; prompt:Destroy() end
			returnCargo(cargo)
		end
	end
	if state.carry and state.carry.source then
		local cargo = state.carry
		setCarry(player, state, nil)
		returnCargo(cargo)
	end
end

if RunService:IsStudio() then
	screenshotService = ScreenshotService.new({ world = World, profiles = profiles, weather = weather,
		network = network, rootOf = rootOf, sync = sync, updateSlot = updateSlot, dockCargo = dockCargo,
		settle = settleCargo, finishRaid = function(recovered) if finishRaid then finishRaid(recovered) end end })
end

Players.PlayerRemoving:Connect(function(player)
	if screenshotService and screenshotService.player == player then screenshotService:Reset() end
	local state = profiles[player]
	if not state then
		local index = table.find(waiting, player)
		if index then table.remove(waiting, index) end
		return
	end
	state.closing = true
	settleCargo(player, state)
	-- Save a settled snapshot before destroying any models or releasing the bay.
	data:Save(player, true)
	profiles[player] = nil
	crews:Refresh()
	local bay = state.bay
	if state.carry then returnCargo(state.carry) end
	for _, slot in ipairs(bay.slots) do
		if slot.cargo then slot.cargo.model:Destroy() end
		slot.cargo = nil
		if slot.reserved then clearSource(slot.reserved) end
		slot.prompt:SetAttribute("Owner", 0)
		updateSlot(slot)
	end
	bay.owner = nil
	bay.header:SetAttribute("LockedUntil", 0)
	bay.collectPrompt:SetAttribute("Owner", 0)
	bay.lockPrompt:SetAttribute("Owner", 0)
	bay.lockLabel.Text = "BAY OPEN"
	bay.lockLabel.TextColor3 = World.cyan
	World.title(bay, "BAY " .. bay.number .. "  /  VACANT")
	local nextPlayer = table.remove(waiting, 1)
	if nextPlayer then assign(nextPlayer) end
end)

game:BindToClose(function()
	serverClosing = true
	if screenshotService then screenshotService:Reset() end
	for player, state in pairs(profiles) do state.closing = true; settleCargo(player, state) end
	local pending = 0
	for player in pairs(profiles) do
		pending += 1
		task.spawn(function() data:Save(player, true); pending -= 1 end)
	end
	local deadline = os.clock() + 25
	while pending > 0 and os.clock() < deadline do task.wait(.1) end
end)

task.spawn(function()
	while not serverClosing do
		task.wait(Catalog.autosaveSeconds)
		for player, state in pairs(profiles) do
			if not state.loading and not state.closing then task.spawn(function() data:Save(player, false) end) end
		end
	end
end)

local conveyor
local function placeOffer(offer, angle)
	local pos = Vector3.new(math.cos(angle) * World.radius, .18, math.sin(angle) * World.radius)
	offer.cargo.model:PivotTo(CFrame.lookAt(pos, Vector3.new(0, .18, 0)))
end

local function stock(offer, first, expiresAt)
	local cargo = offer.cargo
	cargo.model = World.figure(cargo, World.root)
	cargo.model:SetAttribute("OfferExpiresAt", expiresAt)
	local cost = Catalog.price(cargo)
	local rate = Catalog.rate(cargo)
	local rarity = Catalog.tiers[Catalog.entries[cargo.id].tier]
	if not first and Catalog.entries[cargo.id].tier >= 4 then
		World.root:SetAttribute("ArrivalColor", rarity.color)
		World.root:SetAttribute("ArrivalTime", workspace:GetServerTimeNow())
		workspace:SetAttribute("RareCargo", rarity.name:upper() .. " ON THE RING / " .. Catalog.name(cargo))
		workspace:SetAttribute("RareCargoEndsAt", workspace:GetServerTimeNow() + 8)
	end
	local anchor = cargo.model.PrimaryPart
	local label = World.billboard(anchor, rarity.name:upper() .. "   •   +" .. rate .. "/s", rarity.color, 158, 19, 4.2, 28)
	local prompt = World.prompt(anchor, "Buy  $" .. cost, Catalog.name(cargo), Enum.KeyCode.E, .16, 10)
	prompt.Triggered:Connect(function(player)
		if World.root:GetAttribute("ScreenshotFrozen") then return end
		local state = profiles[player]
		if not state or state.loading or state.closing or not near(player, anchor.Position, 13) then return end
		if state.carry then message(player, "Dock your current cargo first.") return end
		if not EconomyService.FreeSlot(state) then message(player, "Bay full. Recycle your weakest cargo in Upgrades.") return end
		if state.cash < cost then message(player, "Need $" .. cost .. " for this brainrot.") return end
		if not conveyor:Claim(offer) then return end
		state.cash -= cost
		label.Parent:Destroy()
		prompt:Destroy()
		cargo.model:SetAttribute("OfferExpiresAt", nil)
		state.guide = math.max(state.guide, 2)
		setCarry(player, state, cargo)
		sync(player, state)
		message(player, "Bought " .. Catalog.name(cargo) .. ". Head to Bay " .. state.bay.number .. ".")
	end)
end

conveyor = ConveyorService.new({ random = rng, profiles = profiles, stock = stock, place = placeOffer })

finishRaid = function(recovered)
	local active = raid
	if not active then return end
	raid = nil
	active.model:Destroy()
	workspace:SetAttribute("Raid", "")
	workspace:SetAttribute("RaidHealth", 0)
	workspace:SetAttribute("RaidEndsAt", 0)
	if not active.cargo then return end
	if recovered then
		returnCargo(active.cargo)
	else
		local source = active.cargo.source
		-- The escaping gremlin drops the loot at the portal for a final recovery window.
		dropCargo(active.cargo, World.portal)
		if source and source.bay.owner then message(source.bay.owner, "Your cargo fell at the rift. Recover it before it expires.") end
	end
end

local function startRaid()
	if World.root:GetAttribute("ScreenshotFrozen") then return end
	local now = workspace:GetServerTimeNow()
	local target, highest = nil, -1
	for _, state in pairs(profiles) do
		if not state.loading and not state.closing and now >= state.lockedUntil then
			for _, slot in ipairs(state.bay.slots) do
				if slot.cargo and Catalog.rate(slot.cargo) > highest then
					target = slot
					highest = Catalog.rate(slot.cargo)
				end
			end
		end
	end
	if not target then return end
	raidCount += 1
	local boss = raidCount % 3 == 0
	raid = { target = target, cargo = nil, position = World.portal, model = World.gremlin(), ready = now + 5, health = boss and 4 or 2, boss = boss, endsAt = now + 50 }
	workspace:SetAttribute("Raid", (boss and "BOSS RAID" or "RIFT RAID") .. "  /  BAY " .. target.bay.number)
	workspace:SetAttribute("RaidHealth", raid.health)
	workspace:SetAttribute("RaidEndsAt", raid.endsAt)
	announce((boss and "Boss gremlin" or "Gremlin") .. " inbound to Bay " .. target.bay.number .. "! Lock the bay or land " .. raid.health .. " zaps.")
end

local function moveRaid(delta, now)
	local active = raid
	if not active or now < active.ready then return end
	if now >= active.endsAt then finishRaid(false); return end
	local slot = active.target
	local owner = slot.bay.owner
	local state = owner and profiles[owner]
	if not active.cargo and (not slot.cargo or not state or state.loading or state.closing or BayShield.IsActive(state, now)) then
		finishRaid(false)
		if state and BayShield.IsActive(state, now) then
			state.cash += 25
			crews:Award(state, 5)
			sync(owner, state)
			message(owner, "Raid repelled  /  +$25 defence bonus.")
		end
		return
	end
	local goal = active.cargo and World.portal or slot.pad.Position
	goal = Vector3.new(goal.X, World.portal.Y, goal.Z)
	local direction = goal - active.position
	if direction.Magnitude > 1 then
		active.position += direction.Unit * math.min(direction.Magnitude, delta * (active.cargo and 9 or 7))
		local cf = CFrame.lookAt(active.position, active.position + direction)
		active.model:PivotTo(cf)
		if active.cargo then active.cargo.model:PivotTo(cf * CFrame.new(0, .85, 2)) end
	elseif active.cargo then
		finishRaid(false)
	else
		active.cargo = take(slot)
		sync(owner, state)
		workspace:SetAttribute("Raid", active.boss and "BOSS HAS CARGO  /  CHASE TO RIFT" or "CARGO TAKEN  /  CHASE TO RIFT")
		message(owner, "The gremlin has your cargo. Zap it before it reaches the rift!")
	end
end

action.OnServerEvent:Connect(function(player, request, value)
	if request == actions.Screenshot then
		if RunService:IsStudio() and (value == "Cover" or value == "Index" or value == "Raid" or value == "Upgrades" or value == "Reset") then
			ScreenshotMode.Select(value, player)
		end
		return
	end
	if World.root:GetAttribute("ScreenshotFrozen") then return end
	local state, root = profiles[player], rootOf(player)
	if not state or state.loading or state.closing or not root then return end
	local now = workspace:GetServerTimeNow()
	if now < (state.actionReady or 0) then return end
	state.actionReady = now + .12
	if request == actions.Blink or request == actions.Sprint then
		local success, words = SkillService.Use(player, state, request, function(origin, direction, distance)
			return BayShield.BlinkDistance(profiles, origin, direction, distance, now)
		end)
		if success then World.flash(root.Position, World.cyan, request == actions.Blink and 5 or 3)
		elseif words then message(player, words) end
		return
	end
	if request ~= actions.Zap then
		if now < (state.menuReady or 0) then return end
		state.menuReady = now + .3
		if request == actions.Crew then
			local _, words = crews:Select(state, value, raid ~= nil)
			message(player, words)
		elseif request == actions.Upgrade then
			local _, words = EconomyService.Upgrade(state, value)
			SkillService.Update(player, state)
			message(player, words)
		elseif request == actions.Rebirth then
			local best, reason = EconomyService.RebirthCheck(state)
			if not best then message(player, reason) return end
			local kept = best.cargo
			for _, slot in ipairs(state.bay.slots) do
				if slot.cargo and slot.cargo ~= kept then slot.cargo.model:Destroy() end
				slot.cargo = nil
				updateSlot(slot)
			end
			state.cash, state.bank, state.level, state.guide = 90, 0, 0, 1
			state.speedLevel, state.shieldLevel = 0, 0
			state.rebirths += 1
			dockCargo(state.bay.slots[1], kept)
			state.guide = 3
			EconomyService.Activity(state, "Rebirth")
			SkillService.Update(player, state)
			World.flash(state.bay.bank.Position, World.gold, 12)
			message(player, "Rebirth complete. Best cargo kept, +25% base income, +2s shield" .. (state.rebirths == 2 and ", longer Blink!" or "."))
		elseif request == actions.Contract then
			local contract = Catalog.contracts[state.contract]
			if state.progress < contract.goal then message(player, "Contract is still in progress.") return end
			state.cash += contract.reward
			state.contract = state.contract % #Catalog.contracts + 1
			state.progress = 0
			message(player, "Contract complete  /  +$" .. contract.reward)
		elseif request == actions.ContractSkip then
			if state.progress >= Catalog.contracts[state.contract].goal then message(player, "Claim this completed contract first.") return end
			if state.cash < 90 then message(player, "Need $90 to skip a contract.") return end
			state.cash -= 90
			state.contract = state.contract % #Catalog.contracts + 1
			state.progress = 0
			message(player, "New contract  /  " .. Catalog.contracts[state.contract].title)
		elseif request == actions.Recycle then
			local weakest
			for _, slot in ipairs(state.bay.slots) do
				if slot.cargo and (not weakest or Catalog.rate(slot.cargo) < Catalog.rate(weakest.cargo)) then
					weakest = slot
				end
			end
			if not weakest then message(player, "There is no docked cargo to recycle.") return end
			local cargo = weakest.cargo
			local salvage = math.floor(Catalog.price(cargo) / 2)
			weakest.cargo = nil
			cargo.model:Destroy()
			updateSlot(weakest)
			state.cash += salvage
			message(player, Catalog.name(cargo) .. " recycled  /  +$" .. salvage)
		else
			return
		end
		sync(player, state)
		if request == actions.Rebirth then task.spawn(function() data:Save(player, false) end) end
		return
	end
	if now < state.zapReady then return end
	state.zapReady = now + Catalog.zap.cooldown
	player:SetAttribute("ZapReady", state.zapReady)
	World.flash(root.Position, World.cyan, 7)
	local target, targetState, targetPosition, best = nil, nil, nil, Catalog.zap.range
	for other, otherState in pairs(profiles) do
		local cargo = otherState.carry
		if other ~= player and not otherState.loading and not otherState.closing and cargo and cargo.source
			and not CrewService.Same(state, otherState) then
			local otherRoot = rootOf(other)
			local distance = otherRoot and (root.Position - otherRoot.Position).Magnitude
			if distance and distance <= best and not BayShield.BlocksZap(profiles, root.Position, otherRoot.Position, now) then
				target, targetState, targetPosition, best = other, otherState, otherRoot.Position, distance
			end
		end
	end
	if raid and (raid.position - root.Position).Magnitude <= best
		and not BayShield.BlocksZap(profiles, root.Position, raid.position, now) then
		World.flash(raid.position + Vector3.yAxis * 2, World.gold, 6)
		EconomyService.Activity(state, "Zap")
		raid.health -= 1
		workspace:SetAttribute("RaidHealth", raid.health)
		if raid.health > 0 then
			raid.ready = now + 1
			message(player, "Gremlin stunned  /  " .. raid.health .. " zaps remaining.")
			sync(player, state)
			return
		end
		local boss, position, cargo = raid.boss, raid.position, raid.cargo
		raid.cargo = nil
		finishRaid(true)
		announce(player.DisplayName .. " zapped the rift gremlin.")
		if cargo then
			dropCargo(cargo, position, true)
			local owner = cargo.source and cargo.source.bay.owner
			if owner then message(owner, "Raid cargo dropped. Recover it where the gremlin fell.") end
		end
		local reward = boss and 220 or 65
		state.cash += reward
		crews:Award(state, boss and 30 or 10)
		for member, memberState in pairs(profiles) do
			if member ~= player and not memberState.loading and not memberState.closing
				and CrewService.Same(state, memberState) and near(member, position, 40) then
				memberState.cash += 20
				sync(member, memberState)
				message(member, "Squad defence assist  /  +$20")
			end
		end
		sync(player, state)
		message(player, (boss and "Boss" or "Gremlin") .. " repelled  /  +$" .. reward)
	elseif target then
		local cargo = targetState.carry
		setCarry(target, targetState, nil)
		dropCargo(cargo, targetPosition, true)
		targetState.stunnedUntil = math.max(now + Catalog.zap.stun, targetState.stunnedUntil or 0)
		targetState.stealReady = now + Catalog.zap.stealCooldown
		SkillService.Update(target, targetState)
		message(target, "You were zapped and dropped the stolen cargo.")
		message(player, "Stolen cargo dropped. Recover it with E.")
	else
		message(player, "Zap needs a gremlin or cargo thief within 22 studs.")
	end
end)

task.spawn(function()
	local last = os.clock()
	while not serverClosing do
		task.wait(.09)
		local now = os.clock()
		local delta = now - last
		last = now
		local frozen = World.root:GetAttribute("ScreenshotFrozen")
		conveyor:Step(delta, frozen)
		for player, state in pairs(profiles) do
			local root = state.carry and rootOf(player)
			if root then state.carry.model:PivotTo(root.CFrame * CFrame.new(0, -.85, -2.6)) end
		end
		local serverNow = workspace:GetServerTimeNow()
		if not frozen then moveRaid(math.min(delta, .35), serverNow) end
		weather:Step(serverNow)
	end
end)

task.spawn(function()
	while true do
		task.wait(1)
		local now = workspace:GetServerTimeNow()
		for player, state in pairs(profiles) do
			if state.loading or state.closing then continue end
			if World.root:GetAttribute("ScreenshotFrozen") then continue end
			SkillService.Update(player, state)
			if state.lockedUntil > 0 and now >= state.lockedUntil then
				state.lockedUntil = 0
				state.bay.lockLabel.Text = "BAY OPEN"
				state.bay.lockLabel.TextColor3 = World.cyan
				crews:Refresh()
			end
			local rate = sync(player, state)
			state.bank = math.min(1e12, state.bank + rate)
			player:SetAttribute("Unclaimed", state.bank)
			if rate == 0 and state.bank + state.cash < 50 and not state.carry then
				state.cash = 75
				message(player, "Station relief grant  /  Wallet topped up to $75.")
			end
		end
	end
end)

task.spawn(function()
	while true do
		task.wait(48)
		if not raid then startRaid() end
	end
end)
