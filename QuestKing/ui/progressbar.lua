local addonName, QuestKing = ...

local tinsert = table.insert
local tremove = table.remove

local tonumber = tonumber
local type = type

local BACKDROP_TEMPLATE = BackdropTemplateMixin and "BackdropTemplate" or nil

local BAR_HEIGHT = 15
local BAR_LEFT_INSET = 16
local BAR_TOP_OFFSET = -1
local BAR_MIN_WIDTH = 80

local progressBarPool = {}
local numProgressBars = 0

local progressBackdrop = {
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    insets = { left = 0, right = 0, top = 0, bottom = 0 },
}

local function GetOptions()
    return QuestKing.options or {}
end

local function GetButtonWidth()
    local opt = GetOptions()
    local width = tonumber(opt.buttonWidth) or 230
    if width < 120 then
        width = 120
    end
    return width
end

local function GetProgressBarWidth()
    local width = GetButtonWidth() - 36
    if width < BAR_MIN_WIDTH then
        width = BAR_MIN_WIDTH
    end
    return width
end

local function GetFontPath()
    local opt = GetOptions()
    return opt.font or STANDARD_TEXT_FONT
end

local function GetFontSize()
    local opt = GetOptions()
    local size = tonumber(opt.fontSize) or 12
    size = size - 1
    if size < 8 then
        size = 8
    end
    return size
end

local function GetFontStyle()
    local opt = GetOptions()
    return opt.fontStyle or ""
end

local function ClampPercent(percent)
    percent = tonumber(percent) or 0

    if percent <= 1 and percent >= 0 then
        percent = percent * 100
    end

    if percent < 0 then
        return 0
    end

    if percent > 100 then
        return 100
    end

    return percent
end

local function ApplyFontStringStyle(fontString)
    if not fontString then
        return
    end

    fontString:SetFont(GetFontPath(), GetFontSize(), GetFontStyle())
    fontString:SetJustifyH("CENTER")
    fontString:SetJustifyV("MIDDLE")
    fontString:SetTextColor(1, 1, 1)
    fontString:SetShadowOffset(1, -1)
    fontString:SetShadowColor(0, 0, 0, 1)
    fontString:SetWordWrap(false)
    fontString:SetNonSpaceWrap(false)
end

local function EnsureBackdrop(progressBar)
    if not progressBar then
        return
    end

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

local function StopAnimationGroupSafe(animGroup)
    if animGroup and animGroup.IsPlaying and animGroup:IsPlaying() then
        animGroup:Stop()
    end
end

local function HideBurstTextures(progressBar)
    if progressBar.glow then
        progressBar.glow:SetAlpha(0)
        progressBar.glow:Hide()
    end

    if progressBar.topLineBurst then
        progressBar.topLineBurst:SetAlpha(0)
        progressBar.topLineBurst:Hide()
    end

    if progressBar.bottomLineBurst then
        progressBar.bottomLineBurst:SetAlpha(0)
        progressBar.bottomLineBurst:Hide()
    end

    if progressBar.pulse then
        progressBar.pulse:SetAlpha(0)
        progressBar.pulse:Hide()
    end
end

local function UpdateBurstWidths(progressBar)
    if not progressBar then
        return
    end

    local burstWidth = (progressBar:GetWidth() or GetProgressBarWidth()) * 0.6
    if burstWidth < 8 then
        burstWidth = 8
    end

    if progressBar.topLineBurst then
        progressBar.topLineBurst:SetWidth(burstWidth)
    end

    if progressBar.bottomLineBurst then
        progressBar.bottomLineBurst:SetWidth(burstWidth)
    end
end

local function ResetProgressBar(progressBar)
    if not progressBar then
        return
    end

    progressBar.baseLine = nil
    progressBar.baseButton = nil
    progressBar._lastPercent = nil

    progressBar:SetMinMaxValues(0, 100)
    progressBar:SetValue(100)
    progressBar:SetStatusBarColor(0.2, 0.4, 0.9)
    progressBar:SetWidth(GetProgressBarWidth())
    progressBar:SetHeight(BAR_HEIGHT)

    if progressBar.text then
        progressBar.text:SetText("0.0%")
        ApplyFontStringStyle(progressBar.text)
    end

    StopAnimationGroupSafe(progressBar.glow and progressBar.glow.animGroup)
    StopAnimationGroupSafe(progressBar.topLineBurst and progressBar.topLineBurst.animGroup)
    StopAnimationGroupSafe(progressBar.bottomLineBurst and progressBar.bottomLineBurst.animGroup)
    StopAnimationGroupSafe(progressBar.pulse and progressBar.pulse.animGroup)

    HideBurstTextures(progressBar)
    EnsureBackdrop(progressBar)
    UpdateBurstWidths(progressBar)
end

local function FreeProgressBar(self)
    self:Hide()
    self:ClearAllPoints()
    self:SetScript("OnUpdate", nil)

    if self.baseLine then
        self.baseLine.progressBar = nil
        self.baseLine.progressBarText = nil
    end

    ResetProgressBar(self)
    tinsert(progressBarPool, self)
end

local function PlayBurstAnimations(self, delta, percent)
    if delta < 0 then
        delta = 0
    end

    if delta >= 5 then
        StopAnimationGroupSafe(self.topLineBurst and self.topLineBurst.animGroup)
        StopAnimationGroupSafe(self.bottomLineBurst and self.bottomLineBurst.animGroup)

        if self.topLineBurst then
            self.topLineBurst:Show()
            self.topLineBurst.animGroup:Play()
        end

        if self.bottomLineBurst then
            self.bottomLineBurst:Show()
            self.bottomLineBurst.animGroup:Play()
        end
    end

    if delta >= 1 and self.glow then
        local width = self:GetWidth() or GetProgressBarWidth()
        local offset = width * percent / 100
        local deltaWidth = delta * (width / 100)

        if deltaWidth < 2 then
            deltaWidth = 2
        end

        self.glow:SetWidth(deltaWidth)
        self.glow:ClearAllPoints()
        self.glow:SetPoint("RIGHT", self, "LEFT", offset, 0)
        self.glow:Show()

        StopAnimationGroupSafe(self.glow.animGroup)
        self.glow.animGroup:Play()
    end

    if self.pulse then
        self.pulse:Show()
        StopAnimationGroupSafe(self.pulse.animGroup)
        self.pulse.animGroup:Play()
    end
