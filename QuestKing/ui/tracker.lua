local addonName, QuestKing = ...

local opt = QuestKing.options

local BACKDROP_TEMPLATE = BackdropTemplateMixin and "BackdropTemplate" or nil

local Tracker = CreateFrame("Frame", nil, UIParent, BACKDROP_TEMPLATE)
QuestKing.Tracker = Tracker

local TRACKER_BOTTOM_PADDING = 6
local TITLEBAR_LEFT_PADDING = 2
local TITLEBAR_RIGHT_PADDING = 2
local TITLEBAR_TEXT_GAP = 4
local DEFAULT_TITLEBAR_TEXT = "Unlocked - Drag me!"

local function GetQuestCap()
    if C_QuestLog and C_QuestLog.GetMaxNumQuests then
        local count = C_QuestLog.GetMaxNumQuests()
        if type(count) == "number" and count > 0 then
            return count
        end
    end

    return _G.MAX_QUESTS or 25
end

local function ClampAlpha(alpha)
    if alpha == nil then
        return 1
    end
    if alpha < 0 then
        return 0
    end
    if alpha > 1 then
        return 1
    end
    return alpha
end

local function SetFontStringStyle(fontString, r, g, b)
    if not fontString then
        return
    end

    fontString:SetFont(opt.font, opt.fontSize, opt.fontStyle)
    fontString:SetShadowOffset(1, -1)
    fontString:SetShadowColor(0, 0, 0, 1)
    if r and g and b then
        fontString:SetTextColor(r, g, b)
    end
end

local function SafeSetBackdrop(frame, backdropTable, color)
    if not frame or not frame.SetBackdrop or type(backdropTable) ~= "table" then
        return false
    end

    frame:SetBackdrop(backdropTable)
    if color and frame.SetBackdropColor then
        frame:SetBackdropColor(unpack(color))
    end

    return true
end

local function SafeSetBackdropColor(frame, r, g, b, a)
    if frame and frame.SetBackdropColor then
        frame:SetBackdropColor(r, g, b, a)
        return true
    end

    return false
end

local function SafeGetBackdropColor(frame)
    if frame and frame.GetBackdropColor then
        return frame:GetBackdropColor()
    end

    return 0, 0, 0, 0
end

local function PlaySoundSafe(soundKit)
    if not soundKit or not PlaySound then
        return
    end

    if SOUNDKIT then
        PlaySound(soundKit)
        return
    end

    if type(soundKit) == "string" or type(soundKit) == "number" then
        PlaySound(soundKit)
    end
end

local function EnsureSavedVariables()
    QuestKingDB = QuestKingDB or {}
    QuestKingDBPerChar = QuestKingDBPerChar or {}
end

local function GetDefaultDragOffsets(point)
    if point == "BOTTOMRIGHT" then
        return -12, 220
    elseif point == "BOTTOMLEFT" then
        return 12, 220
    elseif point == "TOPLEFT" then
        return 12, -160
    end

    return -12, -160
end

local function GetSavedDragPoint()
    EnsureSavedVariables()

    local point = QuestKingDB.dragOrigin or "TOPRIGHT"
    local relativePoint = QuestKingDB.dragRelativePoint or point
    local x = tonumber(QuestKingDB.dragX)
    local y = tonumber(QuestKingDB.dragY)

    if x == nil or y == nil then
        x, y = GetDefaultDragOffsets(point)
    end

    return point, relativePoint, x, y
end

