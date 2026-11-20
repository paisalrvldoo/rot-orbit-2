local Catalog = require(game:GetService("ReplicatedStorage"):WaitForChild("Orbit"):WaitForChild("Catalog"))
local Backdrop = require(script.Parent.OrbitBackdrop)
local BrainrotModel = require(script.Parent.BrainrotModel)
local BillboardLabels = require(script.Parent.BillboardLabels)
local Pedestals = require(script.Parent.Pedestals)
local StationEffects = require(script.Parent.StationEffects)

local World = {
	cyan = Color3.fromRGB(42, 236, 255),
	gold = Color3.fromRGB(255, 221, 81),
	pink = Color3.fromRGB(248, 70, 213),
	dark = Color3.fromRGB(20, 27, 49),
	radius = 32,
}
local cyan, gold, pink, dark = World.cyan, World.gold, World.pink, World.dark
local ink = Color3.fromRGB(9, 13, 27)
local ice = Color3.fromRGB(226, 252, 255)
local neon = Enum.Material.Neon

function World.part(parent, name, size, cf, color, material, collide, shape)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cf
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.CanCollide = collide == true
	part.CanTouch = false
	part.CanQuery = part.CanCollide
	part.CastShadow = part.CanCollide
	if shape then part.Shape = shape end
	part.Parent = parent
	return part
end

local function cylinder(parent, name, position, diameter, height, color, material, collide)
	return World.part(parent, name, Vector3.new(height, diameter, diameter),
		CFrame.new(position) * CFrame.Angles(0, 0, math.pi / 2), color, material, collide, Enum.PartType.Cylinder)
end

function World.flash(position, color, size)
	local pulse = World.part(World.root, "Pulse", Vector3.one * size, CFrame.new(position),
		color, neon, false, Enum.PartType.Ball)
	pulse.Transparency = .45
	game:GetService("Debris"):AddItem(pulse, .18)
end

local function bar(parent, a, b, width, color, material, collide)
	local distance = (b - a).Magnitude
	return World.part(parent, "Beam", Vector3.new(width, width, distance + .04),
		CFrame.lookAt((a + b) / 2, b), color, material, collide)
end

local function ring(parent, center, u, v, radius, count, width, color, material, collide, sweep, start)
	sweep, start = sweep or math.pi * 2, start or 0
	for i = 0, count - 1 do
		local a, b = start + i * sweep / count, start + (i + 1) * sweep / count
		local function point(angle)
			return center + radius * (u * math.cos(angle) + v * math.sin(angle))
		end
		bar(parent, point(a), point(b), width, color, material, collide)
	end
end

function World.billboard(part, words, color, width, height, offset, distance)
	local card = part:FindFirstChild("CargoCard")
	if card and words:find("/s", 1, true) then return BillboardLabels.offer(card) end
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(width, height)
	gui.StudsOffsetWorldSpace = Vector3.new(0, offset, 0)
	gui.MaxDistance = distance or 38
	gui.Adornee = part
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.Text = words
	label.TextColor3 = color
	label.TextStrokeColor3 = ink
	label.TextStrokeTransparency = .18
	label.Parent = gui
	return label
end

local function sign(parent, cf, width, height, words, accent)
	local panel = World.part(parent, words, Vector3.new(width, height, .5), cf, ink)
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.LightInfluence = 0
		gui.CanvasSize = Vector2.new(width * 32, height * 32)
		gui.Parent = panel
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(.92, .77)
		label.Position = UDim2.fromScale(.04, .08)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBlack
		label.TextColor3 = accent
		label.TextScaled = true
		label.Text = words
		label.TextStrokeColor3 = ink
		label.TextStrokeTransparency = .22
		label.Parent = gui
	end
	for _, y in ipairs({ -height / 2, height / 2 }) do
		World.part(parent, "Sign Trim", Vector3.new(width, .12, .62), cf * CFrame.new(0, y, 0), accent, neon)
	end
	return panel
end

function World.prompt(part, action, object, key, hold, distance)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = action
	prompt.ObjectText = object
	prompt.KeyboardKeyCode = key or Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.HoldDuration = hold or .18
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = distance or 9
	prompt.Parent = part
	if part:GetAttribute("SlotIndex") then Pedestals.bindPrompt(part, prompt) end
	return prompt
end

