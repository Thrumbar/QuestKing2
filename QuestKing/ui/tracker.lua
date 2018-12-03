local addonName, QuestKing = ...

-- options
local opt = QuestKing.options

-- local variables
local measureFrame = nil

----

local Tracker = CreateFrame("Frame", nil, UIParent)
QuestKing.Tracker = Tracker

function Tracker:Init ()
	-- size

	Tracker:SetWidth(opt.buttonWidth)
	Tracker:SetHeight(opt.titleHeight)

	-- titlebar

	local titlebar = CreateFrame("Button", nil, Tracker)
	titlebar:SetWidth(opt.buttonWidth)
	titlebar:SetHeight(opt.titleHeight)
	titlebar:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, -100)
	titlebar:SetBackdrop({
		bgFile = "Interface/Tooltips/UI-Tooltip-Background",
		insets = { left = 0, right = 0, top = 0, bottom = 0 }
	})
	titlebar:SetBackdropColor(0, 0, 0, 0)
	titlebar:EnableMouse(false)
	titlebar.parent = Tracker
	Tracker.titlebar = titlebar

	-- titlebar text

	local titlebarText = titlebar:CreateFontString(nil, opt.fontLayer)
	titlebarText:SetFont(opt.font, opt.fontSize, opt.fontStyle)
	titlebarText:SetJustifyH("RIGHT")
	titlebarText:SetTextColor(opt.colors.TrackerTitlebarText[1], opt.colors.TrackerTitlebarText[2], opt.colors.TrackerTitlebarText[3])
	titlebarText:SetShadowOffset(1, -1)
	titlebarText:SetShadowColor(0, 0, 0, 1)
	titlebarText:SetWordWrap(false)
	titlebarText:SetText("0/"..MAX_QUESTS)
	Tracker.titlebarText = titlebarText

	local titlebarText2 = titlebar:CreateFontString(nil, opt.fontLayer)
	titlebarText2:SetFont(opt.font, opt.fontSize, opt.fontStyle)
	titlebarText2:SetJustifyH("LEFT")
	titlebarText2:SetTextColor(0.7, 0.5, 0.9)
	titlebarText2:SetShadowOffset(1, -1)
	titlebarText2:SetShadowColor(0, 0, 0, 1)
	titlebarText2:SetWordWrap(false)
	titlebarText2:SetText("Unlocked - Drag me!")
	titlebarText2:SetPoint("TOPLEFT", titlebar, "TOPLEFT", 2, -1)
	Tracker.titlebarText2 = titlebarText2

	-- drag

	if (opt.allowDrag) then
		Tracker:InitDrag()
	else
		Tracker:SetPresetPosition()
	end

	-- minimize button

	local minimizeButton = CreateFrame("Button", "QuestKing_TrackerMinimizeButton", titlebar)
	minimizeButton:SetWidth(15)
	minimizeButton:SetHeight(15)

	if (not opt.hideToggleButtonBorder) then
		local tex = minimizeButton:CreateTexture()
		tex:SetPoint("CENTER")
		tex:SetTexture([[Interface\Buttons\UI-Quickslot2]])
		tex:SetWidth(22)
		tex:SetHeight(22)
		minimizeButton:SetNormalTexture(tex)

		local tex = minimizeButton:CreateTexture()
		tex:SetPoint("CENTER")
		tex:SetTexture([[Interface\Buttons\UI-Quickslot2]])
		tex:SetWidth(15)
		tex:SetHeight(15)
		minimizeButton:SetPushedTexture(tex)
	end

	local tex = minimizeButton:CreateTexture()
	tex:SetPoint("CENTER")
	tex:SetTexture([[Interface\Buttons\UI-Quickslot-Depress]])
	tex:SetWidth(15)
	tex:SetHeight(15)
	minimizeButton:SetHighlightTexture(tex, "ADD")

	local label = minimizeButton:CreateFontString(nil, opt.fontLayer)
	label:SetFont(opt.font, opt.fontSize, opt.fontStyle)
	label:SetJustifyH("CENTER")
	label:SetJustifyV("MIDDLE")
	label:SetTextColor(opt.colors.TrackerTitlebarText[1], opt.colors.TrackerTitlebarText[2], opt.colors.TrackerTitlebarText[3])
	label:SetShadowOffset(1, -1)
	label:SetShadowColor(0, 0, 0, 1)
	label:SetPoint("CENTER", 1, 0.5)
	label:SetWordWrap(false)
	label:SetText("+")
	minimizeButton.label = label

	minimizeButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	minimizeButton:SetScript("OnClick", Tracker.MinimizeButtonOnClick)

	if (opt.enableAdvancedBackground) or (opt.enableBackdrop) then
		if (opt.enableAdvancedBackground) then
			Tracker:AddAdvancedBackground()
		elseif (opt.enableBackdrop) then
			Tracker:SetBackdrop(opt.backdropTable)
			Tracker:SetBackdropColor(unpack(opt.backdropTable._backdropColor))
		end

		minimizeButton:EnableMouseWheel()
		minimizeButton:SetScript("OnMouseWheel", Tracker.MinimizeButtonOnMouseWheel)
	end

	-- mode button

	local modeButton = CreateFrame("Button", "QuestKing_TrackerModeButton", titlebar)
	modeButton:SetWidth(15)
	modeButton:SetHeight(15)

	if (not opt.hideToggleButtonBorder) then
		local tex = modeButton:CreateTexture()
		tex:SetPoint("CENTER")
		tex:SetTexture([[Interface\Buttons\UI-Quickslot2]])
		tex:SetWidth(22)
		tex:SetHeight(22)
		modeButton:SetNormalTexture(tex)

		local tex = modeButton:CreateTexture()
		tex:SetPoint("CENTER")
		tex:SetTexture([[Interface\Buttons\UI-Quickslot2]])
		tex:SetWidth(15)
		tex:SetHeight(15)
		modeButton:SetPushedTexture(tex)
	end

	local tex = modeButton:CreateTexture()
	tex:SetPoint("CENTER")
	tex:SetTexture([[Interface\Buttons\UI-Quickslot-Depress]])
	tex:SetWidth(15)
	tex:SetHeight(15)
	modeButton:SetHighlightTexture(tex, "ADD")

	local label = modeButton:CreateFontString(nil, opt.fontLayer)
	label:SetFont(opt.font, opt.fontSize, opt.fontStyle)
	label:SetJustifyH("CENTER")
	label:SetJustifyV("MIDDLE")
	label:SetTextColor(opt.colors.TrackerTitlebarText[1], opt.colors.TrackerTitlebarText[2], opt.colors.TrackerTitlebarText[3])
	label:SetShadowOffset(1, -1)
	label:SetShadowColor(0, 0, 0, 1)
	label:SetPoint("CENTER", 0.5, 0)
	label:SetWordWrap(false)
	label:SetText("Q")
	modeButton.label = label

	modeButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	modeButton:SetScript("OnClick", Tracker.ModeButtonOnClick)

	-- layout

	minimizeButton:SetPoint("RIGHT", titlebar, "RIGHT", 0, 0)
	modeButton:SetPoint("RIGHT", minimizeButton, "LEFT", 1, 0)
	titlebarText:SetPoint("RIGHT", modeButton, "LEFT", -4, 0)

	titlebar:SetPoint("TOPLEFT", Tracker)

	Tracker:SetCustomAlpha()
	Tracker:SetCustomScale()
