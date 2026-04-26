local addonName, QuestKing = ...

local BACKDROP_TEMPLATE = BackdropTemplateMixin and "BackdropTemplate" or nil

local tinsert = table.insert
local tremove = table.remove
local floor = math.floor
local max = math.max
local tonumber = tonumber
local type = type

local WatchButtonPrototype = CreateFrame("Frame")
local WatchButton = setmetatable({}, { __index = WatchButtonPrototype })
WatchButton.__index = WatchButton
QuestKing.WatchButton = WatchButton

local LINE_INDENT_LEFT = 0
local LINE_RIGHT_PADDING = 4
local LINE_GAP = 2
local TITLE_TO_FIRST_LINE_GAP = 2
local BAR_VERTICAL_PADDING = 4
local BUTTON_BOTTOM_PADDING = 4
local BAR_HEIGHT_FALLBACK = 15

local usedPool = {}
local freePool = {}
local requestOrder = {}
local buttonCounter = 0

WatchButton.usedPool = usedPool
WatchButton.freePool = freePool
WatchButton.requestOrder = requestOrder
WatchButton.requestCount = 0

local function GetOptions()
    return QuestKing.options or {}
end

local function GetColors()
    local options = GetOptions()
    return options.colors or {}
end

local function GetButtonWidth()
    local width = tonumber(GetOptions().buttonWidth) or 230
    if width < 120 then
        width = 120
    end
    return width
end

local function GetLineHeight()
    local height = tonumber(GetOptions().lineHeight) or 16
    if height < 10 then
        height = 10
    end
    return height
end

local function GetTitleHeight()
    local height = tonumber(GetOptions().titleHeight) or GetLineHeight()
    if height < 10 then
        height = 10
    end
    return height
end

local function GetItemButtonScale()
    local scale = tonumber(QuestKing.itemButtonScale) or tonumber(GetOptions().itemButtonScale) or 1
    if scale <= 0 then
        scale = 1
    end
    return scale
end

local function GetItemAnchorSide()
    return GetOptions().itemAnchorSide == "left" and "left" or "right"
end

local function GetItemInset(lineHeight, itemButtonScale, hasItemButton)
    if not hasItemButton then
        return 0
    end

    return floor((lineHeight * 2 * itemButtonScale) + 10)
end

local function HideQuestKingTooltips()
    if QuestKing and QuestKing.HideTooltip then
        QuestKing:HideTooltip()
    end
end

local function QueueTrackerRefresh(forceBuild)
    if QuestKing and type(QuestKing.QueueTrackerUpdate) == "function" then
        QuestKing:QueueTrackerUpdate(forceBuild, false)
        return
    end

    if QuestKing and type(QuestKing.UpdateTracker) == "function" then
        QuestKing:UpdateTracker(forceBuild, false)
    end
end

local function IsInCombatLockdownSafe()
    return type(InCombatLockdown) == "function" and InCombatLockdown() or false
end

local function ApplyButtonBackdrop(button)
    if not button then
        return
    end

    if button.SetBackdrop then
        button:SetBackdrop({
            bgFile = "Interface/Tooltips/UI-Tooltip-Background",
            insets = { left = 0, right = 0, top = 0, bottom = 0 },
        })
        button:SetBackdropColor(0, 0, 0, 0)
        return
    end

    if not button.background then
        local background = button:CreateTexture(nil, "BACKGROUND")
        background:SetAllPoints(button)
        background:SetColorTexture(0, 0, 0, 0)
        button.background = background
    else
        button.background:SetColorTexture(0, 0, 0, 0)
        button.background:Show()
    end
end

local function SetTransparentBackground(button)
    if not button then
        return
    end

    if button.SetBackdropColor then
        button:SetBackdropColor(0, 0, 0, 0)
    elseif button.background then
        button.background:SetColorTexture(0, 0, 0, 0)
    end
end

local function ApplyFontStyle(fontString, sizeOverride)
    if not fontString then
        return
    end

    local options = GetOptions()
    local fontPath = options.font or STANDARD_TEXT_FONT
    local fontSize = tonumber(sizeOverride) or tonumber(options.fontSize) or 12
    local fontStyle = options.fontStyle or ""

    fontString:SetFont(fontPath, fontSize, fontStyle)
    fontString:SetShadowOffset(1, -1)
    fontString:SetShadowColor(0, 0, 0, 1)
    if fontString.SetSpacing then
        fontString:SetSpacing(0)
    end