function World.build()
	local root = Instance.new("Folder")
	root.Name = "RotOrbitStation"
	root.Parent = workspace
	World.root = root
	local grade = Backdrop.build(root, World.part, ring, cyan, gold, pink, ice)

	cylinder(root, "Station Deck", Vector3.new(0, -1.2, 0), 156, 2.4, ink, Enum.Material.Metal, true)
	cylinder(root, "Hull", Vector3.new(0, -4.2, 0), 151, 3, dark, Enum.Material.Metal)
	cylinder(root, "Reactor Platform", Vector3.new(0, -.1, 0), 21, .4, dark)
	cylinder(root, "Reactor Well", Vector3.new(0, .14, 0), 11, .17, Color3.fromRGB(15, 97, 121), neon)
	local reactor = cylinder(root, "Reactor Core", Vector3.new(0, .24, 0), 3.4, .1, cyan, neon)
	World.meteor, World.solarFlare = StationEffects.bind(root, World.part, reactor, grade)
	ring(root, Vector3.new(0, 1.08, 0), Vector3.xAxis, Vector3.zAxis, 77, 40, .9, dark, nil, true)
	ring(root, Vector3.new(0, 1.7, 0), Vector3.xAxis, Vector3.zAxis, 77, 40, .17, cyan, neon)
	for i = 0, 11 do
		local angle = i * math.pi / 6
		local position = Vector3.new(math.cos(angle) * 77, 1.4, math.sin(angle) * 77)
		World.part(root, "Orbit Rail Post", Vector3.new(.2, 2.8, .2), CFrame.new(position), dark, Enum.Material.Metal)
		World.part(root, "Rail Marker", Vector3.new(.3, .28, .3), CFrame.new(position + Vector3.new(0, 1.28, 0)),
			i % 3 == 0 and gold or cyan, neon)
	end
	-- Layered disks give the inner road edge a continuous curve with three parts.
	cylinder(root, "Market Annulus", Vector3.new(0, .01, 0), 70.9, .05, dark, Enum.Material.Metal)
	cylinder(root, "Inner Market Rail", Vector3.new(0, .04, 0), 57.6, .04, cyan, neon)
	cylinder(root, "Reactor Concourse", Vector3.new(0, .065, 0), 56.45, .03, ink, Enum.Material.Metal)
	for i, color in ipairs({ ice, cyan, pink, cyan, ice, gold, cyan, gold }) do
		ring(root, Vector3.new(0, .11, 0), Vector3.xAxis, Vector3.zAxis, 35.3, 8, .38,
			color, neon, false, math.pi / 4, (i - 1) * math.pi / 4)
	end
	for i = 0, 19 do
		local angle = i * math.pi / 10
		local axis = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local y = Vector3.new(0, .10, 0)
		bar(root, axis * 12 + y, axis * 25.5 + y, .075, i % 3 == 0 and pink or cyan, neon)
		bar(root, axis * 36.8 + y, axis * 43 + y, .10, i % 3 == 0 and gold or cyan, neon)
	end
	for _, x in ipairs({ -17.1, 17.1 }) do
		World.part(root, "Marquee Support", Vector3.new(.55, 12.5, .75), CFrame.new(x, 6.25, -5), cyan, Enum.Material.Metal)
		World.part(root, "Marquee Beacon", Vector3.new(.9, .65, .9), CFrame.new(x, 12.7, -5), ice, neon)
	end
	local marquee = CFrame.new(0, 9.05, -5) * CFrame.Angles(math.rad(-13), 0, 0)
	sign(root, marquee, 34, 5.8, "ROT ORBIT", ice)
	World.part(root, "Marquee Gold Crown", Vector3.new(35, .22, .8), marquee * CFrame.new(0, 3.1, 0), gold, neon)
	World.part(root, "Marquee Cyan Sill", Vector3.new(35, .22, .8), marquee * CFrame.new(0, -3.1, 0), cyan, neon)

	local bays = {}
	for i = 1, 6 do
		local angle = (i - 1) * math.pi / 3 + math.pi / 2
		local backward = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local center = backward * 56
		local pivot = CFrame.lookAt(center, center - backward)
		local accent = i % 3 == 0 and gold or cyan
		World.part(root, "Bay Deck", Vector3.new(27, .45, 19), pivot * CFrame.new(0, .19, 0), dark, Enum.Material.Metal, true)
		for _, x in ipairs({ -13.2, 13.2 }) do
			World.part(root, "Bay Stripe", Vector3.new(.18, .13, 19), pivot * CFrame.new(x, .47, 0), accent, neon)
			World.part(root, "Bay Pylon", Vector3.new(.45, 5, .45), pivot * CFrame.new(x, 2.7, 9), accent, Enum.Material.Metal)
		end
		for _, z in ipairs({ -9.35, 9.35 }) do
			World.part(root, "Bay Threshold", Vector3.new(27, .13, .18), pivot * CFrame.new(0, .47, z), accent, neon)
		end
		local header = sign(root, pivot * CFrame.new(0, 5.2, 9), 27, 2.1, "BAY " .. i .. "  /  VACANT", accent)
		local bay = { header = header, slots = {}, spawn = pivot * CFrame.new(0, 3.5, -12), center = center }
		local ramp = World.part(root, "Bay Access Ramp", Vector3.new(13, .42, 10),
			pivot * CFrame.new(0, .16, -15) * CFrame.Angles(-.04, 0, 0), dark, Enum.Material.Metal, true)
		ramp.TopSurface = Enum.SurfaceType.Smooth
		for _, x in ipairs({ -6.2, 6.2 }) do
			World.part(root, "Ramp Light", Vector3.new(.12, .08, 9.8),
				pivot * CFrame.new(x, .4, -15) * CFrame.Angles(-.04, 0, 0), accent, neon)
		end
		for slot = 1, 6 do
			local x = ((slot - 1) % 3 - 1) * 7.7
			local z = slot <= 3 and -2.5 or 5
			bay.slots[slot] = Pedestals.build(root, pivot * CFrame.new(x, .415, z), slot, accent,
				World.part, cylinder, World.billboard)
		end
		local bank = World.part(root, "Credit Terminal", Vector3.new(2.6, 2.5, 1.6), pivot * CFrame.new(-8.5, 1.55, -7.7), dark)
		World.part(root, "Terminal Screen", Vector3.new(2.1, .87, .13), pivot * CFrame.new(-8.5, 2.1, -8.55), accent, neon)
		bay.bank = bank
		World.billboard(bank, "COLLECT", gold, 98, 21, 1.8, 24)
		bay.lock = World.part(root, "Lock Terminal", Vector3.new(2.6, 2.5, 1.6), pivot * CFrame.new(8.5, 1.55, -7.7), dark)
		bay.lockLabel = World.billboard(bay.lock, "BAY OPEN", cyan, 105, 20, 1.8, 24)
		bays[i] = bay
	end
	for _, x in ipairs({ -43, 43 }) do
		local center = Vector3.new(x, 6.2, 0)
		local portalColor = x < 0 and cyan or pink
		cylinder(root, "Portal Landing", Vector3.new(x, .18, 0), 14, .36, dark, Enum.Material.Metal, true)
		cylinder(root, "Portal Landing Trim", Vector3.new(x, .4, 0), 13.2, .08, portalColor, neon)
		ring(root, center, Vector3.zAxis, Vector3.yAxis, 6, 24, .27, portalColor, neon)
		ring(root, center, Vector3.zAxis, Vector3.yAxis, 6.45, 24, .15, x < 0 and gold or ice, neon)
	end
	World.portal = Vector3.new(43, .42, 0)
	local gate = World.part(root, "Rift Beacon", Vector3.new(2, .35, 2), CFrame.new(World.portal), pink, neon)
	World.billboard(gate, "GREMLIN RIFT", gold, 145, 23, 6.5, 46)
	return bays
