local Catalog = require(game:GetService("ReplicatedStorage"):WaitForChild("Orbit"):WaitForChild("Catalog"))
local ContractService = {}

local function matches(definition, kind, tier)
	return definition.kind == kind and tier >= (definition.minTier or 0)
end

function ContractService.Activity(state, kind, cargo, amount)
	local tier = cargo and Catalog.entries[cargo.id].tier or 0
	local contract = Catalog.contracts[state.contract]
	if matches(contract, kind, tier) then
		state.progress = math.min(contract.goal, state.progress + (amount or 1))
	end
	for id, track in ipairs(Catalog.contractTracks) do
		local progress = state.tracks[id]
		local stage = track.stages[progress.stage]
		if matches(stage, kind, tier) then
			progress.progress = math.min(stage.goal, progress.progress + (amount or 1))
		end
	end
end

function ContractService.Claim(state, id, skip)
	if id == nil then
		local contract = Catalog.contracts[state.contract]
		if skip then
			if state.progress >= contract.goal then return "Claim this completed contract first." end
			if state.cash < 90 then return "Need $90 to skip a contract." end
			state.cash -= 90
		else
			if state.progress < contract.goal then return "Contract is still in progress." end
			state.cash = math.min(Catalog.maxCash, state.cash + contract.reward)
		end
		state.contract = state.contract % #Catalog.contracts + 1
		state.progress = 0
		return skip and ("New contract / " .. Catalog.contracts[state.contract].title)
			or ("Contract complete / +$" .. contract.reward)
	end
	local track = type(id) == "number" and Catalog.contractTracks[id]
	if not track or skip then return "Choose a valid contract." end
	local progress = state.tracks[id]
	local stage = track.stages[progress.stage]
	if progress.progress < stage.goal then return "Contract is still in progress." end
	state.cash = math.min(Catalog.maxCash, state.cash + stage.reward)
	progress.stage = progress.stage % #track.stages + 1
	progress.progress = 0
	return track.title .. " complete / +$" .. stage.reward
end

function ContractService.Publish(player, state)
	player:SetAttribute("Contract", state.contract)
	player:SetAttribute("ContractProgress", state.progress)
	for id, progress in ipairs(state.tracks) do
		player:SetAttribute("ContractTrack" .. id, progress.stage)
		player:SetAttribute("ContractTrackProgress" .. id, progress.progress)
	end
end

return ContractService
