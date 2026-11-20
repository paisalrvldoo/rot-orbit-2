local BillboardLabels = {}
local ink = Color3.fromRGB(9, 13, 27)
local white = Color3.fromRGB(241, 250, 255)
local mint = Color3.fromRGB(144, 255, 193)
local gold = Color3.fromRGB(255, 213, 81)
local dockedAt = setmetatable({}, { __mode = "k" })
local styles = {
	LEGENDARY = { Color3.fromRGB(61, 42, 15), gold, "LEGENDARY" },
	MYTHIC = { Color3.fromRGB(62, 21, 45), Color3.fromRGB(255, 109, 161), "MYTHIC" },
	COSMIC = { Color3.fromRGB(16, 53, 62), Color3.fromRGB(168, 255, 239), "COSMIC" },
	SECRET = { Color3.fromRGB(57, 23, 67), gold, "[  S E C R E T  ]" },
}

local function text(parent, name, value, x, y, w, h, color, max, font)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Size = UDim2.fromScale(w, h)
	label.Position = UDim2.fromScale(x, y)
	label.BackgroundTransparency = 1
	label.Font = font or Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = color
	label.Text = value
	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MinTextSize = 10
	constraint.MaxTextSize = max
	constraint.Parent = label
	label.Parent = parent
	return label
end

local function credits(amount)
	local formatted = string.format("%.0f", math.floor(amount or 0)):reverse():gsub("(%d%d%d)", "%1,")
		:reverse():gsub("^,", "")
	return "$" .. formatted
end

local function makeCard(anchor, name, distance)
	local card = Instance.new("BillboardGui")
	card.Name = name
	card.Size = UDim2.fromOffset(168, 72)
	card.MaxDistance = distance
	card.AlwaysOnTop = false
	card.LightInfluence = 0
	card.Adornee = anchor

	local panel = Instance.new("Frame")
	panel.Name = "Readout"
	panel.Size = UDim2.fromScale(1, 1)
	panel.BackgroundColor3 = ink
	panel.BackgroundTransparency = .08
	panel.BorderSizePixel = 0
	panel.Parent = card
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = panel
	local outline = Instance.new("UIStroke")
	outline.Name = "RarityOutline"
	outline.Parent = panel
	local gradient = Instance.new("UIGradient")
	gradient.Name = "RarityGradient"
	gradient.Rotation = 25
	gradient.Parent = panel
	local edge = Instance.new("Frame")
	edge.Name = "RankStripe"
	edge.Size = UDim2.new(1, -10, 0, 2)
	edge.Position = UDim2.fromOffset(5, 0)
	edge.BorderSizePixel = 0
	edge.Parent = panel
	local crown = Instance.new("Frame")
	crown.Name = "SecretCrown"
	crown.Size = UDim2.fromOffset(16, 12)
	crown.Position = UDim2.fromOffset(8, 6)
	crown.BackgroundTransparency = 1
	crown.Visible = false
	crown.Parent = panel
	for i = -1, 1 do
		local point = Instance.new("Frame")
		point.Size = UDim2.fromOffset(3, i == 0 and 9 or 7)
		point.Position = UDim2.fromOffset((i + 1) * 5 + 1, i == 0 and 0 or 2)
		point.Rotation = i * 22
		point.BackgroundColor3 = gold
		point.BorderSizePixel = 0
		point.Parent = crown
	end
	local band = Instance.new("Frame")
	band.Size = UDim2.fromOffset(16, 3)
	band.Position = UDim2.fromOffset(0, 9)
	band.BackgroundColor3 = gold
	band.BorderSizePixel = 0
	band.Parent = crown
	text(panel, "Rarity", "", .05, .065, .90, .20, white, 12)
	local caption = text(panel, "CargoName", "", .045, .29, .91, .44, white, 16, Enum.Font.GothamBlack)
	caption.TextWrapped = true
	caption.UITextSizeConstraint.MinTextSize = 12
	text(panel, "Income", "", .05, .76, .90, .21, mint, 14)
	local status = text(panel, "SlotStatus", "", .05, .76, .23, .21, white, 11)
	status.Visible = false
	card.Parent = anchor
	return card
end

