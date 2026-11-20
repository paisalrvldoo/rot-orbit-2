-- Offers share an entry point and expire after one circuit, even if nobody buys.
local Catalog = require(game:GetService("ReplicatedStorage"):WaitForChild("Orbit"):WaitForChild("Catalog"))
local ConveyorService = {}
ConveyorService.__index = ConveyorService
local config = Catalog.conveyor
local lap = config.interval * config.capacity

function ConveyorService.new(context)
	context.offers = {}
	context.clock, context.nextSpawn, context.arrivals = 0, config.interval, 0
	local self = setmetatable(context, ConveyorService)
	for i, tier in ipairs(config.previewTiers) do
		self:Spawn(self:Cargo(tier, true, i == 1 and 1 or nil), -(i - 1) * config.interval, true)
	end
	return self
end

function ConveyorService:Cargo(tier, standard, id)
	local choices = Catalog.byTier[tier]
	return { id = id or choices[self.random:NextInteger(1, #choices)],
		mutation = standard and 1 or Catalog.rollMutation(self.random) }
end

function ConveyorService:Roll()
	self.arrivals += 1
	if self.arrivals % 3 == 0 then
		return self:Cargo(1, true, self.random:NextInteger(1, 4))
	end
	local required, progress = nil, 0
	for _, state in pairs(self.profiles) do
		if not state.loading and not state.closing then
			progress = math.max(progress, (state.level + 2 * state.rebirths) / (#Catalog.upgrades + 2 * Catalog.rebirthMax))
			if self.arrivals % 4 == 1 and state.rebirths >= 3 and state.rebirths < Catalog.rebirthMax then
				required = math.max(required or 0, Catalog.rebirthTier(state.rebirths))
			end
		end
	end
	if required then return self:Cargo(required, false) end
	-- At max progression, shift 14 points from low tiers toward Rare and above.
	local shift = { -8, -6, 2, 3, 3.5, 3, 2, .5 }
	local roll = self.random:NextNumber(0, 100)
	for tier, weight in ipairs(config.weights) do
		roll -= weight + progress * shift[tier]
		if roll < 0 then return self:Cargo(tier, false) end
	end
	return self:Cargo(#config.weights, false)
end

function ConveyorService:Spawn(cargo, born, preview)
	local offer = { cargo = cargo, born = born, expires = born + lap }
	self.offers[offer] = true
	self.stock(offer, preview, workspace:GetServerTimeNow() + offer.expires - self.clock)
	self.place(offer, config.entryAngle + (self.clock - born) * math.pi * 2 / lap)
end

function ConveyorService:Claim(offer)
	if not self.offers[offer] or self.clock >= offer.expires then return false end
	self.offers[offer] = nil
	return true
end

function ConveyorService:Step(delta, frozen)
	if frozen then
		self.paused = true
		return
	end
	local resumed = self.paused
	self.paused = false
	self.clock += resumed and 0 or delta
	local count = 0
	for offer in pairs(self.offers) do
		if self.clock >= offer.expires then
			self.offers[offer] = nil
			offer.cargo.model:Destroy()
		else
			if resumed then
				offer.cargo.model:SetAttribute("OfferExpiresAt", workspace:GetServerTimeNow() + offer.expires - self.clock)
			end
			self.place(offer, config.entryAngle + (self.clock - offer.born) * math.pi * 2 / lap)
			count += 1
		end
	end
	if self.clock >= self.nextSpawn then
		-- A stalled server resumes at the normal cadence instead of spawning a burst.
		self.nextSpawn += (math.floor((self.clock - self.nextSpawn) / config.interval) + 1) * config.interval
		if count < config.capacity then self:Spawn(self:Roll(), self.clock, false) end
	end
end

return ConveyorService
