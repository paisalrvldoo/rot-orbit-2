-- Vacant player bays double as NPC rivals; joining players always take priority.
local Catalog = require(game:GetService("ReplicatedStorage"):WaitForChild("Orbit"):WaitForChild("Catalog"))
local RivalService = {}
RivalService.__index = RivalService

function RivalService.new(context)
	return setmetatable(context, RivalService)
end

function RivalService:Clear(bay)
	bay.rival = false
	for _, slot in ipairs(bay.slots) do
		-- Loot already carried away stays with its carrier when this bay is assigned.
		if slot.reserved then self.clearSource(slot.reserved) end
		if slot.cargo then slot.cargo.model:Destroy(); slot.cargo = nil end
		slot.prompt:SetAttribute("Rival", false)
		self.updateSlot(slot)
	end
end

function RivalService:Restock()
	local progression = 0
	for _, state in pairs(self.profiles) do
		if not state.loading and not state.closing then progression = math.max(progression, state.rebirths) end
	end
	local count = 0
	for index = #self.bays, 1, -1 do
		local bay = self.bays[index]
		if not bay.owner and count < 2 then
			count += 1
			bay.rival = true
			self.world.title(bay, "BAY " .. bay.number .. "  /  RIVAL CREW")
			for position, slot in ipairs(bay.slots) do
				slot.prompt:SetAttribute("Rival", true)
				slot.prompt:SetAttribute("Crew", 0)
				slot.prompt:SetAttribute("LockedUntil", 0)
				if position <= 3 and not slot.cargo and not slot.reserved then
					local tier = math.min(6, position + math.floor(progression / 2))
					local choices = Catalog.byTier[tier]
					local cargo = { id = choices[self.random:NextInteger(1, #choices)], mutation = Catalog.rollMutation(self.random) }
					cargo.model = self.world.figure(cargo, self.world.root)
					self.dockCargo(slot, cargo)
				end
			end
		end
	end
end

return RivalService
