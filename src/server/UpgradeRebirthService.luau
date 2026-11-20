local Catalog = require(game:GetService("ReplicatedStorage"):WaitForChild("Orbit"):WaitForChild("Catalog"))
local Pedestals = require(script.Parent.Pedestals)
local EconomyService = require(script.Parent.EconomyService)

local UpgradeRebirthService = {}
UpgradeRebirthService.__index = UpgradeRebirthService

function UpgradeRebirthService.new(world, bindSlot)
	return setmetatable({ world = world, bindSlot = bindSlot }, UpgradeRebirthService)
end

function UpgradeRebirthService:Resize(bay, count)
	local world = self.world
	for index = #bay.slots, count + 1, -1 do
		local slot = bay.slots[index]
		assert(not slot.cargo and not slot.reserved, "Cannot remove a dock holding cargo")
		slot.container:Destroy()
		bay.slots[index] = nil
	end
	if count == Catalog.baseSlots then
		if bay.expansion then bay.expansion:Destroy(); bay.expansion = nil end
		return
	end
	local frame = CFrame.new(bay.center) * bay.spawn.Rotation
	if not bay.expansion then
		bay.expansion = Instance.new("Folder")
		bay.expansion.Name = "Bay " .. bay.number .. " Extra Docks"
		bay.expansion.Parent = world.root
		world.part(bay.expansion, "Extension Deck", Vector3.new(24, .45, 12),
			frame * CFrame.new(0, .19, 15), world.dark, Enum.Material.Metal, true)
	end
	local function cylinder(parent, name, position, diameter, height, color, material, collide)
		return world.part(parent, name, Vector3.new(height, diameter, diameter),
			CFrame.new(position) * CFrame.Angles(0, 0, math.pi / 2), color, material, collide, Enum.PartType.Cylinder)
	end
	for index = #bay.slots + 1, count do
		local extra = index - Catalog.baseSlots - 1
		local container = Instance.new("Folder")
		container.Name = "Dock " .. index
		container.Parent = bay.expansion
		local cf = frame * CFrame.new((extra % 4 - 1.5) * 5.5, .415, 12 + math.floor(extra / 4) * 5.5)
		local slot = Pedestals.build(container, cf, index, bay.slots[1].emptyColor, world.part, cylinder)
		slot.container = container
		bay.slots[index] = slot
		self.bindSlot(bay, slot)
	end
end

function UpgradeRebirthService:Buy(state, kind)
	local upgraded, words = EconomyService.Upgrade(state, kind)
	if upgraded and kind == "Slots" then self:Resize(state.bay, Catalog.slotCount(state)) end
	return words
end

function UpgradeRebirthService:Rebirth(state, dockCargo, updateSlot)
	local best, reason = EconomyService.RebirthCheck(state)
	if not best then return false, reason end
	local kept = best.cargo
	for _, slot in ipairs(state.bay.slots) do
		if slot.cargo and slot.cargo ~= kept then slot.cargo.model:Destroy() end
		slot.cargo = nil
		updateSlot(slot)
	end
	state.cash, state.bank, state.level = 90, 0, 0
	state.speedLevel, state.carryLevel, state.shieldLevel, state.slotsLevel = 0, 0, 0, 0
	state.rebirths += 1
	self:Resize(state.bay, Catalog.slotCount(state))
	dockCargo(state.bay.slots[1], kept)
	return true, "Rebirth complete. Best cargo kept, +25% base income, +2s shield, "
		.. Catalog.bonusSlots(state.rebirths) .. " permanent bonus docks."
end

return UpgradeRebirthService
