local Catalog = {}
Catalog.maxCash = 1e12
Catalog.autosaveSeconds = 50
Catalog.offline = { minimumSeconds = 60, maximumSeconds = 7200, share = .25 }

Catalog.tiers = {
	{ name = "Common", color = Color3.fromRGB(94, 240, 167), price = 50, rate = 4 },
	{ name = "Uncommon", color = Color3.fromRGB(86, 221, 255), price = 155, rate = 11 },
	{ name = "Rare", color = Color3.fromRGB(123, 145, 255), price = 420, rate = 28 },
	{ name = "Epic", color = Color3.fromRGB(240, 111, 255), price = 1100, rate = 72 },
	{ name = "Legendary", color = Color3.fromRGB(255, 213, 81), price = 3000, rate = 185 },
	{ name = "Mythic", color = Color3.fromRGB(255, 103, 126), price = 8500, rate = 490 },
	{ name = "Cosmic", color = Color3.fromRGB(170, 255, 233), price = 24000, rate = 1350 },
	{ name = "SECRET", color = Color3.fromRGB(255, 146, 83), price = 96000, rate = 5600 },
}

local names = {
	{ "Sprout Sputnik", "Bean Biscotto", "Doodle Dumpling", "Lunar Loaf", "Pico Pickle", "Crater Crouton", "Puddle Pesto" },
	{ "Turbo Tofu", "Boba Booster", "Radar Radish", "Bungo Bongo", "Pepper Pilot", "Wobble Waffle", "Noodle Nacelle" },
	{ "Comet Cannoli", "Orbit Octato", "Sushi Shuttle", "Phantom Flan", "Rocket Ravioli", "Disco Durian", "Quasar Quokka" },
	{ "Turbo Truffle", "Astro Axoloco", "Neon Nachonaut", "Mochi Mirage", "Captain Calzone", "Pixel Pineapod", "Robo Rigatoni" },
	{ "Solar Salamango", "Emperor Eggclipse", "Gold Guaczilla", "Duke Dango", "Plasma Panini", "Cosmic Cornado", "Saturn Sorbet" },
	{ "Void Volcanoli", "Omega Omelord", "Nova Narwhal", "Black Hole Baguette", "Zenith Zappuccino", "Galactic Gelato", "Oracle Orzo" },
	{ "Infinity Macaron", "Nebula Nectaroon", "Singularity Saffron" },
	-- Append only: existing cargo IDs 1–45 and their discovery keys remain unchanged.
	{ "Event Horizon Espresso", "Forbidden Focaccia", "Paradox Pistachio" },
}

Catalog.entries = {}
Catalog.byTier = {}
for tier, group in ipairs(names) do
	Catalog.byTier[tier] = {}
	for slot, name in ipairs(group) do
		local id = #Catalog.entries + 1
		local rarity = Catalog.tiers[tier]
		Catalog.entries[id] = {
			id = id, name = name, tier = tier,
			color = Color3.fromHSV(((slot - 1) / 7 + (tier - 1) * .045) % 1, .58, .95),
			shape = slot,
			price = math.floor(rarity.price * (1 + (slot - 1) * .11)),
			rate = math.floor(rarity.rate * (1 + (slot - 1) * .13)),
		}
		table.insert(Catalog.byTier[tier], id)
	end
end