local function styleCard(card, rank, color)
	local panel = card.Readout
	local style = styles[rank]
	local accent = color
	panel.BackgroundColor3 = style and style[1] or ink
	panel.RarityOutline.Color = accent
	panel.RarityOutline.Thickness = rank == "SECRET" and 2 or 1
	panel.RarityOutline.Transparency = style and .08 or .35
	panel.RarityGradient.Enabled = style ~= nil
	panel.RarityGradient.Color = ColorSequence.new(white, Color3.fromRGB(135, 148, 174))
	panel.RankStripe.BackgroundColor3 = accent
	panel.RankStripe.Visible = style ~= nil
	panel.SecretCrown.Visible = rank == "SECRET"
	panel.Rarity.Position = UDim2.fromScale(rank == "SECRET" and .19 or .05, .065)
	panel.Rarity.Size = UDim2.fromScale(rank == "SECRET" and .75 or .90, .20)
	panel.Rarity.TextColor3 = accent
	panel.Rarity.Text = style and style[3] or rank
end

function BillboardLabels.cargo(model, rarity, rate, price)
	local anchor = model.PrimaryPart
	local offset = 0
	for _, piece in ipairs(model:GetChildren()) do
		if not piece:IsA("BasePart") then continue end
		local frame, half = piece.CFrame, piece.Size / 2
		local top = frame.Position.Y + math.abs(frame.RightVector.Y) * half.X
			+ math.abs(frame.UpVector.Y) * half.Y + math.abs(frame.LookVector.Y) * half.Z
		offset = math.max(offset, top - anchor.Position.Y)
	end
	model:SetAttribute("MoneyPerSecond", rate)
	model:SetAttribute("Price", price)
	model:SetAttribute("BillboardHeight", offset + 1.5)
	local card = makeCard(anchor, "CargoCard", 30)
	card.StudsOffsetWorldSpace = Vector3.yAxis * (offset + 1.5)
	styleCard(card, rarity.name:upper(), rarity.color)
	card.Readout.CargoName.Text = model.Name
	card.Readout.Income.Text = "+" .. credits(rate) .. "/s"
	card:SetAttribute("Price", price)
	return card
end

function BillboardLabels.pedestal(pad, index, accent)
	local card = makeCard(pad, "SlotReadout", 22)
	card:SetAttribute("SlotIndex", index)
	BillboardLabels.slot(card, nil, "EMPTY", accent)
	return card
end

function BillboardLabels.slot(card, model, state, accent)
	local panel = card.Readout
	local index = card:GetAttribute("SlotIndex")
	if model then
		styleCard(card, model:GetAttribute("Rarity"), model:GetAttribute("RarityColor"))
		panel.CargoName.Text = model.Name
		panel.SlotStatus.Text = string.format("%02d", index)
		panel.SlotStatus.Visible = true
		panel.Income.Position = UDim2.fromScale(.28, .76)
		panel.Income.Size = UDim2.fromScale(.67, .21)
		panel.Income.Text = "+" .. credits(model:GetAttribute("MoneyPerSecond")) .. "/s"
		card.Size = UDim2.fromOffset(168, 72)
		card.StudsOffsetWorldSpace = Vector3.yAxis * (model.PrimaryPart.Position.Y - card.Adornee.Position.Y
			+ model:GetAttribute("BillboardHeight"))
		card.MaxDistance = 24
	else
		styleCard(card, state == "RESERVED" and "CARGO IN TRANSIT" or "CARGO SOCKET", accent)
		panel.CargoName.Text = string.format("%02d  /  %s", index, state)
		panel.Income.Text = ""
		panel.SlotStatus.Visible = false
		card.Size = UDim2.fromOffset(126, 42)
		card.StudsOffsetWorldSpace = Vector3.yAxis * .98
		card.MaxDistance = 18
	end
	card.Enabled = true
end

function BillboardLabels.docked(model, occupied, pad)
	-- A deferred refresh from the previous bay must not reveal a newly docked card.
	if occupied then
		dockedAt[model] = pad
	elseif dockedAt[model] == pad then
		dockedAt[model] = nil
	else
		return
	end
	local anchor = model.PrimaryPart
	local card = anchor and anchor:FindFirstChild("CargoCard")
	if card then card.Enabled = not occupied end
end

function BillboardLabels.offer(card)
	-- The market destroys label.Parent on purchase.
	local previous = card:FindFirstChild("SaleBadge")
	if previous then return previous.Price end
	local badge = Instance.new("Frame")
	badge.Name = "SaleBadge"
	badge.Size = UDim2.new(.80, 0, 0, 18)
	badge.Position = UDim2.new(.10, 0, 1, 3)
	badge.BackgroundColor3 = ink
	badge.BorderSizePixel = 0
	badge.Parent = card
	return text(badge, "Price", "BUY  " .. credits(card:GetAttribute("Price")), .04, 0, .92, 1, gold, 13)
end

return BillboardLabels