function Tracker:RefreshLayoutMetrics()
    local width = opt.buttonWidth or 230
    local titleHeight = opt.titleHeight or 18

    self:SetWidth(width)

    if self.titlebar then
        self.titlebar:SetWidth(width)
        self.titlebar:SetHeight(titleHeight)
    end

    if self.titlebarText2 and self.titlebar then
        self.titlebarText2:ClearAllPoints()
        self.titlebarText2:SetPoint("TOPLEFT", self.titlebar, "TOPLEFT", TITLEBAR_LEFT_PADDING, -1)
    end

    if self.minimizeButton and self.titlebar then
        self.minimizeButton:ClearAllPoints()
        self.minimizeButton:SetPoint("RIGHT", self.titlebar, "RIGHT", -TITLEBAR_RIGHT_PADDING, 0)
    end

    if self.modeButton and self.minimizeButton then
        self.modeButton:ClearAllPoints()
        self.modeButton:SetPoint("RIGHT", self.minimizeButton, "LEFT", 1, 0)
    end

    if self.titlebarText and self.modeButton then
        self.titlebarText:ClearAllPoints()
        self.titlebarText:SetPoint("RIGHT", self.modeButton, "LEFT", -TITLEBAR_TEXT_GAP, 0)
    end
end

function Tracker:Init()
    EnsureSavedVariables()

    self:SetClampedToScreen(true)
    self:SetFrameStrata("MEDIUM")
    self:SetWidth(opt.buttonWidth or 230)
    self:SetHeight(opt.titleHeight or 18)

    local titlebar = CreateFrame("Button", nil, self, BACKDROP_TEMPLATE)
    titlebar:SetWidth(opt.buttonWidth or 230)
    titlebar:SetHeight(opt.titleHeight or 18)
    titlebar:SetPoint("TOPLEFT", self, "TOPLEFT", 0, 0)
    SafeSetBackdrop(titlebar, {
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        insets = { left = 0, right = 0, top = 0, bottom = 0 },
    }, { 0, 0, 0, 0 })
    titlebar:EnableMouse(false)
    titlebar.parent = self
    self.titlebar = titlebar

    local titlebarText = titlebar:CreateFontString(nil, opt.fontLayer)
    SetFontStringStyle(
        titlebarText,
        opt.colors.TrackerTitlebarText[1],
        opt.colors.TrackerTitlebarText[2],
        opt.colors.TrackerTitlebarText[3]
    )
    titlebarText:SetJustifyH("RIGHT")
    titlebarText:SetJustifyV("MIDDLE")
    titlebarText:SetWordWrap(false)
    titlebarText:SetText(string.format("0/%d", GetQuestCap()))
    self.titlebarText = titlebarText

    local titlebarText2 = titlebar:CreateFontString(nil, opt.fontLayer)
    SetFontStringStyle(titlebarText2, 0.7, 0.5, 0.9)
    titlebarText2:SetJustifyH("LEFT")
    titlebarText2:SetJustifyV("MIDDLE")
    titlebarText2:SetWordWrap(false)
    titlebarText2:SetText(DEFAULT_TITLEBAR_TEXT)
    self.titlebarText2 = titlebarText2

    local minimizeButton = CreateFrame("Button", "QuestKing_TrackerMinimizeButton", titlebar)
    minimizeButton:SetWidth(15)
    minimizeButton:SetHeight(15)

    if not opt.hideToggleButtonBorder then
        local texture = minimizeButton:CreateTexture(nil, "ARTWORK")
        texture:SetPoint("CENTER")
        texture:SetTexture([[Interface\Buttons\UI-Quickslot2]])
        texture:SetWidth(22)
        texture:SetHeight(22)
        minimizeButton:SetNormalTexture(texture)

        texture = minimizeButton:CreateTexture(nil, "ARTWORK")
        texture:SetPoint("CENTER")
        texture:SetTexture([[Interface\Buttons\UI-Quickslot2]])
        texture:SetWidth(15)
        texture:SetHeight(15)
        minimizeButton:SetPushedTexture(texture)
    end

    do
        local texture = minimizeButton:CreateTexture(nil, "HIGHLIGHT")
        texture:SetPoint("CENTER")
        texture:SetTexture([[Interface\Buttons\UI-Quickslot-Depress]])
        texture:SetWidth(15)
        texture:SetHeight(15)
        minimizeButton:SetHighlightTexture(texture, "ADD")
    end

    local minLabel = minimizeButton:CreateFontString(nil, opt.fontLayer)
    SetFontStringStyle(
        minLabel,
        opt.colors.TrackerTitlebarText[1],
        opt.colors.TrackerTitlebarText[2],
        opt.colors.TrackerTitlebarText[3]
    )
    minLabel:SetJustifyH("CENTER")
    minLabel:SetJustifyV("MIDDLE")
    minLabel:SetPoint("CENTER", 1, 0.5)
    minLabel:SetWordWrap(false)
    minLabel:SetText("+")
    minimizeButton.label = minLabel
    minimizeButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    minimizeButton:SetScript("OnClick", Tracker.MinimizeButtonOnClick)
    self.minimizeButton = minimizeButton

    local modeButton = CreateFrame("Button", "QuestKing_TrackerModeButton", titlebar)
    modeButton:SetWidth(15)
    modeButton:SetHeight(15)

    if not opt.hideToggleButtonBorder then
        local texture = modeButton:CreateTexture(nil, "ARTWORK")
        texture:SetPoint("CENTER")
        texture:SetTexture([[Interface\Buttons\UI-Quickslot2]])
        texture:SetWidth(22)
        texture:SetHeight(22)
        modeButton:SetNormalTexture(texture)

        texture = modeButton:CreateTexture(nil, "ARTWORK")
        texture:SetPoint("CENTER")
        texture:SetTexture([[Interface\Buttons\UI-Quickslot2]])
        texture:SetWidth(15)
        texture:SetHeight(15)
        modeButton:SetPushedTexture(texture)
    end

    do
        local texture = modeButton:CreateTexture(nil, "HIGHLIGHT")
        texture:SetPoint("CENTER")
        texture:SetTexture([[Interface\Buttons\UI-Quickslot-Depress]])
        texture:SetWidth(15)
        texture:SetHeight(15)
        modeButton:SetHighlightTexture(texture, "ADD")
    end

    local modeLabel = modeButton:CreateFontString(nil, opt.fontLayer)
    SetFontStringStyle(
        modeLabel,
        opt.colors.TrackerTitlebarText[1],
        opt.colors.TrackerTitlebarText[2],
        opt.colors.TrackerTitlebarText[3]
    )
    modeLabel:SetJustifyH("CENTER")
    modeLabel:SetJustifyV("MIDDLE")
    modeLabel:SetPoint("CENTER", 0.5, 0)
    modeLabel:SetWordWrap(false)
    modeLabel:SetText("Q")
    modeButton.label = modeLabel
    modeButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    modeButton:SetScript("OnClick", Tracker.ModeButtonOnClick)
    self.modeButton = modeButton

    if opt.enableAdvancedBackground or opt.enableBackdrop then
        if opt.enableAdvancedBackground then
            self:AddAdvancedBackground()
        elseif opt.enableBackdrop then
            SafeSetBackdrop(self, opt.backdropTable, opt.backdropTable._backdropColor)
        end

        minimizeButton:EnableMouseWheel(true)
        minimizeButton:SetScript("OnMouseWheel", Tracker.MinimizeButtonOnMouseWheel)
    end

    self:RefreshLayoutMetrics()

    if opt.allowDrag then
        self:InitDrag()
    else
        self:SetPresetPosition()
        self:CheckDrag()
    end

    self:SetCustomAlpha()
    self:SetCustomScale()
