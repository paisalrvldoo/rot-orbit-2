local GuideService = {}

function GuideService.Stage(state)
	if state.guide >= 4 then return 4 end
	if state.carry then return 2 end
	if state.bank > 0 then return 3 end
	for _, slot in ipairs(state.bay.slots) do
		if slot.cargo or slot.reserved then return 3 end
	end
	-- Losing undocked starter cargo sends the player back to the buy step.
	return 1
end

return GuideService
