local Pedestals = {}
local metal = Enum.Material.Metal
local neon = Enum.Material.Neon

function Pedestals.build(parent, frame, index, accent, part, cylinder, billboard)
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
	local label = billboard(pad, string.format("%02d  /  EMPTY", index), accent, 94, 16, .86, 17)
	label.Name = "SlotStatus"
	label.Parent.Name = "SlotReadout"
	return { pad = pad, cf = frame * CFrame.new(0, .82, 0), ring = ring }
end

function Pedestals.bindPrompt(pad, prompt)
	local readout = pad:FindFirstChild("SlotReadout")
	if not readout then return end
	local index = pad:GetAttribute("SlotIndex")
	local function refresh()
		readout.Enabled = prompt:GetAttribute("Occupied") ~= true
		readout.SlotStatus.Text = string.format("%02d  /  %s", index, prompt.Enabled and "EMPTY" or "RESERVED")
	end
	prompt:GetAttributeChangedSignal("Occupied"):Connect(refresh)
	prompt:GetPropertyChangedSignal("Enabled"):Connect(refresh)
	refresh()
end

return Pedestals
