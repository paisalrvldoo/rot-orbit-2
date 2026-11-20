-- Studio-only staging. Saves always encode the real pre-preview profile.
local RunService = game:GetService("RunService")
local Orbit = game:GetService("ReplicatedStorage"):WaitForChild("Orbit")
local Catalog = require(Orbit:WaitForChild("Catalog"))
local ScreenshotMode = require(Orbit:WaitForChild("ScreenshotMode"))
local DataService = require(script.Parent.DataService)
local ScreenshotService = {}
ScreenshotService.__index = ScreenshotService
local fields = { "cash", "bank", "level", "rebirths", "guide", "crew", "contract", "progress", "index", "speedLevel", "shieldLevel", "milestone" }

function ScreenshotService.new(context)
	assert(RunService:IsStudio(), "Screenshot staging requires Studio")
	local self = setmetatable(context, ScreenshotService)
	ScreenshotMode.Configure(function(scene, player) return self:Select(scene, player) end)
	return self
end

function ScreenshotService:Clear(state)
	if state.carry then state.carry.model:Destroy(); state.carry = nil end
	for _, slot in ipairs(state.bay.slots) do
		if slot.cargo then slot.cargo.model:Destroy() end
		slot.cargo = nil
		self.updateSlot(slot)
	end
end

function ScreenshotService:Publish(player, state)
	local keys = {}
	for key in pairs(state.index) do table.insert(keys, key) end
	table.sort(keys)
	player:SetAttribute("Index", table.concat(keys, ","))
	self.sync(player, state)
end

function ScreenshotService:Reset()
	local player = self.player
	if not player then return true end
	local state = self.profiles[player]
	if self.preview then self.preview:Destroy(); self.preview = nil end
	if state and state.previewSaved then
		local restored = DataService.Decode(state.previewSaved, #state.bay.slots)
		self:Clear(state)
		for _, key in ipairs(fields) do state[key] = restored[key] end
		for position, record in ipairs(restored.inventory) do
			record.model = self.world.figure(record, self.world.root)
			self.dockCargo(state.bay.slots[position], record)
		end
		state.previewSaved = nil
		-- Purchased cargo present on entry is safely redocked on reset.
		self:Publish(player, state)
	end
	if self.root and self.root.Parent then
		self.root.Anchored = self.anchored
		self.root.CFrame = self.frame
	end
	self.player, self.root = nil, nil
	self.world.root:SetAttribute("ScreenshotFrozen", false)
	self.world.root:SetAttribute("ScreenshotPreset", nil)
	self.weather:Resume()
	self.network.Screenshot:FireClient(player, "Reset")
	return true
end

function ScreenshotService:Select(scene, player)
	if not RunService:IsStudio() then return false end
	if scene == "Reset" then return self:Reset() end
	if scene ~= "Cover" and scene ~= "Index" and scene ~= "Raid" and scene ~= "Upgrades" then return false end
	local state, root = self.profiles[player], self.rootOf(player)
	if not state or state.loading or state.closing or not root then return false end
	self:Reset()
	self.settle(player, state)
	self.finishRaid(true)
	state.previewSaved = DataService.Encode(state)
	self.player, self.root, self.frame, self.anchored = player, root, root.CFrame, root.Anchored
	self.weather:Pause()
	self.world.root:SetAttribute("ScreenshotFrozen", true)
	self.world.root:SetAttribute("ScreenshotPreset", scene)
	self:Clear(state)
	state.cash, state.bank, state.level, state.rebirths, state.guide = 867500, 12500, 3, 3, 4
	state.speedLevel, state.shieldLevel, state.milestone = 2, 2, 3
	state.contract, state.progress, state.index = 1, Catalog.contracts[1].goal, {}
	for id = 1, 32 do state.index[Catalog.discoveryKey({ id = id, mutation = 1 })] = true end
	for position, id in ipairs({ 1, 15, 28, 36, 44, 48 }) do
		local cargo = { id = id, mutation = position + 1 }
		cargo.model = self.world.figure(cargo, self.world.root)
		self.dockCargo(state.bay.slots[position], cargo)
		state.index[Catalog.discoveryKey(cargo)] = true
	end
	root.Anchored = true
	if scene == "Raid" then
		self.preview = self.world.gremlin()
		self.preview:PivotTo(CFrame.lookAt(self.world.portal + Vector3.new(-4, 0, 4), Vector3.new(0, self.world.portal.Y, 0)))
	end
	self:Publish(player, state)
	self.network.Screenshot:FireClient(player, scene)
	return true
end

return ScreenshotService
