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
	biscuit = { 2.12, 2.66, .96, ball, .12 },
	puff = { 2.8, 2.15, 1.9, ball },
	loaf = { 2.6, 2.15, 1.8, nil },
	capsule = { 1.55, 3.04, 1.6, ball, .15 },
	discus = { 2.9, 1.65, 1.95, ball },
	cup = { 2.12, 2.18, 1.82, tube },
	pixel = { 1.95, 2.52, 1.7, nil },
	sub = { 3.06, 1.68, 1.7, ball, -.11 },
	nacho = { 2.8, 2.1, 1.15, "WedgePart", -.16 },
}
local fallbackShapes = { "bean", "biscuit", "puff", "loaf", "capsule", "cup", "sub" }
local fallbackFeatures = { "leaves", "chips", "pleats", "crust", "bumps", "coffee", "fins" }

-- Base catalog names keep a stable design even if entries are reordered.
local designs = {
	["Sprout Sputnik"] = { "bean", "leaves" },
	["Bean Biscotto"] = { "biscuit", "chips" },
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
	["Neon Nachonaut"] = { "nacho", "cheese" },
	["Mochi Mirage"] = { "discus", "cream" },
	["Captain Calzone"] = { "sub", "fold" },
	["Pixel Pineapod"] = { "pixel", "leaves" },
	["Robo Rigatoni"] = { "cup", "noodles" },
	["Solar Salamango"] = { "bean", "gills" },
	["Emperor Eggclipse"] = { "bean", "craters" },
	["Gold Guaczilla"] = { "puff", "spikes" },
	["Duke Dango"] = { "capsule", "skewer" },
	["Plasma Panini"] = { "loaf", "grid" },
	["Cosmic Cornado"] = { "capsule", "kernels" },
	["Saturn Sorbet"] = { "cup", "sorbet" },
	["Void Volcanoli"] = { "puff", "craters" },
	["Omega Omelord"] = { "discus", "fried" },
	["Nova Narwhal"] = { "sub", "horn" },
	["Black Hole Baguette"] = { "sub", "crust" },
	["Zenith Zappuccino"] = { "cup", "coffee" },
	["Galactic Gelato"] = { "cup", "scoop" },
	["Oracle Orzo"] = { "bean", "oracle" },
	["Infinity Macaron"] = { "discus", "macaron" },
	["Nebula Nectaroon"] = { "puff", "wings" },
	["Singularity Saffron"] = { "capsule", "spikes" },
	["Event Horizon Espresso"] = { "cup", "blackhole" },
	["Forbidden Focaccia"] = { "loaf", "kernels" },
	["Paradox Pistachio"] = { "bean", "horn" },
}