end

function Tracker:AddAdvancedBackground()
	local bg = opt.advancedBackgroundTable

	local frame = CreateFrame("Frame", "QuestKing_AdvancedBackground", self)
	frame:SetFrameStrata("BACKGROUND")
	frame:SetPoint("TOPLEFT", Tracker, "TOPLEFT", bg._anchorPoints.topLeftX, bg._anchorPoints.topLeftY)
	frame:SetPoint("BOTTOMRIGHT", Tracker, "BOTTOMRIGHT", bg._anchorPoints.bottomRightX, bg._anchorPoints.bottomRightY)
	frame:SetBackdrop(bg)
	frame:SetBackdropColor(unpack(bg._backdropColor))
	frame:SetBackdropBorderColor(unpack(bg._borderColor))
	frame:SetAlpha(bg._alpha)
	frame:Show()

	Tracker.advancedBackground = frame
	Tracker.advancedBackgroundHideWhenEmpty = bg._hideWhenEmpty
end


---- ###########################################
---- positioning
---- ###########################################


function Tracker:SetCustomAlpha (alpha)
	if (not opt.dbAllowTrackerAlpha) then
		alpha = opt.trackerAlpha
	elseif (not alpha) then
		alpha = QuestKingDB.dbTrackerAlpha or opt.trackerAlpha
	else
		QuestKingDB.dbTrackerAlpha = alpha
	end
	Tracker:SetAlpha(alpha)

	QuestKing.itemButtonAlpha = alpha
