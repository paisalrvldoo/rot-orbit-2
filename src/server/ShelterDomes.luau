local ShelterDomes = {}
local mint = Color3.fromRGB(126, 255, 211)
local dark = Color3.fromRGB(9, 13, 27)

function ShelterDomes.build(parent, part, cylinder, billboard, reactorRadius)
	local shelters = {}
	for index, position in ipairs({ Vector3.zero, Vector3.new(-43, 0, 0), Vector3.new(43, 0, 0) }) do
		local radius = index == 1 and reactorRadius or 6
		local frame = CFrame.new(position + Vector3.yAxis * .14)
		local dome = part(parent, "Meteor Shelter Dome", Vector3.one * radius * 2,
			frame, mint, Enum.Material.ForceField, false, Enum.PartType.Ball)
		dome.Transparency = .88
		dome:SetAttribute("ShelterRadius", radius)
		-- The deck hides the lower hemisphere. Two disks mark the exact safe radius.
		local edge = cylinder(parent, "Shelter Boundary", position + Vector3.yAxis * .11,
			radius * 2, .06, mint, Enum.Material.Neon)
		local inset = cylinder(parent, "Shelter Floor", position + Vector3.yAxis * .15,
			radius * 2 - .24, .04, dark, Enum.Material.Metal)
		-- Portal landings are taller than the reactor floor.
		if index > 1 then
			edge.Position += Vector3.yAxis * .36
			inset.Position += Vector3.yAxis * .36
		end
		local label = billboard(dome, "METEOR SHELTER", mint, 148, 20, 3.3, 26)
		table.insert(shelters, { Center = position, Radius = radius, Part = dome,
			Boundary = edge, Label = label.Parent, Color = mint })
	end
	return shelters
end

return ShelterDomes
