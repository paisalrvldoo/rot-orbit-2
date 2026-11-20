local Lighting = game:GetService("Lighting")

local Backdrop = {}
local neon = Enum.Material.Neon

function Backdrop.build(root, part, arc, cyan, gold, pink, ice)
	Lighting.ClockTime = 0
	Lighting.Brightness = 1.6
	Lighting.Ambient = Color3.fromRGB(43, 47, 66)
	Lighting.OutdoorAmbient = Color3.fromRGB(50, 54, 73)
	Lighting.ExposureCompensation = -.15
	Lighting.ShadowSoftness = .32
	Lighting.EnvironmentDiffuseScale = .15
	Lighting.EnvironmentSpecularScale = .22

	local bloom = Instance.new("BloomEffect")
	bloom.Name = "Orbit Bloom"
	bloom.Intensity = 1.08
	bloom.Size = 32
	bloom.Threshold = .78
	bloom.Parent = Lighting

	local grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "Orbit Color Grade"
	grade.Contrast = .08
	grade.Saturation = .09
	grade.TintColor = Color3.fromRGB(236, 243, 255)
	grade.Parent = Lighting

	local backdrop = Instance.new("Model")
	backdrop.Name = "Orbit Backdrop"
	backdrop.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	backdrop.Parent = root
	-- A dark shell gives the physical stars a consistent background without external sky assets.
	for _, normal in ipairs({ Vector3.xAxis, Vector3.yAxis, Vector3.zAxis }) do
		for _, side in ipairs({ -1, 1 }) do
			part(backdrop, "Deep Space", Vector3.one * 1100 - normal * 1098,
				CFrame.new(normal * side * 549), Color3.fromRGB(3, 5, 11), neon)
		end
	end

	local rng = Random.new(827)
	for i = 1, 64 do
		local azimuth = (i * .6180339887 % 1) * math.pi * 2
		local y = (i - .5) / 64 * 1.42 - .48
		local horizontal = math.sqrt(1 - y * y)
		local pos = Vector3.new(math.cos(azimuth) * horizontal, y, math.sin(azimuth) * horizontal) * 395
		local size = i % 9 == 0 and .96 or rng:NextNumber(.28, .69)
		part(backdrop, "Star", Vector3.one * size, CFrame.new(pos), i % 7 == 0 and cyan or ice,
			neon, false, Enum.PartType.Ball)
	end

	local planet = Vector3.new(-29, 58, -166)
	part(backdrop, "Ion Giant", Vector3.one * 24, CFrame.new(planet), Color3.fromRGB(19, 83, 109),
		Enum.Material.SmoothPlastic, false, Enum.PartType.Ball)
	local tilt = CFrame.Angles(.55, 0, -.42)
	arc(backdrop, planet, tilt.RightVector, tilt.LookVector, 17, 28, .24, cyan, neon)
	arc(backdrop, planet, tilt.RightVector, tilt.LookVector, 20, 28, .15, gold, neon)
	arc(backdrop, planet, tilt.UpVector, tilt.LookVector, 12.25, 24, .14, cyan, neon)
	local tilt2 = CFrame.Angles(.18, 0, .41)
	for i, spec in ipairs({ { 97, cyan }, { 103, pink }, { 111, gold } }) do
		arc(backdrop, Vector3.new(0, 46, 0), tilt2.RightVector, tilt2.LookVector, spec[1], 15, .22,
			spec[2], neon, false, 1.65, -.75 + i * .13)
	end
end

return Backdrop
