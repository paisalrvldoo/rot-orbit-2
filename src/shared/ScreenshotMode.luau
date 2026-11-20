-- Studio command bar: require(game.ReplicatedStorage.Orbit.ScreenshotMode).Index()
-- Cover / Index / Raid / Upgrades / Reset also accept a player or UserId on the server.
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Orbit = game:GetService("ReplicatedStorage"):WaitForChild("Orbit")
local ScreenshotMode = {}
local scenes = { Cover = true, Index = true, Raid = true, Upgrades = true, Reset = true }
local handler

function ScreenshotMode.Configure(callback)
	assert(RunService:IsStudio() and RunService:IsServer(), "Configure screenshot presets in a Studio server")
	handler = callback
end

function ScreenshotMode.Select(scene, target)
	assert(RunService:IsStudio(), "Screenshot presets are available in Studio")
	assert(scenes[scene], "Unknown screenshot preset")
	if RunService:IsServer() then
		if type(target) == "number" then target = Players:GetPlayerByUserId(target) end
		target = target or Players:GetPlayers()[1]
		assert(handler and target, "Start a Studio playtest with a player first")
		handler(scene, target)
	else
		Orbit:WaitForChild("Action"):FireServer("Screenshot", scene)
	end
end

function ScreenshotMode.Listen(callback)
	assert(RunService:IsClient(), "Listen from the client")
	return Orbit:WaitForChild("Screenshot").OnClientEvent:Connect(function(scene)
		if RunService:IsStudio() and scenes[scene] then callback(scene) end
	end)
end

function ScreenshotMode.Cover(target) ScreenshotMode.Select("Cover", target) end
function ScreenshotMode.Index(target) ScreenshotMode.Select("Index", target) end
function ScreenshotMode.Raid(target) ScreenshotMode.Select("Raid", target) end
function ScreenshotMode.Upgrades(target) ScreenshotMode.Select("Upgrades", target) end
function ScreenshotMode.Reset(target) ScreenshotMode.Select("Reset", target) end

return ScreenshotMode