end

function World.title(bay, name)
	for _, gui in ipairs(bay.header:GetChildren()) do
		gui.TextLabel.Text = name
	end
end

function World.figure(cargo, parent)
	local entry = Catalog.entries[cargo.id]
	local rarity = Catalog.tiers[entry.tier]
	local mutation = Catalog.mutations[cargo.mutation]
	local model = BrainrotModel.build(entry, rarity, mutation, Catalog.name(cargo), World.part)
	BillboardLabels.cargo(model, rarity, Catalog.rate(cargo), Catalog.price(cargo))
	model.Parent = parent
	return model
end

function World.gremlin()
	local model = Instance.new("Model")
	model.Name = "Rift Gremlin"
	local body = World.part(model, "Body", Vector3.new(2.4, 2.5, 2.15), CFrame.new(0, 1.5, 0),
		Color3.fromRGB(122, 211, 70), nil, false, Enum.PartType.Ball)
	model.PrimaryPart = body
	body.PivotOffset = body.CFrame:ToObjectSpace(CFrame.identity)
	for _, x in ipairs({ -.64, .64 }) do
		World.part(model, "Ear", Vector3.new(.58, 1.32, .54), CFrame.new(x * 1.48, 2.47, 0)
			* CFrame.Angles(0, 0, x * -.6), pink)
		World.part(model, "Eye", Vector3.new(.41, .5, .22), CFrame.new(x, 1.95, -.94), gold, neon)
		World.part(model, "Claw", Vector3.new(.45, .55, .8), CFrame.new(x * 2, .74, -.34), ice)
	end
	World.billboard(body, "RIFT GREMLIN", pink, 130, 22, 2.1, 66)
	model:PivotTo(CFrame.new(World.portal))
	model.Parent = World.root
	return model
end

return World
