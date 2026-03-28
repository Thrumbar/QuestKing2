local addonName, QuestKing = ...

local opt = QuestKing.options

local tinsert = table.insert
local tremove = table.remove
local max = math.max

local BACKDROP_TEMPLATE = BackdropTemplateMixin and "BackdropTemplate" or nil

local LINE_INDENT_LEFT = 0
local LINE_RIGHT_PADDING = 4
local LINE_GAP = 2
local TITLE_TO_FIRST_LINE_GAP = 2
local BAR_VERTICAL_PADDING = 4
local BUTTON_BOTTOM_PADDING = 4
local BAR_HEIGHT_FALLBACK = 15

local WatchButtonPrototype = CreateFrame("Frame")
local WatchButton = setmetatable({}, { __index = WatchButtonPrototype })
WatchButton.__index = WatchButton
QuestKing.WatchButton = WatchButton

local function GetButtonWidth()
    return (opt and opt.buttonWidth) or 230
end

local function GetLineHeight()
    return (opt and opt.lineHeight) or 16
end

local function GetTitleHeight()
    local titleHeight = (opt and opt.titleHeight) or 0
    if titleHeight > 0 then
        return titleHeight
    end
    return GetLineHeight()
end

local function GetFontPath()
    return (opt and opt.font) or STANDARD_TEXT_FONT
end

local function GetFontSize()
    return (opt and opt.fontSize) or 12
end

local function GetFontStyle()
    return (opt and opt.fontStyle) or ""
end

local function GetFontLayer()
    return (opt and opt.fontLayer) or "OVERLAY"
end

local function GetColors()
    return (opt and opt.colors) or {}
end

local function GetItemButtonScale()
    local scale = (opt and opt.itemButtonScale) or 1
    if scale <= 0 then
        scale = 1
    end
    return scale
end

local function GetItemAnchorSide()
    return (opt and opt.itemAnchorSide) or "right"
end

local function ApplyFontStringStyle(fontString)
    if not fontString then
        return
    end

    fontString:SetFont(GetFontPath(), GetFontSize(), GetFontStyle())
    fontString:SetShadowOffset(1, -1)
    fontString:SetShadowColor(0, 0, 0, 1)
end

local function HideOnAnimFinished(animationGroup)
    local parent = animationGroup and animationGroup:GetParent()
    if parent then
        parent:Hide()
    end
end

local function GetLineAvailableWidth(line)
    local right = line and line.right
    local rightWidth = 0

    if right and right:IsShown() then
        rightWidth = right:GetStringWidth() or 0
        if rightWidth < 0 then
            rightWidth = 0
        end
    end

    local availableWidth = GetButtonWidth() - LINE_INDENT_LEFT - LINE_RIGHT_PADDING - rightWidth
    if availableWidth < 40 then
        availableWidth = 40
    end

    return availableWidth, rightWidth
end

local function GetLineContentHeight(line)
    if not line then
        return GetLineHeight()
    end

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

