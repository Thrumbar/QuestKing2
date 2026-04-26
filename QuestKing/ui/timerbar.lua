local addonName, QuestKing = ...

local tinsert = table.insert
local tremove = table.remove

local GetTime = GetTime
local GetTimeStringFromSecondsShort = QuestKing.GetTimeStringFromSecondsShort

local tonumber = tonumber
local type = type

local BACKDROP_TEMPLATE = BackdropTemplateMixin and "BackdropTemplate" or nil

local BAR_HEIGHT = 15
local BAR_LEFT_INSET = 16
local BAR_TOP_OFFSET = -1
local BAR_MIN_WIDTH = 80
local UPDATE_INTERVAL = 0.05

local timerBarPool = {}
local numTimerBars = 0

local timerBackdrop = {
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    insets = { left = 0, right = 0, top = 0, bottom = 0 },
}

local function GetOptions()
    return QuestKing.options or {}
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

local function GetTimerBarWidth()
    local opt = GetOptions()
    local width = (tonumber(opt.buttonWidth) or 230) - 36
    if width < BAR_MIN_WIDTH then
        width = BAR_MIN_WIDTH
    end
    return width
end

local function ApplyFontStringStyle(fontString)
    if not fontString then
        return
    end

    local opt = GetOptions()
    fontString:SetFont(opt.font or STANDARD_TEXT_FONT, tonumber(opt.fontSize) or 12, opt.fontStyle or "")
    fontString:SetShadowOffset(1, -1)
    fontString:SetShadowColor(0, 0, 0, 1)
end

local function EnsureBackdrop(timerBar)
    if not timerBar then
        return
    end

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

local function ResetTimerBar(timerBar)
    if not timerBar then
        return
    end

    timerBar.baseLine = nil
    timerBar.baseButton = nil
    timerBar.duration = nil
    timerBar.startTime = nil
    timerBar._expired = nil
    timerBar._nextUpdate = 0

    timerBar:SetMinMaxValues(0, 1)
    timerBar:SetValue(1)
    timerBar:SetStatusBarColor(0.6, 0.1, 0.2)
    timerBar:SetWidth(GetTimerBarWidth())
    timerBar:SetHeight(BAR_HEIGHT)
    timerBar:SetScript("OnUpdate", nil)

    if timerBar.text then
        timerBar.text:SetText("0:00")
    end
end

local function FreeTimerBar(self)
    self:Hide()
    self:ClearAllPoints()
    self:SetScript("OnUpdate", nil)

    if self.baseLine then
        self.baseLine.timerBar = nil
        self.baseLine.timerBarText = nil
        self.baseLine.isTimer = nil
    end

    ResetTimerBar(self)
    tinsert(timerBarPool, self)
end

local function UpdateTimerBarDisplay(self, forceNow)
    local duration = tonumber(self.duration)
    local startTime = tonumber(self.startTime)

    if not duration or not startTime or duration <= 0 then
        self:SetMinMaxValues(0, 1)
        self:SetValue(0)
        self.text:SetText("0:00")
        return
    end

    local timeRemaining = duration - (GetTime() - startTime)

    if timeRemaining <= 0 then
        if timeRemaining > -0.5 or forceNow then
            timeRemaining = 0
            self:SetMinMaxValues(0, duration)
            self:SetValue(0)
            self.text:SetText("0:00")
        else
            self:SetMinMaxValues(0, duration)
            self:SetValue(0)
            self.text:SetText("0:00")
            self:SetScript("OnUpdate", nil)

            if not self._expired then
                self._expired = true
                QueueTrackerRefresh(true)
            end
        end
        return
    end

    self:SetMinMaxValues(0, duration)
    self:SetValue(timeRemaining)
    self.text:SetText(GetTimeStringFromSecondsShort(timeRemaining))
end

local function TimerBar_OnUpdate(self, elapsed)
    self._nextUpdate = (self._nextUpdate or 0) - elapsed
    if self._nextUpdate > 0 then
        return
    end

    self._nextUpdate = UPDATE_INTERVAL
    UpdateTimerBarDisplay(self, false)
end

local function CreateTimerBar()
    numTimerBars = numTimerBars + 1

    local parent = QuestKing and QuestKing.Tracker or UIParent
    local timerBar = CreateFrame("StatusBar", nil, parent, BACKDROP_TEMPLATE)

    timerBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")

    local statusTexture = timerBar:GetStatusBarTexture()
    if statusTexture and statusTexture.SetHorizTile then
        statusTexture:SetHorizTile(false)
    end

    timerBar:SetStatusBarColor(0.6, 0.1, 0.2)
    timerBar:SetMinMaxValues(0, 1)
    timerBar:SetValue(1)
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
    ResetTimerBar(timerBar)

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
    end

    timerBar.baseButton = self
    timerBar.baseLine = line
    timerBar._expired = nil
    timerBar._nextUpdate = 0

    duration = tonumber(duration) or 0
    startTime = tonumber(startTime) or GetTime()

    if duration <= 0 then
        duration = 1
    end

    timerBar.duration = duration
    timerBar.startTime = startTime

    timerBar:SetParent(self)
    timerBar:SetFrameLevel((self.GetFrameLevel and self:GetFrameLevel()) or 1)
    timerBar:SetWidth(GetTimerBarWidth())
    timerBar:SetHeight(BAR_HEIGHT)
    EnsureBackdrop(timerBar)

    timerBar:ClearAllPoints()
    timerBar:SetPoint("TOPLEFT", line, "TOPLEFT", BAR_LEFT_INSET, BAR_TOP_OFFSET)
    timerBar:Show()

    line.isTimer = true
    line:SetText("")
    if line.right then
        line.right:SetText("")
    end
    line:SetHeight(BAR_HEIGHT)

    UpdateTimerBarDisplay(timerBar, true)
    timerBar:SetScript("OnUpdate", TimerBar_OnUpdate)

    return timerBar
end
