local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Orbit = ReplicatedStorage:WaitForChild("Orbit")
local Catalog = require(Orbit:WaitForChild("Catalog"))
local World = require(script:WaitForChild("World"))
local CrewService = require(script:WaitForChild("CrewService"))
local DataService = require(script:WaitForChild("DataService"))
local SkillService = require(script:WaitForChild("SkillService"))
local data = DataService.new()

local rng = Random.new()
local bays = World.build()
local profiles = {}
local crews = CrewService.new(profiles)
local waiting = {}
local market = {}
local drops = {}
local raid
local finishRaid
local serverClosing = false
local action = Instance.new("RemoteEvent")
action.Name = "Action"
action.Parent = Orbit

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
	local rate = 0
	for _, slot in ipairs(state.bay.slots) do
		if slot.cargo then rate += Catalog.rate(slot.cargo) end
	end
	rate = math.floor(rate * (1 + .25 * state.level + .25 * state.rebirths)
		* (workspace:GetAttribute("Event") == "Solar Flare" and 2 or 1))
	player:SetAttribute("Cash", state.cash)
	player:SetAttribute("Unclaimed", state.bank)
	player:SetAttribute("Income", rate)
	player:SetAttribute("Carry", state.carry and Catalog.name(state.carry) or "")
	player:SetAttribute("Bay", state.bay.number)
	player:SetAttribute("Guide", state.loading and 0 or state.guide)
	player:SetAttribute("Loading", state.loading == true)
	player:SetAttribute("SaveStatus", state.saveStatus or "Loading")
	player:SetAttribute("LockedUntil", state.lockedUntil)
	player:SetAttribute("Upgrade", state.level)
	player:SetAttribute("Rebirths", state.rebirths)
	player:SetAttribute("Contract", state.contract)
	player:SetAttribute("ContractProgress", state.progress)
	player:SetAttribute("CrewId", state.crew or 0)
	player:SetAttribute("CrewReady", state.crewReady or 0)
	player:SetAttribute("PersonalScore", state.score or 0)
	for _, slot in ipairs(state.bay.slots) do slot.prompt:SetAttribute("Crew", state.crew or 0) end
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

local function dropPurchased(cargo, position)
	if not position or Vector3.new(position.X, 0, position.Z).Magnitude > 75 then
		cargo.model:Destroy()
		return
	end
	cargo.model:PivotTo(CFrame.new(position.X, .55, position.Z))
	local prompt = World.prompt(cargo.model.PrimaryPart, "Recover Cargo", Catalog.name(cargo), Enum.KeyCode.E, .32)
	drops[cargo] = prompt
	prompt.Triggered:Connect(function(player)
		local state = profiles[player]
		if drops[cargo] ~= prompt or not state or state.loading or state.closing or state.carry
			or not near(player, cargo.model.PrimaryPart.Position, 10) then return end
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
		cargo.model:Destroy()
	end)
end

