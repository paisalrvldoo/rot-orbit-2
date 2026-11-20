-- Supply policy stays separate from the orbit's world presentation.
local Catalog = require(game:GetService("ReplicatedStorage"):WaitForChild("Orbit"):WaitForChild("Catalog"))
local ConveyorService = {}
ConveyorService.__index = ConveyorService

function ConveyorService.new(random, profiles)
	return setmetatable({ random = random, profiles = profiles, restocks = 0 }, ConveyorService)
end

function ConveyorService:Roll(index, first)
	local tier = Catalog.marketThemes[index]
	if not first then
		self.restocks += 1
		-- Keep Common lanes affordable; regularly supply the tier needed to rebirth.
		if tier > 1 and self.restocks % 4 == 0 then
			for _, state in pairs(self.profiles) do
				if not state.loading and not state.closing and state.rebirths >= 3 then
					tier = math.max(tier, Catalog.rebirthTier(state.rebirths))
				end
			end
		end
	end
	if index == #Catalog.marketThemes then
		local chance = self.random:NextNumber()
		if chance < Catalog.secretChance then tier = 8
		elseif chance < Catalog.secretChance + Catalog.cosmicChance then tier = math.max(tier, 7) end
	end
	local choices = Catalog.byTier[tier]
	return {
		id = first and index == 1 and 1 or choices[self.random:NextInteger(1, #choices)],
		mutation = not first and Catalog.marketThemes[index] ~= 1 and Catalog.rollMutation(self.random) or 1,
	}
end

return ConveyorService