function BrainrotModel.build(entry, rarity, mutation, name, part)
	local fallback = ((entry.shape or entry.id or 1) - 1) % #fallbackShapes + 1
	local design = designs[entry.name] or { fallbackShapes[fallback], fallbackFeatures[fallback] }
	local spec = silhouettes[design[1]]
	local feature = design[2]
	local rank = rarity.name:upper()
	local accent = mutation.color or rarity.color
	local body = mutation.color and entry.color:Lerp(accent, .42) or entry.color
	local scale = rank == "SECRET" and 1.1 or 1
	local model = Instance.new("Model")
	model.Name = name
	model:SetAttribute("BrainrotId", entry.id)
	model:SetAttribute("Rarity", rank)
	model:SetAttribute("RarityColor", rarity.color)
	model:SetAttribute("Mutation", mutation.name)
	model:SetAttribute("SocketColor", accent)
	local function piece(id, w, h, d, x, y, z, color, shape, tilt, material)
		local size = Vector3.new(w, h, d)
		if shape == tube then size = Vector3.new(h, w, d) end
		local className
		if shape == "WedgePart" then className, shape = shape, nil end
		return part(model, id, size * scale, CFrame.new(Vector3.new(x, y, z) * scale)
			* CFrame.Angles(0, 0, tilt or 0) * (shape == tube and upright or CFrame.identity),
			color, material, false, shape, className)
	end
	local function glow(id, w, h, d, x, y, z, color, shape, tilt)
		return piece(id, w, h, d, x, y, z, color, shape, tilt, neon)
	end
	local anchor = glow("Hover Ring", 3.55, .15, 3.55, 0, .16, 0, accent, tube)
	model.PrimaryPart = anchor
	anchor.PivotOffset = anchor.CFrame:ToObjectSpace(CFrame.identity)
	piece("Hover Plate", 3.23, .12, 3.23, 0, .25, 0, ink, tube)
	-- Two curved beams form a charm without adding a ring of replicated parts.
	local function orbitCharm(radius, height, color, tilt)
		local frame = CFrame.new(0, height * scale, 0) * CFrame.Angles(tilt or .2, 0, .16)
		local ends = {}
		for _, side in ipairs({ -1, 1 }) do
			local attachment = Instance.new("Attachment")
			attachment.Name = "OrbitCharmMount"
			attachment.CFrame = anchor.CFrame:ToObjectSpace(frame * CFrame.new(side * radius * scale, 0, 0)
				* CFrame.Angles(0, side * math.pi / 2, 0))
			attachment.Parent = anchor
			table.insert(ends, attachment)
		end
		for _, side in ipairs({ -1, 1 }) do
			local charm = Instance.new("Beam")
			charm.Name = "OrbitCharm"
			charm.Attachment0, charm.Attachment1 = ends[1], ends[2]
			charm.CurveSize0, charm.CurveSize1 = side * radius * scale * 4 / 3, side * radius * scale * 4 / 3
			charm.Width0, charm.Width1 = .09 * scale, .09 * scale
			charm.Segments = 10
			charm.FaceCamera = true
			charm.LightEmission = 1
			charm.Color = ColorSequence.new(color)
			charm.Transparency = NumberSequence.new(.12)
			charm.Parent = anchor
		end
	end

	local w, h, d, shape, tilt = table.unpack(spec)
	local y = .66 + h / 2
	local top = y + h / 2
	if feature == "macaron" then
		piece("Lower Macaron", w, .7, d, 0, y - .49, 0, body, ball)
		piece("Macaron Filling", w * .92, .29, d * .94, 0, y, 0, cream, tube)
		piece("Upper Macaron", w, .7, d, 0, y + .49, 0, body, ball)
	else
		piece("Body", w, h, d, 0, y, 0, body, shape, tilt)
	end
	local faceZ = -d / 2 + .045
	local faceY = y + .13
	local expression = (entry.id or entry.shape or 1) % 5
	piece("Faceplate", 1.53, .85, .38, 0, faceY, faceZ, ink, ball)
	for _, side in ipairs({ -1, 1 }) do
		local wink = expression == 2 and side == -1
		local eyeY = faceY + .08 + (expression == 0 and side == -1 and .06 or 0)
		piece("Eye White", .43, wink and .12 or .46, .16, side * .34, eyeY, faceZ - .16, ice, ball)
		piece("Pupil", .18, wink and .07 or .26, .1, side * .34 + (expression == 1 and -.07 or .035),
			eyeY, faceZ - .25, ink, ball)
		piece("Boot", .64, .43, .9, side * w * .23, .52, -.2, ink, ball)
	end
	glow("Mouth", expression == 0 and .2 or .45, expression == 0 and .26 or .09, .09,
		0, faceY - .22, faceZ - .18, accent, ball, expression == 2 and .14 or 0)
	if expression == 3 or expression == 4 then
		piece(expression == 3 and "Tongue" or "Goofy Tooth", .2, .16, .1, .09, faceY - .27,
			faceZ - .22, expression == 3 and jam or ice, ball)
	end

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
	elseif feature == "crust" or feature == "grid" or feature == "fold" then
		for i = -1, 1 do
			piece(feature, .23, .16, .83, i * w * .23, top - .07 - math.abs(i) * .09, -.12,
				feature == "grid" and gold or cream, ball, i * .23)
		end
		if feature == "grid" then
			for _, z in ipairs({ -.4, .31 }) do
				piece("Waffle Grid", w * .76, .13, .16, 0, top - .08, z, gold)
			end
		elseif feature == "fold" then
			piece("Calzone Seam", w * .88, .2, .17, 0, top - .3, -d * .28, cream, ball)
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
	elseif feature == "straw" or feature == "radar" or feature == "skewer" or feature == "horn"
		or feature == "oracle" then
		local x = feature == "straw" and .51 or 0
		piece(feature, feature == "horn" and .43 or .19, feature == "horn" and 1.04 or .79, .25,
			x, top + .16, -.13, accent, feature == "horn" and "WedgePart" or ball, -.28)
		if feature == "radar" then
			glow("Receiver", .66, .22, .47, x + .08, top + .49, -.13, accent, ball, -.27)
		elseif feature == "straw" or feature == "skewer" then
			piece("Topping", 1.28, .29, 1.22, 0, top - .12, 0, cream, ball)
			if feature == "straw" then
				for i = -1, 1 do
					piece("Boba Pearl", .31, .31, .18, i * .42, y - .63, -d / 2, ink, ball)
				end
			end
		elseif feature == "oracle" then
			piece("Oracle Eye", .83, .5, .22, 0, top + .5, -.16, ice, ball)
			glow("Oracle Iris", .22, .31, .12, 0, top + .5, -.29, accent, ball)
		end
	elseif feature == "drum" or feature == "caramel" or feature == "fried" or feature == "scoop"
		or feature == "sorbet" then
		local color = feature == "fried" and gold or feature == "caramel" and Color3.fromRGB(139, 70, 33) or cream
		piece(feature, w * .84, (feature == "scoop" or feature == "sorbet") and .99 or .28, d * .87,
			0, top, 0, color, ball)
		if feature == "sorbet" then
			orbitCharm(1.52, top + .14, accent, .36)
		elseif feature == "drum" then
			for _, side in ipairs({ -1, 1 }) do
				piece("Drumstick", .14, .82, .14, side * .81, top + .35, .12, cream, nil, side * .62)
			end
		end
	elseif feature == "sushi" then
		piece("Seaweed Belt", w * .91, h * .49, d * 1.01, 0, y, .08, ink, tube)
		piece("Salmon", w * .64, .39, d * .77, 0, top - .06, -.08, jam, ball)
		for _, side in ipairs({ -1, 1 }) do
			piece("Salmon Stripe", .15, .41, d * .68, side * .4, top - .04, -.09, cream, ball, -.18)
		end
	elseif feature == "coffee" or feature == "blackhole" then
		piece("Cup Rim", w * 1.06, .16, d * 1.05, 0, top - .03, 0, cream, tube)
		piece("Espresso", w * .88, .17, d * .87, 0, top + .01, 0, ink, tube)
		for i = -1, 1 do
			piece("Cup Handle", .38, .65, .39, w / 2 + .44 + (i == 0 and .19 or 0),
				y + i * .44, .16, body, ball, i * .5)
		end
		if feature == "blackhole" then orbitCharm(1.15, top + .47, gold, -.18) end
	elseif feature == "cheese" then
		piece("Cheese Melt", w * .81, .22, d * .88, 0, top - .4, 0, gold, ball, -.16)
		for _, side in ipairs({ -1, 1 }) do
			piece("Nacho Chip", .81, 1.1, .49, side * w * .49, y - .15, .12, body,
				"WedgePart", -side * .52)
		end
	elseif feature == "cream" or feature == "noodles" then
		for i = -1, 1 do
			piece(feature, .6, .41, .67, i * w * .26, top - .1 - math.abs(i) * .12, -.12,
				cream, ball, -.23 * i)
		end
	end

	local variant = mutation.name
	if variant == "Ion" then
		for _, side in ipairs({ -1, 1 }) do
			glow("Ion Fin", .41, 1.03, .49, side * (w / 2 + .18), y - .1, .29, accent,
				"WedgePart", side * .4)
		end
	elseif variant == "Supernova" then
		for i = -1, 1 do
			glow("Supernova Ray", .4, 1.55, .32, i * w * .46, top - .22 - math.abs(i) * .55,
				.81, accent:Lerp(gold, math.abs(i) * .35), "WedgePart", -i * .68)
		end
	elseif variant == "Gilded" then
		glow("Gilded Medallion", .53, .44, .18, 0, faceY - .5, faceZ, accent, ball)
		for _, side in ipairs({ -1, 1 }) do
			piece("Gilded Shoulder", .52, .45, .63, side * w * .46, y + .22, .1, accent, ball,
				-side * .22, Enum.Material.Metal)
		end
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
		orbitCharm(w / 2 + .33, top - .38, accent, -.28)
	end

	if rank == "SECRET" then
		piece("Royal Cape", w * .92, h * .9, .22, 0, y - .08, d / 2 + .16,
			Color3.fromRGB(93, 26, 132), "WedgePart", .06)
		piece("Crown Base", 1.6, .24, 1.05, 0, top + .53, 0, gold, tube)
		for i = -1, 1 do
			glow("Crown Point", .33, .59 - math.abs(i) * .13, .33, i * .5, top + .79, -.25,
				i == 0 and ice or gold, "WedgePart", -i * .31)
		end
		orbitCharm(1.23, top + .53, gold, 0)
	elseif rank == "COSMIC" then
		orbitCharm(1.38, top + .24, rarity.color, -.25)
		glow("Cosmic Star", .37, .62, .21, 0, top + .26, -.28, ice, "WedgePart", .36)
	elseif rank == "MYTHIC" or rank == "LEGENDARY" then
		for _, side in ipairs({ -1, 1 }) do
			glow(rank .. " Crest", .24, rank == "LEGENDARY" and .45 or .71, .25, side * .64,
				top + .34, .04, rarity.color, rank == "MYTHIC" and "WedgePart" or nil, side * .42)
		end
	end
	return model
end

return BrainrotModel
