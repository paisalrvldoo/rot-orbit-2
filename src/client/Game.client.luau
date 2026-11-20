local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local orbit = ReplicatedStorage:WaitForChild("Orbit")
local Catalog = require(orbit:WaitForChild("Catalog"))
local Remotes = require(orbit:WaitForChild("Remotes"))
local actions = Remotes.Actions
local ScreenshotMode = require(orbit:WaitForChild("ScreenshotMode"))
local HudLayout = require(script.Parent:WaitForChild("HudLayout"))
local action = Remotes.Get().Action
local menuOpen = false

local gui = Instance.new("ScreenGui")
gui.Name = "OrbitHUD"
gui.ResetOnSpawn = false
gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
gui.Parent = player:WaitForChild("PlayerGui")

local ink = Color3.fromRGB(10, 17, 32)
local cyan = Color3.fromRGB(94, 237, 255)
local gold = Color3.fromRGB(255, 224, 102)
local white = Color3.fromRGB(234, 247, 255)
local muted = Color3.fromRGB(147, 174, 190)

local function number(value)
	value = value or 0
	for _, unit in ipairs({ { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } }) do
		if value >= unit[1] then return string.format("%.1f%s", value / unit[1], unit[2]) end
	end
	return tostring(math.floor(value))
end

local function panel(class, parent, size, pos, anchor)
	local item = Instance.new(class)
	item.Size = size
	item.Position = pos
	item.AnchorPoint = anchor
	item.BackgroundColor3 = ink
	item.BackgroundTransparency = .12
	item.BorderSizePixel = 0
	item.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = item
	local stroke = Instance.new("UIStroke")
	stroke.Color = cyan
	stroke.Transparency = .6
	stroke.Thickness = 1
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = item
	return item
end

local function label(parent, size, pos, color, textSize, align)
	local item = Instance.new("TextLabel")
	item.Size = size
	item.Position = pos
	item.BackgroundTransparency = 1
	item.TextColor3 = color
	item.Font = Enum.Font.GothamBold
	item.TextSize = textSize
	item.TextXAlignment = align or Enum.TextXAlignment.Center
	item.TextTruncate = Enum.TextTruncate.AtEnd
	item.Parent = parent
	return item
end

local wallet = panel("Frame", gui, UDim2.fromOffset(280, 68), UDim2.new(.5, 0, 0, 10), Vector2.new(.5, 0))
local cash = label(wallet, UDim2.new(1, -20, 0, 32), UDim2.fromOffset(10, 2), gold, 24, Enum.TextXAlignment.Left)
local bank = label(wallet, UDim2.new(1, -20, 0, 28), UDim2.fromOffset(10, 34), cyan, 14, Enum.TextXAlignment.Left)
local guideBox = panel("Frame", gui, UDim2.new(1, -24, 0, 56), UDim2.new(.5, 0, 0, 86), Vector2.new(.5, 0))
local maxGuide = Instance.new("UISizeConstraint")
maxGuide.MaxSize = Vector2.new(500, 56)
maxGuide.Parent = guideBox
local guide = label(guideBox, UDim2.new(1, -18, 1, 0), UDim2.fromOffset(9, 0), white, 14)
guide.TextWrapped = true
guide.TextTruncate = Enum.TextTruncate.None
local notice = label(gui, UDim2.new(1, -32, 0, 44), UDim2.new(.5, 0, 0, 146), gold, 15)
notice.AnchorPoint = Vector2.new(.5, 0)
notice.TextWrapped = true
notice.TextTruncate = Enum.TextTruncate.None
notice.Text = ""
notice.TextStrokeTransparency = .25
local incident = label(gui, UDim2.new(1, -24, 0, 32), UDim2.new(.5, 0, 0, 192), gold, 14)
incident.AnchorPoint = Vector2.new(.5, 0)
incident.TextWrapped = true
incident.TextTruncate = Enum.TextTruncate.None
local skillBar = Instance.new("Frame")
skillBar.Name = "Skills"
skillBar.BackgroundTransparency = 1
skillBar.Size = UDim2.fromOffset(100, 160)
skillBar.Position = UDim2.new(1, -10, .57, 0)
skillBar.AnchorPoint = Vector2.new(1, .5)
skillBar.Parent = gui
local zap = panel("TextButton", skillBar, UDim2.fromOffset(100, 48), UDim2.fromOffset(0, 0), Vector2.zero)
zap.Font = Enum.Font.GothamBold
zap.TextSize = 16
zap.TextColor3 = cyan
zap.Activated:Connect(function() action:FireServer(actions.Zap) end)
local blink = panel("TextButton", skillBar, UDim2.fromOffset(100, 48), UDim2.fromOffset(0, 56), Vector2.zero)
local sprint = panel("TextButton", skillBar, UDim2.fromOffset(100, 48), UDim2.fromOffset(0, 112), Vector2.zero)
for name, control in pairs({ Blink = blink, Sprint = sprint }) do
	control.Font = Enum.Font.GothamBold
	control.TextSize = 15
	control.TextColor3 = cyan
	control.Activated:Connect(function() action:FireServer(name) end)