end

function Tracker:SetCustomScale (scale)
	if (not opt.dbAllowTrackerScale) then
		scale = opt.trackerScale
	elseif (not scale) then
		scale = QuestKingDB.dbTrackerScale or opt.trackerScale
	else
		QuestKingDB.dbTrackerScale = scale
	end
	Tracker:SetScale(scale)

	QuestKing.itemButtonScale = opt.itemButtonScale * scale
end

function Tracker:Resize (lastShown)
	if (not lastShown) then
		Tracker:SetHeight(opt.titleHeight)

		if (Tracker.advancedBackgroundHideWhenEmpty) then
			Tracker.advancedBackground:Hide()
		end
	else
		Tracker:SetHeight(Tracker:GetTop() - lastShown:GetBottom())
		
		if (Tracker.advancedBackgroundHideWhenEmpty) then
			Tracker.advancedBackground:Show()
		end
	end
end

function Tracker:SetPresetPosition()
	local preset = opt.positionPresets[QuestKingDBPerChar.trackerPositionPreset]
	if not preset then
		QuestKingDBPerChar.trackerPositionPreset = 1
		preset = opt.positionPresets[1]
	end
	self:SetPoint(unpack(preset))
end

function Tracker:CyclePresetPosition()
	local new = QuestKingDBPerChar.trackerPositionPreset + 1
	if new > #opt.positionPresets then
		new = 1
	end
	QuestKingDBPerChar.trackerPositionPreset = new
	self:PositionTracker()
end


---- ###########################################
---- dragging
---- ###########################################


function Tracker:StartDragging ()
	self.isMoving = true
	self:StartMoving()
end

function Tracker:StopDragging ()
	self.isMoving = false
	self:StopMovingOrSizing()

	local dragOrigin = QuestKingDB.dragOrigin
	local x, y

	local scale = self:GetScale()

	if (dragOrigin == "TOPRIGHT") then
		x = (self:GetRight() * scale - UIParent:GetRight()) / scale
		y = (self:GetTop() * scale - UIParent:GetTop()) / scale
	elseif (dragOrigin == "BOTTOMRIGHT") then
		x = (self:GetRight() * scale - UIParent:GetRight()) / scale
		y = self:GetBottom()
	elseif (dragOrigin == "BOTTOMLEFT") then
		x = self:GetLeft()
		y = self:GetBottom()
	elseif (dragOrigin == "TOPLEFT") then
		x = self:GetLeft()
		y = (self:GetTop() * scale - UIParent:GetTop()) / scale
	end

	-- D(dragOrigin, x, y)
	self:ClearAllPoints()
	self:SetPoint(dragOrigin, UIParent, dragOrigin, x, y)

	QuestKingDB.dragX = x
	QuestKingDB.dragY = y

	QuestKing:UpdateTracker()
end

