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
		local roster = {}
		for player, state in pairs(self.profiles) do
			if state.crew == id and not state.loading and not state.closing then
				table.insert(roster, { number = state.bay.number, name = player.DisplayName,
					sealed = workspace:GetServerTimeNow() < state.lockedUntil })
			end
		end
		table.sort(roster, function(a, b) return a.number < b.number end)
		local rows = {}
		for _, member in ipairs(roster) do
			table.insert(rows, member.name .. "  •  BAY " .. member.number .. (member.sealed and "  •  SEALED" or "  •  OPEN"))
		end
		workspace:SetAttribute("CrewRoster" .. id, table.concat(rows, "\n"))
		workspace:SetAttribute("CrewMembers" .. id, #roster)
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
