-- Keep the existing Orbit paths so live clients and saved places remain compatible.
-- Requiring this module on a client never creates a network instance.
local RunService = game:GetService("RunService")
local Orbit = game:GetService("ReplicatedStorage"):WaitForChild("Orbit")
local Remotes = {}
local registry

Remotes.Definitions = table.freeze({
	Action = "RemoteEvent",
	Screenshot = "RemoteEvent",
	Meteor = "RemoteEvent",
})

Remotes.Actions = table.freeze({
	Zap = "Zap", Blink = "Blink", Sprint = "Sprint", Crew = "Crew",
	Upgrade = "Upgrade", Rebirth = "Rebirth", Recycle = "Recycle",
	Contract = "Contract", ContractSkip = "ContractSkip", Screenshot = "Screenshot",
})

function Remotes.Get()
	if registry then return registry end
	local result = {}
	for name, className in pairs(Remotes.Definitions) do
		local remote = Orbit:FindFirstChild(name)
		if not remote and RunService:IsServer() then
			remote = Instance.new(className)
			remote.Name = name
			remote.Parent = Orbit
		end
		remote = remote or Orbit:WaitForChild(name)
		assert(remote:IsA(className), "Orbit remote has the wrong class: " .. name)
		result[name] = remote
	end
	registry = table.freeze(result)
	return registry
end

return table.freeze(Remotes)
