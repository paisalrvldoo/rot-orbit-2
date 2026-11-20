local BillboardLabels = require(script.Parent.BillboardLabels)
local Pedestals = {}
local metal = Enum.Material.Metal
local neon = Enum.Material.Neon
local slots = setmetatable({}, { __mode = "k" })

function Pedestals.build(parent, frame, index, accent, part, cylinder)
	local center = frame.Position
	local dark = Color3.fromRGB(20, 27, 49)
	local ink = Color3.fromRGB(9, 13, 27)
	cylinder(parent, "Pedestal Foot", center + Vector3.yAxis * .12, 4.7, .25, ink, metal)
	cylinder(parent, "Pedestal Stem", center + Vector3.yAxis * .4, 3.2, .55, dark, metal)
	local ring = cylinder(parent, "Socket Glow", center + Vector3.yAxis * .66, 4.62, .12, accent, neon)
	local pad = cylinder(parent, "Dock " .. index, center + Vector3.yAxis * .74, 4.3, .16, ink, metal, true)
	pad:SetAttribute("SlotIndex", index)
	part(parent, "Dock Stripe", Vector3.new(1.35, .06, .17), frame * CFrame.new(0, .81, -1.78),
		accent, neon)
	local readout = BillboardLabels.pedestal(pad, index, accent)
	local foot, tip = Instance.new("Attachment"), Instance.new("Attachment")
	foot.CFrame = pad.CFrame:ToObjectSpace(frame * CFrame.new(0, .81, 0))
	tip.CFrame = pad.CFrame:ToObjectSpace(frame * CFrame.new(0, 2.4, 0))
	foot.Parent, tip.Parent = pad, pad
	local aura = Instance.new("Beam")
	aura.Name = "SocketAura"
	aura.Attachment0, aura.Attachment1 = foot, tip
	aura.Width0, aura.Width1 = 4.3, .5
	aura.FaceCamera = true
	aura.LightEmission = .8
	aura.Segments = 1
	aura.Transparency = NumberSequence.new(.9, 1)
	aura.Enabled = false
	aura.Parent = pad
	local slot = { pad = pad, cf = frame * CFrame.new(0, .82, 0), ring = ring, emptyColor = accent,
		readout = readout, aura = aura }
	slots[pad] = slot
	return slot
end

function Pedestals.bindPrompt(pad, prompt)
	local readout = pad:FindFirstChild("SlotReadout")
	if not readout then return end
	local slot = slots[pad]
	local function refresh()
		if not pad.Parent or not prompt.Parent then return end
		local cargo = slot and slot.cargo
		local model = cargo and cargo.model
		if slot then
			if slot.visualCargo and slot.visualCargo ~= model then BillboardLabels.docked(slot.visualCargo, false, pad) end
			slot.visualCargo = model
			slot.ring.Color = model and model:GetAttribute("SocketColor") or slot.emptyColor
			local rank = model and model:GetAttribute("Rarity")
			slot.aura.Enabled = rank == "LEGENDARY" or rank == "MYTHIC" or rank == "COSMIC" or rank == "SECRET"
			slot.aura.Color = ColorSequence.new(slot.ring.Color)
			BillboardLabels.slot(readout, model, prompt.Enabled and "EMPTY" or "RESERVED", slot.emptyColor)
			if model then BillboardLabels.docked(model, true, pad) end
		end
	end
	-- ObjectText also changes when one occupied slot receives a different cargo.
	prompt:GetAttributeChangedSignal("Occupied"):Connect(function() task.defer(refresh) end)
	prompt:GetPropertyChangedSignal("Enabled"):Connect(function() task.defer(refresh) end)
	prompt:GetPropertyChangedSignal("ObjectText"):Connect(function() task.defer(refresh) end)
	refresh()
end

return Pedestals
