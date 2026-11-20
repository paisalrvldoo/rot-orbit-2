local Catalog = {}

Catalog.tiers = {
	{ name = "Common", color = Color3.fromRGB(94, 240, 167), price = 50, rate = 4 },
	{ name = "Uncommon", color = Color3.fromRGB(86, 221, 255), price = 155, rate = 11 },
	{ name = "Rare", color = Color3.fromRGB(123, 145, 255), price = 420, rate = 28 },
	{ name = "Epic", color = Color3.fromRGB(240, 111, 255), price = 1100, rate = 72 },
	{ name = "Legendary", color = Color3.fromRGB(255, 213, 81), price = 3000, rate = 185 },
	{ name = "Mythic", color = Color3.fromRGB(255, 103, 126), price = 8500, rate = 490 },
	{ name = "Cosmic", color = Color3.fromRGB(170, 255, 233), price = 24000, rate = 1350 },
}

local names = {
	{ "Sprout Sputnik", "Bean Biscotto", "Doodle Dumpling", "Lunar Loaf", "Pico Pickle", "Crater Crouton", "Puddle Pesto" },
	{ "Turbo Tofu", "Boba Booster", "Radar Radish", "Bungo Bongo", "Pepper Pilot", "Wobble Waffle", "Noodle Nacelle" },
	{ "Comet Cannoli", "Orbit Octato", "Sushi Shuttle", "Phantom Flan", "Rocket Ravioli", "Disco Durian", "Quasar Quokka" },
	{ "Turbo Truffle", "Astro Axoloco", "Neon Nachonaut", "Mochi Mirage", "Captain Calzone", "Pixel Pineapod", "Robo Rigatoni" },
	{ "Solar Salamango", "Emperor Eggclipse", "Gold Guaczilla", "Duke Dango", "Plasma Panini", "Cosmic Cornado", "Saturn Sorbet" },
	{ "Void Volcanoli", "Omega Omelord", "Nova Narwhal", "Black Hole Baguette", "Zenith Zappuccino", "Galactic Gelato", "Oracle Orzo" },
	{ "Infinity Macaron", "Nebula Nectaroon", "Singularity Saffron" },
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

function Catalog.rollMutation(random)
	local chance, cumulative = random:NextNumber(), 0
	for mutation = #Catalog.mutations, 2, -1 do
		cumulative += Catalog.mutations[mutation].chance
		if chance < cumulative then return mutation end
	end
	return 1
end

Catalog.upgrades = { 240, 620, 1550, 3800, 8000 }
Catalog.crews = {
	{ name = "Ion Runners", color = Color3.fromRGB(94, 237, 255) },
	{ name = "Solar Union", color = Color3.fromRGB(255, 224, 102) },
	{ name = "Void Scouts", color = Color3.fromRGB(231, 103, 255) },
}
Catalog.contracts = {
	{ title = "Cargo Shift", goal = 3, reward = 180, detail = "Dock 3 brainrots" },
	{ title = "Credit Run", goal = 250, reward = 260, detail = "Collect 250 banked credits" },
	{ title = "Rare Delivery", goal = 1, reward = 410, detail = "Dock a Rare or better" },
}

function Catalog.rebirthCost(rebirths)
	return 6500 + 3500 * rebirths
end

function Catalog.discoveryKey(cargo)
	return (cargo.id - 1) * #Catalog.mutations + cargo.mutation
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

return Catalog
