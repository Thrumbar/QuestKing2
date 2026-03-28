local addonName, QuestKing = ...

local tinsert = table.insert
local tremove = table.remove

local GetTime = GetTime
local GetTimeStringFromSecondsShort = QuestKing.GetTimeStringFromSecondsShort

local opt = QuestKing.options

local BAR_HEIGHT = 15
local BAR_LEFT_INSET = 16
local BAR_TOP_OFFSET = -1
local BAR_MIN_WIDTH = 80

local BACKDROP_TEMPLATE = BackdropTemplateMixin and "BackdropTemplate" or nil

local timerBarPool = {}
local numTimerBars = 0

local timerBackdrop = {
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    insets = { left = 0, right = 0, top = 0, bottom = 0 },
}

local function GetTimerBarWidth()
    local width = ((opt and opt.buttonWidth) or 230) - 36
    if width < BAR_MIN_WIDTH then
        width = BAR_MIN_WIDTH
    end
    return width
end

local function ApplyFontStringStyle(fontString)
    if not fontString then
        return
    end

    fontString:SetFont((opt and opt.font) or STANDARD_TEXT_FONT, (opt and opt.fontSize) or 12, (opt and opt.fontStyle) or "")
    fontString:SetShadowOffset(1, -1)
    fontString:SetShadowColor(0, 0, 0, 1)
end

local function EnsureBackdrop(timerBar)
    if timerBar.SetBackdrop then
        timerBar:SetBackdrop(timerBackdrop)
        if timerBar.SetBackdropColor then
            timerBar:SetBackdropColor(0, 0, 0, 0.4)
        end
        return
    end

    if not timerBar.background then
        local background = timerBar:CreateTexture(nil, "BACKGROUND")
        background:SetAllPoints(timerBar)
        background:SetColorTexture(0, 0, 0, 0.4)
        timerBar.background = background
    else
        timerBar.background:SetColorTexture(0, 0, 0, 0.4)
        timerBar.background:Show()
    end
end

local function FreeTimerBar(self)
    self:Hide()
    self:ClearAllPoints()
    self:SetScript("OnUpdate", nil)

    if self.baseLine then
        self.baseLine.timerBar = nil
        self.baseLine.timerBarText = nil
    end

    self.baseLine = nil
    self.baseButton = nil
    self.duration = nil
    self.startTime = nil

    tinsert(timerBarPool, self)
end

local function TimerBar_OnUpdate(self)
    local duration = self.duration
    local startTime = self.startTime

    if not duration or not startTime or duration <= 0 then
        self:SetValue(0)
        self.text:SetText("0:00")
        return
    end

    local timeNow = GetTime()
    local timeRemaining = duration - (timeNow - startTime)

    if timeRemaining < 0 then
        if timeRemaining > -0.5 then
            timeRemaining = 0
        else
            self:SetScript("OnUpdate", nil)
            QuestKing:UpdateTracker()
            return
        end
    end

    self:SetValue(timeRemaining)
    self.text:SetText(GetTimeStringFromSecondsShort(timeRemaining))
end

local function CreateTimerBar()
    numTimerBars = numTimerBars + 1

    local timerBar = CreateFrame(
        "StatusBar",
        "QuestKing_TimerBar" .. numTimerBars,
        QuestKing.Tracker,
        BACKDROP_TEMPLATE
    )
    timerBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    timerBar:GetStatusBarTexture():SetHorizTile(false)
    timerBar:SetStatusBarColor(0.6, 0.1, 0.2)
    timerBar:SetMinMaxValues(0, 100)
    timerBar:SetValue(100)
    timerBar:SetWidth(GetTimerBarWidth())
    timerBar:SetHeight(BAR_HEIGHT)

    EnsureBackdrop(timerBar)

    local border = timerBar:CreateTexture(nil, "OVERLAY")
    border:SetTexture([[Interface\Challenges\challenges-main]])
    border:SetPoint("TOPLEFT", timerBar, "TOPLEFT", -3, 3)
    border:SetPoint("BOTTOMRIGHT", timerBar, "BOTTOMRIGHT", 3, -3)
    border:SetTexCoord(0.00097656, 0.13769531, 0.47265625, 0.51757813)
    timerBar.border = border

    local text = timerBar:CreateFontString(nil, "OVERLAY")
    ApplyFontStringStyle(text)
    text:SetJustifyH("CENTER")
    text:SetJustifyV("MIDDLE")
    text:SetPoint("TOPLEFT", timerBar, "TOPLEFT", 0, 0)
    text:SetPoint("BOTTOMRIGHT", timerBar, "BOTTOMRIGHT", 0, 0)
    text:SetTextColor(1, 1, 1)
    text:SetWordWrap(false)
    text:SetText("0:00")
    timerBar.text = text

    timerBar.Free = FreeTimerBar

    return timerBar
end

function QuestKing.WatchButton:AddTimerBar(duration, startTime)
    local line = self:AddLine()
    local timerBar = line.timerBar

    if not timerBar then
        if #timerBarPool > 0 then
            timerBar = tremove(timerBarPool)
        else
            timerBar = CreateTimerBar()
        end

        line.timerBar = timerBar
        line.timerBarText = timerBar.text

        timerBar.baseButton = self
        timerBar.baseLine = line
    else
        timerBar.baseButton = self
        timerBar.baseLine = line
    end

    timerBar:SetWidth(GetTimerBarWidth())
    timerBar:SetHeight(BAR_HEIGHT)
    EnsureBackdrop(timerBar)

    timerBar:ClearAllPoints()
    timerBar:SetPoint("TOPLEFT", line, "TOPLEFT", BAR_LEFT_INSET, BAR_TOP_OFFSET)
    timerBar:Show()

    timerBar:SetMinMaxValues(0, duration and duration > 0 and duration or 1)
    timerBar.duration = duration
    timerBar.startTime = startTime
    timerBar:SetScript("OnUpdate", TimerBar_OnUpdate)

    line.isTimer = true
    line:SetText("")
    line.right:SetText("")
    line:SetHeight(BAR_HEIGHT)

    TimerBar_OnUpdate(timerBar)

    return timerBar
end