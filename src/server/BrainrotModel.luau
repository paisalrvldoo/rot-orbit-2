local BrainrotModel = {}

local ball, tube = Enum.PartType.Ball, Enum.PartType.Cylinder
local neon = Enum.Material.Neon
local ink = Color3.fromRGB(13, 18, 34)
local ice = Color3.fromRGB(235, 252, 255)
local gold = Color3.fromRGB(255, 213, 81)
local cream = Color3.fromRGB(255, 229, 163)
local leaf = Color3.fromRGB(121, 235, 93)
local jam = Color3.fromRGB(252, 91, 129)
local upright = CFrame.Angles(0, 0, math.pi / 2)

-- Silhouette dimensions are in world axes. Cylinders are turned upright by the builder.
local silhouettes = {
	bean = { 1.8, 2.8, 1.65, ball, -.19 },
	puff = { 2.8, 2.15, 1.9, ball },
	loaf = { 2.6, 2.15, 1.8, nil },
	capsule = { 1.55, 3.04, 1.6, ball, .15 },
	discus = { 2.9, 1.65, 1.95, ball },
	cup = { 2.12, 2.18, 1.82, tube },
	pixel = { 1.95, 2.52, 1.7, nil },
	sub = { 3.06, 1.68, 1.7, ball, -.11 },
}

-- Base catalog names keep a stable design even if entries are reordered.
local designs = {
	["Sprout Sputnik"] = { "bean", "leaves" },
	["Bean Biscotto"] = { "capsule", "chips" },
	["Doodle Dumpling"] = { "puff", "pleats" },
	["Lunar Loaf"] = { "loaf", "crust" },
	["Pico Pickle"] = { "capsule", "bumps" },
	["Crater Crouton"] = { "pixel", "craters" },
	["Puddle Pesto"] = { "discus", "leaves" },
	["Turbo Tofu"] = { "pixel", "thrusters" },
	["Boba Booster"] = { "cup", "straw" },
	["Radar Radish"] = { "bean", "radar" },
	["Bungo Bongo"] = { "cup", "drum" },
	["Pepper Pilot"] = { "capsule", "wings" },
	["Wobble Waffle"] = { "loaf", "grid" },
	["Noodle Nacelle"] = { "sub", "noodles" },
	["Comet Cannoli"] = { "sub", "cream" },
	["Orbit Octato"] = { "puff", "tentacles" },
	["Sushi Shuttle"] = { "discus", "sushi" },
	["Phantom Flan"] = { "cup", "caramel" },
	["Rocket Ravioli"] = { "loaf", "fins" },
	["Disco Durian"] = { "puff", "spikes" },
	["Quasar Quokka"] = { "bean", "ears" },
	["Turbo Truffle"] = { "puff", "thrusters" },
	["Astro Axoloco"] = { "sub", "gills" },
	["Neon Nachonaut"] = { "loaf", "fins" },
	["Mochi Mirage"] = { "discus", "cream" },
	["Captain Calzone"] = { "sub", "pleats" },
	["Pixel Pineapod"] = { "pixel", "leaves" },
	["Robo Rigatoni"] = { "cup", "noodles" },
	["Solar Salamango"] = { "bean", "gills" },
	["Emperor Eggclipse"] = { "bean", "craters" },
	["Gold Guaczilla"] = { "puff", "spikes" },
	["Duke Dango"] = { "capsule", "skewer" },
	["Plasma Panini"] = { "loaf", "grid" },
	["Cosmic Cornado"] = { "capsule", "kernels" },
	["Saturn Sorbet"] = { "cup", "cream" },
	["Void Volcanoli"] = { "puff", "craters" },
	["Omega Omelord"] = { "discus", "fried" },
	["Nova Narwhal"] = { "sub", "horn" },
	["Black Hole Baguette"] = { "sub", "crust" },
	["Zenith Zappuccino"] = { "cup", "straw" },
	["Galactic Gelato"] = { "cup", "scoop" },
	["Oracle Orzo"] = { "bean", "radar" },
	["Infinity Macaron"] = { "discus", "cream" },
	["Nebula Nectaroon"] = { "puff", "wings" },
	["Singularity Saffron"] = { "capsule", "spikes" },
	["Event Horizon Espresso"] = { "cup", "radar" },
	["Forbidden Focaccia"] = { "loaf", "kernels" },
	["Paradox Pistachio"] = { "bean", "horn" },
}

