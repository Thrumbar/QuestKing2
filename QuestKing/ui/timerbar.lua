local addonName, QuestKing = ...

-- options
local opt = QuestKing.options
local opt_buttonWidth = opt.buttonWidth
local opt_lineHeight = opt.lineHeight
local opt_itemButtonScale = opt.itemButtonScale

-- import
local GetTimeStringFromSecondsShort = QuestKing.GetTimeStringFromSecondsShort

local GetTime = GetTime

-- local functions
local freeTimerBar
local timerBar_OnUpdate

-- local variables
local timerBarPool = {}
local numTimerBars = 0

local timerBackdrop = {
	bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
	insets = { left = 0, right = 0, top = 0, bottom = 0 }
}

--

function freeTimerBar (self)
	self:Hide()
	self:ClearAllPoints()

	self.baseLine.timerBar = nil
	self.baseLine = nil
	self.baseButton = nil

	tinsert(timerBarPool, self)
end

function QuestKing.WatchButton:AddTimerBar (duration, startTime)
	local line = self:AddLine()
	local timerBar = line.timerBar

	if (not timerBar) then
		if (#timerBarPool > 0) then
			timerBar = tremove(timerBarPool)
		else
			numTimerBars = numTimerBars + 1

			timerBar = CreateFrame("StatusBar", "QuestKing_TimerBar"..numTimerBars, QuestKing.Tracker)
			timerBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
			timerBar:GetStatusBarTexture():SetHorizTile(false)
			timerBar:SetStatusBarColor(0.6, 0.1, 0.2)
			timerBar:SetMinMaxValues(0, 100)
			timerBar:SetValue(100)
			timerBar:SetWidth(opt_buttonWidth - 36)
			timerBar:SetHeight(15)

			timerBar:SetBackdrop(timerBackdrop)
			timerBar:SetBackdropColor(0, 0, 0, 0.4)

			local border = timerBar:CreateTexture(nil, "OVERLAY")
			border:SetTexture([[Interface\Challenges\challenges-main]])
			border:SetPoint("TOPLEFT", timerBar, "TOPLEFT", -3, 3)
			border:SetPoint("BOTTOMRIGHT", timerBar, "BOTTOMRIGHT", 3, -3)
			border:SetTexCoord(0.00097656, 0.13769531, 0.47265625, 0.51757813)
			timerBar.border = border

			local text = timerBar:CreateFontString(nil, "OVERLAY")
			text:SetFont(opt.font, opt.fontSize, opt.fontStyle)
			text:SetJustifyH("CENTER")
			text:SetJustifyV("CENTER")
			text:SetAllPoints(true)
			text:SetTextColor(1, 1, 1)
			text:SetShadowOffset(1, -1)
			text:SetShadowColor(0, 0, 0, 1)
			text:SetWordWrap(false)
			text:SetText("0:00")
			timerBar.text = text

			timerBar:SetScript("OnUpdate", timerBar_OnUpdate)

			timerBar.Free = freeTimerBar
		end

		line.timerBar = timerBar
		line.timerBarText = timerBarText

		timerBar.baseButton = self
		timerBar.baseLine = line

		timerBar:SetPoint("TOPLEFT", line, "TOPLEFT", 16, -3)
		timerBar:Show()
	end

	timerBar:SetMinMaxValues(0, duration)
	timerBar.duration = duration
	timerBar.startTime = startTime
	timerBar.block = block

	return timerBar
end

function timerBar_OnUpdate(self, elapsed)
	local timeNow = GetTime()
	local timeRemaining = self.duration - (timeNow - self.startTime)
	self:SetValue(timeRemaining)

	if (timeRemaining < 0) then
		-- hold at 0 for a moment
		if (timeRemaining > -0.5) then
			timeRemaining = 0
		else
			QuestKing:UpdateTracker()
			return
		end
	end

	self.text:SetText(GetTimeStringFromSecondsShort(timeRemaining))
	-- self.text:SetTextColor(ObjectiveTrackerTimerBar_GetTextColor(self.duration, self.duration - timeRemaining));
end
