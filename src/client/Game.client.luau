local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local orbit = ReplicatedStorage:WaitForChild("Orbit")
local Catalog = require(orbit:WaitForChild("Catalog"))
local action = orbit:WaitForChild("Action")

local gui = Instance.new("ScreenGui")
gui.Name = "OrbitHUD"
gui.ResetOnSpawn = false
gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
gui.Parent = player:WaitForChild("PlayerGui")

local ink = Color3.fromRGB(10, 17, 32)
local cyan = Color3.fromRGB(94, 237, 255)
local gold = Color3.fromRGB(255, 224, 102)
local white = Color3.fromRGB(234, 247, 255)

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
local zap = panel("TextButton", gui, UDim2.fromOffset(100, 48), UDim2.new(1, -10, .63, 0), Vector2.new(1, .5))
zap.Font = Enum.Font.GothamBold
zap.TextSize = 16
zap.TextColor3 = cyan
zap.Activated:Connect(function() action:FireServer("Zap") end)
UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and (input.KeyCode == Enum.KeyCode.Q or input.KeyCode == Enum.KeyCode.ButtonY) then
		action:FireServer("Zap")
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
	local usable = (kind == "Owner" and mine)
		or (kind == "Slot" and owner ~= 0 and ((mine and not occupied and carrying) or (not mine and not friendly and occupied and not carrying)))
	prompt.MaxActivationDistance = usable and 9 or 0
end
local function watchPrompt(instance)
	if not instance:IsA("ProximityPrompt") or not instance:GetAttribute("OrbitPrompt") then return end
	prompts[instance] = true
	for _, key in ipairs({ "Owner", "Occupied", "Crew" }) do
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
	incident.Text = raid ~= "" and raid or (workspace:GetAttribute("Event") or ""):upper()
end
workspace:GetAttributeChangedSignal("Raid"):Connect(renderIncident)
workspace:GetAttributeChangedSignal("Event"):Connect(renderIncident)
renderIncident()
task.spawn(function()
	while gui.Parent do
		local cooldown = math.ceil((player:GetAttribute("ZapReady") or 0) - workspace:GetServerTimeNow())
		zap.Text = cooldown > 0 and "ZAP  " .. cooldown .. "s" or (UserInputService.TouchEnabled and "ZAP" or "ZAP  [Q]")
		task.wait(.2)
	end
end)

local function render()
	local bay = player:GetAttribute("Bay")
	local stage = player:GetAttribute("Guide") or 0
	local carried = player:GetAttribute("Carry") or ""
	cash.Text = "$" .. number(player:GetAttribute("Cash"))
	bank.Text = "$" .. number(player:GetAttribute("Unclaimed")) .. " banked   •   +" .. number(player:GetAttribute("Income")) .. "/s"
	if stage == 0 then
		guide.Text = "Waiting for a free docking bay"
	elseif carried ~= "" then
		guide.Text = "Dock " .. carried .. " at Bay " .. bay
	elseif stage == 1 then
		guide.Text = "1  /  Walk to the glowing rail and buy a Common"
	elseif stage <= 3 then
		guide.Text = "3  /  Collect banked credits at Bay " .. bay
	else
		local remainder = math.ceil((player:GetAttribute("LockedUntil") or 0) - workspace:GetServerTimeNow())
		guide.Text = remainder > 0 and ("BAY " .. bay .. "  /  SEALED " .. remainder .. "s")
			or ("BAY " .. bay .. "   /   Collect credits and buy rarer cargo")
	end
end

local fade
player:GetAttributeChangedSignal("OrbitMessageId"):Connect(function()
	if fade then fade:Cancel() end
	notice.Text = player:GetAttribute("OrbitMessage") or ""
	notice.TextTransparency = 0
	notice.TextStrokeTransparency = .25
	fade = TweenService:Create(notice, TweenInfo.new(.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 3),
		{ TextTransparency = 1, TextStrokeTransparency = 1 })
	fade:Play()
end)
for _, key in ipairs({ "Cash", "Unclaimed", "Income", "Carry", "Bay", "Guide", "LockedUntil" }) do
	player:GetAttributeChangedSignal(key):Connect(render)
end
render()

local function button(parent, words, size, pos)
	local control = panel("TextButton", parent, size, pos, Vector2.zero)
	control.Font = Enum.Font.GothamBold
	control.TextColor3 = cyan
	control.TextSize = 14
	control.Text = words
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
local content = Instance.new("ScrollingFrame")
content.Size = UDim2.new(1, -24, 1, -108)
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
	return row
end

