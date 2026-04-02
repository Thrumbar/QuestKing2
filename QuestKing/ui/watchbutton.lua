local addonName, QuestKing = ...

-- options
local opt = QuestKing.options

local opt_font = opt.font
local opt_fontChallengeTimer = opt.fontChallengeTimer
local opt_fontSize = opt.fontSize
local opt_fontStyle = opt.fontStyle
local opt_fontLayer = opt.fontLayer

local opt_colors = opt.colors

-- import
local tinsert = table.insert
local tremove = table.remove
local floor = math.floor
local max = math.max
local tonumber = tonumber

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
    local width = tonumber(opt.buttonWidth) or 230
    if width < 120 then
        width = 120
    end
    return width
end

local function GetLineHeight()
    local height = tonumber(opt.lineHeight) or 16
    if height < 10 then
        height = 10
    end
    return height
end

local function GetTitleHeight()
    local height = tonumber(opt.titleHeight) or GetLineHeight()
    if height < 10 then
        height = 10
    end
    return height
end

local function GetItemButtonScale()
    local scale = tonumber(QuestKing.itemButtonScale) or tonumber(opt.itemButtonScale) or 1
    if scale <= 0 then
        scale = 1
    end
    return scale
end

local function GetItemAnchorSide()
    return opt.itemAnchorSide == "left" and "left" or "right"
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

    if GameTooltip then
        GameTooltip:Hide()
    end
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
            button.wasRequested = false
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

    function WatchButton:GetKeyedRaw(type, uniq)
        for i = 1, #usedPool do
            local b = usedPool[i]
            if b.type == type and b.uniq == uniq then
                return b
            end
        end
        return nil
    end

    function WatchButton:GetKeyed(type, uniq)
        local button

        for i = 1, #usedPool do
            local b = usedPool[i]
            if b.type == type and b.uniq == uniq then
                button = b
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
            button.type = type
            button.uniq = uniq

            if type == "header" then
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
            if InCombatLockdown() then
                QuestKing:StartCombatTimer()
            else
                self:RemoveItemButton()
            end
        end

        self:EnableMouse(false)
        self.titleButton:EnableMouse(true)

        if self.SetBackdropColor then
            self:SetBackdropColor(0, 0, 0, 0)
        end

        self:SetScript("OnUpdate", nil)

        self.icon.animGroup:Stop()
        self.icon:Hide()
        self.buttonPulser.animGroup:Stop()
        self.buttonPulser:Hide()

        if self.challengeBar then
            self.challengeBar:Hide()
            self.challengeBar = nil
            self.challengeBarIcon = nil
            self.challengeBarText = nil
        end

        local lines = self.lines
        for i = 1, #lines do
            lines[i]:Wipe()
        end

        self.noTitle = false
        self.titleButton:Show()
        self.title:SetWidth(GetButtonWidth())

        self.mouseHandler = nil

        self.questID = nil
        self.questIndex = nil

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
    end

    local function hideOnOnFinished(self)
        self:GetParent():Hide()
    end

    local function buttonPulse(self, r, g, b)
        local pulser = self.buttonPulser

        pulser:SetVertexColor(r, g, b)
        pulser:Show()

        pulser.animGroup:Stop()
        pulser.animGroup:Play()
    end

    local function buttonSetIcon(self, iconType)
        local icon = self.icon

        if iconType == "QuestIcon-Exclamation" then
            icon:SetTexCoord(0.13476563, 0.17187500, 0.01562500, 0.53125000)
        elseif iconType == "QuestIcon-QuestionMark" then
            icon:SetTexCoord(0.17578125, 0.21289063, 0.01562500, 0.53125000)
        end

        icon:Show()
        icon.animGroup:Play()
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

    local function GetLineAvailableWidth(line)
        local right = line.right
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

    function WatchButton:Create()
        buttonCounter = buttonCounter + 1
        local name = "QuestKing_PoolButton" .. buttonCounter

        local buttonWidth = GetButtonWidth()
        local lineHeight = GetLineHeight()
        local titleHeight = GetTitleHeight()

        local button = CreateFrame("Button", name, QuestKing.Tracker, BACKDROP_TEMPLATE)
        button.name = name
        button:SetWidth(buttonWidth)
        button:SetHeight(lineHeight)
        button:SetPoint("TOPLEFT", 0, 0)

        if button.SetBackdrop then
            button:SetBackdrop({
                bgFile = "Interface/Tooltips/UI-Tooltip-Background",
                insets = { left = 0, right = 0, top = 0, bottom = 0 }
            })
            button:SetBackdropColor(0, 0, 0, 0)
        end

        local buttonHighlight = button:CreateTexture()
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

        local buttonPulser = button:CreateTexture()
        buttonPulser:SetAllPoints(button)
        buttonPulser:SetTexture([[Interface\QuestFrame\UI-QuestLogTitleHighlight]])
        buttonPulser:SetBlendMode("ADD")
        buttonPulser:SetAlpha(0)

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

        button.buttonPulser = buttonPulser
        button.buttonPulser.animGroup = animGroup
        button.Pulse = buttonPulse

        local icon = button:CreateTexture(nil, nil, "QuestIcon-Exclamation")
        icon:ClearAllPoints()
        icon:SetPoint("RIGHT", button, "LEFT")
        icon:SetHeight(lineHeight * 2 - 2)
        icon:SetWidth(lineHeight * 1.4)
        icon:Hide()

        local iconAnimGroup = icon:CreateAnimationGroup()
        local ia1 = iconAnimGroup:CreateAnimation("Alpha")
        ia1:SetStartDelay(0.25)
        ia1:SetDuration(0.33)
        ia1:SetFromAlpha(1)
        ia1:SetToAlpha(0)
        ia1:SetOrder(1)
        ia1:SetSmoothing("IN")
        iconAnimGroup:SetLooping("BOUNCE")

        button.icon = icon
        button.icon.animGroup = iconAnimGroup
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
        button.titleButton = titleButton

        local tex = titleButton:CreateTexture()
        tex:SetAllPoints(titleButton)
        tex:SetTexture([[Interface\QuestFrame\UI-QuestLogTitleHighlight]])
        tex:SetAlpha(0.5)
        titleButton.highlightTexture = tex

        titleButton:EnableMouse(true)
        titleButton:SetHighlightTexture(tex, "ADD")

        local title = titleButton:CreateFontString(nil, opt_fontLayer)
        title:SetFont(opt_font, opt_fontSize, opt_fontStyle)
        title:SetJustifyH("LEFT")
        title:SetJustifyV("TOP")
        title:SetTextColor(1, 1, 0)
        title:SetShadowOffset(1, -1)
        title:SetShadowColor(0, 0, 0, 1)
        title:SetPoint("TOPLEFT", 0, 0)
        title:SetWidth(buttonWidth)
        title:SetHeight(titleHeight)
        title:SetWordWrap(false)
        title:SetText("<Error>")

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

    local function lineWipe(self)
        self:Hide()
        self.right:Hide()

        self.flash.animGroup:Stop()
        self.flash:Hide()
        self.glow.animGroup:Stop()
        self.glow:Hide()

        if self.timerBar then
            self.timerBar:Free()
        end

        if self.progressBar then
            self.progressBar:Free()
        end

        self._lastQuant = nil
        self:SetText("")
        self.right:SetText("")
        self:ClearAllPoints()
        self.right:ClearAllPoints()
        self:SetWidth(0)
        self:SetHeight(0)
    end

    local function lineFlash(self)
        if self.timerBar or self.progressBar then
            return
        end

        self.flash:Show()
        self.flash.animGroup:Play()
    end

    local function lineGlow(self, r, g, b)
        if self.timerBar or self.progressBar then
            return
        end

        if r then
            self.glow:SetVertexColor(r, g, b)
        end

        self.glow:Show()
        self.glow.animGroup:Play()
    end

    function WatchButton:CreateLines(currentLine)
        local buttonWidth = GetButtonWidth()

        local line = self:CreateFontString(nil, opt_fontLayer)
        line:SetFont(opt_font, opt_fontSize, opt_fontStyle)
        line:SetJustifyH("LEFT")
        line:SetJustifyV("TOP")
        line:SetTextColor(1, 1, 0)
        line:SetShadowOffset(1, -1)
        line:SetShadowColor(0, 0, 0, 1)
        line:SetPoint("TOPLEFT", 0, 0)
        line:SetWordWrap(true)
        line:SetNonSpaceWrap(true)
        tinsert(self.lines, line)

        local right = self:CreateFontString(nil, opt_fontLayer)
        right:SetFont(opt_font, opt_fontSize, opt_fontStyle)
        right:SetJustifyH("RIGHT")
        right:SetJustifyV("TOP")
        right:SetTextColor(1, 1, 0)
        right:SetShadowOffset(1, -1)
        right:SetShadowColor(0, 0, 0, 1)
        right:SetPoint("TOPLEFT", 0, 0)
        right:SetWordWrap(false)
        line.right = right

        local flash = self:CreateTexture()
        flash:SetPoint("TOPLEFT", line)
        flash:SetPoint("BOTTOMLEFT", line)
        flash:SetWidth(buttonWidth)
        flash:SetTexture([[Interface\QuestFrame\UI-QuestLogTitleHighlight]])
        flash:SetBlendMode("ADD")
        flash:SetVertexColor(
            opt_colors.ObjectiveProgressFlash[1],
            opt_colors.ObjectiveProgressFlash[2],
            opt_colors.ObjectiveProgressFlash[3],
            0
        )
        flash:Hide()

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

        line.flash = flash
        line.flash.animGroup = flashAnimGroup
        line.Flash = lineFlash

        local glow = self:CreateTexture()
        glow:SetPoint("TOPLEFT", line)
        glow:SetPoint("BOTTOMLEFT", line, 0, -2.5)
        glow:SetWidth(buttonWidth)
        glow:SetTexture([[Interface\AddOns\QuestKing\textures\Objective-Lineglow-White]])
        glow:SetBlendMode("ADD")
        glow:SetVertexColor(0.8, 0.6, 0.2, 0)
        glow:Hide()

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

        line.glow = glow
        line.glow.animGroup = glowAnimGroup
        line.Glow = lineGlow

        line.Wipe = lineWipe

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

                local lineLeftInset = LINE_INDENT_LEFT
                local lineRightInset = LINE_RIGHT_PADDING

                if itemInset > 0 then
                    if itemAnchorSide == "right" then
                        lineRightInset = lineRightInset + itemInset
                    else
                        lineLeftInset = lineLeftInset + itemInset
                    end
                end

                if lastRegion == nil then
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
                    local contentLineHeight = GetLineContentHeight(line)
                    line:SetHeight(contentLineHeight)
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
            if InCombatLockdown() then
                QuestKing:StartCombatTimer()
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
    HideQuestKingTooltips()
end

function WatchButton:ButtonOnClick(mouse, down)
    local button = self

    if button.mouseHandler and button.mouseHandler.ButtonOnClick then
        button.mouseHandler.ButtonOnClick(self, mouse, down)
        return
    end
end