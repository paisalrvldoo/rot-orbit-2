local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Orbit = ReplicatedStorage:WaitForChild("Orbit")
local Catalog = require(Orbit:WaitForChild("Catalog"))
local World = require(script:WaitForChild("World"))

local rng = Random.new()
local bays = World.build()
local profiles = {}
local waiting = {}
local market = {}
local function message(player, words)
	player:SetAttribute("OrbitMessage", words)
	player:SetAttribute("OrbitMessageId", (player:GetAttribute("OrbitMessageId") or 0) + 1)
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
	player:SetAttribute("Cash", state.cash)
	player:SetAttribute("Unclaimed", state.bank)
	player:SetAttribute("Income", rate)
	player:SetAttribute("Carry", state.carry and Catalog.name(state.carry) or "")
	player:SetAttribute("Bay", state.bay.number)
	player:SetAttribute("Guide", state.guide)
	return rate
end

local function setCarry(player, state, cargo)
	if state.carry then state.carry.model:Destroy() end
	state.carry = cargo
	if not cargo then return end
	local root = rootOf(player)
	if root then cargo.model:PivotTo(root.CFrame * CFrame.new(0, -.85, -2.6)) end
end

local function dockCargo(slot, cargo)
	slot.cargo = cargo
	cargo.model:PivotTo(slot.cf)
end

local function assign(player)
	local bay
	for _, candidate in ipairs(bays) do
		if not candidate.owner then bay = candidate break end
	end
	if not bay then return false end
	bay.owner = player
	local state = { bay = bay, cash = 90, bank = 0, guide = 1 }
	profiles[player] = state
	World.title(bay, "BAY " .. bay.number .. "  /  " .. player.DisplayName)
	local root = rootOf(player)
	if root then player.Character:PivotTo(bay.spawn) end
	sync(player, state)
	return true
end

for i, bay in ipairs(bays) do
	bay.number = i
	local collect = World.prompt(bay.bank, "Collect Credits", "Bay " .. i)
	collect.Triggered:Connect(function(player)
		local state = profiles[player]
		if not state or state.bay ~= bay or not near(player, bay.bank.Position, 10) then return end
		if state.bank <= 0 then message(player, "Dock a brainrot to start earning.") return end
		local value = state.bank
		state.cash += value
		state.bank = 0
		state.guide = math.max(state.guide, 4)
		sync(player, state)
		message(player, "+ " .. value .. " credits collected")
	end)
	for _, slot in ipairs(bay.slots) do
		local prompt = World.prompt(slot.pad, "Dock Cargo", "Bay " .. i)
		slot.prompt = prompt
		prompt.Triggered:Connect(function(player)
			local state = profiles[player]
			if not state or state.bay ~= bay or not near(player, slot.pad.Position, 10) then return end
			if not state.carry or slot.cargo then return end
			local cargo = state.carry
			state.carry = nil
			dockCargo(slot, cargo)
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
			humanoid.Died:Connect(function()
				if state and state.carry then
					setCarry(player, state, nil)
					sync(player, state)
				end
			end)
		end
	end
	player.CharacterAdded:Connect(spawned)
	if player.Character then task.spawn(spawned, player.Character) end
end

Players.PlayerAdded:Connect(join)
for _, player in ipairs(Players:GetPlayers()) do task.spawn(join, player) end
Players.PlayerRemoving:Connect(function(player)
	local state = profiles[player]
	if not state then
		local index = table.find(waiting, player)
		if index then table.remove(waiting, index) end
		return
	end
	profiles[player] = nil
	local bay = state.bay
	setCarry(player, state, nil)
	for _, slot in ipairs(bay.slots) do
		if slot.cargo then slot.cargo.model:Destroy() end
		slot.cargo = nil
	end
	bay.owner = nil
	World.title(bay, "BAY " .. bay.number .. "  /  VACANT")
	local nextPlayer = table.remove(waiting, 1)
	if nextPlayer then assign(nextPlayer) end
end)

local themes = { 1, 2, 1, 3, 1, 4, 2, 1, 5, 2, 3, 6 }
local function roll(index, first)
	local tier = themes[index]
	local id = (tier - 1) * 7 + (first and index == 1 and 1 or rng:NextInteger(1, 7))
	local chance = rng:NextNumber()
	local mutation = not first and (tier ~= 1 or index ~= 1)
		and (chance < .008 and 4 or chance < .025 and 3 or chance < .10 and 2 or 1) or 1
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
	placeOffer(offer)
	local cost = Catalog.price(cargo)
	local rate = Catalog.rate(cargo)
	local rarity = Catalog.tiers[Catalog.entries[cargo.id].tier]
	local anchor = cargo.model.PrimaryPart
	local label = World.billboard(anchor, rarity.name:upper() .. "   •   +" .. rate .. "/s", rarity.color, 158, 19, 4.2, 28)
	local prompt = World.prompt(anchor, "Buy  $" .. cost, Catalog.name(cargo), Enum.KeyCode.E, .16, 10)
	prompt.Triggered:Connect(function(player)
		local state = profiles[player]
		if offer.cargo ~= cargo or not state or not near(player, anchor.Position, 13) then return end
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

task.spawn(function()
	local last = os.clock()
	while true do
		task.wait(.09)
		local now = os.clock()
		local delta = math.min(now - last, .35)
		last = now
		for _, offer in ipairs(market) do
			offer.angle = (offer.angle + delta * .12) % (math.pi * 2)
			if offer.cargo then placeOffer(offer) end
		end
		for player, state in pairs(profiles) do
			local root = state.carry and rootOf(player)
			if root then state.carry.model:PivotTo(root.CFrame * CFrame.new(0, -.85, -2.6)) end
		end
	end
end)

task.spawn(function()
	while true do
		task.wait(1)
		for player, state in pairs(profiles) do
			state.bank += sync(player, state)
			player:SetAttribute("Unclaimed", state.bank)
		end
	end
end)