end

function Tracker:AddAdvancedBackground()
    local background = opt.advancedBackgroundTable
    if not background then
        return
    end

    local frame = self.advancedBackground
    if not frame then
        frame = CreateFrame("Frame", "QuestKing_AdvancedBackground", self, BACKDROP_TEMPLATE)
        frame:SetFrameStrata("BACKGROUND")
        self.advancedBackground = frame
    end

    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", self, "TOPLEFT", background._anchorPoints.topLeftX, background._anchorPoints.topLeftY)
    frame:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", background._anchorPoints.bottomRightX, background._anchorPoints.bottomRightY)

    SafeSetBackdrop(frame, background)

    if frame.SetBackdropColor and background._backdropColor then
        frame:SetBackdropColor(unpack(background._backdropColor))
    end

    if frame.SetBackdropBorderColor and background._borderColor then
        frame:SetBackdropBorderColor(unpack(background._borderColor))
    end

    frame:SetAlpha(background._alpha or 1)
    frame:Show()

    self.advancedBackgroundHideWhenEmpty = background._hideWhenEmpty and true or false
end

function Tracker:SetCustomAlpha(alpha)
    if not opt.dbAllowTrackerAlpha then
        alpha = opt.trackerAlpha
    elseif alpha == nil then
        alpha = QuestKingDB.dbTrackerAlpha or opt.trackerAlpha
    else
        QuestKingDB.dbTrackerAlpha = alpha
    end

    alpha = ClampAlpha(alpha)

    self:SetAlpha(alpha)
    QuestKing.itemButtonAlpha = alpha