local function assign(player)
	local bay
	for _, candidate in ipairs(bays) do
		if not candidate.owner then bay = candidate break end
	end
	if not bay then return false end
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
		for _, key in ipairs({ "cash", "bank", "level", "rebirths", "guide", "crew", "contract", "progress", "index" }) do state[key] = saved[key] end
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
		local state = profiles[player]
		if not state or state.loading or state.closing or state.bay ~= bay or not near(player, bay.bank.Position, 10) then return end
		if state.bank <= 0 then message(player, "Dock a brainrot to start earning.") return end
		local value = state.bank
		state.cash += value
		state.bank = 0
		if state.contract == 2 then state.progress = math.min(250, state.progress + value) end
		state.guide = math.max(state.guide, 4)
		sync(player, state)
		message(player, "+ " .. value .. " credits collected")
	end)
	local lock = World.prompt(bay.lock, "Lock Bay", "Bay " .. i)
	bay.lockPrompt = lock
	lock:SetAttribute("OrbitPrompt", "Owner")
	lock.Triggered:Connect(function(player)
		local state = profiles[player]
		if not state or state.loading or state.closing or state.bay ~= bay or not near(player, bay.lock.Position, 10) then return end
		local now = workspace:GetServerTimeNow()
		if now < state.lockReady then
			message(player, "Lock recharges in " .. math.ceil(state.lockReady - now) .. "s.")
			return
		end
		state.lockedUntil = now + 32
		state.lockReady = now + 56
		bay.lockLabel.Text = "BAY SEALED"
		bay.lockLabel.TextColor3 = World.gold
		sync(player, state)
		message(player, "Bay sealed for 32 seconds.")
	end)
	for _, slot in ipairs(bay.slots) do
		local prompt = World.prompt(slot.pad, "Dock Cargo", "Bay " .. i)
		slot.prompt = prompt
		slot.bay = bay
		prompt:SetAttribute("OrbitPrompt", "Slot")
		updateSlot(slot)
		prompt.Triggered:Connect(function(player)
			local state = profiles[player]
			if not state or state.loading or state.closing or not near(player, slot.pad.Position, 10) then return end
			if state.bay ~= bay then
				local owner = bay.owner
				local ownerState = owner and profiles[owner]
				if not ownerState or ownerState.loading or ownerState.closing or not slot.cargo or state.carry then return end
				if CrewService.Same(state, ownerState) then message(player, "Squad cargo is protected.") return end
				if workspace:GetServerTimeNow() < ownerState.lockedUntil then
					message(player, "That bay is sealed.")
					return
				end
				local cargo = take(slot)
				setCarry(player, state, cargo)
				sync(owner, ownerState)
				message(owner, player.DisplayName .. " stole " .. Catalog.name(cargo) .. ". Zap them to recover it!")
				message(player, "Stolen cargo. Dock it before you get zapped!")
				return
			end
			if not state.carry or slot.cargo or slot.reserved then return end
			local cargo = state.carry
			clearSource(cargo)
			state.carry = nil
			dockCargo(slot, cargo)
			local key = Catalog.discoveryKey(cargo)
			if not state.index[key] then
				state.index[key] = true
				crews:Award(state, 2)
				local keys = {}
				for found in pairs(state.index) do table.insert(keys, found) end
				player:SetAttribute("Index", table.concat(keys, ","))
			end
			if state.contract == 1 then state.progress = math.min(3, state.progress + 1) end
			if state.contract == 3 and Catalog.entries[cargo.id].tier >= 3 then state.progress = 1 end
			state.guide = math.max(state.guide, 3)
			sync(player, state)
			message(player, Catalog.name(cargo) .. " docked  /  +" .. Catalog.rate(cargo) .. "/s")
		end)
	end
end

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
					if cargo.source then returnCargo(cargo) else dropPurchased(cargo, root.Position) end
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
	if state.carry and state.carry.source then
		local cargo = state.carry
		setCarry(player, state, nil)
		returnCargo(cargo)
	end
end

Players.PlayerRemoving:Connect(function(player)
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
		task.wait(50)
		for player, state in pairs(profiles) do
			if not state.loading and not state.closing then task.spawn(function() data:Save(player, false) end) end
		end
	end
end)