end
UserInputService.InputBegan:Connect(function(input, processed)
	if menuOpen then return end
	if not processed and (input.KeyCode == Enum.KeyCode.Q or input.KeyCode == Enum.KeyCode.ButtonY) then
		action:FireServer(actions.Zap)
	elseif not processed and (input.KeyCode == Enum.KeyCode.F or input.KeyCode == Enum.KeyCode.ButtonB) then
		action:FireServer(actions.Blink)
	elseif not processed and (input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.ButtonL3) then
		action:FireServer(actions.Sprint)
	end
end)

local prompts = {}
local function refreshPrompt(prompt)
	local kind = prompt:GetAttribute("OrbitPrompt")
	local owner = prompt:GetAttribute("Owner") or 0
	local mine = owner == player.UserId
	local carrying = (player:GetAttribute("Carry") or "") ~= ""
	local occupied = prompt:GetAttribute("Occupied")
	local crew = player:GetAttribute("CrewId") or 0
	local friendly = crew > 0 and prompt:GetAttribute("Crew") == crew
	local sealed = workspace:GetServerTimeNow() < (prompt:GetAttribute("LockedUntil") or 0)
	local usable = not player:GetAttribute("Loading") and ((kind == "Owner" and mine)
		or (kind == "Slot" and owner ~= 0 and ((mine and not occupied and carrying) or (not mine and not friendly and not sealed and occupied and not carrying)))
	)
	prompt.MaxActivationDistance = usable and 9 or 0
end
local function watchPrompt(instance)
	if not instance:IsA("ProximityPrompt") or not instance:GetAttribute("OrbitPrompt") then return end
	prompts[instance] = true
	for _, key in ipairs({ "Owner", "Occupied", "Crew", "LockedUntil" }) do
		instance:GetAttributeChangedSignal(key):Connect(function() refreshPrompt(instance) end)
	end
	instance.Destroying:Connect(function() prompts[instance] = nil end)
	refreshPrompt(instance)
end
workspace.DescendantAdded:Connect(watchPrompt)
for _, instance in ipairs(workspace:GetDescendants()) do watchPrompt(instance) end
player:GetAttributeChangedSignal("Carry"):Connect(function()
	for prompt in pairs(prompts) do refreshPrompt(prompt) end
end)

local function renderIncident()
	local raid = workspace:GetAttribute("Raid") or ""
	local text = raid ~= "" and raid or (workspace:GetAttribute("Event") or ""):upper()
	local deadline = workspace:GetAttribute(raid ~= "" and "RaidEndsAt" or "EventEndsAt") or 0
	if raid ~= "" then text ..= "  •  " .. (workspace:GetAttribute("RaidHealth") or 0) .. " HP" end
	if text ~= "" and deadline > 0 then text ..= "  •  " .. math.max(0, math.ceil(deadline - workspace:GetServerTimeNow())) .. "s" end
	incident.Text = text