Catalog.mutations = {
	{ name = "", factor = 1 },
	{ name = "Ion", factor = 2, chance = .08, color = Color3.fromRGB(71, 255, 240) },
	{ name = "Gilded", factor = 3, chance = .025, color = Color3.fromRGB(255, 208, 73) },
	{ name = "Eclipse", factor = 5, chance = .012, color = Color3.fromRGB(231, 103, 255) },
	{ name = "Aurora", factor = 7, chance = .006, color = Color3.fromRGB(137, 255, 161) },
	{ name = "Zero-G", factor = 10, chance = .003, color = Color3.fromRGB(181, 213, 255) },
	{ name = "Supernova", factor = 15, chance = .001, color = Color3.fromRGB(255, 141, 82) },
}
-- Standard cargo occupies slot 1; the six mutations retain stable discovery IDs.
Catalog.mutationCount = #Catalog.mutations - 1
Catalog.conveyor = {
	interval = 4.5, capacity = 12, entryAngle = math.pi / 2,
	previewTiers = { 1, 2, 1, 3, 1, 4, 2, 1, 5, 2, 3, 6 },
	weights = { 30, 25, 19, 12, 8, 4, 1.8, .2 },
}
Catalog.zap = { range = 22, cooldown = 3, stun = 1.2, stealCooldown = 6 }
Catalog.meteor = { interval = 90, duration = 20, warning = 2.5, waveInterval = 2,
	perWave = 2, radius = 9, damage = 25, stun = 1, shelterRadius = 9 }
Catalog.solarFlare = { interval = 150, duration = 20, multiplier = 2 }

function Catalog.rollMutation(random)
	local chance, cumulative = random:NextNumber(), 0
	for mutation = #Catalog.mutations, 2, -1 do
		cumulative += Catalog.mutations[mutation].chance
		if chance < cumulative then return mutation end
	end
	return 1
end

Catalog.upgrades = { 240, 620, 1550, 3800, 8000 }
Catalog.utilityUpgrades = {
	Speed = { name = "Flight boots", key = "speedLevel", costs = { 310, 780, 1800, 4200 }, detail = "+2 walking and sprint speed with empty hands per level" },
	Carry = { name = "Cargo harness", key = "carryLevel", costs = { 470, 1200, 2700, 6000 }, detail = "+2 movement speed while carrying per level" },
	Shield = { name = "Bay shield", key = "shieldLevel", costs = { 360, 900, 2100, 4600 }, detail = "+4 seconds of protection per level" },
	Slots = { name = "Extra docks", key = "slotsLevel", costs = { 4000, 12000, 36000, 108000 }, detail = "+1 cargo dock per level" },
}
Catalog.baseSlots = 6
function Catalog.bonusSlots(rebirths)
	return rebirths > 0 and math.min(4, rebirths + 1) or 0
end

function Catalog.slotCount(state)
	return Catalog.baseSlots + (state.slotsLevel or 0) + Catalog.bonusSlots(state.rebirths)
end

Catalog.rebirthMax = 10
Catalog.indexMilestones = { { goal = 10, reward = 300 }, { goal = 20, reward = 1400 }, { goal = 35, reward = 5000 }, { goal = 45, reward = 15000 } }
Catalog.crews = {
	{ name = "Ion Runners", color = Color3.fromRGB(94, 237, 255) },
	{ name = "Solar Union", color = Color3.fromRGB(255, 224, 102) },
	{ name = "Void Scouts", color = Color3.fromRGB(231, 103, 255) },
}
Catalog.skills = {
	Blink = { cooldown = 9, distance = 28, carryDistance = 15 },
	Sprint = { cooldown = 11, duration = 4, speed = 28, carrySpeed = 21 },
}
Catalog.contracts = {
	{ title = "Cargo Shift", kind = "Dock", goal = 3, reward = 180, detail = "Dock 3 brainrots" },
	{ title = "Credit Run", kind = "Collect", goal = 250, reward = 260, detail = "Collect 250 banked credits" },
	{ title = "Rare Delivery", kind = "Dock", minTier = 3, goal = 1, reward = 410, detail = "Dock a Rare or better" },
	{ title = "Rift Defender", kind = "Zap", goal = 2, reward = 220, detail = "Land 2 zaps on rift gremlins" },
	{ title = "Strange Cargo", kind = "Mutation", goal = 2, reward = 600, detail = "Dock 2 mutated brainrots" },
	{ title = "Fresh Orbit", kind = "Rebirth", goal = 1, reward = 1100, detail = "Complete a rebirth" },
}