function Tracker:InitDrag()
	local dragOrigin = QuestKingDB.dragOrigin
	local dragX = QuestKingDB.dragX
	local dragY = QuestKingDB.dragY

	self:ClearAllPoints()
	if (not dragX) or (not dragY) then
		self:SetPoint(dragOrigin, UIParent, "CENTER", 0, 0)
	else
		self:SetPoint(dragOrigin, UIParent, dragOrigin, dragX, dragY)
	end

	self:CheckDrag()
end

function Tracker:ToggleDrag()
	QuestKingDB.dragLocked = not QuestKingDB.dragLocked
	self:CheckDrag()
	return QuestKingDB.dragLocked
end

function Tracker:CheckDrag()
	local dragLocked = QuestKingDB.dragLocked

	if (dragLocked == false) then
		self.titlebar:SetBackdropColor(0.6, 0, 0.6, 1)
		self.titlebarText2:Show()

		self:EnableMouse(true)
		self:SetMovable(true)
		self:RegisterForDrag("LeftButton")
		self:SetScript("OnDragStart", self.StartDragging)
		self:SetScript("OnDragStop", self.StopDragging)
	else
		if (self.isMoving) then self:StopDragging() end

		self.titlebar:SetBackdropColor(0, 0, 0, 0)
		self.titlebarText2:Hide()

		self:EnableMouse(false)
		self:SetMovable(false)
		self:RegisterForDrag()
		self:SetScript("OnDragStart", nil)
		self:SetScript("OnDragStop", nil)
	end
end


---- ###########################################
---- tracker related handlers
---- ###########################################


function Tracker.MinimizeButtonOnClick (self, mouse, down)
	if (IsShiftKeyDown()) and (not opt.allowDrag) then
		Tracker:CyclePresetPosition()
	else
		if (mouse == "RightButton") then
			QuestKingDBPerChar.trackerCollapsed = 2
			PlaySound("igMiniMapClose")
		elseif (QuestKingDBPerChar.trackerCollapsed ~= 0) then
			QuestKingDBPerChar.trackerCollapsed = 0
			wipe(QuestKing.newlyAddedQuests)
			PlaySound("igMiniMapOpen")
		else
			QuestKingDBPerChar.trackerCollapsed = 1
			PlaySound("igMiniMapClose")
		end
		QuestKing:UpdateTracker()
	end
end

function Tracker.MinimizeButtonOnMouseWheel (self, direction)
	if (opt.enableAdvancedBackground) then
		local alpha = Tracker.advancedBackground:GetAlpha()

		if (direction > 0) then
			alpha = alpha + opt.advancedBackgroundTable._alphaStep
		elseif (direction < 0) then
			alpha = alpha - opt.advancedBackgroundTable._alphaStep
		end

		if (alpha > 1) then alpha = 1 end
		if (alpha < 0) then alpha = 0 end

		Tracker.advancedBackground:SetAlpha(alpha)
	elseif (opt.enableBackdrop) then
		local r, g, b, alpha = Tracker:GetBackdropColor()

		if (direction > 0) then
			alpha = alpha + opt.backdropTable._alphaStep
		elseif (direction < 0) then
			alpha = alpha - opt.backdropTable._alphaStep
		end

		if (alpha > 1) then alpha = 1 end
		if (alpha < 0) then alpha = 0 end

		Tracker:SetBackdropColor(r, g, b, alpha)
	end
end

function Tracker.ModeButtonOnClick (self, mouse, down)
	if mouse == "RightButton" then
		if IsAltKeyDown() then
			QuestKing:SetSuperTrackedQuestID(0)
		elseif QuestKingDBPerChar.displayMode ~= "combined" then
			QuestKingDBPerChar.displayMode = "combined"
		else
			QuestKingDBPerChar.displayMode = "quests"
		end
	else
		if QuestKingDBPerChar.displayMode == "quests" then
			QuestKingDBPerChar.displayMode = "achievements"
		else
			QuestKingDBPerChar.displayMode = "quests"
		end
	end
	QuestKing:UpdateTracker()
end
