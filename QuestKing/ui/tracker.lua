local addonName, QuestKing = ...

local BACKDROP_TEMPLATE = BackdropTemplateMixin and "BackdropTemplate" or nil

local Tracker = QuestKing.Tracker or CreateFrame("Frame", nil, UIParent, BACKDROP_TEMPLATE)
QuestKing.Tracker = Tracker

local TRACKER_BOTTOM_PADDING = 6
local TITLEBAR_LEFT_PADDING = 2
local TITLEBAR_RIGHT_PADDING = 2
local TITLEBAR_TEXT_GAP = 4
local DEFAULT_TITLEBAR_TEXT = "Unlocked - Drag titlebar"
local BUTTON_SIZE = 15
local BUTTON_ART_SIZE = 22

local VALID_DISPLAY_MODES = {
    combined = true,
    quests = true,
    achievements = true,
    raids = true,
}

local pairs = pairs
local tonumber = tonumber
local tostring = tostring
local type = type
local unpack = table.unpack or unpack
local wipe = wipe

local function GetOptions()
    return QuestKing.options or {}
end

local function EnsureColorTriplet(color, fallbackR, fallbackG, fallbackB)
    if type(color) == "table" then
        return color[1] or fallbackR, color[2] or fallbackG, color[3] or fallbackB
    end

    return fallbackR, fallbackG, fallbackB
end

local function IsInCombatLockdownSafe()
    return type(InCombatLockdown) == "function" and InCombatLockdown() or false
end

local function DeferProtectedPresentation(tracker)
    if not IsInCombatLockdownSafe() then
        return false
    end

    tracker._presentationRefreshPending = true

    if QuestKing and type(QuestKing.StartCombatTimer) == "function" then
        QuestKing:StartCombatTimer()
    end

    return true
end

local function GetQuestCap()
    -- Use the accepted quest-log capacity, not Blizzard's broad internal quest
    -- cap. On modern clients GetMaxNumQuests can report values such as 175.
    if C_QuestLog and C_QuestLog.GetMaxNumQuestsCanAccept then
        local ok, count = pcall(C_QuestLog.GetMaxNumQuestsCanAccept)
        if ok and type(count) == "number" and count > 0 then
            return count
        end
    end

    if C_QuestLog and C_QuestLog.GetMaxNumQuests then
        local ok, count = pcall(C_QuestLog.GetMaxNumQuests)
        if ok and type(count) == "number" and count > 0 and count <= 50 then
            return count
        end
    end

    return _G.MAX_QUESTLOG_QUESTS or _G.MAX_QUESTS or 25
end

local function ClampAlpha(alpha)
    alpha = tonumber(alpha)
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

local function ResolveTrackerBackgroundAlpha(options, backgroundTable)
    local alpha = nil

    if _G.QuestKingDB and type(_G.QuestKingDB.options) == "table" then
        alpha = _G.QuestKingDB.options.trackerBackgroundAlpha
    end

    if alpha == nil and options then
        alpha = options.trackerBackgroundAlpha
    end

    if alpha == nil and type(backgroundTable) == "table" then
        local color = backgroundTable._backdropColor
        if type(color) == "table" then
            alpha = color[4]
        end
    end

    return ClampAlpha(alpha or 0.55)
end

local function GetColorWithAlpha(color, alpha, fallbackR, fallbackG, fallbackB)
    if type(color) ~= "table" then
        return fallbackR or 0, fallbackG or 0, fallbackB or 0, alpha
    end

    return color[1] or fallbackR or 0, color[2] or fallbackG or 0, color[3] or fallbackB or 0, alpha
end

local function SaveTrackerBackgroundAlpha(alpha)
    _G.QuestKingDB = _G.QuestKingDB or {}
    _G.QuestKingDB.options = type(_G.QuestKingDB.options) == "table" and _G.QuestKingDB.options or {}

    alpha = ClampAlpha(alpha)
    _G.QuestKingDB.options.trackerBackgroundAlpha = alpha

    local options = GetOptions()
    options.trackerBackgroundAlpha = alpha
    return alpha
end

local function IsWatchFrameBorderHidden(options)
    options = options or GetOptions()
    return options.hideWatchFrameBorder == true
end

local function GetBackdropForBorderVisibility(backdropTable, hideBorder, topInset)
    if type(backdropTable) ~= "table" then
        return backdropTable
    end

    if not hideBorder and topInset == nil then
        return backdropTable
    end

    local adjustedBackdrop = {}
    for key, value in pairs(backdropTable) do
        adjustedBackdrop[key] = value
    end

    if hideBorder then
        adjustedBackdrop.edgeFile = nil
        adjustedBackdrop.edgeSize = 0
    end

    if topInset ~= nil then
        adjustedBackdrop.insets = {}
        if type(backdropTable.insets) == "table" then
            for key, value in pairs(backdropTable.insets) do
                adjustedBackdrop.insets[key] = value
            end
        end
        adjustedBackdrop.insets.top = topInset
    end

    return adjustedBackdrop