do
    local buttonCounter = 0

    local usedPool = {}
    local freePool = {}
    local requestOrder = {}

    WatchButton.usedPool = usedPool
    WatchButton.freePool = freePool
    WatchButton.requestOrder = requestOrder
    WatchButton.requestCount = 0

    function WatchButton:StartOrder()
        for i = 1, #usedPool do
            local button = usedPool[i]
            if button then
                button.wasRequested = false
            end
        end

        WatchButton.requestCount = 0
    end

    function WatchButton:FreeUnused()
        for i = #usedPool, 1, -1 do
            local button = usedPool[i]
            if button and button.wasRequested == false then
                button:Wipe()
                tremove(usedPool, i)
                tinsert(freePool, button)
            end
        end
    end

    function WatchButton:GetKeyedRaw(buttonType, uniq)
        for i = 1, #usedPool do
            local button = usedPool[i]
            if button.type == buttonType and button.uniq == uniq then
                return button
            end
        end

        return nil
    end

    function WatchButton:GetKeyed(buttonType, uniq)
        local button

        for i = 1, #usedPool do
            local existing = usedPool[i]
            if existing.type == buttonType and existing.uniq == uniq then
                button = existing
                button.fresh = false
                break
            end
        end

        if not button then
            if #freePool > 0 then
                button = tremove(freePool)
            else
                button = WatchButton:Create()
            end

            tinsert(usedPool, button)

            button.fresh = true
            button.type = buttonType
            button.uniq = uniq

            if buttonType == "header" and button.titleButton then
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

        if self.itemButton then
            if InCombatLockdown and InCombatLockdown() then
                if QuestKing.StartCombatTimer then
                    QuestKing:StartCombatTimer()
                end
            else
                if self.RemoveItemButton then
                    self:RemoveItemButton()
                end
            end
        end

        self:EnableMouse(false)

        if self.titleButton then
            self.titleButton:EnableMouse(true)
            self.titleButton:Show()
            self.titleButton:SetWidth(GetButtonWidth())
            self.titleButton:SetHeight(GetTitleHeight())
        end

        if self.SetBackdropColor then
            self:SetBackdropColor(0, 0, 0, 0)
        end

        self:SetWidth(GetButtonWidth())
        self:SetHeight(GetLineHeight())
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
            self.challengeBar:Hide()
            self.challengeBar:SetScript("OnUpdate", nil)
            self.challengeBar = nil
            self.challengeBarIcon = nil
            self.challengeBarText = nil
        end

        local lines = self.lines or {}
        for i = 1, #lines do
            lines[i]:Wipe()
        end

        self.noTitle = false
        self.mouseHandler = nil

        self.questID = nil
        self.questIndex = nil
        self.questLogIndex = nil
        self.questKind = nil

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
        self.currentLine = 0
        self.challengeBarShown = false
        self.wasRequested = nil

        if self.title then
            ApplyFontStringStyle(self.title)
            self.title:ClearAllPoints()
            self.title:SetPoint("TOPLEFT", 0, 0)
            self.title:SetWidth(GetButtonWidth())
            self.title:SetHeight(GetTitleHeight())
            self.title:SetJustifyH("LEFT")
            self.title:SetJustifyV("TOP")
            self.title:SetTextColor(1, 1, 0, 1)
            self.title:SetWordWrap(false)
            self.title:SetText("")
            self.title:Show()
        end

        if self.level then
            ApplyFontStringStyle(self.level)
            self.level:SetText("")
            self.level:ClearAllPoints()
            self.level:SetPoint("TOPLEFT", self, "TOPLEFT", 4, -4)
            self.level:Hide()
        end

        if self.completed then
            self.completed:Hide()
        end
    end

    function WatchButton:HideTitle()
        self.noTitle = true
        if self.titleButton then
            self.titleButton:Hide()
        end
    end

    function WatchButton:Ready()
        self.currentLine = 0
        self:SetWidth(GetButtonWidth())

        if self.titleButton then
            self.titleButton:SetWidth(GetButtonWidth())
            self.titleButton:SetHeight(GetTitleHeight())
        end

        if self.title then
            ApplyFontStringStyle(self.title)
            self.title:SetWidth(GetButtonWidth())
            self.title:SetHeight(GetTitleHeight())
        end

        if self.level then
            ApplyFontStringStyle(self.level)
        end
    end

    local function ButtonPulse(self, r, g, b)
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

    local function ButtonSetIcon(self, iconType)
        local icon = self.icon
        if not icon then
            return
        end

        if iconType == "QuestIcon-Exclamation" then
            icon:SetTexCoord(0.13476563, 0.17187500, 0.01562500, 0.53125000)
        elseif iconType == "QuestIcon-QuestionMark" then
            icon:SetTexCoord(0.17578125, 0.21289063, 0.01562500, 0.53125000)
        end

        icon:Show()

        if icon.animGroup then
            icon.animGroup:Stop()
            icon.animGroup:Play()
        end
    end

    local function TitleSetTextIcon(self, ...)
        self:SetText(...)
        self:Hide()
        self:Show()
        self:SetAlpha(0)
        self:SetAlpha(1)
    end

    local function TitleSetFormattedTextIcon(self, ...)
        self:SetFormattedText(...)
        self:Hide()
        self:Show()
        self:SetAlpha(0)
        self:SetAlpha(1)
    end

    function WatchButton:Create()
        buttonCounter = buttonCounter + 1

        local name = "QuestKing_PoolButton" .. buttonCounter
        local button = CreateFrame("Button", name, QuestKing.Tracker, BACKDROP_TEMPLATE)

        button.name = name
        button:SetWidth(GetButtonWidth())
        button:SetHeight(GetLineHeight())
        button:SetPoint("TOPLEFT", 0, 0)

        if button.SetBackdrop then
            button:SetBackdrop({
                bgFile = "Interface/Tooltips/UI-Tooltip-Background",
                insets = { left = 0, right = 0, top = 0, bottom = 0 },
            })
            button:SetBackdropColor(0, 0, 0, 0)
        end

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

        local buttonPulser = button:CreateTexture(nil, "ARTWORK")
        buttonPulser:SetAllPoints(button)
        buttonPulser:SetTexture([[Interface\QuestFrame\UI-QuestLogTitleHighlight]])
        buttonPulser:SetBlendMode("ADD")
        buttonPulser:SetAlpha(0)
        buttonPulser:Hide()

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
            animGroup:SetScript("OnFinished", HideOnAnimFinished)

            buttonPulser.animGroup = animGroup
        end

        button.buttonPulser = buttonPulser
        button.Pulse = ButtonPulse

        local icon = button:CreateTexture(nil, "OVERLAY")
        icon:ClearAllPoints()
        icon:SetPoint("RIGHT", button, "LEFT")
        icon:SetHeight(GetLineHeight() * 2 - 2)
        icon:SetWidth(GetLineHeight() * 1.4)
        icon:Hide()

        do
            local iconAnimGroup = icon:CreateAnimationGroup()

            local a1 = iconAnimGroup:CreateAnimation("Alpha")
            a1:SetStartDelay(0.25)
            a1:SetDuration(0.33)
            a1:SetFromAlpha(1)
            a1:SetToAlpha(0)
            a1:SetOrder(1)
            a1:SetSmoothing("IN")

            iconAnimGroup:SetLooping("BOUNCE")
            icon.animGroup = iconAnimGroup
        end

        button.icon = icon
        button.SetIcon = ButtonSetIcon

        local titleButton = CreateFrame("Button", nil, button, BACKDROP_TEMPLATE)
        titleButton:SetPoint("TOPLEFT", 0, 0)
        titleButton:SetWidth(GetButtonWidth())
        titleButton:SetHeight(GetTitleHeight())
        titleButton.parent = button

        titleButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        titleButton:SetScript("OnClick", WatchButton.TitleButtonOnClick)
        titleButton:SetScript("OnEnter", WatchButton.TitleButtonOnEnter)
        titleButton:SetScript("OnLeave", WatchButton.TitleButtonOnLeave)

        local titleHighlight = titleButton:CreateTexture(nil, "HIGHLIGHT")
        titleHighlight:SetAllPoints(titleButton)
        titleHighlight:SetTexture([[Interface\QuestFrame\UI-QuestLogTitleHighlight]])
        titleHighlight:SetAlpha(0.5)
        titleButton.highlightTexture = titleHighlight

        titleButton:EnableMouse(true)
        titleButton:SetHighlightTexture(titleHighlight, "ADD")
        button.titleButton = titleButton

        local title = titleButton:CreateFontString(nil, GetFontLayer())
        ApplyFontStringStyle(title)
        title:SetJustifyH("LEFT")
        title:SetJustifyV("TOP")
        title:SetTextColor(1, 1, 0, 1)
        title:SetPoint("TOPLEFT", 0, 0)
        title:SetWidth(GetButtonWidth())
        title:SetHeight(GetTitleHeight())
        title:SetWordWrap(false)
        title:SetText("")

        title.SetTextIcon = TitleSetTextIcon
        title.SetFormattedTextIcon = TitleSetFormattedTextIcon

        button.title = title
        titleButton.text = title

        local level = titleButton:CreateFontString(nil, GetFontLayer())
        ApplyFontStringStyle(level)
        level:SetJustifyH("LEFT")
        level:SetJustifyV("TOP")
        level:SetTextColor(1, 0.82, 0, 1)
        level:SetPoint("TOPLEFT", button, "TOPLEFT", 4, -4)
        level:SetWordWrap(false)
        level:SetText("")
        level:Hide()
        button.level = level

        local completed = titleButton:CreateTexture(nil, "OVERLAY")
        completed:SetSize(14, 14)
        completed:SetPoint("TOPRIGHT", titleButton, "TOPRIGHT", -2, -2)
        completed:SetTexture([[Interface\RaidFrame\ReadyCheck-Ready]])
        completed:Hide()
        button.completed = completed

        button.lines = {}
        button.currentLine = 0
        button.challengeBarShown = false

        setmetatable(button, WatchButton)
        button:Wipe()

        return button
    end

    local function LineWipe(self)
        self:Hide()

        if self.right then
            self.right:Hide()
            self.right:SetText("")
            self.right:ClearAllPoints()
        end

        if self.flash and self.flash.animGroup then
            self.flash.animGroup:Stop()
            self.flash:Hide()
        end

        if self.glow and self.glow.animGroup then
            self.glow.animGroup:Stop()
            self.glow:Hide()
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

    local function LineFlash(self)
        if self.timerBar or self.progressBar then
            return
        end

        if self.flash and self.flash.animGroup then
            self.flash:Show()
            self.flash.animGroup:Stop()
            self.flash.animGroup:Play()
        end
    end

    local function LineGlow(self, r, g, b)
        if self.timerBar or self.progressBar then
            return
        end

        if self.glow then
            if r ~= nil and g ~= nil and b ~= nil then
                self.glow:SetVertexColor(r, g, b)
            end

            self.glow:Show()

            if self.glow.animGroup then
                self.glow.animGroup:Stop()
                self.glow.animGroup:Play()
            end
        end
    end

    function WatchButton:CreateLines(currentLine)
        local line = self:CreateFontString(nil, GetFontLayer())
        ApplyFontStringStyle(line)
        line:SetJustifyH("LEFT")
        line:SetJustifyV("TOP")
        line:SetTextColor(1, 1, 0, 1)
        line:SetPoint("TOPLEFT", 0, 0)
        line:SetWordWrap(true)
        line:SetNonSpaceWrap(true)
        tinsert(self.lines, line)

        local right = self:CreateFontString(nil, GetFontLayer())
        ApplyFontStringStyle(right)
        right:SetJustifyH("RIGHT")
        right:SetJustifyV("TOP")
        right:SetTextColor(1, 1, 0, 1)
        right:SetPoint("TOPLEFT", 0, 0)
        right:SetWordWrap(false)
        line.right = right

        local colors = GetColors()

        local flash = self:CreateTexture(nil, "ARTWORK")
        flash:SetPoint("TOPLEFT", line)
        flash:SetPoint("BOTTOMLEFT", line)
        flash:SetWidth(GetButtonWidth())
        flash:SetTexture([[Interface\QuestFrame\UI-QuestLogTitleHighlight]])
        flash:SetBlendMode("ADD")
        flash:SetVertexColor(
            (colors.ObjectiveProgressFlash and colors.ObjectiveProgressFlash[1]) or 1,
            (colors.ObjectiveProgressFlash and colors.ObjectiveProgressFlash[2]) or 1,
            (colors.ObjectiveProgressFlash and colors.ObjectiveProgressFlash[3]) or 1,
            0
        )
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

            flashAnimGroup:SetScript("OnFinished", HideOnAnimFinished)

            flash.animGroup = flashAnimGroup
        end

        line.flash = flash
        line.Flash = LineFlash

        local glow = self:CreateTexture(nil, "ARTWORK")
        glow:SetPoint("TOPLEFT", line)
        glow:SetPoint("BOTTOMLEFT", line, 0, -2.5)
        glow:SetWidth(GetButtonWidth())
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

            glowAnimGroup:SetScript("OnFinished", HideOnAnimFinished)

            glow.animGroup = glowAnimGroup
        end

        line.glow = glow
        line.Glow = LineGlow
        line.Wipe = LineWipe

        return line, right
    end

    function WatchButton:AddLine(textleft, textright, r, g, b, a)
        local currentLine = self.currentLine + 1
        self.currentLine = currentLine

        local line
        local right

        if self.lines[currentLine] then
            line = self.lines[currentLine]
            right = line.right
        else
            line, right = self:CreateLines(currentLine)
        end

        ApplyFontStringStyle(line)
        ApplyFontStringStyle(right)

        line.isTimer = false
        line:SetText(textleft or "")
        right:SetText(textright or "")

        if r ~= nil and g ~= nil and b ~= nil then
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
        if line then
            line:Hide()
            line:Show()
            line:SetAlpha(0)
            line:SetAlpha(1)
        end
        return line
    end

    function WatchButton:Render()
        local noTitle = self.noTitle
        local lastRegion = nil
        local contentHeight = 0
        local buttonWidth = GetButtonWidth()
        local lineHeight = GetLineHeight()
        local titleHeight = GetTitleHeight()

        self:SetWidth(buttonWidth)

        if self.titleButton then
            self.titleButton:SetWidth(buttonWidth)
            self.titleButton:SetHeight(titleHeight)
        end

        if self.title then
            ApplyFontStringStyle(self.title)
            if not (self.level and self.level:IsShown()) then
                self.title:SetWidth(buttonWidth)
            end
        end

        if self.level and self.level:GetText() and self.level:GetText() ~= "" then
            self.level:Show()
        elseif self.level then
            self.level:Hide()
        end

        for i = 1, #self.lines do
            local line = self.lines[i]
            local right = line.right

            if i > self.currentLine then
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

                if lastRegion == nil then
                    if noTitle then
                        line:SetPoint("TOPLEFT", self, "TOPLEFT", LINE_INDENT_LEFT, 0)
                    else
                        line:SetPoint("TOPLEFT", self.title, "BOTTOMLEFT", LINE_INDENT_LEFT, -TITLE_TO_FIRST_LINE_GAP)
                    end
                else
                    line:SetPoint("TOPLEFT", lastRegion, "BOTTOMLEFT", 0, -LINE_GAP)
                end

                if hasRightText then
                    right:SetPoint("TOPRIGHT", self, "TOPRIGHT", -LINE_RIGHT_PADDING, 0)
                    line:SetWidth(GetLineAvailableWidth(line))
                else
                    line:SetWidth(buttonWidth - LINE_INDENT_LEFT - LINE_RIGHT_PADDING)
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

                if i > 1 then
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
            totalHeight = titleHeight
            if self.currentLine > 0 then
                totalHeight = totalHeight + TITLE_TO_FIRST_LINE_GAP + contentHeight
            end
        end

        totalHeight = totalHeight + BUTTON_BOTTOM_PADDING
        totalHeight = max(totalHeight, titleHeight, lineHeight)

        self:SetHeight(totalHeight)
        self:Show()

        if self.itemButton then
            if InCombatLockdown and InCombatLockdown() then
                if QuestKing.StartCombatTimer then
                    QuestKing:StartCombatTimer()
                end
            else
                local scale = GetItemButtonScale()

                self.itemButton:ClearAllPoints()

                if GetItemAnchorSide() == "right" then
                    self.itemButton:SetPoint(
                        "TOPLEFT",
                        UIParent,
                        "BOTTOMLEFT",
                        (self:GetRight() / scale) + 4,
                        (self:GetTop() / scale) - 1
                    )
                else
                    self.itemButton:SetPoint(
                        "TOPRIGHT",
                        UIParent,
                        "BOTTOMLEFT",
                        (self:GetLeft() / scale) - 4,
                        (self:GetTop() / scale) - 1
                    )
                end
            end
        end
    end
