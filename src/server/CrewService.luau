-- Membership and session scores are owned by the server.
local Catalog = require(game:GetService("ReplicatedStorage"):WaitForChild("Orbit"):WaitForChild("Catalog"))
local CrewService = {}
CrewService.__index = CrewService

function CrewService.new(profiles)
	local self = setmetatable({ profiles = profiles, scores = {} }, CrewService)
	for id in ipairs(Catalog.crews) do self.scores[id] = 0 end
	self:Refresh()
	return self
end

function CrewService.Same(first, second)
	return first ~= nil and second ~= nil and (first.crew or 0) > 0 and first.crew == second.crew
end

function CrewService:Refresh()
	for id in ipairs(Catalog.crews) do
		local members = 0
		for _, state in pairs(self.profiles) do
			if state.crew == id then members += 1 end
		end
		workspace:SetAttribute("CrewMembers" .. id, members)
		workspace:SetAttribute("CrewScore" .. id, self.scores[id])
	end
end

function CrewService:Select(state, id, raidActive)
	if type(id) ~= "number" or id % 1 ~= 0 or (id ~= 0 and not Catalog.crews[id]) then
		return false, "Choose Solo or an available squad."
	end
	if state.crew == id then return false, "You are already in that crew." end
	local now = workspace:GetServerTimeNow()
	if now < (state.crewReady or 0) then
		return false, "Crew switch ready in " .. math.ceil(state.crewReady - now) .. "s."
	end
	if state.carry or raidActive then return false, "Switch crews after docking cargo and finishing the raid." end
	for _, slot in ipairs(state.bay.slots) do
		if slot.reserved then return false, "Recover your missing cargo before switching crews." end
	end
	state.crew, state.crewReady = id, now + 30
	self:Refresh()
	return true, id == 0 and "Solo mode enabled." or ("Joined " .. Catalog.crews[id].name .. ". Squad cargo is protected.")
end

function CrewService:Award(state, points)
	state.score = (state.score or 0) + points
	if (state.crew or 0) > 0 then
		self.scores[state.crew] += points
		self:Refresh()
	end
end

return CrewService