Catalog.contractTracks = {
	{ title = "Freight", stages = {
		{ kind = "Dock", title = "Dock 3 brainrots", goal = 3, reward = 360 },
		{ kind = "Buy", minTier = 3, title = "Buy 5 Rare or better", goal = 5, reward = 1800 },
		{ kind = "Buy", minTier = 4, title = "Buy 3 Epic or better", goal = 3, reward = 3500 },
		{ kind = "Dock", minTier = 5, title = "Dock 3 Legendary or better", goal = 3, reward = 9000 },
		{ kind = "Buy", minTier = 6, title = "Buy 3 Mythic or better", goal = 3, reward = 22500 },
	} },
	{ title = "Raider", stages = {
		{ kind = "Steal", title = "Dock 2 stolen brainrots", goal = 2, reward = 450 },
		{ kind = "Steal", title = "Dock 5 stolen brainrots", goal = 5, reward = 1500 },
		{ kind = "Steal", minTier = 5, title = "Dock 2 stolen Legendary or better", goal = 2, reward = 6500 },
		{ kind = "Dock", minTier = 4, title = "Dock 6 Epic or better", goal = 6, reward = 7000 },
		{ kind = "Rebirth", title = "Complete a rebirth", goal = 1, reward = 6000 },
	} },
	{ title = "Station Defence", stages = {
		{ kind = "ShelterMeteor", title = "Finish a meteor shower sheltered with cargo", goal = 1, reward = 500 },
		{ kind = "Zap", title = "Land 3 zaps on attackers", goal = 3, reward = 750 },
		{ kind = "ShelterMeteor", minTier = 6, title = "Shelter Mythic cargo through a shower", goal = 1, reward = 6000 },
		{ kind = "Zap", title = "Land 5 zaps on attackers", goal = 5, reward = 1250 },
		{ kind = "ShelterMeteor", minTier = 5, title = "Shelter Legendary cargo through 3 showers", goal = 3, reward = 9000 },
	} },
}

function Catalog.rebirthCost(rebirths)
	return math.floor(6500 * 1.7 ^ rebirths)
end

function Catalog.rebirthTier(rebirths)
	return math.min(7, 3 + math.floor(rebirths / 2))
end

function Catalog.lockDuration(state)
	return 32 + 4 * (state.shieldLevel or 0) + math.min(20, 2 * state.rebirths)
end

function Catalog.discoveryKey(cargo)
	return (cargo.id - 1) * #Catalog.mutations + cargo.mutation
end

function Catalog.discoveryCount(index)
	local namesFound, variantsFound = 0, 0
	for _, entry in ipairs(Catalog.entries) do
		local found = false
		for mutation = 1, #Catalog.mutations do
			if index[Catalog.discoveryKey({ id = entry.id, mutation = mutation })] then
				found = true
				if mutation > 1 then variantsFound += 1 end
			end
		end
		if found then namesFound += 1 end
	end
	return namesFound, variantsFound
end

function Catalog.name(cargo)
	local prefix = Catalog.mutations[cargo.mutation].name
	return (prefix == "" and "" or prefix .. " ") .. Catalog.entries[cargo.id].name
end

function Catalog.price(cargo)
	return Catalog.entries[cargo.id].price * Catalog.mutations[cargo.mutation].factor
end

function Catalog.rate(cargo)
	return Catalog.entries[cargo.id].rate * Catalog.mutations[cargo.mutation].factor
end

function Catalog.incomeFactor(state)
	return 1 + .25 * state.level + .25 * state.rebirths
end

local uniqueNames = {}
assert(#Catalog.entries == 48 and #Catalog.tiers == 8 and Catalog.mutationCount == 6, "Catalog size changed; review save IDs and index rewards")
for _, entry in ipairs(Catalog.entries) do
	assert(not uniqueNames[entry.name], "Duplicate brainrot name: " .. entry.name)
	assert(Catalog.tiers[entry.tier] and entry.price > 0 and entry.rate > 0, "Invalid cargo economy")
	uniqueNames[entry.name] = true
end

return Catalog