end

local function SetPercent(self, percent)
    percent = ClampPercent(percent)

    self:SetValue(percent)

    if self.text then
        self.text:SetFormattedText("%.1f%%", percent)
    end

    local lastPercent = self._lastPercent
    if type(lastPercent) == "number" and percent ~= lastPercent then
        PlayBurstAnimations(self, percent - lastPercent, percent)
    end

    self._lastPercent = percent
end

local function CreateProgressBar()
    numProgressBars = numProgressBars + 1

    local parent = (QuestKing and QuestKing.Tracker) or UIParent
    local progressBar = CreateFrame("StatusBar", nil, parent, BACKDROP_TEMPLATE)

    progressBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")

    local statusTexture = progressBar:GetStatusBarTexture()
    if statusTexture and statusTexture.SetHorizTile then
        statusTexture:SetHorizTile(false)
    end

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
    ApplyFontStringStyle(text)
    text:SetPoint("TOPLEFT", progressBar, "TOPLEFT", 0, 0)
    text:SetPoint("BOTTOMRIGHT", progressBar, "BOTTOMRIGHT", 0, 2)
    text:SetText("0.0%")
    progressBar.text = text

    local glow = progressBar:CreateTexture(nil, "OVERLAY")
    glow:SetPoint("RIGHT", progressBar, "LEFT", 0, 0)
    glow:SetWidth(5)
    glow:SetHeight(BAR_HEIGHT - 4)
    glow:SetTexture([[Interface\AddOns\QuestKing\textures\Full-Line-Glow-White]])
    glow:SetVertexColor(0.6, 0.8, 1, 0)
    glow:SetBlendMode("ADD")
    glow:Hide()
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

        animGroup:SetScript("OnFinished", function()
            glow:Hide()
            glow:SetAlpha(0)
        end)

        glow.animGroup = animGroup
    end

    local topLineBurst = progressBar:CreateTexture(nil, "OVERLAY")
    topLineBurst:SetPoint("CENTER", glow, "TOP", -3, 0)
    topLineBurst:SetHeight(8)
    topLineBurst:SetTexture([[Interface\QuestFrame\ObjectiveTracker]])
    topLineBurst:SetTexCoord(0.1640625, 0.33203125, 0.66796875, 0.74609375)
    topLineBurst:SetVertexColor(0.6, 0.8, 1, 0)
    topLineBurst:SetBlendMode("ADD")
    topLineBurst:Hide()
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

        animGroup:SetScript("OnFinished", function()
            topLineBurst:Hide()
            topLineBurst:SetAlpha(0)
        end)

        topLineBurst.animGroup = animGroup
    end

    local bottomLineBurst = progressBar:CreateTexture(nil, "OVERLAY")
    bottomLineBurst:SetPoint("CENTER", glow, "BOTTOM", -3, 0)
    bottomLineBurst:SetHeight(8)
    bottomLineBurst:SetTexture([[Interface\QuestFrame\ObjectiveTracker]])
    bottomLineBurst:SetTexCoord(0.1640625, 0.33203125, 0.66796875, 0.74609375)
    bottomLineBurst:SetVertexColor(0.6, 0.8, 1, 0)
    bottomLineBurst:SetBlendMode("ADD")
    bottomLineBurst:Hide()
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

        animGroup:SetScript("OnFinished", function()
            bottomLineBurst:Hide()
            bottomLineBurst:SetAlpha(0)
        end)

        bottomLineBurst.animGroup = animGroup
    end

    local pulse = progressBar:CreateTexture(nil, "OVERLAY")
    pulse:SetAllPoints(progressBar)
    pulse:SetTexture([[Interface\QuestFrame\UI-QuestLogTitleHighlight]])
    pulse:SetVertexColor(0.6, 0.8, 1, 0)
    pulse:SetBlendMode("ADD")
    pulse:Hide()
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

        animGroup:SetScript("OnFinished", function()
            pulse:Hide()
            pulse:SetAlpha(0)
        end)

        pulse.animGroup = animGroup
    end

    progressBar.Free = FreeProgressBar
    progressBar.SetPercent = SetPercent
    progressBar.UpdateBurstWidths = UpdateBurstWidths

    ResetProgressBar(progressBar)
    return progressBar
end

function QuestKing.WatchButton:AddProgressBar()
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
    end

    progressBar.baseButton = self
    progressBar.baseLine = line
    progressBar._lastPercent = nil

    progressBar:SetParent(self)
    progressBar:SetFrameLevel((self.GetFrameLevel and self:GetFrameLevel()) or 1)
    progressBar:SetWidth(GetProgressBarWidth())
    progressBar:SetHeight(BAR_HEIGHT)
    progressBar:UpdateBurstWidths()
    EnsureBackdrop(progressBar)

    progressBar:ClearAllPoints()
    progressBar:SetPoint("TOPLEFT", line, "TOPLEFT", BAR_LEFT_INSET, BAR_TOP_OFFSET)
    progressBar:Show()

    line.isTimer = false
    line:SetText("")
    if line.right then
        line.right:SetText("")
    end
    line:SetHeight(BAR_HEIGHT)

    return progressBar
end