end

local function hideOnOnFinished(self)
    self:GetParent():Hide()
end

local function buttonPulse(self, r, g, b)
    local pulser = self.buttonPulser
    if not pulser then
        return
    end

    pulser:SetVertexColor(r or 1, g or 1, b or 1)
    pulser:Show()

    if pulser.animGroup then
        pulser.animGroup:Stop()
        pulser.animGroup:Play()
    end
end

local function buttonSetIcon(self, iconType)
    local icon = self.icon
    if not icon then
        return
    end

    if iconType == "QuestIcon-Exclamation" then
        icon:SetTexCoord(0.13476563, 0.17187500, 0.01562500, 0.53125000)
    elseif iconType == "QuestIcon-QuestionMark" then
        icon:SetTexCoord(0.17578125, 0.21289063, 0.01562500, 0.53125000)
    else
        icon:SetTexCoord(0, 1, 0, 1)
    end

    icon:Show()
    if icon.animGroup then
        icon.animGroup:Play()
    end
end

local function titleSetTextIcon(self, ...)
    self:SetText(...)
    self:Hide()
    self:Show()
    self:SetAlpha(0)
    self:SetAlpha(1)
end

local function titleSetFormattedTextIcon(self, ...)
    self:SetFormattedText(...)
    self:Hide()
    self:Show()
    self:SetAlpha(0)
    self:SetAlpha(1)
end

local function GetLineContentHeight(line)
    if line.timerBar or line.progressBar then
        local bar = line.timerBar or line.progressBar
        local barHeight = (bar and bar.GetHeight and bar:GetHeight()) or BAR_HEIGHT_FALLBACK
        return barHeight + BAR_VERTICAL_PADDING
    end

    local textHeight = line:GetStringHeight() or 0
    if textHeight <= 0 then
        textHeight = GetLineHeight()
    end

    return max(GetLineHeight(), textHeight)
end

function WatchButton:StartOrder()
    for index = 1, #usedPool do
        local button = usedPool[index]
        if button then
            button.wasRequested = false
        end
    end

    for index = 1, #requestOrder do
        requestOrder[index] = nil
    end

    WatchButton.requestCount = 0
end

function WatchButton:FreeUnused()
    for index = #usedPool, 1, -1 do
        local button = usedPool[index]
        if button and button.wasRequested == false then
            button:Wipe()
            tremove(usedPool, index)
            tinsert(freePool, button)
        end
    end
end

function WatchButton:GetKeyedRaw(buttonType, uniq)
    for index = 1, #usedPool do
        local button = usedPool[index]
        if button.type == buttonType and button.uniq == uniq then
            return button
        end
    end

    return nil
end

function WatchButton:GetKeyed(buttonType, uniq)
    local button = self:GetKeyedRaw(buttonType, uniq)

    if button then
        button.fresh = false
    else
        if #freePool > 0 then
            button = tremove(freePool)
        else
            button = WatchButton:Create()
        end

        tinsert(usedPool, button)
        button.fresh = true
        button.type = buttonType
        button.uniq = uniq

        if buttonType == "header" then
            button.titleButton:EnableMouse(false)
        end
    end

    WatchButton.requestCount = WatchButton.requestCount + 1
    requestOrder[WatchButton.requestCount] = button
    button.wasRequested = true
    button:Ready()

    return button
end