local themes = { 1, 2, 1, 3, 1, 4, 2, 1, 5, 2, 3, 6 }
local function roll(index, first)
	local tier = themes[index]
	if index == #themes and rng:NextNumber() < .12 then tier = 7 end
	local choices = Catalog.byTier[tier]
	local id = first and index == 1 and 1 or choices[rng:NextInteger(1, #choices)]
	local mutation = not first and index ~= 1 and Catalog.rollMutation(rng) or 1
	local cargo = { id = id, mutation = mutation }
	cargo.model = World.figure(cargo, World.root)
	return cargo
end

local function placeOffer(offer)
	local angle = offer.angle
	local pos = Vector3.new(math.cos(angle) * World.radius, .18, math.sin(angle) * World.radius)
	offer.cargo.model:PivotTo(CFrame.lookAt(pos, Vector3.new(0, .18, 0)))
end

local function stock(offer, first)
	local cargo = roll(offer.index, first)
	offer.cargo = cargo
	offer.refresh = os.clock() + rng:NextNumber(49, 68)
	placeOffer(offer)
	local cost = Catalog.price(cargo)
	local rate = Catalog.rate(cargo)
	local rarity = Catalog.tiers[Catalog.entries[cargo.id].tier]
	local anchor = cargo.model.PrimaryPart
	local label = World.billboard(anchor, rarity.name:upper() .. "   •   +" .. rate .. "/s", rarity.color, 158, 19, 4.2, 28)
	local prompt = World.prompt(anchor, "Buy  $" .. cost, Catalog.name(cargo), Enum.KeyCode.E, .16, 10)
	prompt.Triggered:Connect(function(player)
		local state = profiles[player]
		if offer.cargo ~= cargo or not state or state.loading or state.closing or not near(player, anchor.Position, 13) then return end
		if state.carry then message(player, "Dock your current cargo first.") return end
		if state.cash < cost then message(player, "Need $" .. cost .. " for this brainrot.") return end
		state.cash -= cost
		label.Parent:Destroy()
		prompt:Destroy()
		offer.cargo = nil
		state.guide = math.max(state.guide, 2)
		setCarry(player, state, cargo)
		sync(player, state)
		message(player, "Bought " .. Catalog.name(cargo) .. ". Head to Bay " .. state.bay.number .. ".")
		task.delay(3, stock, offer, false)
	end)
end

for i = 1, #themes do
	local offer = { angle = (i - 1) * math.pi * 2 / #themes + math.pi / 2, index = i }
	market[i] = offer
	stock(offer, true)
end

finishRaid = function(recovered)
	local active = raid
	raid = nil
	active.model:Destroy()
	workspace:SetAttribute("Raid", "")
	if not active.cargo then return end
	if recovered then
		returnCargo(active.cargo)
	else
		local source = clearSource(active.cargo)
		-- The escaping gremlin drops the loot at the portal for a final recovery window.
		dropPurchased(active.cargo, World.portal)
		if source and source.bay.owner then message(source.bay.owner, "Your cargo fell at the rift. Recover it before it expires.") end
	end
end

local function startRaid()
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
	raid = { target = target, cargo = nil, position = World.portal, model = World.gremlin(), ready = now + 2 }
	workspace:SetAttribute("Raid", "RIFT RAID  /  BAY " .. target.bay.number)
	announce("Gremlin inbound to Bay " .. target.bay.number .. "! Get close and zap it.")
end

local function moveRaid(delta, now)
	local active = raid
	if not active or now < active.ready then return end
	local slot = active.target
	local owner = slot.bay.owner
	local state = owner and profiles[owner]
	if not active.cargo and (not slot.cargo or not state or now < state.lockedUntil) then
		finishRaid(false)
		if owner then message(owner, "The gremlin raid was repelled.") end
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
		workspace:SetAttribute("Raid", "CARGO TAKEN  /  CHASE TO RIFT")
		message(owner, "The gremlin has your cargo. Zap it before it reaches the rift!")
	end
end

action.OnServerEvent:Connect(function(player, request, value)
	local state, root = profiles[player], rootOf(player)
	if not state or state.loading or state.closing or not root then return end
	local now = workspace:GetServerTimeNow()
	if now < (state.actionReady or 0) then return end
	state.actionReady = now + .12
	if request == "Blink" or request == "Sprint" then
		local success, words = SkillService.Use(player, state, request)
		if success then World.flash(root.Position, World.cyan, request == "Blink" and 5 or 3)
		elseif words then message(player, words) end
		return
	end
	if request ~= "Zap" then
		if now < (state.menuReady or 0) then return end
		state.menuReady = now + .3
		if request == "Crew" then
			local _, words = crews:Select(state, value, raid ~= nil)
			message(player, words)
		elseif request == "Upgrade" then
			local price = Catalog.upgrades[state.level + 1]
			if not price then message(player, "Income upgrade is maxed.") return end
			if state.cash < price then message(player, "Need $" .. price .. " to upgrade.") return end
			state.cash -= price
			state.level += 1
			message(player, "Dock income upgraded. +25% base income.")
		elseif request == "Rebirth" then
			local price = Catalog.rebirthCost(state.rebirths)
			if state.cash < price then message(player, "Need $" .. price .. " to rebirth.") return end
			if state.carry then message(player, "Dock your carried cargo before rebirthing.") return end
			for _, slot in ipairs(state.bay.slots) do
				if slot.reserved then message(player, "Recover your missing cargo before rebirthing.") return end
			end
			for _, slot in ipairs(state.bay.slots) do
				if slot.cargo then slot.cargo.model:Destroy() end
				slot.cargo = nil
				updateSlot(slot)
			end
			state.cash, state.bank, state.level, state.guide = 90, 0, 0, 1
			state.rebirths += 1
			message(player, "Rebirth complete. Permanent +25% base income.")
		elseif request == "Contract" then
			local contract = Catalog.contracts[state.contract]
			if state.progress < contract.goal then message(player, "Contract is still in progress.") return end
			state.cash += contract.reward
			state.contract = state.contract % #Catalog.contracts + 1
			state.progress = 0
			message(player, "Contract complete  /  +$" .. contract.reward)
		elseif request == "Recycle" then
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
		return
	end
	if now < state.zapReady then return end
	state.zapReady = now + 5
	player:SetAttribute("ZapReady", state.zapReady)
	World.flash(root.Position, World.cyan, 7)
	local target, targetState, best = nil, nil, 17
	for other, otherState in pairs(profiles) do
		local cargo = otherState.carry
		if other ~= player and cargo and cargo.source and not CrewService.Same(state, otherState) then
			local otherRoot = rootOf(other)
			local distance = otherRoot and (root.Position - otherRoot.Position).Magnitude
			if distance and distance < best then
				target, targetState, best = other, otherState, distance
			end
		end
	end
	if raid and (raid.position - root.Position).Magnitude < best then
		World.flash(raid.position + Vector3.yAxis * 2, World.gold, 6)
		finishRaid(true)
		state.cash += 35
		crews:Award(state, 10)
		sync(player, state)
		announce(player.DisplayName .. " zapped the rift gremlin.")
		message(player, "Gremlin repelled  /  +$35")
	elseif target then
		local cargo = targetState.carry
		setCarry(target, targetState, nil)
		returnCargo(cargo)
		message(target, "You were zapped. The cargo went back to its bay.")
		message(player, "Cargo returned to its bay.")
	else
		message(player, "Zap needs a gremlin or cargo thief within 16 studs.")
	end
end)

task.spawn(function()
	local last = os.clock()
	while true do
		task.wait(.09)
		local now = os.clock()
		local delta = math.min(now - last, .35)
		last = now
		for _, offer in ipairs(market) do
			offer.angle = (offer.angle + delta * .12) % (math.pi * 2)
			if offer.cargo then
				if now >= offer.refresh then
					local anchor = offer.cargo.model.PrimaryPart
					local busy = false
					for player in pairs(profiles) do
						if near(player, anchor.Position, 11) then busy = true break end
					end
					if busy then
						offer.refresh += 3
					else
						offer.cargo.model:Destroy()
						stock(offer, false)
					end
				end
				placeOffer(offer)
			end
		end
		for player, state in pairs(profiles) do
			local root = state.carry and rootOf(player)
			if root then state.carry.model:PivotTo(root.CFrame * CFrame.new(0, -.85, -2.6)) end
		end
		moveRaid(delta, workspace:GetServerTimeNow())
	end
end)

task.spawn(function()
	while true do
		task.wait(1)
		local now = workspace:GetServerTimeNow()
		for player, state in pairs(profiles) do
			if state.loading or state.closing then continue end
			SkillService.Update(player, state)
			local rate = sync(player, state)
			state.bank += rate
			player:SetAttribute("Unclaimed", state.bank)
			if rate == 0 and state.bank + state.cash < 50 and not state.carry then
				state.cash = 75
				message(player, "Station relief grant  /  Wallet topped up to $75.")
			end
			if state.lockedUntil > 0 and now >= state.lockedUntil then
				state.lockedUntil = 0
				state.bay.lockLabel.Text = "BAY OPEN"
				state.bay.lockLabel.TextColor3 = World.cyan
			end
		end
	end
end)

task.spawn(function()
	local solar = true
	while true do
		task.wait(72)
		while not next(profiles) do task.wait(5) end
		if solar then
			workspace:SetAttribute("Event", "Solar Flare")
			announce("Solar flare  /  Double dock income for 24 seconds.")
			World.flash(Vector3.new(0, 1, 0), World.gold, 15)
		else
			workspace:SetAttribute("Event", "Meteor Drop")
			announce("Meteor drop  /  Recover Ion cargo at the central reactor.")
			local cargo = { id = rng:NextInteger(8, 21), mutation = 2 }
			cargo.model = World.figure(cargo, World.root)
			World.flash(Vector3.new(0, 2, 0), World.pink, 12)
			dropPurchased(cargo, Vector3.new(0, 0, 0))
		end
		solar = not solar
		task.wait(24)
		workspace:SetAttribute("Event", "")
	end
end)

task.spawn(function()
	while true do
		task.wait(48)
		if not raid then startRaid() end
	end
end)