end
workspace:GetAttributeChangedSignal("Raid"):Connect(renderIncident)
workspace:GetAttributeChangedSignal("Event"):Connect(renderIncident)
renderIncident()
local function updateSkills()
	local compactLabels = UserInputService.TouchEnabled or (gui.AbsoluteSize.X > gui.AbsoluteSize.Y and gui.AbsoluteSize.Y < 500)
	local cooldown = math.ceil((player:GetAttribute("ZapReady") or 0) - workspace:GetServerTimeNow())
	zap.Text = cooldown > 0 and "ZAP  " .. cooldown .. "s" or (compactLabels and "ZAP" or "ZAP  [Q]")
	local now = workspace:GetServerTimeNow()
	local blinkCooldown = math.max(0, math.ceil((player:GetAttribute("BlinkReady") or 0) - now))
	local sprintCooldown = math.max(0, math.ceil((player:GetAttribute("SprintReady") or 0) - now))
	blink.Text = blinkCooldown > 0 and "BLINK " .. blinkCooldown .. "s" or (compactLabels and "BLINK" or "BLINK [F]")
	sprint.Text = now < (player:GetAttribute("SprintUntil") or 0) and "RUNNING"
		or (sprintCooldown > 0 and "RUN " .. sprintCooldown .. "s" or (compactLabels and "SPRINT" or "RUN [SHIFT]"))
	for _, pair in ipairs({ { zap, cooldown }, { blink, blinkCooldown }, { sprint, sprintCooldown } }) do
		local ready = pair[2] <= 0 and player:GetAttribute("Bay") ~= nil and not player:GetAttribute("Loading")
		pair[1].Interactable = ready
		pair[1].TextColor3 = ready and cyan or muted
	end
end

local function render()
	local bay = player:GetAttribute("Bay")
	local stage = player:GetAttribute("Guide") or 0
	local carried = player:GetAttribute("Carry") or ""
	cash.Text = "$" .. number(player:GetAttribute("Cash"))
	bank.Text = "$" .. number(player:GetAttribute("Unclaimed")) .. " banked   •   +" .. number(player:GetAttribute("Income")) .. "/s"
	if stage == 0 then
		guide.Text = player:GetAttribute("Loading") and "Loading your saved docking bay…" or "Waiting for a free docking bay"
	elseif carried ~= "" then
		guide.Text = "Dock " .. carried .. " at Bay " .. bay
	elseif stage == 1 then
		guide.Text = "1  /  Walk to the glowing rail and buy a Common"
	elseif stage <= 3 then
		guide.Text = "3  /  Collect banked credits at Bay " .. bay
	else
		local remainder = math.ceil((player:GetAttribute("LockedUntil") or 0) - workspace:GetServerTimeNow())
		local recharge = math.max(0, math.ceil((player:GetAttribute("LockReady") or 0) - workspace:GetServerTimeNow()))
		local crew = Catalog.crews[player:GetAttribute("CrewId") or 0]
		guide.Text = "BAY " .. bay .. "  •  " .. (crew and crew.name or "SOLO") .. "\n"
			.. (remainder > 0 and ("SEALED " .. remainder .. "s  •  Cargo protected")
				or (recharge > 0 and ("Lock recharges in " .. recharge .. "s  •  Collect credits") or "Lock ready  •  Collect credits and upgrade"))
	end
end

local fades = {}
local menuNotice
player:GetAttributeChangedSignal("OrbitMessageId"):Connect(function()
	for _, fade in ipairs(fades) do fade:Cancel() end
	table.clear(fades)
	for _, target in ipairs({ notice, menuNotice }) do
		target.Text = player:GetAttribute("OrbitMessage") or ""
		target.TextTransparency = 0
		target.TextStrokeTransparency = .25
		local fade = TweenService:Create(target, TweenInfo.new(.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 4),
			{ TextTransparency = 1, TextStrokeTransparency = 1 })
		table.insert(fades, fade)
		fade:Play()
	end
end)
for _, key in ipairs({ "Cash", "Unclaimed", "Income", "Carry", "Bay", "Guide", "LockedUntil" }) do
	player:GetAttributeChangedSignal(key):Connect(render)