function WatchButton:Wipe()
    self:Hide()
    self.wasRequested = false

    if self.itemButton then
        if IsInCombatLockdownSafe() then
            if QuestKing and type(QuestKing.StartCombatTimer) == "function" then
                QuestKing:StartCombatTimer()
            end
        elseif type(self.RemoveItemButton) == "function" then
            self:RemoveItemButton()
        end
    end

    self:EnableMouse(false)
    self.titleButton:EnableMouse(true)
    self.titleButton:Show()
    self.noTitle = false

    SetTransparentBackground(self)

    self:SetScript("OnUpdate", nil)

    if self.icon and self.icon.animGroup then
        self.icon.animGroup:Stop()
        self.icon:Hide()
    end

    if self.buttonPulser and self.buttonPulser.animGroup then
        self.buttonPulser.animGroup:Stop()
        self.buttonPulser:Hide()
    end

    if self.challengeBar then
        self.challengeBar:SetScript("OnUpdate", nil)
        self.challengeBar:Hide()
        self.challengeBar = nil
        self.challengeBarIcon = nil
        self.challengeBarText = nil
    end

    if self._challengeBarPersistent then
        self._challengeBarPersistent:SetScript("OnUpdate", nil)
        self._challengeBarPersistent:Hide()
    end

    local lines = self.lines or {}
    for index = 1, #lines do
        local line = lines[index]
        if line and line.Wipe then
            line:Wipe()
        end
    end

    self.title:SetWidth(GetButtonWidth())
    self.title:SetText("")
    self.title:SetTextColor(1, 1, 0, 1)

    self.mouseHandler = nil

    self.questID = nil
    self.questIndex = nil
    self.questLogIndex = nil
    self.achievementID = nil
    self.stepIndex = nil

    self._questCompleted = nil
    self._lastNumObj = nil
    self._lastStepIndex = nil
    self._previousHeader = nil

    self._challengeMedalTimes = nil
    self._challengeTime = nil
    self._challengeCurrentMedalTime = nil
    self._challengeRecheck = nil

    self._popupType = nil
    self._itemID = nil
    self._headerName = nil

    self.type = "none"
    self.uniq = 0
end

function WatchButton:HideTitle()
    self.titleButton:Hide()
    self.noTitle = true
end

function WatchButton:Ready()
    self.currentLine = 0
    self:SetWidth(GetButtonWidth())
    self.titleButton:SetWidth(GetButtonWidth())
    self.titleButton:SetHeight(GetTitleHeight())
    self.title:SetHeight(GetTitleHeight())

    ApplyFontStyle(self.title)

    local lines = self.lines or {}
    for index = 1, #lines do
        local line = lines[index]
        if line then
            ApplyFontStyle(line)
            if line.right then
                ApplyFontStyle(line.right)
            end
        end
    end
end

local function lineWipe(self)
    self:Hide()

    if self.right then
        self.right:Hide()
        self.right:SetText("")
        self.right:ClearAllPoints()
    end

    if self.flash and self.flash.animGroup then
        self.flash.animGroup:Stop()
        self.flash:Hide()
        self.flash:SetAlpha(0)
    end

    if self.glow and self.glow.animGroup then
        self.glow.animGroup:Stop()
        self.glow:Hide()
        self.glow:SetAlpha(0)
    end

    if self.timerBar then
        self.timerBar:Free()
    end

    if self.progressBar then
        self.progressBar:Free()
    end

    self._lastQuant = nil
    self.isTimer = false
    self:SetText("")
    self:ClearAllPoints()
    self:SetWidth(0)
    self:SetHeight(0)
end

local function lineFlash(self)
    if self.timerBar or self.progressBar or not self.flash then
        return
    end

    self.flash:Show()
    if self.flash.animGroup then
        self.flash.animGroup:Stop()
        self.flash.animGroup:Play()
    end
end

local function lineGlow(self, r, g, b)
    if self.timerBar or self.progressBar or not self.glow then
        return
    end

    self.glow:SetVertexColor(r or 0.8, g or 0.6, b or 0.2)
    self.glow:Show()
    if self.glow.animGroup then
        self.glow.animGroup:Stop()
        self.glow.animGroup:Play()
    end
end

