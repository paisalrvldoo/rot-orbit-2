local Catalog = require(game:GetService("ReplicatedStorage"):WaitForChild("Orbit"):WaitForChild("Catalog"))
local EconomyService = {}

function EconomyService.Credit(state, amount)
	local before = state.cash
	state.cash = math.clamp(before + amount, 0, Catalog.maxCash)
	return state.cash - before
end

function EconomyService.Rate(state, incomeMultiplier)
	local rate = 0
	for _, slot in ipairs(state.bay.slots) do
		if slot.cargo then rate += Catalog.rate(slot.cargo) end
	end
	return math.floor(rate * (1 + .25 * state.level + .25 * state.rebirths) * (incomeMultiplier or 1))
end

function EconomyService.FreeSlot(state)
	for _, slot in ipairs(state.bay.slots) do
		if not slot.cargo and not slot.reserved then return slot end
	end
end

function EconomyService.Discover(state, cargo)
	local key = Catalog.discoveryKey(cargo)
	if state.index[key] then return false, 0 end
	state.index[key] = true
	local count = Catalog.discoveryCount(state.index)
	local reward = 0
	for index, milestone in ipairs(Catalog.indexMilestones) do
		if count >= milestone.goal and index > (state.milestone or 0) then
			reward += milestone.reward
			state.milestone = index
		end
	end
	return true, EconomyService.Credit(state, reward)
end

function EconomyService.Upgrade(state, kind)
	if kind ~= nil and type(kind) ~= "string" then return false, "Unknown upgrade." end
	local definition = kind and Catalog.utilityUpgrades[kind]
	if kind and kind ~= "Income" and not definition then return false, "Unknown upgrade." end
	local key, costs = definition and definition.key or "level", definition and definition.costs or Catalog.upgrades
	local price = costs[(state[key] or 0) + 1]
	if not price then return false, "This upgrade is maxed." end
	if state.cash < price then return false, "Need $" .. price .. " for this upgrade." end
	state.cash -= price
	state[key] = (state[key] or 0) + 1
	return true, definition and (definition.name .. " upgraded to level " .. state[key] .. ".") or "Dock amplifier upgraded. +25% base income."
end

function EconomyService.RebirthCheck(state)
	if state.rebirths >= Catalog.rebirthMax then return nil, "You reached Orbit Ace: all rebirths complete." end
	if state.cash < Catalog.rebirthCost(state.rebirths) then return nil, "Need $" .. Catalog.rebirthCost(state.rebirths) .. " to rebirth." end
	if state.carry then return nil, "Dock your carried cargo before rebirthing." end
	local best
	for _, slot in ipairs(state.bay.slots) do
		if slot.reserved then return nil, "Recover your missing cargo before rebirthing." end
		if slot.cargo and (not best or Catalog.rate(slot.cargo) > Catalog.rate(best.cargo)) then best = slot end
	end
	local highest = 0
	for _, slot in ipairs(state.bay.slots) do
		if slot.cargo then highest = math.max(highest, Catalog.entries[slot.cargo.id].tier) end
	end
	if not best or highest < Catalog.rebirthTier(state.rebirths) then
		return nil, "Dock " .. Catalog.tiers[Catalog.rebirthTier(state.rebirths)].name .. " or better to qualify."
	end
	return best
end

return EconomyService