end

local function ApplyBackdropBorderColor(frame, borderColor, hideBorder)
    if not frame or not frame.SetBackdropBorderColor then
        return
    end

    if hideBorder then
        frame:SetBackdropBorderColor(0, 0, 0, 0)
        return
    end

    if type(borderColor) == "table" then
        frame:SetBackdropBorderColor(unpack(borderColor))
    end
end

local function EnsureFlatBackground(frame)
    if not frame then
        return
    end

    if frame.SetBackdrop then
        return
    end

    if not frame._questKingBackground then
        local background = frame:CreateTexture(nil, "BACKGROUND")
        background:SetAllPoints(frame)
        frame._questKingBackground = background
    end

    frame._questKingBackground:SetColorTexture(0, 0, 0, 0)
    frame._questKingBackground:Show()
end

local function SetFlatBackgroundColor(frame, r, g, b, a)
    if frame and frame._questKingBackground then
        frame._questKingBackground:SetColorTexture(r, g, b, a)
    end
end

local function PlaySoundSafe(soundKit)
    if not soundKit or type(PlaySound) ~= "function" then
        return
    end

    pcall(PlaySound, soundKit)
end

local function EnsureSavedVariables()
    _G.QuestKingDB = _G.QuestKingDB or {}
    _G.QuestKingDBPerChar = _G.QuestKingDBPerChar or {}
    _G.QuestKingDB.options = type(_G.QuestKingDB.options) == "table" and _G.QuestKingDB.options or {}

    if QuestKingDB.dragLocked == nil then
        QuestKingDB.dragLocked = false
    end

    QuestKingDB.dragOrigin = QuestKingDB.dragOrigin or "TOPRIGHT"
    QuestKingDB.dragRelativePoint = QuestKingDB.dragRelativePoint or QuestKingDB.dragOrigin

    local trackerCollapsed = tonumber(QuestKingDBPerChar.trackerCollapsed)
    if trackerCollapsed ~= 0 and trackerCollapsed ~= 1 and trackerCollapsed ~= 2 then
        trackerCollapsed = 0
    end
    QuestKingDBPerChar.trackerCollapsed = trackerCollapsed

    local displayMode = type(QuestKingDBPerChar.displayMode) == "string"
        and QuestKingDBPerChar.displayMode
        or "combined"
    QuestKingDBPerChar.displayMode = VALID_DISPLAY_MODES[displayMode] and displayMode or "combined"
    QuestKingDBPerChar.trackerPositionPreset = tonumber(QuestKingDBPerChar.trackerPositionPreset) or 1
end

local function GetModeLabel(displayMode)
    if displayMode == "combined" then
        return "C"
    elseif displayMode == "achievements" then
        return "A"
    elseif displayMode == "raids" then
        return "R"
    end

    return "Q"
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

local VALID_ANCHOR_POINTS = {
    TOPLEFT = true,
    TOP = true,
    TOPRIGHT = true,
    LEFT = true,
    CENTER = true,
    RIGHT = true,
    BOTTOMLEFT = true,
    BOTTOM = true,
    BOTTOMRIGHT = true,
}

local function NormalizeAnchorPoint(point, fallback)
    if type(point) == "string" and VALID_ANCHOR_POINTS[point] then
        return point
    end

    return fallback or "TOPRIGHT"
end

local function ResolveRelativeFrame(relativeTo)
    if type(relativeTo) == "table" then
        return relativeTo
    end

    if type(relativeTo) == "string" and type(_G[relativeTo]) == "table" then
        return _G[relativeTo]
    end

    return UIParent
end

local function IsTrackerDragAllowed()
    return GetOptions().allowDrag == true
end

local function IsTrackerDragUnlocked()
    EnsureSavedVariables()
    return IsTrackerDragAllowed() and QuestKingDB.dragLocked == false
end

local function GetSavedDragPoint()
    EnsureSavedVariables()

    local point = NormalizeAnchorPoint(QuestKingDB.dragOrigin, "TOPRIGHT")
    local relativePoint = NormalizeAnchorPoint(QuestKingDB.dragRelativePoint, point)
    local x = tonumber(QuestKingDB.dragX)
    local y = tonumber(QuestKingDB.dragY)

    if x == nil or y == nil then
        x, y = GetDefaultDragOffsets(point)
    end

    return point, relativePoint, x, y
end

local function GetTrackerFontPath()
    local opt = GetOptions()
    return opt.font or STANDARD_TEXT_FONT
end

local function GetTrackerFontSize()
    local opt = GetOptions()
    return tonumber(opt.fontSize) or 12
end

local function GetTrackerFontStyle()
    local opt = GetOptions()
    return opt.fontStyle or ""
end

