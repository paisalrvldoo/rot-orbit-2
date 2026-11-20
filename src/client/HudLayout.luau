-- Pixel positions within ScreenGui's CoreUISafeInsets, including phone rotation.
local HudLayout = {}

function HudLayout.Calculate(width, height)
	local landscape = width > height and height < 500
	local compact = height < 560
	local result = {
		landscape = landscape,
		walletWidth = math.min(280, width - 24), walletHeight = compact and 58 or 68,
		walletX = width / 2, walletY = 10,
		guideWidth = math.min(500, width - 24), guideHeight = compact and 40 or 56,
		guideX = width / 2, guideY = compact and 76 or 86,
		noticeY = compact and 120 or 146, noticeHeight = compact and 32 or 44,
		incidentY = compact and 154 or 192, incidentHeight = 28,
		controlWidth = 100, controlHeight = 48, controlGap = 8,
		menuWidth = 150, menuX = (width - 150) / 2, menuY = height - 64,
	}
	result.skillsX = width - 110
	result.skillsY = math.min(height - 236, math.max(result.incidentY + result.incidentHeight + 12, height * .57 - 80))
	if landscape then
		result.walletWidth = math.min(240, width * .42)
		result.walletX = width * .24
		result.guideWidth = math.min(400, width * .5)
		result.guideX, result.guideY, result.guideHeight = width * .73, 10, 58
		result.noticeY, result.noticeHeight = 78, 36
		result.incidentY = 116
		result.controlWidth = math.clamp(math.floor((width - 224 - 24) / 4), 64, 100)
		local span = 4 * result.controlWidth + 3 * result.controlGap
		result.skillsX, result.skillsY = (width - span) / 2, height - 62
		result.menuWidth = result.controlWidth
		result.menuX = result.skillsX + 3 * (result.controlWidth + result.controlGap)
		result.menuY = result.skillsY
	end
	return result
end

return HudLayout