function WatchButton:CreateLines()
    local buttonWidth = GetButtonWidth()
    local colors = GetColors()
    local flashColor = colors.ObjectiveProgressFlash or { 1, 1, 1 }

    local line = self:CreateFontString(nil, GetOptions().fontLayer)
    ApplyFontStyle(line)
    line:SetJustifyH("LEFT")
    line:SetJustifyV("TOP")
    line:SetTextColor(1, 1, 0)
    line:SetPoint("TOPLEFT", 0, 0)
    line:SetWordWrap(true)
    line:SetNonSpaceWrap(true)
    tinsert(self.lines, line)

    local right = self:CreateFontString(nil, GetOptions().fontLayer)
    ApplyFontStyle(right)
    right:SetJustifyH("RIGHT")
    right:SetJustifyV("TOP")
    right:SetTextColor(1, 1, 0)
    right:SetPoint("TOPLEFT", 0, 0)
    right:SetWordWrap(false)
    line.right = right

    local flash = self:CreateTexture(nil, "OVERLAY")
    flash:SetPoint("TOPLEFT", line)
    flash:SetPoint("BOTTOMLEFT", line)
    flash:SetWidth(buttonWidth)
    flash:SetTexture([[Interface\QuestFrame\UI-QuestLogTitleHighlight]])
    flash:SetBlendMode("ADD")
    flash:SetVertexColor(flashColor[1] or 1, flashColor[2] or 1, flashColor[3] or 1, 0)
    flash:Hide()

    do
        local flashAnimGroup = flash:CreateAnimationGroup()

        local fa1 = flashAnimGroup:CreateAnimation("Alpha")
        fa1:SetStartDelay(0)
        fa1:SetDuration(0.15)
        fa1:SetFromAlpha(0)
        fa1:SetToAlpha(1)
        fa1:SetOrder(1)
        fa1:SetSmoothing("OUT")

        local fa2 = flashAnimGroup:CreateAnimation("Alpha")
        fa2:SetStartDelay(0.25)
        fa2:SetDuration(0.50)
        fa2:SetFromAlpha(1)
        fa2:SetToAlpha(0)
        fa2:SetOrder(2)
        fa2:SetSmoothing("IN")

        flashAnimGroup:SetScript("OnFinished", hideOnOnFinished)
        flash.animGroup = flashAnimGroup
    end

    line.flash = flash
    line.Flash = lineFlash

    local glow = self:CreateTexture(nil, "OVERLAY")
    glow:SetPoint("TOPLEFT", line)
    glow:SetPoint("BOTTOMLEFT", line, 0, -2.5)
    glow:SetWidth(buttonWidth)
    glow:SetTexture([[Interface\AddOns\QuestKing\textures\Objective-Lineglow-White]])
    glow:SetBlendMode("ADD")
    glow:SetVertexColor(0.8, 0.6, 0.2, 0)
    glow:Hide()

    do
        local glowAnimGroup = glow:CreateAnimationGroup()

        local ga0 = glowAnimGroup:CreateAnimation("Scale")
        ga0:SetStartDelay(0)
        ga0:SetScale(0.2, 1)
        ga0:SetDuration(0)
        ga0:SetOrder(1)
        ga0:SetOrigin("LEFT", 0, 0)

        local ga1 = glowAnimGroup:CreateAnimation("Scale")
        ga1:SetStartDelay(0.067)
        ga1:SetScale(5, 1)
        ga1:SetDuration(0.633)
        ga1:SetOrder(1)
        ga1:SetOrigin("LEFT", 0, 0)

        local ga2 = glowAnimGroup:CreateAnimation("Alpha")
        ga2:SetStartDelay(0.067)
        ga2:SetFromAlpha(0)
        ga2:SetToAlpha(1)
        ga2:SetDuration(0.1)
        ga2:SetOrder(1)

        local ga3 = glowAnimGroup:CreateAnimation("Alpha")
        ga3:SetStartDelay(0.867)
        ga3:SetFromAlpha(1)
        ga3:SetToAlpha(0)
        ga3:SetDuration(0.267)
        ga3:SetOrder(1)

        glowAnimGroup:SetScript("OnFinished", hideOnOnFinished)
        glow.animGroup = glowAnimGroup
    end

    line.glow = glow
    line.Glow = lineGlow
    line.Wipe = lineWipe

    return line, right
end

function WatchButton:AddLine(textleft, textright, r, g, b, a)
    local currentLine = self.currentLine + 1
    self.currentLine = currentLine

    local line = self.lines[currentLine]
    local right = line and line.right or nil

    if not line then
        line, right = self:CreateLines()
    end

    line.isTimer = false
    line:SetText(textleft or "")
    right:SetText(textright or "")

    if r ~= nil then
        line:SetTextColor(r, g, b, a or 1)
        right:SetTextColor(r, g, b, a or 1)
    else
        line:SetTextColor(1, 1, 0, 1)
        right:SetTextColor(1, 1, 0, 1)
    end

    return line
