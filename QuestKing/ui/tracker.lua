local addonName, QuestKing = ...

local BACKDROP_TEMPLATE = BackdropTemplateMixin and "BackdropTemplate" or nil

local Tracker = QuestKing.Tracker or CreateFrame("Frame", nil, UIParent, BACKDROP_TEMPLATE)
QuestKing.Tracker = Tracker

local TRACKER_BOTTOM_PADDING = 6
local TITLEBAR_LEFT_PADDING = 2
local TITLEBAR_RIGHT_PADDING = 2
local TITLEBAR_TEXT_GAP = 4
local DEFAULT_TITLEBAR_TEXT = "Unlocked - Drag me!"
local BUTTON_SIZE = 15
local BUTTON_ART_SIZE = 22

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

local function QueueTrackerLayoutRefresh(forceBuild)
    if QuestKing and type(QuestKing.QueueTrackerUpdate) == "function" then
        QuestKing:QueueTrackerUpdate(forceBuild, true)
        return
    end

    if QuestKing and type(QuestKing.StartCombatTimer) == "function" then
        QuestKing:StartCombatTimer()
    end
end

local function GetQuestCap()
    if C_QuestLog and C_QuestLog.GetMaxNumQuests then
        local ok, count = pcall(C_QuestLog.GetMaxNumQuests)
        if ok and type(count) == "number" and count > 0 then
            return count
        end
    end

    return _G.MAX_QUESTS or 25
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

    if QuestKingDB.dragLocked == nil then
        QuestKingDB.dragLocked = false
    end

    QuestKingDB.dragOrigin = QuestKingDB.dragOrigin or "TOPRIGHT"
    QuestKingDB.dragRelativePoint = QuestKingDB.dragRelativePoint or QuestKingDB.dragOrigin

    QuestKingDBPerChar.trackerCollapsed = tonumber(QuestKingDBPerChar.trackerCollapsed) or 0
    QuestKingDBPerChar.displayMode = type(QuestKingDBPerChar.displayMode) == "string" and QuestKingDBPerChar.displayMode or "combined"
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

local function SetFontStringStyle(fontString, r, g, b)
    if not fontString then
        return
    end

    fontString:SetFont(GetTrackerFontPath(), GetTrackerFontSize(), GetTrackerFontStyle())
    fontString:SetShadowOffset(1, -1)
    fontString:SetShadowColor(0, 0, 0, 1)

    if r and g and b then
        fontString:SetTextColor(r, g, b)
    end
end

local function CreateButtonArt(button)
    local opt = GetOptions()

    if not opt.hideToggleButtonBorder then
        local normal = button:CreateTexture(nil, "ARTWORK")
        normal:SetPoint("CENTER")
        normal:SetTexture([[Interface\Buttons\UI-Quickslot2]])
        normal:SetSize(BUTTON_ART_SIZE, BUTTON_ART_SIZE)
        button:SetNormalTexture(normal)

        local pushed = button:CreateTexture(nil, "ARTWORK")
        pushed:SetPoint("CENTER")
        pushed:SetTexture([[Interface\Buttons\UI-Quickslot2]])
        pushed:SetSize(BUTTON_SIZE, BUTTON_SIZE)
        button:SetPushedTexture(pushed)
    end

    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetPoint("CENTER")
    highlight:SetTexture([[Interface\Buttons\UI-Quickslot-Depress]])
    highlight:SetSize(BUTTON_SIZE, BUTTON_SIZE)
    button:SetHighlightTexture(highlight, "ADD")
end

local function CreateTitlebarButton(parent, labelText, onClick)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(BUTTON_SIZE, BUTTON_SIZE)
    CreateButtonArt(button)

    local label = button:CreateFontString(nil, GetOptions().fontLayer)
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

function Tracker:ApplyTitlebarState()
    local opt = GetOptions()
    local titlebar = self.titlebar
    if not titlebar then
        return
    end

    local displayMode = QuestKingDBPerChar and QuestKingDBPerChar.displayMode or "combined"
    local dragLocked = not (QuestKingDB and QuestKingDB.dragLocked == false)

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
        self.titlebarText2:SetShown(not dragLocked)
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

    if dragLocked then
        if not SafeSetBackdropColor(titlebar, 0, 0, 0, 0) then
            SetFlatBackgroundColor(titlebar, 0, 0, 0, 0)
        end
    else
        if not SafeSetBackdropColor(titlebar, 0.6, 0, 0.6, 1) then
            SetFlatBackgroundColor(titlebar, 0.6, 0, 0.6, 1)
        end
    end
end

function Tracker:RefreshLayoutMetrics()
    local opt = GetOptions()
    local width = tonumber(opt.buttonWidth) or 230
    local titleHeight = tonumber(opt.titleHeight) or 18

    if IsInCombatLockdownSafe() then
        QueueTrackerLayoutRefresh(true)
        return false
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

    if self.advancedBackground then
        self:ApplyAdvancedBackground()
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
        local titlebarText = self.titlebar:CreateFontString(nil, opt.fontLayer)
        titlebarText:SetJustifyH("RIGHT")
        titlebarText:SetJustifyV("MIDDLE")
        titlebarText:SetWordWrap(false)
        self.titlebarText = titlebarText
    end

    if not self.titlebarText2 then
        local titlebarText2 = self.titlebar:CreateFontString(nil, opt.fontLayer)
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

    if opt.enableAdvancedBackground or opt.enableBackdrop then
        if opt.enableAdvancedBackground then
            self:ApplyAdvancedBackground()
        elseif opt.enableBackdrop and opt.backdropTable then
            SafeSetBackdrop(self, opt.backdropTable, opt.backdropTable._backdropColor)
        end

        self.minimizeButton:EnableMouseWheel(true)
        self.minimizeButton:SetScript("OnMouseWheel", Tracker.MinimizeButtonOnMouseWheel)
    else
        self.minimizeButton:EnableMouseWheel(false)
        self.minimizeButton:SetScript("OnMouseWheel", nil)
    end

    self:ApplyTitlebarState()
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