local function GetTrackerFontLayer()
    if QuestKing and type(QuestKing.GetFontLayer) == "function" then
        return QuestKing.GetFontLayer()
    end

    local layer = GetOptions().fontLayer
    if layer == "BACKGROUND"
        or layer == "BORDER"
        or layer == "ARTWORK"
        or layer == "OVERLAY"
        or layer == "HIGHLIGHT" then
        return layer
    end

    return "OVERLAY"
end

local function SetFontStringStyle(fontString, r, g, b)
    if not fontString then
        return
    end

    fontString:SetFont(GetTrackerFontPath(), GetTrackerFontSize(), GetTrackerFontStyle())
    if QuestKing and type(QuestKing.ApplyFontLayer) == "function" then
        QuestKing.ApplyFontLayer(fontString)
    elseif type(fontString.SetDrawLayer) == "function" then
        fontString:SetDrawLayer(GetTrackerFontLayer())
    end
    fontString:SetShadowOffset(1, -1)
    fontString:SetShadowColor(0, 0, 0, 1)

    if r and g and b then
        fontString:SetTextColor(r, g, b)
    end
end

local function SetTitlebarButtonBorderVisible(button, visible)
    if not button then
        return
    end

    local alpha = visible and 1 or 0
    if button._questKingNormalBorder then
        button._questKingNormalBorder:SetAlpha(alpha)
    end
    if button._questKingPushedBorder then
        button._questKingPushedBorder:SetAlpha(alpha)
    end
end

local function CreateButtonArt(button)
    local opt = GetOptions()

    local normal = button:CreateTexture(nil, "ARTWORK")
    normal:SetPoint("CENTER")
    normal:SetTexture([[Interface\Buttons\UI-Quickslot2]])
    normal:SetSize(BUTTON_ART_SIZE, BUTTON_ART_SIZE)
    button:SetNormalTexture(normal)
    button._questKingNormalBorder = normal

    local pushed = button:CreateTexture(nil, "ARTWORK")
    pushed:SetPoint("CENTER")
    pushed:SetTexture([[Interface\Buttons\UI-Quickslot2]])
    pushed:SetSize(BUTTON_SIZE, BUTTON_SIZE)
    button:SetPushedTexture(pushed)
    button._questKingPushedBorder = pushed

    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetPoint("CENTER")
    highlight:SetTexture([[Interface\Buttons\UI-Quickslot-Depress]])
    highlight:SetSize(BUTTON_SIZE, BUTTON_SIZE)
    button:SetHighlightTexture(highlight, "ADD")

    SetTitlebarButtonBorderVisible(button, opt.hideToggleButtonBorder ~= true)
end

local function CreateTitlebarButton(parent, labelText, onClick)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(BUTTON_SIZE, BUTTON_SIZE)
    CreateButtonArt(button)

    local label = button:CreateFontString(nil, GetTrackerFontLayer())
    local r, g, b = EnsureColorTriplet((GetOptions().colors or {}).TrackerTitlebarText, 1, 1, 1)
    SetFontStringStyle(label, r, g, b)
    label:SetJustifyH("CENTER")
    label:SetJustifyV("MIDDLE")
    label:SetPoint("CENTER", 0.5, 0)
    label:SetWordWrap(false)
    label:SetText(labelText)
    button.label = label

    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:SetScript("OnClick", onClick)

    return button
end

function Tracker:RefreshTypography()
    local titleColor = (GetOptions().colors or {}).TrackerTitlebarText
    local titleR, titleG, titleB = EnsureColorTriplet(titleColor, 1, 1, 1)

    SetFontStringStyle(self.titlebarText, titleR, titleG, titleB)
    SetFontStringStyle(self.titlebarText2, 0.7, 0.5, 0.9)

    if self.minimizeButton then
        SetFontStringStyle(self.minimizeButton.label, titleR, titleG, titleB)
    end

    if self.modeButton then
        SetFontStringStyle(self.modeButton.label, titleR, titleG, titleB)
    end

    return true
end

function Tracker:RefreshToggleButtonBorders()
    local visible = GetOptions().hideToggleButtonBorder ~= true
    SetTitlebarButtonBorderVisible(self.minimizeButton, visible)
    SetTitlebarButtonBorderVisible(self.modeButton, visible)
    return true
end

