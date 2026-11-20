local Catalog = {}

Catalog.tiers = {
	{ name = "Common", color = Color3.fromRGB(94, 240, 167), price = 50, rate = 4 },
	{ name = "Uncommon", color = Color3.fromRGB(86, 221, 255), price = 155, rate = 11 },
	{ name = "Rare", color = Color3.fromRGB(123, 145, 255), price = 420, rate = 28 },
	{ name = "Epic", color = Color3.fromRGB(240, 111, 255), price = 1100, rate = 72 },
	{ name = "Legendary", color = Color3.fromRGB(255, 213, 81), price = 3000, rate = 185 },
	{ name = "Mythic", color = Color3.fromRGB(255, 103, 126), price = 8500, rate = 490 },
}

local names = {
	{ "Sprout Sputnik", "Bean Biscotto", "Doodle Dumpling", "Lunar Loaf", "Pico Pickle", "Crater Crouton", "Puddle Pesto" },
	{ "Turbo Tofu", "Boba Booster", "Radar Radish", "Bungo Bongo", "Pepper Pilot", "Wobble Waffle", "Noodle Nacelle" },
	{ "Comet Cannoli", "Orbit Octato", "Sushi Shuttle", "Phantom Flan", "Rocket Ravioli", "Disco Durian", "Quasar Quokka" },
	{ "Turbo Truffle", "Astro Axoloco", "Neon Nachonaut", "Mochi Mirage", "Captain Calzone", "Pixel Pineapod", "Robo Rigatoni" },
	{ "Solar Salamango", "Emperor Eggclipse", "Gold Guaczilla", "Duke Dango", "Plasma Panini", "Cosmic Cornado", "Saturn Sorbet" },
	{ "Void Volcanoli", "Omega Omelord", "Nova Narwhal", "Black Hole Baguette", "Zenith Zappuccino", "Galactic Gelato", "Oracle Orzo" },
}

Catalog.entries = {}
for tier, group in ipairs(names) do
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
	end
end

Catalog.mutations = {
	{ name = "", factor = 1 },
	{ name = "Ion", factor = 2, color = Color3.fromRGB(71, 255, 240) },
	{ name = "Gilded", factor = 3, color = Color3.fromRGB(255, 208, 73) },
	{ name = "Eclipse", factor = 5, color = Color3.fromRGB(231, 103, 255) },
}

Catalog.upgrades = { 240, 620, 1550, 3800, 8000 }
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