function BrainrotModel.build(entry, rarity, mutation, name, part)
	local design = designs[entry.name] or { "puff", "radar" }
	local spec = silhouettes[design[1]]
	local feature = design[2]
	local rank = rarity.name:upper()
	local accent = mutation.color or rarity.color
	local body = mutation.color and entry.color:Lerp(accent, .42) or entry.color
	local scale = rank == "SECRET" and 1.1 or 1
	local model = Instance.new("Model")
	model.Name = name
	local function piece(id, w, h, d, x, y, z, color, shape, tilt, material)
		local size = Vector3.new(w, h, d)
		if shape == tube then size = Vector3.new(h, w, d) end
		return part(model, id, size * scale, CFrame.new(Vector3.new(x, y, z) * scale)
			* CFrame.Angles(0, 0, tilt or 0) * (shape == tube and upright or CFrame.identity),
			color, material, false, shape)
	end
	local function glow(id, w, h, d, x, y, z, color, shape, tilt)
		return piece(id, w, h, d, x, y, z, color, shape, tilt, neon)
	end
	local anchor = glow("Hover Ring", 3.55, .15, 3.55, 0, .16, 0, accent, tube)
	model.PrimaryPart = anchor
	anchor.PivotOffset = anchor.CFrame:ToObjectSpace(CFrame.identity)
	piece("Hover Plate", 3.23, .12, 3.23, 0, .25, 0, ink, tube)

	local w, h, d, shape, tilt = table.unpack(spec)
	local y = .66 + h / 2
	local top = y + h / 2
	piece("Body", w, h, d, 0, y, 0, body, shape, tilt)
	local faceZ = -d / 2 + .045
	local faceY = y + .13
	piece("Faceplate", 1.43, .73, .38, 0, faceY, faceZ, ink, ball)
	for _, side in ipairs({ -1, 1 }) do
		glow("Eye", .22, .34, .14, side * .31, faceY + .04, faceZ - .16, ice, ball, side * .12)
		piece("Boot", .64, .43, .9, side * w * .23, .52, -.2, ink, ball)
	end
	glow("Mouth", .24, .07, .09, 0, faceY - .15, faceZ - .18, accent, ball)

	if feature == "leaves" or feature == "pleats" or feature == "spikes" then
		for i = -1, 1 do
			local color = feature == "leaves" and leaf or feature == "pleats" and cream or accent
			local lobes = feature == "pleats"
			piece(feature, lobes and .65 or .39, lobes and .4 or .76, .54, i * .43,
				top - math.abs(i) * .13, .12, color, ball, -i * .5)
		end
	elseif feature == "chips" or feature == "bumps" or feature == "craters" or feature == "kernels" then
		for i = 1, 4 do
			local color = feature == "kernels" and gold or body:Lerp(ink, .55)
			local side = i % 2 == 0 and -1 or 1
			piece(feature, .34, .29, .22, side * w * .35, y + ((i - 2.5) * .43), -d * .34, color, ball)
		end
	elseif feature == "crust" or feature == "grid" then
		for i = -1, 1 do
			piece(feature, .23, .16, .83, i * w * .23, top - .07 - math.abs(i) * .09, -.12,
				feature == "grid" and gold or cream, ball, i * .23)
		end
	elseif feature == "thrusters" or feature == "tentacles" or feature == "wings" or feature == "fins"
		or feature == "gills" or feature == "ears" then
		for _, side in ipairs({ -1, 1 }) do
			local high = feature == "ears" or feature == "gills"
			local long = feature == "tentacles" or feature == "thrusters"
			local thrust = feature == "thrusters"
			local x = side * w * (feature == "ears" and .31 or .51)
			local level = high and top - .26 or long and 1.17 or y
			piece(feature, feature == "wings" and 1.03 or .54, long and 1.16 or .84, .64,
				x, level, .14, thrust and ink or accent, thrust and tube or ball, -side * (high and .46 or .81))
			if thrust then
				glow("Exhaust", .37, .43, .37, x + side * .27, .79, .14, accent, ball)
			elseif feature == "tentacles" or feature == "gills" then
				piece(feature, .52, .53, .52, x + side * .27, level - .42, -.29, accent, ball, side * .44)
			end
		end
	elseif feature == "straw" or feature == "radar" or feature == "skewer" or feature == "horn" then
		local x = feature == "straw" and .51 or 0
		piece(feature, feature == "horn" and .31 or .19, .79, .2, x, top + .16, -.13, accent, ball, -.28)
		if feature == "radar" then
			glow("Receiver", .66, .22, .47, x + .08, top + .49, -.13, accent, ball, -.27)
		elseif feature == "straw" or feature == "skewer" then
			piece("Topping", 1.28, .29, 1.22, 0, top - .12, 0, cream, ball)
		end
	elseif feature == "drum" or feature == "caramel" or feature == "fried" or feature == "scoop" then
		local color = feature == "fried" and gold or feature == "caramel" and Color3.fromRGB(139, 70, 33) or cream
		piece(feature, w * .84, feature == "scoop" and .99 or .28, d * .87, 0, top, 0, color, ball)
	elseif feature == "sushi" or feature == "cream" or feature == "noodles" then
		for i = -1, 1 do
			piece(feature, .6, .41, .67, i * w * .26, top - .1 - math.abs(i) * .12, -.12,
				feature == "sushi" and jam or cream, ball, -.23 * i)
		end
	end

	local variant = mutation.name
	if variant == "Ion" or variant == "Supernova" then
		for _, side in ipairs({ -1, 1 }) do
			glow(variant, .41, variant == "Ion" and 1.03 or .62, .49, side * (w / 2 + .18),
				y - .1, .29, accent, ball, side * .4)
		end
	elseif variant == "Gilded" then
		glow("Gilded Medallion", .53, .44, .18, 0, faceY - .5, faceZ, accent, ball)
	elseif variant == "Eclipse" then
		glow("Eclipse Rim", 1.21, 1.21, .18, 0, top + .21, .46, accent, ball)
		piece("Eclipse Shadow", .96, .96, .2, .15, top + .28, .43, ink, ball)
	elseif variant == "Aurora" then
		for i = -1, 1 do
			glow("Aurora Ribbon", .24, .93 - math.abs(i) * .22, .23, i * .67, top - .08, .62,
				accent:Lerp(ice, (i + 1) * .22), ball, -.34)
		end
	elseif variant == "Zero-G" then
		for _, side in ipairs({ -1, 1 }) do
			glow("Orbit Satellite", .31, .31, .31, side * (w / 2 + .29), top - .42 + side * .47,
				.16, accent, ball)
		end
	end

	if rank == "SECRET" then
		piece("Crown Base", 1.6, .24, 1.05, 0, top + .53, 0, gold, tube)
		for i = -1, 1 do
			glow("Crown Point", .33, .59 - math.abs(i) * .13, .33, i * .5, top + .79, -.25,
				i == 0 and ice or gold, ball, -i * .31)
		end
	elseif rank == "COSMIC" or rank == "MYTHIC" or rank == "LEGENDARY" then
		for _, side in ipairs({ -1, 1 }) do
			glow(rank .. " Crest", .24, rank == "LEGENDARY" and .45 or .71, .25, side * .64,
				top + .34, .04, rarity.color, nil, side * .42)
		end
	end
	return model
end

return BrainrotModel