function Tracker:ApplyTitlebarState()
    local opt = GetOptions()
    local titlebar = self.titlebar
    if not titlebar then
        return false
    end

    if DeferProtectedPresentation(self) then
        return false
    end

    local displayMode = QuestKingDBPerChar and QuestKingDBPerChar.displayMode or "combined"
    local dragUnlocked = IsTrackerDragUnlocked()

    local titleColor = (opt.colors or {}).TrackerTitlebarText
    local dimColor = (opt.colors or {}).TrackerTitlebarTextDimmed
    local titleR, titleG, titleB = EnsureColorTriplet(titleColor, 1, 1, 1)
    local dimR, dimG, dimB = EnsureColorTriplet(dimColor, 0.7, 0.7, 0.7)

    if self.titlebarText then
        SetFontStringStyle(self.titlebarText, titleR, titleG, titleB)
        if self.titlebarText:GetText() == nil or self.titlebarText:GetText() == "" then
            self.titlebarText:SetText(string.format("0/%d", GetQuestCap()))
            self.titlebarText:SetTextColor(dimR, dimG, dimB)
        end
    end

    if self.titlebarText2 then
        SetFontStringStyle(self.titlebarText2, 0.7, 0.5, 0.9)
        self.titlebarText2:SetText(DEFAULT_TITLEBAR_TEXT)
        self.titlebarText2:SetShown(dragUnlocked)
    end

    if self.minimizeButton and self.minimizeButton.label then
        local r, g, b = titleR, titleG, titleB
        SetFontStringStyle(self.minimizeButton.label, r, g, b)
    end

    if self.modeButton and self.modeButton.label then
        local r, g, b = titleR, titleG, titleB
        SetFontStringStyle(self.modeButton.label, r, g, b)
        self.modeButton.label:SetText(GetModeLabel(displayMode))
    end

    if dragUnlocked then
        if not SafeSetBackdropColor(titlebar, 0.6, 0, 0.6, 1) then
            SetFlatBackgroundColor(titlebar, 0.6, 0, 0.6, 1)
        end
    elseif not SafeSetBackdropColor(titlebar, 0, 0, 0, 0) then
        SetFlatBackgroundColor(titlebar, 0, 0, 0, 0)
    end

    return true
end

local function HasCompleteLayoutControls(tracker)
    return tracker
        and tracker.titlebar ~= nil
        and tracker.titlebarText ~= nil
        and tracker.titlebarText2 ~= nil
        and tracker.minimizeButton ~= nil
        and tracker.modeButton ~= nil
end

function Tracker:RefreshLayoutMetrics()
    local opt = GetOptions()
    local width = tonumber(opt.buttonWidth) or 230
    local titleHeight = tonumber(opt.titleHeight) or 18
    local controlsReady = HasCompleteLayoutControls(self)

    if controlsReady
        and self._layoutMetricsInitialized == true
        and self._layoutMetricWidth == width
        and self._layoutMetricTitleHeight == titleHeight then
        return true
    end

    if DeferProtectedPresentation(self) then
        return false
    end

    if QuestKing and type(QuestKing.RecordPerformanceMetric) == "function" then
        QuestKing:RecordPerformanceMetric("layoutMetricPassCount", 1)
    end

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

    if controlsReady then
        self._layoutMetricWidth = width
        self._layoutMetricTitleHeight = titleHeight
        self._layoutMetricsInitialized = true
        self._layoutGeneration = (tonumber(self._layoutGeneration) or 0) + 1
    else
        -- ui/optionspanel.lua can apply saved presentation settings from its
        -- ADDON_LOADED handler before Tracker:Init creates the titlebar and
        -- controls. Never let that partial pass satisfy the initialized cache.
        self._layoutMetricWidth = nil
        self._layoutMetricTitleHeight = nil
        self._layoutMetricsInitialized = false
    end

    return true
end

function Tracker:Init()
    EnsureSavedVariables()

    local opt = GetOptions()

    self:SetClampedToScreen(true)
    self:SetFrameStrata("MEDIUM")
    self:SetWidth(tonumber(opt.buttonWidth) or 230)
    self:SetHeight(tonumber(opt.titleHeight) or 18)

    if not self.titlebar then
        local titlebar = CreateFrame("Button", nil, self, BACKDROP_TEMPLATE)
        titlebar:SetPoint("TOPLEFT", self, "TOPLEFT", 0, 0)
        SafeSetBackdrop(titlebar, {
            bgFile = "Interface/Tooltips/UI-Tooltip-Background",
            insets = { left = 0, right = 0, top = 0, bottom = 0 },
        }, { 0, 0, 0, 0 })
        EnsureFlatBackground(titlebar)
        titlebar:EnableMouse(false)
        titlebar.parent = self
        self.titlebar = titlebar
    end

    if not self.titlebarText then
        local titlebarText = self.titlebar:CreateFontString(nil, GetTrackerFontLayer())
        titlebarText:SetJustifyH("RIGHT")
        titlebarText:SetJustifyV("MIDDLE")
        titlebarText:SetWordWrap(false)
        self.titlebarText = titlebarText
    end

    if not self.titlebarText2 then
        local titlebarText2 = self.titlebar:CreateFontString(nil, GetTrackerFontLayer())
        titlebarText2:SetJustifyH("LEFT")
        titlebarText2:SetJustifyV("MIDDLE")
        titlebarText2:SetWordWrap(false)
        self.titlebarText2 = titlebarText2
    end

    if not self.minimizeButton then
        self.minimizeButton = CreateTitlebarButton(self.titlebar, "+", Tracker.MinimizeButtonOnClick)
    end

    if not self.modeButton then
        self.modeButton = CreateTitlebarButton(self.titlebar, GetModeLabel(QuestKingDBPerChar.displayMode), Tracker.ModeButtonOnClick)
    end

    self:ApplyTrackerBackground()

    self:ApplyTitlebarState()
    -- A saved-options presentation pass may have run before these controls
    -- existed. Force one complete metric and anchor application during Init.
    self._layoutMetricWidth = nil
    self._layoutMetricTitleHeight = nil
    self._layoutMetricsInitialized = false
    self:RefreshLayoutMetrics()

    self:ApplyInitialPosition()
    if opt.allowDrag ~= true then
        QuestKingDB.dragLocked = true
    end
    self:CheckDrag()

    self:SetCustomAlpha()
    self:SetCustomScale()
