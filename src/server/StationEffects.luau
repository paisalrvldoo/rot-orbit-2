local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local ShelterDomes = require(script.Parent.ShelterDomes)
local StationEffects = {}

local amber = Color3.fromRGB(255, 192, 96)
local ember = Color3.fromRGB(241, 101, 66)
local neon = Enum.Material.Neon
local maxMeteors = 4

function StationEffects.bind(root, part, reactor, grade, shelters)
	local active = 0
	local current
	local solarEnabled = false
	local flights = {}
	local connections = {}
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
	local function attribute(name)
		local value = root:GetAttribute(name)
		if value == nil then value = workspace:GetAttribute(name) end
		return value
	end
	local function meteorActive()
		local enabled = attribute("MeteorShowerActive")
		if enabled ~= nil then return enabled == true end
		local event = attribute("Event")
		return event == "Meteor Shower" or event == "Meteor Drop"
	end

	local function meteor(impact, duration, offset)
		if active >= maxMeteors or not root.Parent or root:GetAttribute("ScreenshotFrozen") then return end
		local travel = offset or Vector3.new(-41, 79, 25)
		if travel.Magnitude < .01 then travel = Vector3.new(0, 79, 0) end
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
		active += 1
		local flight = {}
		flights[rock] = flight
		local function release()
			if not flights[rock] then return end
			flights[rock] = nil
			active -= 1
			rock:Destroy()
		end
		flight.cancel = function()
			if flight.tween then flight.tween:Cancel() end
			release()
		end
		task.spawn(function()
			if not flights[rock] then return end
			local fall = TweenService:Create(rock, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{ Position = impact })
			flight.tween = fall
			fall:Play()
			local playback = fall.Completed:Wait()
			if playback == Enum.PlaybackState.Completed and rock.Parent and flights[rock] then
				streak.Enabled = false
				rock.Name = "Meteor Impact"
				rock.Color = amber
				local flash = TweenService:Create(rock, TweenInfo.new(.32, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{ Size = Vector3.new(10, .24, 10), Transparency = 1 })
				flight.tween = flash
				flash:Play()
				flash.Completed:Wait()
			end
			release()
		end)
		return rock
	end

	local function solarFlare(enabled)
		enabled = enabled == true
		if not root.Parent then return end
		ShelterDomes.update(shelters, meteorActive(), enabled)
		if solarEnabled == enabled then return end
		solarEnabled = enabled
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
		if not root.Parent then return end
		local event = attribute("Event")
		local solarActive = attribute("SolarFlareActive")
		if solarActive == nil then solarActive = event == "Solar Flare" end
		solarFlare(solarActive)
		if current == event then return end
		current = event
		-- Authoritative showers call World.meteor for each warned impact. Only the
		-- older Meteor Drop event needs a decorative fallback, so impacts never double.
		if event ~= "Meteor Drop" then return end
		meteor(Vector3.new(0, .44, 0), 1.2)
		local deadline = attribute("EventEndsAt")
		for i, target in ipairs({ Vector3.new(-24, .15, 15), Vector3.new(23, .15, -18), Vector3.new(4, .15, 27) }) do
			task.delay(i * 1.4, function()
				if current == "Meteor Drop" and attribute("EventEndsAt") == deadline then
					meteor(target, 1.55, Vector3.new(-41 + i * 7, 79, 25))
				end
			end)
		end
	end
	local refreshQueued = false
	local function queueRefresh()
		if refreshQueued then return end
		refreshQueued = true
		task.defer(function()
			refreshQueued = false
			refresh()
		end)
	end
	for _, source in ipairs({ root, workspace }) do
		for _, name in ipairs({ "Event", "SolarFlareActive", "MeteorShowerActive" }) do
			table.insert(connections, source:GetAttributeChangedSignal(name):Connect(queueRefresh))
		end
	end
	local function clearMeteors()
		local pending = {}
		for _, flight in pairs(flights) do table.insert(pending, flight) end
		for _, flight in ipairs(pending) do flight.cancel() end
	end
	table.insert(connections, root:GetAttributeChangedSignal("ScreenshotFrozen"):Connect(function()
		if root:GetAttribute("ScreenshotFrozen") then clearMeteors() end
	end))
	root.Destroying:Once(function()
		for _, connection in ipairs(connections) do connection:Disconnect() end
		clearMeteors()
		if lightTween then lightTween:Cancel() end
		if gradeTween then gradeTween:Cancel() end
		if coreTween then coreTween:Cancel() end
		-- Also restore the baseline if teardown interrupts a flare fading out.
		if lightTween then
			for property, value in pairs(calm) do Lighting[property] = value end
			grade.TintColor = calmTint
		end
	end)
	refresh()
	return meteor, solarFlare
end

return StationEffects