end

function WatchButton:AddLineIcon(...)
    local line = self:AddLine(...)
    line:Hide()
    line:Show()
    line:SetAlpha(0)
    line:SetAlpha(1)
    return line
end

function WatchButton:Render()
    local noTitle = self.noTitle
    local lastRegion = nil
    local contentHeight = 0

    local buttonWidth = GetButtonWidth()
    local lineHeight = GetLineHeight()
    local itemButtonScale = GetItemButtonScale()
    local itemAnchorSide = GetItemAnchorSide()
    local itemInset = GetItemInset(lineHeight, itemButtonScale, self.itemButton ~= nil)

    self:SetWidth(buttonWidth)
    self.titleButton:SetWidth(buttonWidth)
    self.titleButton:SetHeight(GetTitleHeight())

    if self.title then
        local titleLeftInset = 0
        local titleRightInset = 0

        if itemInset > 0 then
            if itemAnchorSide == "right" then
                titleRightInset = itemInset
            else
                titleLeftInset = itemInset
            end
        end

        self.title:ClearAllPoints()
        self.title:SetPoint("TOPLEFT", self.titleButton, "TOPLEFT", titleLeftInset, 0)
        self.title:SetPoint("TOPRIGHT", self.titleButton, "TOPRIGHT", -titleRightInset, 0)
        self.title:SetWidth(buttonWidth - titleLeftInset - titleRightInset)
        self.title:SetHeight(self.titleButton:GetHeight())
    end

    for index = 1, #self.lines do
        local line = self.lines[index]
        local right = line.right

        if index > self.currentLine then
            line:Wipe()
        else
            line:Show()

            local rightText = right:GetText()
            local hasRightText = rightText and rightText ~= ""

            if hasRightText then
                right:Show()
            else
                right:Hide()
            end

            line:ClearAllPoints()
            right:ClearAllPoints()

            local lineLeftInset = LINE_INDENT_LEFT
            local lineRightInset = LINE_RIGHT_PADDING

            if itemInset > 0 then
                if itemAnchorSide == "right" then
                    lineRightInset = lineRightInset + itemInset
                else
                    lineLeftInset = lineLeftInset + itemInset
                end
            end

            if not lastRegion then
                if noTitle then
                    line:SetPoint("TOPLEFT", self, "TOPLEFT", lineLeftInset, 0)
                else
                    line:SetPoint("TOPLEFT", self.title, "BOTTOMLEFT", 0, -TITLE_TO_FIRST_LINE_GAP)
                end
            else
                line:SetPoint("TOPLEFT", lastRegion, "BOTTOMLEFT", 0, -LINE_GAP)
            end

            if hasRightText then
                right:SetPoint("TOPRIGHT", self, "TOPRIGHT", -lineRightInset, 0)

                local rightWidth = right:GetStringWidth() or 0
                if rightWidth < 0 then
                    rightWidth = 0
                end

                local availableWidth = buttonWidth - lineLeftInset - lineRightInset - rightWidth
                if availableWidth < 40 then
                    availableWidth = 40
                end

                line:SetWidth(availableWidth)
            else
                line:SetWidth(buttonWidth - lineLeftInset - lineRightInset)
            end

            if line.flash then
                line.flash:SetWidth(buttonWidth)
            end

            if line.glow then
                line.glow:SetWidth(buttonWidth)
            end

            line:SetHeight(0)

            if line.timerBar or line.progressBar then
                line:SetHeight(GetLineContentHeight(line))
            else
                local measuredHeight = line:GetStringHeight() or 0
                if measuredHeight <= 0 then
                    measuredHeight = lineHeight
                end
                line:SetHeight(max(lineHeight, measuredHeight))
            end

            lastRegion = line
            contentHeight = contentHeight + line:GetHeight()
            if index > 1 then
                contentHeight = contentHeight + LINE_GAP
            end
        end
    end

    if self.challengeBar then
        contentHeight = contentHeight + (self.challengeBar.bonusHeight or 0)
    end

    local totalHeight
    if noTitle then
        totalHeight = contentHeight
    else
        totalHeight = self.titleButton:GetHeight()
        if self.currentLine > 0 then
            totalHeight = totalHeight + TITLE_TO_FIRST_LINE_GAP + contentHeight
        end
    end

    totalHeight = totalHeight + BUTTON_BOTTOM_PADDING
    totalHeight = max(totalHeight, self.titleButton:GetHeight(), lineHeight)

    self:SetHeight(totalHeight)
    self:Show()

    if self.itemButton then
        if IsInCombatLockdownSafe() then
            if QuestKing and type(QuestKing.StartCombatTimer) == "function" then
                QuestKing:StartCombatTimer()
            end
        else
            self.itemButton:ClearAllPoints()

            if itemAnchorSide == "right" then
                self.itemButton:SetPoint("TOPRIGHT", self, "TOPRIGHT", -4, -1)
            else
                self.itemButton:SetPoint("TOPLEFT", self, "TOPLEFT", 4, -1)
            end
        end
    end