end

function Tracker:GetBackgroundAlpha()
    local opt = GetOptions()
    local background = opt.enableAdvancedBackground and opt.advancedBackgroundTable or opt.backdropTable
    return ResolveTrackerBackgroundAlpha(opt, background)
end

function Tracker:SetBackgroundAlpha(alpha)
    if alpha ~= nil then
        SaveTrackerBackgroundAlpha(alpha)
    end

    self:ApplyTrackerBackground()
end

function Tracker:ApplyTrackerBackground()
    if DeferProtectedPresentation(self) then
        return false
    end

    local opt = GetOptions()
    local hasBackground = opt.enableAdvancedBackground == true or opt.enableBackdrop == true

    if self.minimizeButton then
        self.minimizeButton:EnableMouseWheel(hasBackground)
        self.minimizeButton:SetScript("OnMouseWheel", hasBackground and Tracker.MinimizeButtonOnMouseWheel or nil)
    end

    if opt.enableAdvancedBackground then
        if self.SetBackdrop then
            self:SetBackdrop(nil)
        end
        SetFlatBackgroundColor(self, 0, 0, 0, 0)
        self:ApplyAdvancedBackground()
        return true
    end

    if self.advancedBackground then
        self.advancedBackground:Hide()
    end

    if opt.enableBackdrop and opt.backdropTable then
        local hideBorder = IsWatchFrameBorderHidden(opt)
        local topInset = nil
        if opt.backdropTable._titleInsetFollowsTitleHeight == true then
            topInset = (tonumber(opt.titleHeight) or 18) + 1
        end
        local backdrop = GetBackdropForBorderVisibility(opt.backdropTable, hideBorder, topInset)
        local alpha = ResolveTrackerBackgroundAlpha(opt, opt.backdropTable)
        local r, g, b, a = GetColorWithAlpha(opt.backdropTable._backdropColor, alpha, 0, 0, 0)

        if not SafeSetBackdrop(self, backdrop, { r, g, b, a }) then
            EnsureFlatBackground(self)
            SetFlatBackgroundColor(self, r, g, b, a)
        end
        ApplyBackdropBorderColor(self, opt.backdropTable._borderColor, hideBorder)
        return true
    end

    if self.SetBackdrop then
        self:SetBackdrop(nil)
    end

    SetFlatBackgroundColor(self, 0, 0, 0, 0)
    return true
end

function Tracker:ApplyAdvancedBackground()
    if DeferProtectedPresentation(self) then
        return false
    end

    local opt = GetOptions()
    local background = opt.advancedBackgroundTable
    if not background then
        return false
    end

    local frame = self.advancedBackground
    if not frame then
        frame = CreateFrame("Frame", nil, self, BACKDROP_TEMPLATE)
        frame:SetFrameStrata("BACKGROUND")
        self.advancedBackground = frame
    end

    local anchorPoints = type(background._anchorPoints) == "table" and background._anchorPoints or {}
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", self, "TOPLEFT", anchorPoints.topLeftX or -6, anchorPoints.topLeftY or 6)
    frame:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", anchorPoints.bottomRightX or 6, anchorPoints.bottomRightY or -6)

    local hideBorder = IsWatchFrameBorderHidden(opt)
    local backdrop = GetBackdropForBorderVisibility(background, hideBorder)

    SafeSetBackdrop(frame, backdrop)
    EnsureFlatBackground(frame)

    local alpha = ResolveTrackerBackgroundAlpha(opt, background)
    local r, g, b, a = GetColorWithAlpha(background._backdropColor, alpha, 0, 0, 0)
    if frame.SetBackdropColor then
        frame:SetBackdropColor(r, g, b, a)
    else
        SetFlatBackgroundColor(frame, r, g, b, a)
    end

    ApplyBackdropBorderColor(frame, background._borderColor, hideBorder)

    frame:SetAlpha(ClampAlpha(background._alpha or 1))
    frame:Show()

    self.advancedBackgroundHideWhenEmpty = background._hideWhenEmpty and true or false
    return true
end

