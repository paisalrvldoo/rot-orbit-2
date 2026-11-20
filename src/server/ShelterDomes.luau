local ShelterDomes = {}
local mint = Color3.fromRGB(126, 255, 211)
local dark = Color3.fromRGB(9, 13, 27)
local solarGold = Color3.fromRGB(255, 219, 145)

function ShelterDomes.build(parent, part, cylinder, billboard, reactorRadius)
	local shelters = {}
	for index, position in ipairs({ Vector3.zero, Vector3.new(-43, 0, 0), Vector3.new(43, 0, 0) }) do
		local radius = index == 1 and reactorRadius or 6
		local floorHeight = index == 1 and .17 or .53
		local frame = CFrame.new(position + Vector3.yAxis * floorHeight)
		local dome = part(parent, "Meteor Shelter Dome", Vector3.one * radius * 2,
			frame, mint, Enum.Material.ForceField, false, Enum.PartType.Ball)
		dome.Transparency = .82
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
		-- Crossed curved beams keep the canopy readable without extra physical ribs.
		local ribs = {}
		for _, axis in ipairs({ Vector3.xAxis, Vector3.zAxis }) do
			local ends = {}
			for _, side in ipairs({ -1, 1 }) do
				local mount = Instance.new("Attachment")
				mount.Name = "Shelter Rib Mount"
				mount.CFrame = dome.CFrame:ToObjectSpace(CFrame.new(frame.Position + axis * side * radius)
					* CFrame.Angles(0, 0, -side * math.pi / 2))
				mount.Parent = dome
				table.insert(ends, mount)
			end
			local rib = Instance.new("Beam")
			rib.Name = "Shelter Canopy Rib"
			rib.Attachment0, rib.Attachment1 = ends[1], ends[2]
			rib.CurveSize0, rib.CurveSize1 = radius * 4 / 3, radius * 4 / 3
			rib.Width0, rib.Width1 = .075, .075
			rib.Segments = 12
			rib.FaceCamera = true
			rib.LightEmission = 1
			rib.Color = ColorSequence.new(mint)
			rib.Transparency = NumberSequence.new(.3)
			rib.Parent = dome
			table.insert(ribs, rib)
		end
		local label = billboard(dome, "METEOR SHELTER", mint, 148, 20, 3.3, 32)
		table.insert(shelters, { Center = position, Radius = radius, Part = dome,
			Boundary = edge, Label = label, Billboard = label.Parent, Ribs = ribs, Color = mint })
	end
	return shelters
end

function ShelterDomes.update(shelters, meteorActive, solarActive)
	for _, shelter in ipairs(shelters or {}) do
		-- Meteor protection stays mint while an overlapping flare warms the ribs.
		local color = meteorActive and shelter.Color or solarActive and solarGold or shelter.Color
		shelter.Part.Color = color
		shelter.Part.Transparency = meteorActive and .64 or solarActive and .76 or .82
		shelter.Part:SetAttribute("MeteorShowerActive", meteorActive)
		shelter.Part:SetAttribute("SolarFlareActive", solarActive)
		shelter.Boundary.Color = color
		shelter.Billboard.MaxDistance = meteorActive and 56 or solarActive and 44 or 32
		shelter.Label.TextColor3 = color
		shelter.Label.Text = meteorActive and "METEOR SHELTER / SAFE" or "METEOR SHELTER"
		for _, rib in ipairs(shelter.Ribs) do
			rib.Color = ColorSequence.new(solarActive and solarGold or color)
			rib.Transparency = NumberSequence.new(meteorActive and .06 or solarActive and .16 or .3)
		end
	end
end

return ShelterDomes