end

function WatchButton:Create()
    buttonCounter = buttonCounter + 1

    local buttonWidth = GetButtonWidth()
    local lineHeight = GetLineHeight()
    local titleHeight = GetTitleHeight()

    local parent = QuestKing and QuestKing.Tracker or UIParent
    local button = CreateFrame("Button", nil, parent, BACKDROP_TEMPLATE)
    button.name = "QuestKingPoolButton" .. buttonCounter
    button:SetWidth(buttonWidth)
    button:SetHeight(lineHeight)
    button:SetPoint("TOPLEFT", 0, 0)

    ApplyButtonBackdrop(button)

    local buttonHighlight = button:CreateTexture(nil, "HIGHLIGHT")
    buttonHighlight:SetAllPoints(button)
    buttonHighlight:SetTexture([[Interface\QuestFrame\UI-QuestLogTitleHighlight]])
    buttonHighlight:SetAlpha(0.5)
    button.buttonHighlightTexture = buttonHighlight

    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:EnableMouse(false)
    button:SetHighlightTexture(buttonHighlight, "ADD")
    button:SetScript("OnClick", WatchButton.ButtonOnClick)
    button:SetScript("OnEnter", WatchButton.ButtonOnEnter)
    button:SetScript("OnLeave", WatchButton.ButtonOnLeave)

    local buttonPulser = button:CreateTexture(nil, "OVERLAY")
    buttonPulser:SetAllPoints(button)
    buttonPulser:SetTexture([[Interface\QuestFrame\UI-QuestLogTitleHighlight]])
    buttonPulser:SetBlendMode("ADD")
    buttonPulser:SetAlpha(0)

    do
        local animGroup = buttonPulser:CreateAnimationGroup()

        local a1 = animGroup:CreateAnimation("Alpha")
        a1:SetStartDelay(0)
        a1:SetDuration(0.50)
        a1:SetFromAlpha(0)
        a1:SetToAlpha(1)
        a1:SetOrder(1)
        a1:SetSmoothing("OUT")

        local a2 = animGroup:CreateAnimation("Alpha")
        a2:SetStartDelay(0.2)
        a2:SetDuration(0.50)
        a2:SetFromAlpha(1)
        a2:SetToAlpha(0)
        a2:SetOrder(2)
        a2:SetSmoothing("IN")

        animGroup:SetLooping("NONE")
        animGroup:SetScript("OnFinished", hideOnOnFinished)
        buttonPulser.animGroup = animGroup
    end

    button.buttonPulser = buttonPulser
    button.Pulse = buttonPulse

    local icon = button:CreateTexture(nil, "OVERLAY", "QuestIcon-Exclamation")
    icon:ClearAllPoints()
    icon:SetPoint("RIGHT", button, "LEFT")
    icon:SetHeight(lineHeight * 2 - 2)
    icon:SetWidth(lineHeight * 1.4)
    icon:Hide()

    do
        local iconAnimGroup = icon:CreateAnimationGroup()
        local ia1 = iconAnimGroup:CreateAnimation("Alpha")
        ia1:SetStartDelay(0.25)
        ia1:SetDuration(0.33)
        ia1:SetFromAlpha(1)
        ia1:SetToAlpha(0)
        ia1:SetOrder(1)
        ia1:SetSmoothing("IN")
        iconAnimGroup:SetLooping("BOUNCE")
        icon.animGroup = iconAnimGroup
    end

    button.icon = icon
    button.SetIcon = buttonSetIcon

    local titleButton = CreateFrame("Button", nil, button, BACKDROP_TEMPLATE)
    titleButton:SetPoint("TOPLEFT", 0, 0)
    titleButton:SetWidth(buttonWidth)
    titleButton:SetHeight(titleHeight)
    titleButton.parent = button
    titleButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    titleButton:SetScript("OnClick", WatchButton.TitleButtonOnClick)
    titleButton:SetScript("OnEnter", WatchButton.TitleButtonOnEnter)
    titleButton:SetScript("OnLeave", WatchButton.TitleButtonOnLeave)

    local titleButtonHighlight = titleButton:CreateTexture(nil, "HIGHLIGHT")
    titleButtonHighlight:SetAllPoints(titleButton)
    titleButtonHighlight:SetTexture([[Interface\QuestFrame\UI-QuestLogTitleHighlight]])
    titleButtonHighlight:SetAlpha(0.5)
    titleButton.highlightTexture = titleButtonHighlight

    titleButton:EnableMouse(true)
    titleButton:SetHighlightTexture(titleButtonHighlight, "ADD")
    button.titleButton = titleButton

    local title = titleButton:CreateFontString(nil, GetOptions().fontLayer)
    ApplyFontStyle(title)
    title:SetJustifyH("LEFT")
    title:SetJustifyV("TOP")
    title:SetTextColor(1, 1, 0)
    title:SetPoint("TOPLEFT", 0, 0)
    title:SetWidth(buttonWidth)
    title:SetHeight(titleHeight)
    title:SetWordWrap(false)
    title:SetText("")
    title.SetTextIcon = titleSetTextIcon
    title.SetFormattedTextIcon = titleSetFormattedTextIcon

    button.title = title
    titleButton.text = title

    button.lines = {}
    button.currentLine = 0
    button.challengeBarShown = false

    setmetatable(button, WatchButton)
    button:Wipe()

    return button