function Tracker:SetCustomAlpha(alpha)
    local opt = GetOptions()

    if not opt.dbAllowTrackerAlpha then
        alpha = opt.trackerAlpha
    elseif alpha == nil then
        alpha = QuestKingDB.dbTrackerAlpha or opt.trackerAlpha
    else
        QuestKingDB.dbTrackerAlpha = alpha
    end

    alpha = ClampAlpha(alpha)

    if DeferProtectedPresentation(self) then
        return false
    end

    QuestKing.itemButtonAlpha = alpha
    self:SetAlpha(alpha)
    return true
end

function Tracker:SetCustomScale(scale)
    local opt = GetOptions()

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

    if DeferProtectedPresentation(self) then
        return false
    end

    QuestKing.itemButtonScale = (tonumber(opt.itemButtonScale) or 1) * scale
    self:SetScale(scale)
    return true
end

local function GetTrackerHeaderTop(tracker)
    local titlebar = tracker and tracker.titlebar
    if titlebar and type(titlebar.GetTop) == "function" then
        local top = titlebar:GetTop()
        if type(top) == "number" then
            return top
        end
    end

    if tracker and type(tracker.GetTop) == "function" then
        local top = tracker:GetTop()
        if type(top) == "number" then
            return top
        end
    end

    return nil
end

local function SetTrackerHeight(tracker, height, preserveHeaderPosition)
    if not preserveHeaderPosition then
        tracker:SetHeight(height)
        return
    end

    local originalTop = GetTrackerHeaderTop(tracker)
    tracker:SetHeight(height)

    local currentTop = GetTrackerHeaderTop(tracker)
    if originalTop == nil or currentTop == nil then
        return
    end

    local offsetCorrection = originalTop - currentTop
    if math.abs(offsetCorrection) < 0.001 then
        return
    end

    if type(tracker.GetPoint) ~= "function"
        or type(tracker.ClearAllPoints) ~= "function"
        or type(tracker.SetPoint) ~= "function" then
        return
    end

    local point, relativeTo, relativePoint, xOfs, yOfs = tracker:GetPoint(1)
    if not point or type(xOfs) ~= "number" or type(yOfs) ~= "number" then
        return
    end

    tracker:ClearAllPoints()
    tracker:SetPoint(
        point,
        relativeTo,
        relativePoint,
        xOfs,
        yOfs + offsetCorrection
    )

    if type(tracker.CaptureCurrentPosition) == "function" then
        tracker:CaptureCurrentPosition()
    end
end

function Tracker:Resize(lastShown)
    local titleHeight = tonumber(GetOptions().titleHeight) or 18

    if DeferProtectedPresentation(self) then
        return false
    end

    self:RefreshLayoutMetrics()

    local preserveHeaderPosition = self._preserveHeaderPositionOnNextResize == true
    self._preserveHeaderPositionOnNextResize = nil

    if not lastShown or not lastShown.IsShown or not lastShown:IsShown() then
        SetTrackerHeight(self, titleHeight, preserveHeaderPosition)

        if self.advancedBackground and self.advancedBackgroundHideWhenEmpty then
            self.advancedBackground:Hide()
        end
        return
    end

    local titleTop = (self.titlebar and self.titlebar.GetTop and self.titlebar:GetTop()) or self:GetTop()
    local lastBottom = lastShown:GetBottom()

    if not titleTop or not lastBottom then
        SetTrackerHeight(self, titleHeight, preserveHeaderPosition)
    else
        local height = titleTop - lastBottom + TRACKER_BOTTOM_PADDING
        if height < titleHeight then
            height = titleHeight
        end
        SetTrackerHeight(self, height, preserveHeaderPosition)
    end

    if self.advancedBackground and self.advancedBackgroundHideWhenEmpty then
        self.advancedBackground:Show()
    end

    return true
end

function Tracker:SetPresetPosition()
    EnsureSavedVariables()

    local opt = GetOptions()
    local presetIndex = QuestKingDBPerChar.trackerPositionPreset or 1
    local preset = opt.positionPresets and opt.positionPresets[presetIndex]

    if not preset then
        presetIndex = 1
        QuestKingDBPerChar.trackerPositionPreset = presetIndex
        preset = opt.positionPresets and opt.positionPresets[presetIndex]
    end

    if not preset then
        return false
    end

    local point = NormalizeAnchorPoint(preset[1], "TOPRIGHT")
    local relativeTo = ResolveRelativeFrame(preset[2])
    local relativePoint = NormalizeAnchorPoint(preset[3], point)
    local xOfs = tonumber(preset[4])
    local yOfs = tonumber(preset[5])

    if xOfs == nil or yOfs == nil then
        xOfs, yOfs = GetDefaultDragOffsets(point)
    end

    if IsInCombatLockdownSafe() then
        self._positionRefreshPending = "preset"
        DeferProtectedPresentation(self)
        return false
    end

    self:ClearAllPoints()
    self:SetPoint(point, relativeTo, relativePoint, xOfs, yOfs)
    return true
end

