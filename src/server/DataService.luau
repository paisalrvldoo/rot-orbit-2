-- A failed load is session-only. It can never replace an existing save.
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Catalog = require(game:GetService("ReplicatedStorage"):WaitForChild("Orbit"):WaitForChild("Catalog"))
local DataService = {}
DataService.__index = DataService
local VERSION, LEASE_SECONDS, MAX_CASH = 1, 180, 1e12

local function integer(value, fallback, maximum)
	if type(value) ~= "number" or value ~= value or math.abs(value) == math.huge then return fallback end
	return math.clamp(math.floor(value), 0, maximum)
end

local function offlineReward(saved, profile, now)
	local config = Catalog.offline
	local elapsed = math.min(now - integer(saved.savedAt, now, now), config.maximumSeconds)
	if elapsed < config.minimumSeconds then return 0 end
	local rate = 0
	for _, cargo in ipairs(profile.inventory) do
		rate += Catalog.rate(cargo)
	end
	rate = math.floor(rate * Catalog.incomeFactor(profile))
	return math.min(MAX_CASH - profile.cash, math.floor(rate * elapsed * config.share))
end

function DataService.Decode(saved)
	saved = type(saved) == "table" and saved or {}
	local contract = math.max(1, integer(saved.contract, 1, #Catalog.contracts))
	local result = {
		cash = integer(saved.cash, 90, MAX_CASH), bank = integer(saved.bank, 0, MAX_CASH),
		level = integer(saved.level, 0, #Catalog.upgrades), rebirths = integer(saved.rebirths, 0, Catalog.rebirthMax),
		speedLevel = integer(saved.speedLevel, 0, #Catalog.utilityUpgrades.Speed.costs),
		carryLevel = integer(saved.carryLevel, integer(saved.speedLevel, 0, #Catalog.utilityUpgrades.Carry.costs), #Catalog.utilityUpgrades.Carry.costs),
		shieldLevel = integer(saved.shieldLevel, 0, #Catalog.utilityUpgrades.Shield.costs),
		slotsLevel = integer(saved.slotsLevel, 0, #Catalog.utilityUpgrades.Slots.costs),
		milestone = integer(saved.milestone, 0, #Catalog.indexMilestones),
		guide = math.max(1, integer(saved.guide, 1, 4)), crew = integer(saved.crew, 0, #Catalog.crews),
		contract = contract, progress = integer(saved.progress, 0, Catalog.contracts[contract].goal),
		index = {}, inventory = {}, tracks = {},
	}
	for id, track in ipairs(Catalog.contractTracks) do
		local record = type(saved.tracks) == "table" and saved.tracks[id]
		record = type(record) == "table" and record or {}
		local stage = math.max(1, integer(record.stage, 1, #track.stages))
		result.tracks[id] = { stage = stage, progress = integer(record.progress, 0, track.stages[stage].goal) }
	end
	if type(saved.index) == "table" then
		for _, key in ipairs(saved.index) do
			if type(key) == "number" and key % 1 == 0 and key >= 1 and key <= #Catalog.entries * #Catalog.mutations then
				result.index[key] = true
			end
		end
	end
	if type(saved.inventory) == "table" then
		for position = 1, math.min(#saved.inventory, Catalog.slotCount(result)) do
			local cargo = saved.inventory[position]
			if type(cargo) == "table" and type(cargo.id) == "number" and Catalog.entries[cargo.id]
				and type(cargo.mutation) == "number" and Catalog.mutations[cargo.mutation] then
				table.insert(result.inventory, { id = cargo.id, mutation = cargo.mutation })
			end
		end
	end
	return result
end

function DataService.Encode(state)
	if state.previewSaved then return table.clone(state.previewSaved) end
	local saved = {
		version = VERSION, cash = state.cash, bank = state.bank, level = state.level,
		rebirths = state.rebirths, guide = state.guide, crew = state.crew,
		speedLevel = state.speedLevel or 0, shieldLevel = state.shieldLevel or 0, milestone = state.milestone or 0,
		carryLevel = state.carryLevel or 0, slotsLevel = state.slotsLevel or 0,
		contract = state.contract, progress = state.progress, index = {}, inventory = {}, tracks = {},
	}
	for id, track in ipairs(state.tracks) do saved.tracks[id] = table.clone(track) end
	for key in pairs(state.index) do table.insert(saved.index, key) end
	table.sort(saved.index)
	for _, slot in ipairs(state.bay.slots) do
		-- Reserved cargo still belongs to its source until the thief docks it.
		local cargo = slot.cargo or slot.reserved
		if cargo then table.insert(saved.inventory, { id = cargo.id, mutation = cargo.mutation }) end
	end
	if state.carry and not state.carry.source then
		if #saved.inventory < #state.bay.slots then
			table.insert(saved.inventory, { id = state.carry.id, mutation = state.carry.mutation })
		else
			saved.cash += math.floor(Catalog.price(state.carry) / 2)
		end
	end
	return saved
end

function DataService.new()
	local self = setmetatable({ sessions = {} }, DataService)
	local ok, store = pcall(function() return DataStoreService:GetDataStore("RotOrbit2_Profile_v1") end)
	if ok then self.store = store end
	return self
end

function DataService:Load(player, state)
	local session = { token = HttpService:GenerateGUID(false), key = "player_" .. player.UserId, state = state }
	self.sessions[player] = session
	local blocked, offline = nil, 0
	local ok, saved = pcall(function()
		if not self.store then error("DataStore unavailable") end
		return self.store:UpdateAsync(session.key, function(previous)
			blocked, offline = nil, 0
			previous = type(previous) == "table" and previous or { version = VERSION }
			if type(previous.version) == "number" and previous.version > VERSION then
				blocked = "Your progress needs a newer server. Please rejoin."; return nil
			end
			local lease = previous.lease
			if type(lease) == "table" and lease.token ~= session.token
				and type(lease.expires) == "number" and lease.expires > os.time() then
				blocked = "Your bay is saving in another server. Rejoin shortly."; return nil
			end
			local now = os.time()
			local profile = DataService.Decode(previous)
			offline = offlineReward(previous, profile, now)
			-- Redeem the saved interval in the same write as the lease.
			previous.cash = profile.cash + offline
			previous.savedAt = nil
			previous.lease = { token = session.token, expires = now + LEASE_SECONDS }
			return previous
		end)
	end)
	if ok and blocked then return nil, blocked end
	if ok and type(saved) == "table" then
		session.writable = true
		state.saveStatus = "Saved"
		return DataService.Decode(saved), nil, offline
	end
	state.saveStatus = "Session only"
	warn("ROT ORBIT: saving unavailable; this session will not overwrite stored progress.")
	return DataService.Decode(nil)
end

function DataService:Save(player, release)
	local session = self.sessions[player]
	if not session then return true end
	if release then
		local deadline = os.clock() + 8
		while session.saving and os.clock() < deadline do task.wait(.05) end
	end
	if session.saving then return false end
	local state = session.state
	if not session.writable or state.loading then
		if release and not state.loading then self.sessions[player] = nil end
		return false
	end
	session.saving = true
	local saved = DataService.Encode(state)
	saved.savedAt = os.time()
	if not release then saved.lease = { token = session.token, expires = os.time() + LEASE_SECONDS } end
	local success, lostLease = false, false
	for attempt = 1, 3 do
		local ok, result = pcall(function()
			return self.store:UpdateAsync(session.key, function(previous)
				if type(previous) ~= "table" or type(previous.lease) ~= "table" or previous.lease.token ~= session.token then
					lostLease = true; return nil
				end
				return saved
			end)
		end)
		if ok and result then success = true; break end
		if lostLease then break end
		if attempt < 3 then task.wait(attempt) end
	end
	session.saving = false
	state.saveStatus = success and "Saved" or "Retrying save"
	player:SetAttribute("SaveStatus", state.saveStatus)
	if lostLease then
		session.writable = false
		state.loading = true
		if player.Parent then player:Kick("Your progress opened in another server. Rejoin to keep it safe.") end
	end
	if release and success then self.sessions[player] = nil end
	return success
end

-- A player leaving during Load must release the lease without writing defaults.
function DataService:Abandon(player)
	local session = self.sessions[player]
	if not session then return end
	if session.writable then
		pcall(function()
			self.store:UpdateAsync(session.key, function(previous)
				if type(previous) == "table" and type(previous.lease) == "table" and previous.lease.token == session.token then
					previous.lease = nil
					return previous
				end
				return nil
			end)
		end)
	end
	self.sessions[player] = nil
end

return DataService