end

function WatchButton:TitleButtonOnEnter(motion)
    local button = self.parent
    if button.mouseHandler and button.mouseHandler.TitleButtonOnEnter then
        button.mouseHandler.TitleButtonOnEnter(self, motion)
        return
    end
end

function WatchButton:TitleButtonOnLeave(motion)
    HideQuestKingTooltips()
end

function WatchButton:TitleButtonOnClick(mouse, down)
    local button = self.parent

    if button.mouseHandler and button.mouseHandler.TitleButtonOnClick then
        button.mouseHandler.TitleButtonOnClick(self, mouse, down)
        return
    end

    if button.type == "collapser" then
        local headerName = button._headerName
        if not headerName then
            return
        end

        QuestKingDBPerChar = QuestKingDBPerChar or {}
        QuestKingDBPerChar.collapsedHeaders = QuestKingDBPerChar.collapsedHeaders or {}
        QuestKing.newlyAddedQuests = QuestKing.newlyAddedQuests or {}

        if QuestKingDBPerChar.collapsedHeaders[headerName] then
            QuestKingDBPerChar.collapsedHeaders[headerName] = nil
            wipe(QuestKing.newlyAddedQuests)
        else
            QuestKingDBPerChar.collapsedHeaders[headerName] = true
        end

        QueueTrackerRefresh(true)
    end
end

function WatchButton:ButtonOnEnter(motion)
    local button = self
    if button.mouseHandler and button.mouseHandler.TitleButtonOnEnter then
        button.mouseHandler.TitleButtonOnEnter(self, motion)
        return
    end
end

function WatchButton:ButtonOnLeave(motion)
    HideQuestKingTooltips()
end

function WatchButton:ButtonOnClick(mouse, down)
    local button = self
    if button.mouseHandler and button.mouseHandler.ButtonOnClick then
        button.mouseHandler.ButtonOnClick(self, mouse, down)
        return
    end
end