end

function Tracker:SetCustomScale(scale)
    if not opt.dbAllowTrackerScale then
        scale = opt.trackerScale
    elseif scale == nil then
        scale = QuestKingDB.dbTrackerScale or opt.trackerScale
    else
        QuestKingDB.dbTrackerScale = scale
    end

    if type(scale) ~= "number" or scale <= 0 then
        scale = 1
    end

    self:SetScale(scale)
    QuestKing.itemButtonScale = (opt.itemButtonScale or 1) * scale
end

function Tracker:Resize(lastShown)
    local titleHeight = opt.titleHeight or 18

    self:RefreshLayoutMetrics()

    if not lastShown or not lastShown.IsShown or not lastShown:IsShown() then
        self:SetHeight(titleHeight)

        if self.advancedBackground and self.advancedBackgroundHideWhenEmpty then
            self.advancedBackground:Hide()
        end
        return
    end

    local titleTop = (self.titlebar and self.titlebar.GetTop and self.titlebar:GetTop()) or self:GetTop()
    local lastBottom = lastShown:GetBottom()

    if not titleTop or not lastBottom then
        self:SetHeight(titleHeight)
    else
        local height = titleTop - lastBottom + TRACKER_BOTTOM_PADDING
        if height < titleHeight then
            height = titleHeight
        end
        self:SetHeight(height)
    end

    if self.advancedBackground and self.advancedBackgroundHideWhenEmpty then
        self.advancedBackground:Show()
    end
end

function Tracker:SetPresetPosition()
    local presetIndex = (QuestKingDBPerChar and QuestKingDBPerChar.trackerPositionPreset) or 1
    local preset = opt.positionPresets[presetIndex]

    if not preset then
        presetIndex = 1
        QuestKingDBPerChar.trackerPositionPreset = presetIndex
        preset = opt.positionPresets[presetIndex]
    end

    if not preset then
        return
    end

    self:ClearAllPoints()
    self:SetPoint(unpack(preset))
end

function Tracker:CyclePresetPosition()
    local maxPresets = #opt.positionPresets
    if maxPresets <= 0 then
        return
    end

    local newIndex = ((QuestKingDBPerChar.trackerPositionPreset or 1) % maxPresets) + 1
    QuestKingDBPerChar.trackerPositionPreset = newIndex
    self:SetPresetPosition()
end

function Tracker:StartDragging()
    self.isMoving = true
    self:StartMoving()
end

function Tracker:StopDragging()
    if not self.isMoving then
        return
    end

    EnsureSavedVariables()

    self.isMoving = false
    self:StopMovingOrSizing()

    local point, relativeTo, relativePoint, xOfs, yOfs = self:GetPoint(1)

    point = point or QuestKingDB.dragOrigin or "TOPRIGHT"
    relativePoint = relativePoint or QuestKingDB.dragRelativePoint or point
    xOfs = tonumber(xOfs)
    yOfs = tonumber(yOfs)

    if xOfs == nil or yOfs == nil then
        xOfs, yOfs = GetDefaultDragOffsets(point)
    end

    self:ClearAllPoints()
    self:SetPoint(point, UIParent, relativePoint, xOfs, yOfs)

    QuestKingDB.dragOrigin = point
    QuestKingDB.dragRelativePoint = relativePoint
    QuestKingDB.dragX = xOfs
    QuestKingDB.dragY = yOfs

    QuestKing:UpdateTracker()
