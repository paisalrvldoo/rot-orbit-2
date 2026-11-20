local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "OrbitHUD"
gui.ResetOnSpawn = false
gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
gui.Parent = player:WaitForChild("PlayerGui")

local ink = Color3.fromRGB(10, 17, 32)
local cyan = Color3.fromRGB(94, 237, 255)
local gold = Color3.fromRGB(255, 224, 102)
local white = Color3.fromRGB(234, 247, 255)

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

local wallet = panel("Frame", gui, UDim2.fromOffset(168, 62), UDim2.new(1, -10, 0, 9), Vector2.new(1, 0))
local cash = label(wallet, UDim2.new(1, -20, 0, 32), UDim2.fromOffset(10, 2), gold, 24, Enum.TextXAlignment.Left)
local bank = label(wallet, UDim2.new(1, -20, 0, 24), UDim2.fromOffset(10, 31), cyan, 13, Enum.TextXAlignment.Left)
local guideBox = panel("Frame", gui, UDim2.new(.86, 0, 0, 42), UDim2.new(.5, 0, 0, 84), Vector2.new(.5, 0))
local maxGuide = Instance.new("UISizeConstraint")
maxGuide.MaxSize = Vector2.new(480, 42)
maxGuide.Parent = guideBox
local guide = label(guideBox, UDim2.new(1, -18, 1, 0), UDim2.fromOffset(9, 0), white, 14)
guide.TextWrapped = true
guide.TextTruncate = Enum.TextTruncate.None
local notice = label(gui, UDim2.new(.88, 0, 0, 32), UDim2.new(.5, 0, 0, 132), gold, 14)
notice.AnchorPoint = Vector2.new(.5, 0)
notice.Text = ""
notice.TextStrokeTransparency = .25

local function render()
	local bay = player:GetAttribute("Bay")
	local stage = player:GetAttribute("Guide") or 0
	local carried = player:GetAttribute("Carry") or ""
	cash.Text = "$" .. (player:GetAttribute("Cash") or 0)
	bank.Text = "$" .. (player:GetAttribute("Unclaimed") or 0) .. " banked   •   +" .. (player:GetAttribute("Income") or 0) .. "/s"
	if stage == 0 then
		guide.Text = "Waiting for a free docking bay"
	elseif carried ~= "" then
		guide.Text = "Dock " .. carried .. " at Bay " .. bay
	elseif stage == 1 then
		guide.Text = "1  /  Walk to the glowing rail and buy a Common"
	elseif stage <= 3 then
		guide.Text = "3  /  Collect banked credits at Bay " .. bay
	else
		guide.Text = "BAY " .. bay .. "   /   Collect credits and buy rarer cargo"
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
for _, key in ipairs({ "Cash", "Unclaimed", "Income", "Carry", "Bay", "Guide" }) do
	player:GetAttributeChangedSignal(key):Connect(render)
end
render()