end
render()
task.spawn(function()
	while gui.Parent do
		updateSkills()
		render()
		renderIncident()
		for prompt in pairs(prompts) do refreshPrompt(prompt) end
		task.wait(.2)
	end
end)

local function button(parent, words, size, pos)
	local control = panel("TextButton", parent, size, pos, Vector2.zero)
	control.Font = Enum.Font.GothamBold
	control.TextColor3 = cyan
	control.TextSize = 14
	control.Text = words
	control.TextWrapped = true
	control.TextTruncate = Enum.TextTruncate.AtEnd
	return control
end

local menuButton = button(gui, "LOGBOOK  [I]", UDim2.fromOffset(150, 48), UDim2.new(.5, 0, 1, -64))
menuButton.AnchorPoint = Vector2.new(.5, 0)
local menu = panel("Frame", gui, UDim2.new(.94, 0, .84, 0), UDim2.fromScale(.5, .5), Vector2.new(.5, .5))
menu.Visible = false
menu.ZIndex = 2
local maxMenu = Instance.new("UISizeConstraint")
maxMenu.MaxSize = Vector2.new(540, 520)
maxMenu.Parent = menu
local title = label(menu, UDim2.new(1, -77, 0, 40), UDim2.fromOffset(15, 7), white, 21, Enum.TextXAlignment.Left)
title.Text = "STATION LOGBOOK"
title.ZIndex = 3
local close = button(menu, "×", UDim2.fromOffset(44, 44), UDim2.new(1, -51, 0, 6))
close.ZIndex = 3
local tabs = { "Index", "Upgrades", "Contracts", "Crews" }
local active = "Index"
local screenshotScene
local content = Instance.new("ScrollingFrame")
content.Size = UDim2.new(1, -24, 1, -166)
content.Position = UDim2.fromOffset(12, 101)
content.AutomaticCanvasSize = Enum.AutomaticSize.Y
content.CanvasSize = UDim2.fromOffset(0, 0)
content.ScrollingDirection = Enum.ScrollingDirection.Y
content.ScrollBarThickness = 4
content.ScrollBarImageColor3 = cyan
content.BackgroundTransparency = 1
content.BorderSizePixel = 0
content.ZIndex = 3
content.Parent = menu
local list = Instance.new("UIListLayout")
list.Padding = UDim.new(0, 6)
list.Parent = content
menuNotice = label(menu, UDim2.new(1, -24, 0, 50), UDim2.new(0, 12, 1, -58), gold, 14)
menuNotice.Text = ""
menuNotice.TextWrapped = true
menuNotice.TextTruncate = Enum.TextTruncate.None
menuNotice.ZIndex = 4

local tabButtons = {}
local confirmation
local function line(words, color, height)
	local row = label(content, UDim2.new(1, -9, 0, height or 30), UDim2.fromOffset(0, 0),
		color, 15, Enum.TextXAlignment.Left)
	row.Text = words
	row.TextWrapped = true
	row.TextTruncate = Enum.TextTruncate.None
	row.AutomaticSize = Enum.AutomaticSize.Y
	local minimum = Instance.new("UISizeConstraint")
	minimum.MinSize = Vector2.new(0, height or 44)
	minimum.Parent = row
	row.ZIndex = 4
	return row
end

local function menuRow(words)
	local row = button(content, words, UDim2.new(1, -9, 0, 46), UDim2.fromOffset(0, 0))
	row.ZIndex = 4
	row.Interactable = not player:GetAttribute("Loading")
	row.TextTransparency = row.Interactable and 0 or .45
	return row
end

local refreshMenu
local function confirmButton(words, confirm, request)
	local row = menuRow(confirmation == request and confirm or words)
	row.Activated:Connect(function()
		if confirmation == request then
			confirmation = nil
			action:FireServer(request)
		else
			confirmation = request
			refreshMenu()
		end
	end)
end

