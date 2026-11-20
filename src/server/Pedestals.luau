local Pedestals = {}
local metal = Enum.Material.Metal
local neon = Enum.Material.Neon

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
	return { pad = pad, cf = frame * CFrame.new(0, .82, 0), ring = ring }
end

return Pedestals
