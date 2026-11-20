-- Impacts, shelters and income are authoritative; visual modules can bind to
-- the matching attributes on the station and workspace, or the Meteor remote.
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local Catalog = require(game:GetService("ReplicatedStorage"):WaitForChild("Orbit"):WaitForChild("Catalog"))
local SkillService = require(script.Parent.SkillService)
local BayShield = require(script.Parent.BayShield)
local MeteorSolarEvents = {}
MeteorSolarEvents.__index = MeteorSolarEvents

function MeteorSolarEvents:Attribute(name, value)
	workspace:SetAttribute(name, value)
	self.world.root:SetAttribute(name, value)
end

function MeteorSolarEvents.new(context)
	local self = setmetatable(context, MeteorSolarEvents)
	self.pending, self.shelters, self.holding = {}, {}, {}
	self.sequence, self.meteorActive, self.solarActive = 0, false, false
	self.effects = Instance.new("Folder")
	self.effects.Name = "MeteorEffects"
	self.effects.Parent = self.world.root
	local domes = self.world.Domes or self.world.domes or self.world.shelters
	if domes and #domes > 0 then
		for _, dome in ipairs(domes) do
			table.insert(self.shelters, { center = dome.Center or dome.center, radius = dome.Radius or dome.radius })
		end
	else
		-- The reactor and both portal landings are safe stops on the cargo route.
		for index, center in ipairs({ Vector3.zero, Vector3.new(-43, 0, 0), Vector3.new(43, 0, 0) }) do
			local radius = index == 1 and Catalog.meteor.shelterRadius or 6
			local zone = self.world.part(self.effects, "Meteor Shelter", Vector3.new(radius * 2, 12, radius * 2),
				CFrame.new(center + Vector3.yAxis * 6), self.world.cyan, nil, false)
			zone.Transparency = 1
			zone:SetAttribute("ShelterRadius", radius)
			CollectionService:AddTag(zone, "OrbitMeteorShelter")
			self.world.billboard(zone, "METEOR SHELTER", self.world.cyan, 160, 22, -3, 38)
			table.insert(self.shelters, { center = center, radius = radius })
		end
	end
	for index, shelter in ipairs(self.shelters) do
		self:Attribute("MeteorShelter" .. index, shelter.center)
		self:Attribute("MeteorShelterRadius" .. index, shelter.radius)
	end
	self:Attribute("MeteorShelterCount", #self.shelters)
	local now = workspace:GetServerTimeNow()
	self.nextMeteor, self.nextSolar = now + Catalog.meteor.interval, now + Catalog.solarFlare.interval
	self:Attribute("NextMeteorAt", self.nextMeteor)
	self:Attribute("NextSolarAt", self.nextSolar)
	self:Refresh()
	return self
end

function MeteorSolarEvents:IsProtected(position, now)
	for _, shelter in ipairs(self.shelters) do
		local offset = position - shelter.center
		if math.abs(offset.Y) <= 12 and Vector3.new(offset.X, 0, offset.Z).Magnitude <= shelter.radius then return true end
	end
	-- Lane A can register additional shelter volumes without changing the service.
	for _, shelter in ipairs(CollectionService:GetTagged("OrbitMeteorShelter")) do
		if shelter:IsA("BasePart") and shelter:IsDescendantOf(workspace) then
			local offset = shelter.CFrame:PointToObjectSpace(position)
			if math.abs(offset.X) <= shelter.Size.X / 2 and math.abs(offset.Y) <= shelter.Size.Y / 2
				and math.abs(offset.Z) <= shelter.Size.Z / 2 then return true end
		end
	end
	for _, state in pairs(self.profiles) do
		if BayShield.IsActive(state, now) and BayShield.Contains(position, state.bay) then return true end
	end
	return false
end

function MeteorSolarEvents:Refresh()
	self:Attribute("MeteorShowerActive", self.meteorActive)
	self:Attribute("MeteorShowerEndsAt", self.meteorActive and self.meteorUntil or 0)
	self:Attribute("SolarFlareActive", self.solarActive)
	self:Attribute("SolarFlareEndsAt", self.solarActive and self.solarUntil or 0)
	self:Attribute("IncomeMultiplier", self.solarActive and Catalog.solarFlare.multiplier or 1)
	self:Attribute("Event", self.meteorActive and "Meteor Shower" or self.solarActive and "Solar Flare" or "")
	self:Attribute("EventEndsAt", self.meteorActive and self.meteorUntil or self.solarActive and self.solarUntil or 0)
	if self.refresh then self.refresh() end
	-- Event text has one slot, but a shower and a flare may overlap.
	if self.world.solarFlare then
		-- Run after the legacy Event listener so it cannot hide an overlapping flare.
		task.defer(function()
			if self.world.root.Parent then self.world.solarFlare(self.solarActive) end
		end)
	end
end

function MeteorSolarEvents:Warn(position, now)
	self.sequence += 1
	local impact = { id = self.sequence, position = position, impactAt = now + Catalog.meteor.warning,
		radius = Catalog.meteor.radius }
	local warning = Instance.new("Folder")
	warning.Name = "Meteor Warning"
	warning:SetAttribute("ImpactId", impact.id)
	warning:SetAttribute("ImpactAt", impact.impactAt)
	warning:SetAttribute("ImpactPosition", position)
	warning:SetAttribute("ImpactRadius", impact.radius)
	warning.Parent = self.effects
	impact.warning = warning
	for segment = 1, 20 do
		local first, last = (segment - 1) * math.pi / 10, segment * math.pi / 10
		local a = position + Vector3.new(math.cos(first), 0, math.sin(first)) * impact.radius
		local b = position + Vector3.new(math.cos(last), 0, math.sin(last)) * impact.radius
		self.world.part(warning, "Danger Boundary", Vector3.new(.2, .14, (b - a).Magnitude),
			CFrame.lookAt((a + b) / 2, b), self.world.pink, Enum.Material.Neon, false)
	end
	local core = self.world.part(warning, "Impact Target", Vector3.new(.2, .2, .2), CFrame.new(position), self.world.pink, nil, false)
	core.Transparency = 1
	self.world.billboard(core, "IMPACT! MOVE TO SHELTER", self.world.gold, 215, 20, 2, 42)
	if self.world.meteor then
		self.world.meteor(position, Catalog.meteor.warning, Vector3.new(20, 72, -12))
	else
		local rock = self.world.part(warning, "Falling Meteor", Vector3.one * 3.4,
			CFrame.new(position + Vector3.new(20, 72, -12)), self.world.gold, Enum.Material.Neon, false, Enum.PartType.Ball)
		TweenService:Create(rock, TweenInfo.new(Catalog.meteor.warning, Enum.EasingStyle.Linear),
			{ Position = position + Vector3.yAxis * 1.5 }):Play()
	end
	self.pending[impact.id] = impact
	self:Attribute("MeteorImpactPosition", position)
	self:Attribute("MeteorImpactAt", impact.impactAt)
	self:Attribute("MeteorImpactRadius", impact.radius)
	self:Attribute("MeteorImpactId", impact.id)
	self.network.Meteor:FireAllClients("Warning", { id = impact.id, position = position,
		impactAt = impact.impactAt, radius = impact.radius })
	return impact
end

function MeteorSolarEvents:Impact(impact, now)
	impact.warning:Destroy()
	self.pending[impact.id] = nil
	self.world.flash(impact.position + Vector3.yAxis, self.world.gold, impact.radius * 2)
	self.network.Meteor:FireAllClients("Impact", { id = impact.id, position = impact.position, radius = impact.radius })
	for player, state in pairs(self.profiles) do
		if state.loading or state.closing then continue end
		local root = self.rootOf(player)
		if not root or self:IsProtected(root.Position, now) then continue end
		local offset = root.Position - impact.position
		if math.abs(offset.Y) > 12 or Vector3.new(offset.X, 0, offset.Z).Magnitude > impact.radius then continue end
		if now < (state.meteorHitReady or 0) then continue end
		state.meteorHitReady = now + 1
		state.stunnedUntil = math.max(state.stunnedUntil or 0, now + Catalog.meteor.stun)
		local carrying = state.carry ~= nil
		if carrying then self.drop(player, state, root.Position) end
		SkillService.Update(player, state)
		local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then humanoid:TakeDamage(Catalog.meteor.damage) end
		self.message(player, carrying and "Meteor hit! Cargo dropped. Recover it with E, then head to a shelter."
			or "Meteor hit! Move out of the warning rings or into a meteor shelter.")
	end
end

function MeteorSolarEvents:StartMeteor(now)
	self.meteorActive, self.meteorUntil, self.nextWave = true, now + Catalog.meteor.duration, now
	self.nextMeteor = now + Catalog.meteor.interval
	self:Attribute("NextMeteorAt", self.nextMeteor)
	self.holding = {}
	for player, state in pairs(self.profiles) do if state.carry then self.holding[player] = state.carry end end
	self:Refresh()
	self.announce("Meteor shower! Warning rings mark impacts. Shelter at the reactor or a portal; exposed cargo can drop.")
end

function MeteorSolarEvents:Wave(now)
	local carriers = {}
	for player, state in pairs(self.profiles) do
		local root = not state.loading and not state.closing and state.carry and self.rootOf(player)
		if root and not self:IsProtected(root.Position, now) then
			table.insert(carriers, root.Position)
		end
	end
	for index = 1, Catalog.meteor.perWave do
		local position
		if index == 1 and #carriers > 0 then
			position = carriers[self.random:NextInteger(1, #carriers)]
				+ Vector3.new(self.random:NextNumber(-4, 4), 0, self.random:NextNumber(-4, 4))
		else
			local angle, radius = self.random:NextNumber(0, math.pi * 2), math.sqrt(self.random:NextNumber()) * 68
			position = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		end
		self:Warn(Vector3.new(position.X, .2, position.Z), now)
	end
	self.nextWave = now + Catalog.meteor.waveInterval
end

function MeteorSolarEvents:Step(now)
	if self.world.root:GetAttribute("ScreenshotFrozen") then return end
	for _, impact in pairs(self.pending) do
		if now >= impact.impactAt then self:Impact(impact, now) end
	end
	local changed = false
	if self.meteorActive and now >= self.meteorUntil then
		self.meteorActive, changed = false, true
		for player, cargo in pairs(self.holding) do
			local state = self.profiles[player]
			if state and not state.loading and not state.closing and state.carry == cargo then
				self.activity(state, "SurviveMeteor", cargo)
				local root = self.rootOf(player)
				if root and self:IsProtected(root.Position, now) then
					self.activity(state, "ShelterMeteor", cargo)
				end
			end
		end
		self.holding = {}
		if self.onShowerEnd then self.onShowerEnd() end
	end
	if self.solarActive and now >= self.solarUntil then self.solarActive, changed = false, true end
	if changed then self:Refresh() end
	if next(self.profiles) and now >= self.nextMeteor and not self.meteorActive then self:StartMeteor(now) end
	if next(self.profiles) and now >= self.nextSolar and not self.solarActive then
		self.solarActive, self.solarUntil = true, now + Catalog.solarFlare.duration
		self.nextSolar = now + Catalog.solarFlare.interval
		self:Attribute("NextSolarAt", self.nextSolar)
		self:Refresh()
		self.announce("Solar flare! All docked cargo pays x" .. Catalog.solarFlare.multiplier .. " for " .. Catalog.solarFlare.duration .. " seconds.")
	end
	if self.meteorActive and now >= self.nextWave and now + Catalog.meteor.warning <= self.meteorUntil then self:Wave(now) end
end

function MeteorSolarEvents:Pause()
	for _, impact in pairs(self.pending) do impact.warning:Destroy() end
	self.pending, self.holding = {}, {}
	self.meteorActive, self.solarActive = false, false
	self.network.Meteor:FireAllClients("Cancel")
	self:Refresh()
end

function MeteorSolarEvents:Resume()
	local now = workspace:GetServerTimeNow()
	self.nextMeteor, self.nextSolar = now + Catalog.meteor.interval, now + Catalog.solarFlare.interval
	self:Attribute("NextMeteorAt", self.nextMeteor)
	self:Attribute("NextSolarAt", self.nextSolar)
end

return MeteorSolarEvents