refreshMenu = function()
	if not menu.Visible then return end
	for _, item in ipairs(content:GetChildren()) do
		if item ~= list then item:Destroy() end
	end
	for tab, control in pairs(tabButtons) do
		control.TextColor3 = tab == active and gold or cyan
	end
	if active == "Index" then
		local seen = {}
		for key in (player:GetAttribute("Index") or ""):gmatch("%d+") do seen[tonumber(key)] = true end
		if screenshotScene == "Index" and RunService:IsStudio() then
			for _, entry in ipairs(Catalog.entries) do seen[Catalog.discoveryKey({ id = entry.id, mutation = 1 })] = true end
			for mutation = 2, #Catalog.mutations do seen[Catalog.discoveryKey({ id = 44, mutation = mutation })] = true end
			line("STUDIO CATALOG PREVIEW", gold)
		end
		local count, mutations = Catalog.discoveryCount(seen)
		line(count .. " / " .. #Catalog.entries .. " discovered   •   " .. mutations .. " mutations", gold)
		local milestone = Catalog.indexMilestones[(player:GetAttribute("IndexMilestone") or 0) + 1]
		if milestone then line("Next index bonus: " .. milestone.goal .. " names → $" .. number(milestone.reward), white) end
		local variants = {}
		for mutation = 2, #Catalog.mutations do
			local variant = Catalog.mutations[mutation]
			table.insert(variants, variant.name .. " ×" .. variant.factor)
		end
		line(Catalog.mutationCount .. " mutations: " .. table.concat(variants, "  •  "), cyan, 64)
		for _, entry in ipairs(Catalog.entries) do
			local versions = {}
			for mutation, variant in ipairs(Catalog.mutations) do
				if seen[Catalog.discoveryKey({ id = entry.id, mutation = mutation })] then
					table.insert(versions, mutation == 1 and "Standard" or variant.name)
				end
			end
			local tier = Catalog.tiers[entry.tier]
			local words = #versions == 0 and "???   /   " .. tier.name
				or (entry.name .. "   /   " .. table.concat(versions, ", "))
			line(words, tier.color)
		end
	elseif active == "Upgrades" then
		local level = player:GetAttribute("Upgrade") or 0
		local rebirths = player:GetAttribute("Rebirths") or 0
		local cost = Catalog.upgrades[level + 1]
		line("Progress: " .. (player:GetAttribute("SaveStatus") or "Loading") .. "  •  autosave every " .. Catalog.autosaveSeconds .. "s", cyan)
		line("Dock amplifier  /  Level " .. level .. " of " .. #Catalog.upgrades, gold)
		line("Each level adds 25% base dock income.", white)
		if cost then
			menuRow("UPGRADE   $" .. cost).Activated:Connect(function()
				action:FireServer(actions.Upgrade)
			end)
		end
		for _, kind in ipairs({ "Speed", "Shield" }) do
			local definition = Catalog.utilityUpgrades[kind]
			local utilityLevel = player:GetAttribute(kind .. "Upgrade") or 0
			local price = definition.costs[utilityLevel + 1]
			line(definition.name .. "  /  " .. utilityLevel .. " of " .. #definition.costs, gold)
			line(definition.detail, white)
			if price then
				menuRow("UPGRADE " .. kind:upper() .. "  $" .. number(price)).Activated:Connect(function() action:FireServer(actions.Upgrade, kind) end)
			end
		end
		line("Shield protects for " .. (player:GetAttribute("LockDuration") or 32) .. "s. Rebirth 2 unlocks longer Blink.", cyan, 48)
		line("Rebirths  /  " .. rebirths, gold)
		line("Keep your best cargo and all discoveries. Reset other cargo, credits and upgrades for +25% base income and +2s shield.", white, 72)
		if rebirths < Catalog.rebirthMax then
			line("Requires a docked " .. Catalog.tiers[Catalog.rebirthTier(rebirths)].name .. " or better.", cyan)
			confirmButton("REBIRTH   $" .. number(Catalog.rebirthCost(rebirths)), "CONFIRM REBIRTH", actions.Rebirth)
		else
			line("ORBIT ACE  •  All 10 rebirths complete", gold)
		end
		line("Free a slot by scrapping your lowest earner for half its market price.", white, 43)
		confirmButton("RECYCLE WEAKEST CARGO", "CONFIRM RECYCLE", actions.Recycle)
	elseif active == "Contracts" then
		local contract = Catalog.contracts[player:GetAttribute("Contract") or 1]
		local progress = player:GetAttribute("ContractProgress") or 0
		line(contract.title .. "   /   $" .. contract.reward .. " reward", gold)
		line(contract.detail .. "   •   " .. progress .. " / " .. contract.goal, white)
		if progress >= contract.goal then
			menuRow("CLAIM REWARD").Activated:Connect(function() action:FireServer(actions.Contract) end)
		else
			menuRow("SKIP CONTRACT  $90").Activated:Connect(function() action:FireServer(actions.ContractSkip) end)
		end
		line("Next: " .. Catalog.contracts[(player:GetAttribute("Contract") or 1) % #Catalog.contracts + 1].title, cyan)
		line("Contracts cycle through cargo, credits, raids, mutations and rebirths. Claim each finished reward here.", white, 72)
	elseif active == "Crews" then
		local current = player:GetAttribute("CrewId") or 0
		line("Play Solo or join a squad", gold)
		line("Squadmates cannot steal or zap each other's cargo. Server scores: +2 new discovery, +5 shield defence, +10 gremlin, +30 boss. Nearby squadmates earn $20 assists.", white, 100)
		line("Your defence score: " .. (player:GetAttribute("PersonalScore") or 0), gold)
		menuRow(current == 0 and "SOLO  •  ACTIVE" or "PLAY SOLO").Activated:Connect(function() action:FireServer(actions.Crew, 0) end)
		for id, crew in ipairs(Catalog.crews) do
			local points = workspace:GetAttribute("CrewScore" .. id) or 0
			local members = workspace:GetAttribute("CrewMembers" .. id) or 0
			local row = menuRow((current == id and "✓ " or "JOIN ") .. crew.name .. "  •  " .. points .. " pts / " .. members)
			row.TextColor3 = crew.color
			row.Activated:Connect(function() action:FireServer(actions.Crew, id) end)
		end
		line("Crew changes recharge for 30s. Finish raids and recover missing cargo first.", white, 50)
	end
end

local function openMenu(tab)
	active = tab
	confirmation = nil
	menu.Visible = true
	content.CanvasPosition = Vector2.zero
	refreshMenu()
end

local function layout()
	local size = gui.AbsoluteSize
	if size.X <= 0 or size.Y <= 0 then return end
	local geometry = HudLayout.Calculate(size.X, size.Y)
	wallet.Size = UDim2.fromOffset(geometry.walletWidth, geometry.walletHeight)
	wallet.Position = UDim2.fromOffset(geometry.walletX, geometry.walletY)
	bank.Size = UDim2.new(1, -20, 0, geometry.walletHeight - 36)
	guideBox.Position = UDim2.fromOffset(geometry.guideX, geometry.guideY)
	guideBox.Size = UDim2.fromOffset(geometry.guideWidth, geometry.guideHeight)
	notice.Position = UDim2.new(.5, 0, 0, geometry.noticeY)
	notice.Size = UDim2.new(1, -32, 0, geometry.noticeHeight)
	incident.Position = UDim2.new(.5, 0, 0, geometry.incidentY)
	incident.Size = UDim2.new(1, -24, 0, geometry.incidentHeight)
	menu.Size = UDim2.new(1, -24, 1, -24)
	menuButton.Text = (UserInputService.TouchEnabled or geometry.landscape) and "LOGBOOK" or "LOGBOOK  [I]"
	menuButton.AnchorPoint = Vector2.zero
	menuButton.Size = UDim2.fromOffset(geometry.menuWidth, geometry.controlHeight)
	menuButton.Position = UDim2.fromOffset(geometry.menuX, geometry.menuY)
	title.TextSize = size.X < 400 and 17 or 21
	skillBar.AnchorPoint = Vector2.zero
	skillBar.Size = UDim2.fromOffset(geometry.landscape and 3 * geometry.controlWidth + 16 or geometry.controlWidth, geometry.landscape and 48 or 160)
	skillBar.Position = UDim2.fromOffset(geometry.skillsX, geometry.skillsY)
	for index, control in ipairs({ zap, blink, sprint }) do
		control.Size = UDim2.fromOffset(geometry.controlWidth, geometry.controlHeight)
		control.TextSize = geometry.controlWidth < 90 and 14 or 15
		control.Position = UDim2.fromOffset(geometry.landscape and (index - 1) * (geometry.controlWidth + 8) or 0, geometry.landscape and 0 or (index - 1) * 56)
	end
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
layout()

for index, tab in ipairs(tabs) do
	local tabButton = button(menu, tab, UDim2.new(1 / #tabs, -8, 0, 44), UDim2.new((index - 1) / #tabs, 4, 0, 52))
	tabButton.ZIndex = 3
	tabButton.TextSize = 13
	tabButtons[tab] = tabButton
	tabButton.Activated:Connect(function() openMenu(tab) end)
end
menuButton.Activated:Connect(function()
	if menu.Visible then menu.Visible = false else openMenu("Index") end
end)
close.Activated:Connect(function() menu.Visible = false end)
menu:GetPropertyChangedSignal("Visible"):Connect(function()
	menuOpen = menu.Visible
	wallet.Visible = not menu.Visible
	guideBox.Visible = not menu.Visible
	notice.Visible = not menu.Visible
	incident.Visible = not menu.Visible
	skillBar.Visible = not menu.Visible
	menuButton.Visible = not menu.Visible
end)
for _, key in ipairs({ "Index", "Upgrade", "SpeedUpgrade", "ShieldUpgrade", "Rebirths", "Contract", "ContractProgress", "CrewId", "PersonalScore", "SaveStatus", "IndexMilestone", "Cash" }) do
	player:GetAttributeChangedSignal(key):Connect(refreshMenu)
end
player:GetAttributeChangedSignal("Loading"):Connect(function()
	for prompt in pairs(prompts) do refreshPrompt(prompt) end
	render()
	refreshMenu()
end)
player:GetAttributeChangedSignal("CrewId"):Connect(function()
	for prompt in pairs(prompts) do refreshPrompt(prompt) end
end)
for id in ipairs(Catalog.crews) do
	workspace:GetAttributeChangedSignal("CrewScore" .. id):Connect(refreshMenu)
	workspace:GetAttributeChangedSignal("CrewMembers" .. id):Connect(refreshMenu)
end

local cameraShots = {
	Cover = CFrame.lookAt(Vector3.new(1, 59, 77), Vector3.new(0, 1, -8)),
	Raid = CFrame.lookAt(Vector3.new(27, 14, 17), Vector3.new(44, 4, 0)),
}
local originalFov
ScreenshotMode.Listen(function(scene)
	local camera = workspace.CurrentCamera
	if not camera then return end
	originalFov = originalFov or camera.FieldOfView
	screenshotScene = scene
	menu.Visible = false
	if scene == "Reset" then
		camera.CameraType = Enum.CameraType.Custom
		camera.CameraSubject = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		camera.FieldOfView = originalFov
		wallet.Visible, guideBox.Visible, notice.Visible, incident.Visible, skillBar.Visible, menuButton.Visible = true, true, true, true, true, true
	elseif scene == "Index" or scene == "Upgrades" then
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = cameraShots.Cover
		openMenu(scene)
	else
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = cameraShots[scene]
		camera.FieldOfView = scene == "Cover" and 60 or 65
		wallet.Visible, guideBox.Visible, notice.Visible, incident.Visible, skillBar.Visible, menuButton.Visible = false, false, false, false, false, false
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.I then
		if menu.Visible then menu.Visible = false else openMenu("Index") end
	end
	if not RunService:IsStudio() or not workspace.CurrentCamera then return end
	local scene = ({ [Enum.KeyCode.One] = "Cover", [Enum.KeyCode.Two] = "Index", [Enum.KeyCode.Three] = "Raid", [Enum.KeyCode.Four] = "Upgrades", [Enum.KeyCode.Zero] = "Reset" })[input.KeyCode]
	if scene then ScreenshotMode.Select(scene) end
end)