end

function Tracker:InitDrag()
    local point, relativePoint, xOfs, yOfs = GetSavedDragPoint()

    self:ClearAllPoints()
    self:SetPoint(point, UIParent, relativePoint, xOfs, yOfs)

    self:CheckDrag()
end

function Tracker:ToggleDrag()
    EnsureSavedVariables()

    QuestKingDB.dragLocked = not QuestKingDB.dragLocked
    self:CheckDrag()
    return QuestKingDB.dragLocked
end

function Tracker:CheckDrag()
    EnsureSavedVariables()

    local dragLocked = QuestKingDB.dragLocked

    if dragLocked == false then
        SafeSetBackdropColor(self.titlebar, 0.6, 0, 0.6, 1)
        if self.titlebarText2 then
            self.titlebarText2:Show()
        end

        self:EnableMouse(true)
        self:SetMovable(true)
        self:RegisterForDrag("LeftButton")
        self:SetScript("OnDragStart", self.StartDragging)
        self:SetScript("OnDragStop", self.StopDragging)
    else
        if self.isMoving then
            self:StopDragging()
        end

        SafeSetBackdropColor(self.titlebar, 0, 0, 0, 0)
        if self.titlebarText2 then
            self.titlebarText2:Hide()
        end

        self:EnableMouse(false)
        self:SetMovable(false)
        self:RegisterForDrag()
        self:SetScript("OnDragStart", nil)
        self:SetScript("OnDragStop", nil)
    end
end

function Tracker.MinimizeButtonOnClick(self, mouse)
    if IsShiftKeyDown() and (not opt.allowDrag) then
        Tracker:CyclePresetPosition()
        return
    end

    if mouse == "RightButton" then
        QuestKingDBPerChar.trackerCollapsed = 2
        PlaySoundSafe(SOUNDKIT and SOUNDKIT.IG_MINIMAP_CLOSE)
    elseif (QuestKingDBPerChar.trackerCollapsed or 0) ~= 0 then
        QuestKingDBPerChar.trackerCollapsed = 0
        wipe(QuestKing.newlyAddedQuests)
        PlaySoundSafe(SOUNDKIT and SOUNDKIT.IG_MINIMAP_OPEN)
    else
        QuestKingDBPerChar.trackerCollapsed = 1
        PlaySoundSafe(SOUNDKIT and SOUNDKIT.IG_MINIMAP_CLOSE)
    end

    QuestKing:UpdateTracker()
end

function Tracker.MinimizeButtonOnMouseWheel(self, direction)
    if opt.enableAdvancedBackground and Tracker.advancedBackground then
        local alpha = Tracker.advancedBackground:GetAlpha() or 1

        if direction > 0 then
            alpha = alpha + (opt.advancedBackgroundTable._alphaStep or 0)
        elseif direction < 0 then
            alpha = alpha - (opt.advancedBackgroundTable._alphaStep or 0)
        end

        Tracker.advancedBackground:SetAlpha(ClampAlpha(alpha))
    elseif opt.enableBackdrop then
        local r, g, b, alpha = SafeGetBackdropColor(Tracker)
        alpha = alpha or 1

        if direction > 0 then
            alpha = alpha + (opt.backdropTable._alphaStep or 0)
        elseif direction < 0 then
            alpha = alpha - (opt.backdropTable._alphaStep or 0)
        end

        SafeSetBackdropColor(Tracker, r, g, b, ClampAlpha(alpha))
    end
end

function Tracker.ModeButtonOnClick(self, mouse)
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