function Tracker:CaptureCurrentPosition()
    EnsureSavedVariables()

    if not self.GetPoint then
        return false
    end

    local point, relativeTo, relativePoint, xOfs, yOfs = self:GetPoint(1)
    if not point then
        return false
    end

    point = NormalizeAnchorPoint(point, QuestKingDB.dragOrigin or "TOPRIGHT")
    relativePoint = NormalizeAnchorPoint(relativePoint, point)
    xOfs = tonumber(xOfs)
    yOfs = tonumber(yOfs)

    if xOfs == nil or yOfs == nil then
        xOfs, yOfs = GetDefaultDragOffsets(point)
    end

    -- The tracker is restored against UIParent for cross-client stability.
    -- Only the anchor names and offsets are persisted here; this function does
    -- not call ClearAllPoints() or SetPoint(), so changing the option cannot
    -- move the tracker on screen.
    QuestKingDB.dragOrigin = point
    QuestKingDB.dragRelativePoint = relativePoint
    QuestKingDB.dragX = xOfs
    QuestKingDB.dragY = yOfs
    return true
end

function Tracker:ApplyInitialPosition()
    EnsureSavedVariables()

    if IsInCombatLockdownSafe() then
        self._positionRefreshPending = "initial"
        DeferProtectedPresentation(self)
        return false
    end

    if QuestKingDB.dragX ~= nil and QuestKingDB.dragY ~= nil then
        local point, relativePoint, xOfs, yOfs = GetSavedDragPoint()
        self:ClearAllPoints()
        self:SetPoint(point, UIParent, relativePoint, xOfs, yOfs)
        return true
    end

    if self:SetPresetPosition() then
        self:CaptureCurrentPosition()
        return true
    end

    return false
end

function Tracker:CyclePresetPosition()
    local opt = GetOptions()
    local maxPresets = opt.positionPresets and #opt.positionPresets or 0
    if maxPresets <= 0 then
        return
    end

    local newIndex = ((QuestKingDBPerChar.trackerPositionPreset or 1) % maxPresets) + 1
    QuestKingDBPerChar.trackerPositionPreset = newIndex
    self:SetPresetPosition()
end

function Tracker:StartDragging()
    if self.isMoving or not IsTrackerDragUnlocked() then
        return false
    end

    if IsInCombatLockdownSafe() then
        return false
    end

    self.isMoving = true
    self:StartMoving()
    return true
end

function Tracker:StopDragging()
    if not self.isMoving then
        return false
    end

    if IsInCombatLockdownSafe() then
        self._stopDraggingPending = true
        DeferProtectedPresentation(self)
        return false
    end

    EnsureSavedVariables()

    self.isMoving = false
    self:StopMovingOrSizing()

    local point, _, relativePoint, xOfs, yOfs = self:GetPoint(1)

    point = NormalizeAnchorPoint(point or QuestKingDB.dragOrigin, "TOPRIGHT")
    relativePoint = NormalizeAnchorPoint(relativePoint or QuestKingDB.dragRelativePoint, point)
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

    if QuestKing and type(QuestKing.QueueTrackerUpdate) == "function" then
        QuestKing:QueueTrackerUpdate(false, false, "presentation")
    elseif QuestKing and type(QuestKing.UpdateTracker) == "function" then
        QuestKing:UpdateTracker(false, false, "presentation")
    end

    return true
end

function Tracker:InitDrag()
    EnsureSavedVariables()

    self:ApplyInitialPosition()
    self:CheckDrag()
end

function Tracker:ToggleDrag()
    EnsureSavedVariables()

    if not IsTrackerDragAllowed() then
        QuestKingDB.dragLocked = true
        self:CheckDrag()
        return true
    end

    QuestKingDB.dragLocked = not QuestKingDB.dragLocked
    self:CheckDrag()
    return QuestKingDB.dragLocked
end

function Tracker:CheckDrag()
    EnsureSavedVariables()

    local dragAllowed = IsTrackerDragAllowed()
    if not dragAllowed then
        QuestKingDB.dragLocked = true
    end

    if DeferProtectedPresentation(self) then
        return false
    end

    local dragUnlocked = dragAllowed and QuestKingDB.dragLocked == false
    local titlebar = self.titlebar

    if dragUnlocked then
        self:SetMovable(true)
        self:EnableMouse(false)
        self:RegisterForDrag()
        self:SetScript("OnDragStart", nil)
        self:SetScript("OnDragStop", nil)

        if titlebar then
            titlebar:EnableMouse(true)
            titlebar:RegisterForDrag("LeftButton")
            titlebar:SetScript("OnDragStart", function(frame)
                if frame.parent and type(frame.parent.StartDragging) == "function" then
                    frame.parent:StartDragging()
                end
            end)
            titlebar:SetScript("OnDragStop", function(frame)
                if frame.parent and type(frame.parent.StopDragging) == "function" then
                    frame.parent:StopDragging()
                end
            end)
        end
    else
        if self.isMoving then
            self:StopDragging()
        end

        self:EnableMouse(false)
        self:SetMovable(false)
        self:RegisterForDrag()
        self:SetScript("OnDragStart", nil)
        self:SetScript("OnDragStop", nil)

        if titlebar then
            titlebar:EnableMouse(false)
            titlebar:RegisterForDrag()
            titlebar:SetScript("OnDragStart", nil)
            titlebar:SetScript("OnDragStop", nil)
        end
    end

    self:ApplyTitlebarState()
    return true
