local addonName, QuestKing = ...

local tinsert = table.insert
local tremove = table.remove

local opt = QuestKing.options

local BAR_HEIGHT = 15
local BAR_LEFT_INSET = 16
local BAR_TOP_OFFSET = -1
local BAR_MIN_WIDTH = 80

local BACKDROP_TEMPLATE = BackdropTemplateMixin and "BackdropTemplate" or nil

local progressBarPool = {}
local numProgressBars = 0

local progressBackdrop = {
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    insets = { left = 0, right = 0, top = 0, bottom = 0 },
}

local function ClampPercent(percent)
    percent = tonumber(percent) or 0
    if percent < 0 then
        return 0
    end
    if percent > 100 then
        return 100
    end
    return percent
end

local function GetButtonWidth()
    return (opt and opt.buttonWidth) or 230
end

local function GetProgressBarWidth()
    local width = GetButtonWidth() - 36
    if width < BAR_MIN_WIDTH then
        width = BAR_MIN_WIDTH
    end
    return width
end

local function GetFontPath()
    return (opt and opt.font) or STANDARD_TEXT_FONT
end

local function GetFontSize()
    return ((opt and opt.fontSize) or 12) - 1
end

local function GetFontStyle()
    return (opt and opt.fontStyle) or ""
end

local function UpdateBurstWidths(progressBar)
    local burstWidth = progressBar:GetWidth() * 0.6
    progressBar.topLineBurst:SetWidth(burstWidth)
    progressBar.bottomLineBurst:SetWidth(burstWidth)
end

local function EnsureBackdrop(progressBar)
    if progressBar.SetBackdrop then
        progressBar:SetBackdrop(progressBackdrop)
        if progressBar.SetBackdropColor then
            progressBar:SetBackdropColor(0, 0, 0, 0.4)
        end
        return
    end

    if not progressBar.background then
        local background = progressBar:CreateTexture(nil, "BACKGROUND")
        background:SetAllPoints(progressBar)
        background:SetColorTexture(0, 0, 0, 0.4)
        progressBar.background = background
    else
        progressBar.background:SetColorTexture(0, 0, 0, 0.4)
        progressBar.background:Show()
    end
end

local function FreeProgressBar(self)
    self:Hide()
    self:ClearAllPoints()
    self:SetScript("OnUpdate", nil)

    if self.baseLine then
        self.baseLine.progressBar = nil
        self.baseLine.progressBarText = nil
    end

    self.baseLine = nil
    self.baseButton = nil
    self._lastPercent = nil

    tinsert(progressBarPool, self)
end

local function SetPercent(self, percent)
    percent = ClampPercent(percent)

    self:SetValue(percent)
    self.text:SetFormattedText("%.1f%%", percent)

    local lastPercent = self._lastPercent
    if lastPercent and percent ~= lastPercent then
        local delta = percent - lastPercent
        if delta < 0 then
            delta = 0
        end

        if delta >= 5 then
            if self.topLineBurst.animGroup:IsPlaying() then
                self.topLineBurst.animGroup:Stop()
                self.bottomLineBurst.animGroup:Stop()
            end

            self.topLineBurst.animGroup:Play()
            self.bottomLineBurst.animGroup:Play()
        end

        if delta >= 1 then
            local width = self:GetWidth()
            local offset = width * percent / 100
            local deltaWidth = delta * (width / 100)

            if deltaWidth < 2 then
                deltaWidth = 2
            end

            self.glow:SetWidth(deltaWidth)
            self.glow:ClearAllPoints()
            self.glow:SetPoint("RIGHT", self, "LEFT", offset, 0)

            if self.glow.animGroup:IsPlaying() then
                self.glow.animGroup:Stop()
            end
            self.glow.animGroup:Play()
        end

        if self.pulse.animGroup:IsPlaying() then
            self.pulse.animGroup:Stop()
        end
        self.pulse.animGroup:Play()
    end

    self._lastPercent = percent
end