local refreshMenu
local function confirmButton(words, confirm, request)
	local row = menuRow(confirmation == request and confirm or words)
	row.Activated:Connect(function()
		if confirmation == request then
			confirmation = nil
			action:FireServer(request)
			menu.Visible = false
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
		local count, mutations = 0, 0
		for _, entry in ipairs(Catalog.entries) do
			local discovered = false
			for mutation = 1, #Catalog.mutations do
				if seen[Catalog.discoveryKey({ id = entry.id, mutation = mutation })] then
					discovered = true
					if mutation > 1 then mutations += 1 end
				end
			end
			if discovered then count += 1 end
		end
		line(count .. " / " .. #Catalog.entries .. " discovered   •   " .. mutations .. " mutations", gold)
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
		line("Dock amplifier  /  Level " .. level .. " of " .. #Catalog.upgrades, gold)
		line("Each level adds 25% base dock income.", white)
		if cost then
			menuRow("UPGRADE   $" .. cost).Activated:Connect(function()
				action:FireServer("Upgrade")
				menu.Visible = false
			end)
		end
		line("Rebirths  /  " .. rebirths, gold)
		line("Reset cargo, credits and upgrades for a permanent 25% base income boost. Keep all discoveries.", white, 46)
		confirmButton("REBIRTH   $" .. Catalog.rebirthCost(rebirths), "CONFIRM REBIRTH", "Rebirth")
		line("Free a slot by scrapping your lowest earner for half its market price.", white, 43)
		confirmButton("RECYCLE WEAKEST CARGO", "CONFIRM RECYCLE", "Recycle")
	elseif active == "Contracts" then
		local contract = Catalog.contracts[player:GetAttribute("Contract") or 1]
		local progress = player:GetAttribute("ContractProgress") or 0
		line(contract.title .. "   /   $" .. contract.reward .. " reward", gold)
		line(contract.detail .. "   •   " .. progress .. " / " .. contract.goal, white)
		if progress >= contract.goal then
			menuRow("CLAIM REWARD").Activated:Connect(function() action:FireServer("Contract") end)
		end
	elseif active == "Crews" then
		local current = player:GetAttribute("CrewId") or 0
		line("Play Solo or join a squad", gold)
		line("Squadmates cannot steal or zap each other's cargo. Scores last for this server: +2 per new discovery, +10 per gremlin zap.", white, 72)
		line("Your defence score: " .. (player:GetAttribute("PersonalScore") or 0), gold)
		menuRow(current == 0 and "SOLO  •  ACTIVE" or "PLAY SOLO").Activated:Connect(function() action:FireServer("Crew", 0) end)
		for id, crew in ipairs(Catalog.crews) do
			local points = workspace:GetAttribute("CrewScore" .. id) or 0
			local members = workspace:GetAttribute("CrewMembers" .. id) or 0
			local row = menuRow((current == id and "✓ " or "JOIN ") .. crew.name .. "  •  " .. points .. " pts / " .. members)
			row.TextColor3 = crew.color
			row.Activated:Connect(function() action:FireServer("Crew", id) end)
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
	local short = size.Y < 500
	wallet.Size = UDim2.fromOffset(math.min(280, math.max(180, size.X - 24)), short and 58 or 68)
	guideBox.Position = UDim2.new(.5, 0, 0, short and 76 or 86)
	guideBox.Size = UDim2.new(1, -24, 0, short and 40 or 56)
	notice.Position = UDim2.new(.5, 0, 0, short and 118 or 146)
	notice.Size = UDim2.new(1, -32, 0, short and 32 or 44)
	incident.Position = UDim2.new(.5, 0, 0, short and 152 or 192)
	menu.Size = UDim2.new(1, -24, 1, -24)
	menuButton.Text = UserInputService.TouchEnabled and "LOGBOOK" or "LOGBOOK  [I]"
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
layout()

for index, tab in ipairs(tabs) do
	local tabButton = button(menu, tab, UDim2.new(1 / #tabs, -8, 0, 44), UDim2.new((index - 1) / #tabs, 4, 0, 52))
	tabButton.ZIndex = 3
	tabButtons[tab] = tabButton
	tabButton.Activated:Connect(function() openMenu(tab) end)
end
menuButton.Activated:Connect(function()
	if menu.Visible then menu.Visible = false else openMenu("Index") end
end)
close.Activated:Connect(function() menu.Visible = false end)
menu:GetPropertyChangedSignal("Visible"):Connect(function()
	wallet.Visible = not menu.Visible
	guideBox.Visible = not menu.Visible
	notice.Visible = not menu.Visible
	incident.Visible = not menu.Visible
	zap.Visible = not menu.Visible
	menuButton.Visible = not menu.Visible
end)
for _, key in ipairs({ "Index", "Upgrade", "Rebirths", "Contract", "ContractProgress", "CrewId", "PersonalScore" }) do
	player:GetAttributeChangedSignal(key):Connect(refreshMenu)
end
player:GetAttributeChangedSignal("CrewId"):Connect(function()
	for prompt in pairs(prompts) do refreshPrompt(prompt) end
end)
for id in ipairs(Catalog.crews) do
	workspace:GetAttributeChangedSignal("CrewScore" .. id):Connect(refreshMenu)
	workspace:GetAttributeChangedSignal("CrewMembers" .. id):Connect(refreshMenu)
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.I then
		if menu.Visible then menu.Visible = false else openMenu("Index") end
	end
	if not RunService:IsStudio() or not workspace.CurrentCamera then return end
	local camera = workspace.CurrentCamera
	if input.KeyCode == Enum.KeyCode.One then
		menu.Visible = false
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = CFrame.lookAt(Vector3.new(1, 59, 77), Vector3.new(0, 1, -8))
		wallet.Visible, guideBox.Visible, notice.Visible, incident.Visible, zap.Visible, menuButton.Visible = false, false, false, false, false, false
	elseif input.KeyCode == Enum.KeyCode.Two or input.KeyCode == Enum.KeyCode.Four then
		openMenu(input.KeyCode == Enum.KeyCode.Two and "Index" or "Upgrades")
	elseif input.KeyCode == Enum.KeyCode.Three then
		menu.Visible = false
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = CFrame.lookAt(Vector3.new(27, 14, 17), Vector3.new(44, 4, 0))
	elseif input.KeyCode == Enum.KeyCode.Zero then
		menu.Visible = false
		camera.CameraType = Enum.CameraType.Custom
		wallet.Visible, guideBox.Visible, notice.Visible, incident.Visible, zap.Visible, menuButton.Visible = true, true, true, true, true, true
	end
end)