end

function WatchButton:TitleButtonOnEnter(motion)
    local button = self.parent

    if button.mouseHandler and button.mouseHandler.TitleButtonOnEnter then
        button.mouseHandler.TitleButtonOnEnter(self, motion)
        return
    end
end

function WatchButton:TitleButtonOnLeave(motion)
    if opt and opt.tooltipScale then
        local oldScale = GameTooltip.__QuestKingPreviousScale or 1
        GameTooltip.__QuestKingPreviousScale = nil
        GameTooltip:SetScale(oldScale)
    end

    GameTooltip:Hide()
end

function WatchButton:TitleButtonOnClick(mouse, down)
    local button = self.parent

    if button.mouseHandler and button.mouseHandler.TitleButtonOnClick then
        button.mouseHandler.TitleButtonOnClick(self, mouse, down)
        return
    end

    if button.type == "collapser" then
        local headerName = button._headerName
        QuestKingDBPerChar.collapsedHeaders = QuestKingDBPerChar.collapsedHeaders or {}

        if QuestKingDBPerChar.collapsedHeaders[headerName] then
            QuestKingDBPerChar.collapsedHeaders[headerName] = nil
            wipe(QuestKing.newlyAddedQuests)
        else
            QuestKingDBPerChar.collapsedHeaders[headerName] = true
        end

        QuestKing:UpdateTracker()
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
    if opt and opt.tooltipScale then
        local oldScale = GameTooltip.__QuestKingPreviousScale or 1
        GameTooltip.__QuestKingPreviousScale = nil
        GameTooltip:SetScale(oldScale)
    end

    GameTooltip:Hide()
end

function WatchButton:ButtonOnClick(mouse, down)
    local button = self

    if button.mouseHandler and button.mouseHandler.ButtonOnClick then
        button.mouseHandler.ButtonOnClick(self, mouse, down)
        return
    end
end