local function CreateProgressBar()
    numProgressBars = numProgressBars + 1

    local progressBar = CreateFrame(
        "StatusBar",
        "QuestKing_ProgressBar" .. numProgressBars,
        QuestKing.Tracker,
        BACKDROP_TEMPLATE
    )
    progressBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    progressBar:GetStatusBarTexture():SetHorizTile(false)
    progressBar:SetStatusBarColor(0.2, 0.4, 0.9)
    progressBar:SetMinMaxValues(0, 100)
    progressBar:SetValue(100)
    progressBar:SetWidth(GetProgressBarWidth())
    progressBar:SetHeight(BAR_HEIGHT)

    EnsureBackdrop(progressBar)

    local border = progressBar:CreateTexture(nil, "OVERLAY")
    border:SetTexture([[Interface\PaperDollInfoFrame\UI-Character-Skills-BarBorder]])
    border:SetPoint("TOPLEFT", progressBar, "TOPLEFT", -3, 8)
    border:SetPoint("BOTTOMRIGHT", progressBar, "BOTTOMRIGHT", 3, -8)
    progressBar.border = border

    local text = progressBar:CreateFontString(nil, "OVERLAY")
    text:SetFont(GetFontPath(), GetFontSize(), GetFontStyle())
    text:SetJustifyH("CENTER")
    text:SetJustifyV("MIDDLE")
    text:SetPoint("TOPLEFT", progressBar, "TOPLEFT", 0, 0)
    text:SetPoint("BOTTOMRIGHT", progressBar, "BOTTOMRIGHT", 0, 2)
    text:SetTextColor(1, 1, 1)
    text:SetShadowOffset(1, -1)
    text:SetShadowColor(0, 0, 0, 1)
    text:SetWordWrap(false)
    text:SetVertexColor(0.8, 0.8, 0.8)
    text:SetText("0%")
    progressBar.text = text

    local glow = progressBar:CreateTexture(nil, "OVERLAY")
    glow:SetPoint("RIGHT", progressBar, "LEFT", 0, 0)
    glow:SetWidth(5)
    glow:SetHeight(BAR_HEIGHT - 4)
    glow:SetTexture([[Interface\AddOns\QuestKing\textures\Full-Line-Glow-White]])
    glow:SetVertexColor(0.6, 0.8, 1, 0)
    glow:SetBlendMode("ADD")
    progressBar.glow = glow

    do
        local animGroup = glow:CreateAnimationGroup()

        local a0 = animGroup:CreateAnimation("Alpha")
        a0:SetStartDelay(0)
        a0:SetFromAlpha(0)
        a0:SetToAlpha(1)
        a0:SetDuration(0.25)
        a0:SetOrder(1)

        local a1 = animGroup:CreateAnimation("Alpha")
        a1:SetStartDelay(0.3)
        a1:SetFromAlpha(1)
        a1:SetToAlpha(0)
        a1:SetDuration(0.2)
        a1:SetOrder(1)

        glow.animGroup = animGroup
    end

    local topLineBurst = progressBar:CreateTexture(nil, "OVERLAY")
    topLineBurst:SetPoint("CENTER", glow, "TOP", -3, 0)
    topLineBurst:SetHeight(8)
    topLineBurst:SetTexture([[Interface\QuestFrame\ObjectiveTracker]])
    topLineBurst:SetTexCoord(0.1640625, 0.33203125, 0.66796875, 0.74609375)
    topLineBurst:SetVertexColor(0.6, 0.8, 1, 0)
    topLineBurst:SetBlendMode("ADD")
    progressBar.topLineBurst = topLineBurst

    do
        local animGroup = topLineBurst:CreateAnimationGroup()

        local a0 = animGroup:CreateAnimation("Alpha")
        a0:SetStartDelay(0)
        a0:SetFromAlpha(0)
        a0:SetToAlpha(1)
        a0:SetDuration(0.25)
        a0:SetOrder(1)

        local a1 = animGroup:CreateAnimation("Alpha")
        a1:SetStartDelay(0.3)
        a1:SetFromAlpha(1)
        a1:SetToAlpha(0)
        a1:SetDuration(0.2)
        a1:SetOrder(1)

        local a2 = animGroup:CreateAnimation("Translation")
        a2:SetStartDelay(0)
        a2:SetOffset(5, 0)
        a2:SetDuration(0.25)
        a2:SetOrder(1)

        topLineBurst.animGroup = animGroup
    end

    local bottomLineBurst = progressBar:CreateTexture(nil, "OVERLAY")
    bottomLineBurst:SetPoint("CENTER", glow, "BOTTOM", -3, 0)
    bottomLineBurst:SetHeight(8)
    bottomLineBurst:SetTexture([[Interface\QuestFrame\ObjectiveTracker]])
    bottomLineBurst:SetTexCoord(0.1640625, 0.33203125, 0.66796875, 0.74609375)
    bottomLineBurst:SetVertexColor(0.6, 0.8, 1, 0)
    bottomLineBurst:SetBlendMode("ADD")
    progressBar.bottomLineBurst = bottomLineBurst

    do
        local animGroup = bottomLineBurst:CreateAnimationGroup()

        local a0 = animGroup:CreateAnimation("Alpha")
        a0:SetStartDelay(0)
        a0:SetFromAlpha(0)
        a0:SetToAlpha(1)
        a0:SetDuration(0.25)
        a0:SetOrder(1)

        local a1 = animGroup:CreateAnimation("Alpha")
        a1:SetStartDelay(0.3)
        a1:SetFromAlpha(1)
        a1:SetToAlpha(0)
        a1:SetDuration(0.2)
        a1:SetOrder(1)

        local a2 = animGroup:CreateAnimation("Translation")
        a2:SetStartDelay(0)
        a2:SetOffset(5, 0)
        a2:SetDuration(0.25)
        a2:SetOrder(1)

        bottomLineBurst.animGroup = animGroup
    end

    local pulse = progressBar:CreateTexture(nil, "OVERLAY")
    pulse:SetAllPoints(progressBar)
    pulse:SetTexture([[Interface\QuestFrame\UI-QuestLogTitleHighlight]])
    pulse:SetVertexColor(0.6, 0.8, 1, 0)
    pulse:SetBlendMode("ADD")
    progressBar.pulse = pulse

    do
        local animGroup = pulse:CreateAnimationGroup()

        local a1 = animGroup:CreateAnimation("Alpha")
        a1:SetStartDelay(0)
        a1:SetDuration(0.25)
        a1:SetFromAlpha(0)
        a1:SetToAlpha(1)
        a1:SetOrder(1)

        local a2 = animGroup:CreateAnimation("Alpha")
        a2:SetStartDelay(0.3)
        a2:SetDuration(0.2)
        a2:SetFromAlpha(1)
        a2:SetToAlpha(0)
        a2:SetOrder(1)

        pulse.animGroup = animGroup
    end

    progressBar.Free = FreeProgressBar
    progressBar.SetPercent = SetPercent
    progressBar.UpdateBurstWidths = UpdateBurstWidths

    UpdateBurstWidths(progressBar)

    return progressBar
end

function QuestKing.WatchButton:AddProgressBar(duration, startTime)
    local line = self:AddLine()
    local progressBar = line.progressBar

    if not progressBar then
        if #progressBarPool > 0 then
            progressBar = tremove(progressBarPool)
        else
            progressBar = CreateProgressBar()
        end

        line.progressBar = progressBar
        line.progressBarText = progressBar.text

        progressBar.baseButton = self
        progressBar.baseLine = line
        progressBar._lastPercent = nil
    end

    progressBar:SetWidth(GetProgressBarWidth())
    progressBar:SetHeight(BAR_HEIGHT)
    progressBar:UpdateBurstWidths()
    EnsureBackdrop(progressBar)

    progressBar:ClearAllPoints()
    progressBar:SetPoint("TOPLEFT", line, "TOPLEFT", BAR_LEFT_INSET, BAR_TOP_OFFSET)
    progressBar:Show()

    line.isTimer = false
    line:SetText("")
    line.right:SetText("")
    line:SetHeight(BAR_HEIGHT)

    return progressBar
end