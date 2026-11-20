local BillboardLabels = {}
local ink = Color3.fromRGB(9, 13, 27)
local white = Color3.fromRGB(241, 250, 255)
local mint = Color3.fromRGB(144, 255, 193)
local gold = Color3.fromRGB(255, 213, 81)
local styles = {
	LEGENDARY = { Color3.fromRGB(61, 42, 15), gold, "LEGENDARY  /  I" },
	MYTHIC = { Color3.fromRGB(62, 21, 45), Color3.fromRGB(255, 109, 161), "MYTHIC  /  II" },
	COSMIC = { Color3.fromRGB(16, 53, 62), Color3.fromRGB(168, 255, 239), "COSMIC  /  III" },
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
	constraint.MinTextSize = 8
	constraint.MaxTextSize = max
	constraint.Parent = label
	label.Parent = parent
	return label
end

local function credits(amount)
	local formatted = tostring(amount):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
	return "$" .. formatted
end

function BillboardLabels.cargo(model, rarity, rate, price)
	local anchor = model.PrimaryPart
	local offset = 0
	for _, piece in ipairs(model:GetChildren()) do
		local frame, half = piece.CFrame, piece.Size / 2
		local top = frame.Position.Y + math.abs(frame.RightVector.Y) * half.X
			+ math.abs(frame.UpVector.Y) * half.Y + math.abs(frame.LookVector.Y) * half.Z
		offset = math.max(offset, top - anchor.Position.Y)
	end
	local rank = rarity.name:upper()
	local style = styles[rank]
	local accent = style and style[2] or rarity.color
	local card = Instance.new("BillboardGui")
	card.Name = "CargoCard"
	card.Size = UDim2.new(0, 146, 0, 51)
	card.StudsOffsetWorldSpace = Vector3.yAxis * (offset + 1.34)
	card.MaxDistance = 24
	card.LightInfluence = 0
	card.Adornee = anchor

	local panel = Instance.new("Frame")
	panel.Name = "Readout"
	panel.Size = UDim2.fromScale(1, 1)
	panel.BackgroundColor3 = style and style[1] or ink
	panel.BackgroundTransparency = .08
	panel.BorderSizePixel = 0
	panel.Parent = card
	local outline = Instance.new("UIStroke")
	outline.Color = accent
	outline.Thickness = rank == "SECRET" and 2 or 1
	outline.Transparency = style and .12 or .43
	outline.Parent = panel
	if style then
		local edge = Instance.new("Frame")
		edge.Name = "RankStripe"
		edge.Size = UDim2.new(1, 0, 0, 2)
		edge.BackgroundColor3 = accent
		edge.BorderSizePixel = 0
		edge.Parent = panel
	end
	text(panel, "Rarity", style and style[3] or rank, .05, .057, .90, .24, accent, 12)
	local caption = text(panel, "CargoName", model.Name, .035, .30, .93, .42, white, 16, Enum.Font.GothamBlack)
	caption.TextWrapped = true
	text(panel, "Income", "+" .. credits(rate) .. "/s", .05, .72, .90, .24, mint, 13)
	card:SetAttribute("Price", price)
	card.Parent = anchor
end

function BillboardLabels.offer(card)
	-- The market destroys label.Parent on purchase.
	local badge = Instance.new("Frame")
	badge.Name = "SaleBadge"
	badge.Size = UDim2.new(.72, 0, 0, 16)
	badge.Position = UDim2.new(.14, 0, 1, 2)
	badge.BackgroundColor3 = ink
	badge.BorderSizePixel = 0
	badge.Parent = card
	return text(badge, "Price", credits(card:GetAttribute("Price")), .04, 0, .92, 1, gold, 12)
end

return BillboardLabels
