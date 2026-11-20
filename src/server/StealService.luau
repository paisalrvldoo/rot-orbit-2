local Catalog = require(game:GetService("ReplicatedStorage"):WaitForChild("Orbit"):WaitForChild("Catalog"))
local BayShield = require(script.Parent.BayShield)
local CrewService = require(script.Parent.CrewService)
local EconomyService = require(script.Parent.EconomyService)

local StealService = {}
StealService.__index = StealService

function StealService.new(context)
	context.drops = {}
	return setmetatable(context, StealService)
end

function StealService:Take(player, state, slot)
	local bay = slot.bay
	local owner = bay.owner
	local ownerState = owner and self.profiles[owner]
	if not slot.cargo or state.carry then return end
	if not bay.rival and (not ownerState or ownerState.loading or ownerState.closing) then return end
	local now = workspace:GetServerTimeNow()
	if now < (state.stunnedUntil or 0) then self.message(player, "Wait for the stun to end before stealing.") return end
	if CrewService.Same(state, ownerState) then self.message(player, "Squad cargo is protected.") return end
	if not EconomyService.FreeSlot(state) then self.message(player, "Recycle cargo to free a docking slot first.") return end
	if now < (state.stealReady or 0) then self.message(player, "Your theft scanner is recharging.") return end
	if ownerState and BayShield.IsActive(ownerState, now) then
		self.message(player, "That bay is sealed.")
		return
	end
	local cargo = self.take(slot)
	cargo.stolen = true
	self.setCarry(player, state, cargo)
	if ownerState then
		self.sync(owner, ownerState)
		self.message(owner, player.DisplayName .. " stole " .. Catalog.name(cargo) .. ". Zap them to recover it!")
	end
	self.message(player, "Stolen cargo. Dock it before you get zapped!")
end

function StealService:Drop(cargo, position, secured)
	if not position or Vector3.new(position.X, 0, position.Z).Magnitude > 75 then
		self.returnCargo(cargo)
		return
	end
	cargo.model:PivotTo(CFrame.new(position.X, .55, position.Z))
	local prompt = self.world.prompt(cargo.model.PrimaryPart, "Recover Cargo", Catalog.name(cargo), Enum.KeyCode.E, .32)
	self.drops[cargo] = prompt
	local claimUntil = workspace:GetServerTimeNow() + 6
	prompt.Triggered:Connect(function(player)
		if self.world.root:GetAttribute("ScreenshotFrozen") then return end
		local state = self.profiles[player]
		if self.drops[cargo] ~= prompt or not state or state.loading or state.closing
			or not self.near(player, cargo.model.PrimaryPart.Position, 10) then return end
		local now = workspace:GetServerTimeNow()
		if now < (state.stunnedUntil or 0) then return end
		if cargo.source and cargo.source.bay == state.bay then
			self.drops[cargo] = nil
			prompt:Destroy()
			self.returnCargo(cargo)
			self.message(player, "Your cargo was recovered and returned to its dock.")
			return
		end
		local owner = cargo.source and cargo.source.bay.owner
		if owner and CrewService.Same(state, self.profiles[owner]) then
			self.drops[cargo] = nil
			prompt:Destroy()
			self.returnCargo(cargo)
			self.message(player, "Squad cargo recovered and returned to its owner's bay.")
			return
		end
		if owner and (secured or now < claimUntil) then
			self.message(player, "The owning squad has first claim on this cargo.")
			return
		end
		if state.carry then self.message(player, "Dock your current cargo first."); return end
		if not EconomyService.FreeSlot(state) then
			self.message(player, "Bay full. Recycle cargo before recovering another brainrot.")
			return
		end
		self.drops[cargo] = nil
		prompt:Destroy()
		if cargo.source then cargo.stolen = true end
		self.setCarry(player, state, cargo)
		self.message(player, "Cargo recovered. Bring it to your bay.")
	end)
	task.delay(25, function()
		if self.drops[cargo] ~= prompt then return end
		self.drops[cargo] = nil
		prompt:Destroy()
		if secured then
			self.returnCargo(cargo)
			return
		end
		local source = self.clearSource(cargo)
		if source and source.bay.owner then self.message(source.bay.owner, "Rift recovery window expired. Your slot is available again.") end
		cargo.model:Destroy()
	end)
end

function StealService:CancelDrop(cargo)
	local prompt = self.drops[cargo]
	if prompt then
		self.drops[cargo] = nil
		prompt:Destroy()
	end
end

function StealService:NearestThief(player, state, origin, now)
	local target, targetState, targetPosition, best = nil, nil, nil, Catalog.zap.range
	for other, otherState in pairs(self.profiles) do
		local cargo = otherState.carry
		if other ~= player and not otherState.loading and not otherState.closing and cargo and (cargo.stolen or cargo.source)
			and not CrewService.Same(state, otherState) then
			local otherRoot = self.rootOf(other)
			local distance = otherRoot and (origin - otherRoot.Position).Magnitude
			if distance and distance <= best and not BayShield.BlocksZap(self.profiles, origin, otherRoot.Position, now) then
				target, targetState, targetPosition, best = other, otherState, otherRoot.Position, distance
			end
		end
	end
	return target, targetState, targetPosition, best
end

function StealService:Disarm(player, state, position, now)
	local cargo = state.carry
	state.stunnedUntil = math.max(now + Catalog.zap.stun, state.stunnedUntil or 0)
	state.stealReady = now + Catalog.zap.stealCooldown
	self.setCarry(player, state, nil)
	self:Drop(cargo, position, true)
	self.message(player, "You were zapped and dropped the stolen cargo.")
end

return StealService