end

function Tracker:ApplyPresentationSettings()
    self:RefreshTypography()
    self:RefreshToggleButtonBorders()

    local watchButton = QuestKing and QuestKing.WatchButton or nil
    if type(watchButton) == "table" and type(watchButton.RefreshFonts) == "function" then
        watchButton:RefreshFonts()
    end

    if DeferProtectedPresentation(self) then
        return false
    end

    self:SetCustomAlpha()
    self:SetCustomScale()
    self:CheckDrag()
    self:RefreshLayoutMetrics()
    self:ApplyTrackerBackground()

    return true
end

function Tracker:ApplyDeferredProtectedPresentation()
    if IsInCombatLockdownSafe() then
        return false
    end

    local stopDragging = self._stopDraggingPending == true
    local positionMode = self._positionRefreshPending
    local presentationPending = self._presentationRefreshPending == true

    if not stopDragging and positionMode == nil and not presentationPending then
        return false
    end

    self._stopDraggingPending = nil
    self._positionRefreshPending = nil
    self._presentationRefreshPending = nil

    if stopDragging then
        self:StopDragging()
    end

    if positionMode == "initial" then
        self:ApplyInitialPosition()
    elseif positionMode == "preset" then
        self:SetPresetPosition()
    end

    self:ApplyPresentationSettings()
    return true
end

function Tracker.MinimizeButtonOnClick(self, mouse)
    EnsureSavedVariables()
    local opt = GetOptions()

    if IsShiftKeyDown() and (not opt.allowDrag) then
        Tracker:CyclePresetPosition()
        return
    end

    -- The tracker may be anchored from its bottom or center. Its height changes
    -- when rows are minimized or restored, which would otherwise move the
    -- titlebar while leaving that anchor fixed. Preserve the titlebar's screen
    -- position during the next successful layout resize.
    Tracker._preserveHeaderPositionOnNextResize = true

    if mouse == "RightButton" then
        QuestKingDBPerChar.trackerCollapsed = 2
        PlaySoundSafe(SOUNDKIT and SOUNDKIT.IG_MINIMAP_CLOSE)
    elseif (QuestKingDBPerChar.trackerCollapsed or 0) ~= 0 then
        QuestKingDBPerChar.trackerCollapsed = 0
        if QuestKing.newlyAddedQuests then
            wipe(QuestKing.newlyAddedQuests)
        end
        PlaySoundSafe(SOUNDKIT and SOUNDKIT.IG_MINIMAP_OPEN)
    else
        QuestKingDBPerChar.trackerCollapsed = 1
        PlaySoundSafe(SOUNDKIT and SOUNDKIT.IG_MINIMAP_CLOSE)
    end

    if QuestKing and type(QuestKing.UpdateTracker) == "function" then
        QuestKing:UpdateTracker(false, false, "presentation")
    end
end

function Tracker.MinimizeButtonOnMouseWheel(self, direction)
    local opt = GetOptions()
    local background = opt.enableAdvancedBackground and opt.advancedBackgroundTable or opt.backdropTable
    local step = 0.05

    if background then
        step = tonumber(background._alphaStep) or step
    end

    local alpha = Tracker:GetBackgroundAlpha()
    if direction > 0 then
        alpha = alpha + step
    elseif direction < 0 then
        alpha = alpha - step
    end

    Tracker:SetBackgroundAlpha(alpha)
end

function Tracker.ModeButtonOnClick(self, mouse)
    EnsureSavedVariables()

    local displayMode = QuestKingDBPerChar.displayMode or "combined"

    if mouse == "RightButton" then
        if IsAltKeyDown() and QuestKing and type(QuestKing.SetSuperTrackedQuestID) == "function" then
            QuestKing:SetSuperTrackedQuestID(0)
        else
            QuestKingDBPerChar.displayMode = "combined"
        end
    else
        if displayMode == "quests" then
            QuestKingDBPerChar.displayMode = "raids"
        elseif displayMode == "raids" then
            QuestKingDBPerChar.displayMode = "achievements"
        elseif displayMode == "achievements" then
            QuestKingDBPerChar.displayMode = "combined"
        else
            QuestKingDBPerChar.displayMode = "quests"
        end
    end

    Tracker:ApplyTitlebarState()

    if QuestKing and type(QuestKing.UpdateTracker) == "function" then
        QuestKing:UpdateTracker(false, false, "presentation")
    end
end
