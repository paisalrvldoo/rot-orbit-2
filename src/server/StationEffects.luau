local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local StationEffects = {}

local amber = Color3.fromRGB(255, 192, 96)
local ember = Color3.fromRGB(241, 101, 66)
local neon = Enum.Material.Neon
local maxMeteors = 4

function StationEffects.bind(root, part, reactor, grade)
	local active = 0
	local current
	local lightTween, gradeTween, coreTween
	local calm = {
		Ambient = Lighting.Ambient,
		OutdoorAmbient = Lighting.OutdoorAmbient,
		ExposureCompensation = Lighting.ExposureCompensation,
	}
	local calmTint, calmCore = grade.TintColor, reactor.Color
	local solar = {
		Ambient = Color3.fromRGB(91, 57, 43),
		OutdoorAmbient = Color3.fromRGB(94, 61, 44),
		ExposureCompensation = calm.ExposureCompensation + .23,
	}

	local function meteor(impact, duration, offset)
		if active >= maxMeteors or not root.Parent then return end
		active += 1
		local travel = offset or Vector3.new(-41, 79, 25)
		local seconds = math.clamp(duration or 1.4, .25, 5)
		local start = impact + travel
		local rock = part(root, "Falling Meteor", Vector3.one * 1.35, CFrame.new(start),
			ember, neon, false, Enum.PartType.Ball)
		local head = Instance.new("Attachment")
		head.Parent = rock
		local tail = Instance.new("Attachment")
		tail.Position = travel.Unit * 12
		tail.Parent = rock
		local streak = Instance.new("Beam")
		streak.Attachment0, streak.Attachment1 = head, tail
		streak.FaceCamera = true
		streak.Width0, streak.Width1 = 1.65, .08
		streak.LightEmission = 1
		streak.Color = ColorSequence.new(amber, ember)
		streak.Transparency = NumberSequence.new(.12, .94)
		streak.Parent = rock
		task.spawn(function()
			local fall = TweenService:Create(rock, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{ Position = impact })
			fall:Play()
			fall.Completed:Wait()
			if rock.Parent then
				streak.Enabled = false
				rock.Name = "Meteor Impact"
				rock.Color = amber
				local flash = TweenService:Create(rock, TweenInfo.new(.32, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{ Size = Vector3.new(10, .24, 10), Transparency = 1 })
				flash:Play()
				flash.Completed:Wait()
				rock:Destroy()
			end
			active -= 1
		end)
	end

	local function solarFlare(enabled)
		if lightTween then lightTween:Cancel() end
		if gradeTween then gradeTween:Cancel() end
		if coreTween then coreTween:Cancel() end
		local timing = TweenInfo.new(.9, Enum.EasingStyle.Sine)
		lightTween = TweenService:Create(Lighting, timing, enabled and solar or calm)
		gradeTween = TweenService:Create(grade, timing,
			{ TintColor = enabled and Color3.fromRGB(255, 211, 165) or calmTint })
		coreTween = TweenService:Create(reactor, timing, { Color = enabled and amber or calmCore })
		lightTween:Play()
		gradeTween:Play()
		coreTween:Play()
	end

	local function refresh()
		local event = workspace:GetAttribute("Event")
		if current == event then return end
		if event == "Solar Flare" or current == "Solar Flare" then solarFlare(event == "Solar Flare") end
		current = event
		if event ~= "Meteor Drop" then return end
		meteor(Vector3.new(0, .44, 0), 1.2)
		local deadline = workspace:GetAttribute("EventEndsAt")
		for i, target in ipairs({ Vector3.new(-24, .15, 15), Vector3.new(23, .15, -18), Vector3.new(4, .15, 27) }) do
			task.delay(i * 1.4, function()
				if current == "Meteor Drop" and workspace:GetAttribute("EventEndsAt") == deadline then
					meteor(target, 1.55, Vector3.new(-41 + i * 7, 79, 25))
				end
			end)
		end
	end
	local connection = workspace:GetAttributeChangedSignal("Event"):Connect(function()
		task.defer(refresh)
	end)
	root.Destroying:Once(function()
		connection:Disconnect()
		if current == "Solar Flare" then
			lightTween:Cancel()
			gradeTween:Cancel()
			coreTween:Cancel()
			for property, value in pairs(calm) do Lighting[property] = value end
			grade.TintColor = calmTint
		end
	end)
	refresh()
	return meteor, solarFlare
end

return StationEffects