function Tracker:ApplyAdvancedBackground()
    local opt = GetOptions()
    local background = opt.advancedBackgroundTable
    if not background then
        return
    end

    local frame = self.advancedBackground
    if not frame then
        frame = CreateFrame("Frame", nil, self, BACKDROP_TEMPLATE)
        frame:SetFrameStrata("BACKGROUND")
        self.advancedBackground = frame
    end

    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", self, "TOPLEFT", background._anchorPoints.topLeftX, background._anchorPoints.topLeftY)
    frame:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", background._anchorPoints.bottomRightX, background._anchorPoints.bottomRightY)

    SafeSetBackdrop(frame, background)
    EnsureFlatBackground(frame)

    if frame.SetBackdropColor and background._backdropColor then
        frame:SetBackdropColor(unpack(background._backdropColor))
    else
        local color = background._backdropColor or { 0, 0, 0, 0.5 }
        SetFlatBackgroundColor(frame, color[1], color[2], color[3], color[4] or 1)
    end

    if frame.SetBackdropBorderColor and background._borderColor then
        frame:SetBackdropBorderColor(unpack(background._borderColor))
    end

    frame:SetAlpha(background._alpha or 1)
    frame:Show()

    self.advancedBackgroundHideWhenEmpty = background._hideWhenEmpty and true or false
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

    self:SetAlpha(alpha)
    QuestKing.itemButtonAlpha = alpha
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

    self:SetScale(scale)
    QuestKing.itemButtonScale = (tonumber(opt.itemButtonScale) or 1) * scale
end

function Tracker:Resize(lastShown)
    local titleHeight = tonumber(GetOptions().titleHeight) or 18

    if IsInCombatLockdownSafe() then
        QueueTrackerLayoutRefresh(true)
        return
    end

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
    local opt = GetOptions()
    local presetIndex = (QuestKingDBPerChar and QuestKingDBPerChar.trackerPositionPreset) or 1
    local preset = opt.positionPresets and opt.positionPresets[presetIndex]

    if not preset then
        presetIndex = 1
        QuestKingDBPerChar.trackerPositionPreset = presetIndex
        preset = opt.positionPresets and opt.positionPresets[presetIndex]
    end

    if not preset then
        return
    end

    self:ClearAllPoints()
    self:SetPoint(unpack(preset))
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

    local point, _, relativePoint, xOfs, yOfs = self:GetPoint(1)

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

    if QuestKing and type(QuestKing.QueueTrackerUpdate) == "function" then
        QuestKing:QueueTrackerUpdate(true, false)
    elseif QuestKing and type(QuestKing.UpdateTracker) == "function" then
        QuestKing:UpdateTracker(true, false)
    end
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
        self:EnableMouse(true)
        self:SetMovable(true)
        self:RegisterForDrag("LeftButton")
        self:SetScript("OnDragStart", self.StartDragging)
        self:SetScript("OnDragStop", self.StopDragging)
    else
        if self.isMoving then
            self:StopDragging()
        end

        self:EnableMouse(false)
        self:SetMovable(false)
        self:RegisterForDrag()
        self:SetScript("OnDragStart", nil)
        self:SetScript("OnDragStop", nil)
    end

    self:ApplyTitlebarState()
end

function Tracker.MinimizeButtonOnClick(self, mouse)
    EnsureSavedVariables()
    local opt = GetOptions()

    if IsShiftKeyDown() and (not opt.allowDrag) then
        Tracker:CyclePresetPosition()
        return
    end

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
        QuestKing:UpdateTracker(true, false)
    end
end

function Tracker.MinimizeButtonOnMouseWheel(self, direction)
    local opt = GetOptions()

    if opt.enableAdvancedBackground and Tracker.advancedBackground then
        local alpha = Tracker.advancedBackground:GetAlpha() or 1

        if direction > 0 then
            alpha = alpha + ((opt.advancedBackgroundTable and opt.advancedBackgroundTable._alphaStep) or 0)
        elseif direction < 0 then
            alpha = alpha - ((opt.advancedBackgroundTable and opt.advancedBackgroundTable._alphaStep) or 0)
        end

        Tracker.advancedBackground:SetAlpha(ClampAlpha(alpha))
    elseif opt.enableBackdrop then
        local r, g, b, alpha = SafeGetBackdropColor(Tracker)
        alpha = alpha or 1

        if direction > 0 then
            alpha = alpha + ((opt.backdropTable and opt.backdropTable._alphaStep) or 0)
        elseif direction < 0 then
            alpha = alpha - ((opt.backdropTable and opt.backdropTable._alphaStep) or 0)
        end

        SafeSetBackdropColor(Tracker, r, g, b, ClampAlpha(alpha))
    end
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
        QuestKing:UpdateTracker(true, false)
    end
end
