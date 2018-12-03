local addonName, QuestKing = ...

-- options
local opt = QuestKing.options
local opt_colors = opt.colors

-- import
local WatchButton = QuestKing.WatchButton
local GetTimeStringFromSecondsShort = QuestKing.GetTimeStringFromSecondsShort

local floor = math.floor
local ceil = math.ceil
local GetTime = GetTime

-- local functions
local parseChallengeTimers
local setButtonToChallengeTimer, onUpdateChallengeTimer, updateChallengeMedal
local setButtonToProvingGroundsTimer, onUpdateProvingGroundsTimer

local soundPlayed = false

--

function QuestKing:UpdateTrackerChallengeTimers (...)
	-- challenge timers
	local hasTimer = GetWorldElapsedTimers()
	if hasTimer then
		parseChallengeTimers(GetWorldElapsedTimers())
	end
end

function parseChallengeTimers (...)
	-- D(...)
	for i = 1, select("#", ...) do
		local timerID = select(i, ...)

		-- local name, instanceType, difficultyIndex, difficultyName, maxPlayers, dynamicDifficulty, isDynamic, mapID = GetInstanceInfo()
		local description, elapsedTime, type = GetWorldElapsedTime(timerID)

		local _, _, _, _, _, _, _, mapID = GetInstanceInfo()
		if ((timerID == 1) and (type == 0) and (mapID == 1148)) then
			description, elapsedTime, type = GetWorldElapsedTime(2)
		end

		if (type == LE_WORLD_ELAPSED_TIMER_TYPE_CHALLENGE_MODE) then
			-- challenge mode
			-- D("CHALLENGE_MODE", timerID, description, elapsedTime)

			if (mapID) then
				local button = WatchButton:GetKeyed("challengetimer", mapID)
				setButtonToChallengeTimer(button, timerID, elapsedTime, GetChallengeModeMapTimes(mapID))
				return
			end

		elseif (type == LE_WORLD_ELAPSED_TIMER_TYPE_PROVING_GROUND) then
			-- proving grounds
			-- D("PROVING_GROUNDS")
			local diffID, currWave, maxWave, duration = C_Scenario.GetProvingGroundsInfo()

			if (duration > 0) then
				local button = WatchButton:GetKeyed("provinggrounds", mapID)
				setButtonToProvingGroundsTimer(button, elapsedTime, diffID, currWave, maxWave, duration)
				return
			end
		end	
	end

end

function onUpdateProvingGroundsTimer (self, elapsed, manual)
	local elapsedNew = elapsed + self.elapsed
	self.elapsed = elapsedNew

	local timeLeft = self.duration - elapsedNew

	if (timeLeft < 0) then timeLeft = 0	end

	self:SetValue(timeLeft)
	self.text:SetText(GetTimeStringFromSecondsShort(ceil(timeLeft)))

	if ((timeLeft < 5) and (timeLeft > 4)) then
		local anim = self.barPulserAnim
		if ((anim.cycles == 0) and (not anim:IsPlaying())) then
			anim:Play()
			anim.cycles = 4
		end
	end
end

function setButtonToProvingGroundsTimer (button, elapsed, diffID, currWave, maxWave, duration)

	button.titleButton:EnableMouse(false)
	button.title:SetText("")

	local challengeBar = button:AddChallengeBar()
	local challengeBarIcon = challengeBar.icon

	challengeBar.bonusHeight = 28
	challengeBar.extraText:Show()
	

	if (diffID == 1) then
		challengeBar:SetStatusBarColor(0.76, 0.38, 0.15)
		challengeBarIcon:SetTexture([[Interface\Challenges\challenges-bronze-sm]])
	elseif (diffID == 2) then
		challengeBar:SetStatusBarColor(0.64, 0.6, 0.6)
		challengeBarIcon:SetTexture([[Interface\Challenges\challenges-silver-sm]])
	elseif (diffID == 3) then
		challengeBar:SetStatusBarColor(0.93, 0.67, 0.25)
		challengeBarIcon:SetTexture([[Interface\Challenges\challenges-gold-sm]])
	elseif (diffID == 4) then
		challengeBar:SetStatusBarColor(0.6, 0.75, 0.7)
		challengeBarIcon:SetTexture([[Interface\Challenges\challenges-plat-sm]])
	end

	if (diffID < 4) then
		challengeBar.extraText:SetFormattedText("Wave %s/%s", currWave, maxWave)
		challengeBar.score:Hide()
	else
		challengeBar.extraText:SetFormattedText("Wave %s", currWave)
		challengeBar.score:Show()
	end

	if ((duration) and (elapsed) and (elapsed < duration)) then
		challengeBar:SetMinMaxValues(0, duration)
		challengeBar.duration = duration
		challengeBar.elapsed = elapsed
		onUpdateProvingGroundsTimer(challengeBar, 0, true)
		challengeBar:SetScript("OnUpdate", onUpdateProvingGroundsTimer)
	else
		challengeBar:SetMinMaxValues(0, 1)
		challengeBar:SetValue(1)
		challengeBar.text:SetText()
		challengeBar:SetScript("OnUpdate", nil)
	end	
end

local cachedChallengeBar = nil
function WatchButton:AddChallengeBar ()
	local button = self

	if (button.challengeBar) then
		return button.challengeBar
	end

	local challengeBar
	if (not cachedChallengeBar) then
		challengeBar = CreateFrame("StatusBar", "QuestKing_ChallengeBar", QuestKing.Tracker)
		challengeBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
		challengeBar:GetStatusBarTexture():SetHorizTile(false)
		challengeBar:SetStatusBarColor(0, 0.33, 0.61)
		challengeBar:SetMinMaxValues(0, 1)
		challengeBar:SetValue(1)
		challengeBar:SetWidth(opt.buttonWidth - 36)
		challengeBar:SetHeight(17)

		challengeBar:SetBackdrop({
			bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
			insets = { left = 0, right = 0, top = 0, bottom = 0 }
		})
		challengeBar:SetBackdropColor(0, 0, 0, 0.4)

		local barPulser = button:CreateTexture()
		barPulser:SetAllPoints(challengeBar)
		barPulser:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
		barPulser:SetVertexColor(1, 0.9, 0.7, 0)
		barPulser:SetBlendMode("ADD")		
		challengeBar.barPulser = barPulser

		local animGroup = barPulser:CreateAnimationGroup()
		local a1 = animGroup:CreateAnimation("Alpha")
			a1:SetDuration(0.25); a1:SetChange(1); a1:SetOrder(1);
		local a2 = animGroup:CreateAnimation("Alpha")
			a2:SetDuration(0.3); a2:SetChange(-1); a2:SetOrder(2); a2:SetEndDelay(0.45);
		animGroup.cycles = 0
		animGroup:SetScript("OnFinished", function (self)
			if (self.cycles > 0) then
				self:Play()
				self.cycles = self.cycles - 1
			else
				self.cycles = 0
			end
		end)
		challengeBar.barPulserAnim = animGroup

		-- <Alpha childKey="BorderAnim" change="1" duration="0.25" order="1"/>
		-- <Alpha childKey="BorderAnim" endDelay="0.45" change="-1" duration="0.3" order="2"/>		

		local border = challengeBar:CreateTexture(nil, "OVERLAY")
		border:SetTexture([[Interface\Challenges\challenges-main]])
		border:SetPoint("TOPLEFT", challengeBar, "TOPLEFT", -5, 5)
		border:SetPoint("BOTTOMRIGHT", challengeBar, "BOTTOMRIGHT", 5, -5)
		border:SetTexCoord(0.00097656, 0.13769531, 0.47265625, 0.51757813)
		challengeBar.border = border

		local icon = challengeBar:CreateTexture(nil, "OVERLAY")
		icon:SetTexture([[Interface\Challenges\challenges-plat-sm]])
		icon:SetSize(22, 22)
		icon:SetPoint("RIGHT", challengeBar, "LEFT", -6, 0)
		icon:SetTexCoord(0.25, 0.7, 0.25, 0.7)
		challengeBar.icon = icon

		local text = challengeBar:CreateFontString(nil, "OVERLAY")
		text:SetFont(opt.fontChallengeTimer, opt.fontSize, opt.fontStyle)
		text:SetJustifyH("CENTER")
		text:SetJustifyV("CENTER")
		text:SetAllPoints(true)
		text:SetTextColor(1, 1, 1)
		text:SetShadowOffset(1, -1)
		text:SetShadowColor(0, 0, 0, 1)
		text:SetText("No Medal")
		challengeBar.text = text

		local extraText = challengeBar:CreateFontString(nil, "OVERLAY")
		extraText:SetFont(opt.fontChallengeTimer, opt.fontSize - 0.5, opt.fontStyle)
		extraText:SetPoint("BOTTOMLEFT", challengeBar, "TOPLEFT", 2, 4)
		extraText:SetTextColor(1, 1, 1)
		extraText:SetShadowOffset(1, -1)
		extraText:SetShadowColor(0, 0, 0, 1)
		extraText:SetText("Wave 1/5")
		extraText:Hide()
		challengeBar.extraText = extraText

		local score = challengeBar:CreateFontString(nil, "OVERLAY")
		score:SetFont(opt.fontChallengeTimer, opt.fontSize -0.5, opt.fontStyle)
		score:SetJustifyH("RIGHT")
		score:SetPoint("BOTTOMRIGHT", challengeBar, "TOPRIGHT", -2, 4)
		score:SetTextColor(1, 1, 1)
		score:SetShadowOffset(1, -1)
		score:SetShadowColor(0, 0, 0, 1)
		score:SetText("0")
		score:Hide()
		challengeBar.score = score		

		challengeBar.bonusHeight = 18

		challengeBar:SetScript("OnUpdate", nil)

		cachedChallengeBar = challengeBar
	else
		challengeBar = cachedChallengeBar
		challengeBar:ClearAllPoints()

		challengeBar.extraText:Hide()
		challengeBar.score:SetText("0")
		challengeBar.score:Hide()
		challengeBar.bonusHeight = 18

		challengeBar.barPulserAnim:Stop()
		challengeBar.barPulserAnim.cycles = 0

		challengeBar:SetScript("OnUpdate", nil)

		challengeBar:SetStatusBarColor(0, 0.33, 0.61)
		challengeBar.text:SetText("No Medal")

		challengeBar._medalTimes = nil
		challengeBar._currentMedalTime = nil
		challengeBar._startTime = nil
	end

	challengeBar:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 26, 5)
	challengeBar:Show()

	button.challengeBar = challengeBar
	button.challengeBarIcon = challengeBar.icon
	button.challengeBarText = challengeBar.text

	return challengeBar
end

function QuestKing.ProvingGroundsScoreUpdate (score)
	if (cachedChallengeBar) and (cachedChallengeBar:IsShown()) then
		cachedChallengeBar.score:SetText(score)
	end
end

function setButtonToChallengeTimer (button, timerID, elapsedTime, ...)
	button.titleButton:EnableMouse(false)
	button.title:SetText("")

	challengeBar = button:AddChallengeBar()

	challengeBar._medalTimes = challengeBar._medalTimes or {}
	for i = 1, select("#", ...) do
		challengeBar._medalTimes[i] = select(i, ...)
	end
	challengeBar._currentMedalTime = -1
	challengeBar._currentMedal = nil
	challengeBar._startTime = GetTime() - elapsedTime

	onUpdateChallengeTimer(challengeBar, 0, true)

	if (challengeBar._currentMedalTime) then
		challengeBar:SetScript("OnUpdate", onUpdateChallengeTimer)
	else
		challengeBar:SetScript("OnUpdate", nil)
	end
end

function updateChallengeMedal (self, elapsedTime)
	-- D("updateChallengeMedal", elapsedTime)
	local prevMedal = self._currentMedal

	local prevMedalTime = 0
	for i = #self._medalTimes, 1, -1 do
		local curMedalTime = self._medalTimes[i]
		if (elapsedTime < curMedalTime) then
			self._currentMedalTime = curMedalTime
			self._currentMedal = i
			self:SetMinMaxValues(0, curMedalTime - prevMedalTime)

			if i == 1 then
				self:SetStatusBarColor(0.76, 0.38, 0.15)
				self.icon:SetTexture([[Interface\Challenges\challenges-bronze-sm]])
				self.icon:Show()
				if (prevMedal) then PlaySound("UI_Challenges_MedalExpires_SilvertoBronze") end
			elseif i == 2 then
				self:SetStatusBarColor(0.68, 0.64, 0.64)
				self.icon:SetTexture([[Interface\Challenges\challenges-silver-sm]])
				self.icon:Show()
				if (prevMedal) then PlaySound("UI_Challenges_MedalExpires_GoldtoSilver") end
			elseif i == 3 then
				self:SetStatusBarColor(0.93, 0.67, 0.25)
				self.icon:SetTexture([[Interface\Challenges\challenges-gold-sm]])
				self.icon:Show()
			elseif i == 4 then
				self:SetStatusBarColor(0.6, 0.75, 0.7)
				self.icon:SetTexture([[Interface\Challenges\challenges-plat-sm]])
				self.icon:Show()
			else
				self:SetStatusBarColor(1, 0.3, 0.3)
				self.icon:Hide()
			end

			return
		else
			prevMedalTime = curMedalTime
		end
	end

	if (prevMedal) then
		PlaySound("UI_Challenges_MedalExpires")
	end

	-- no medal
	self._currentMedalTime = nil
	self._currentMedal = nil
	self:SetScript("OnUpdate", nil)

	self.text:SetText(CHALLENGES_TIMER_NO_MEDAL)
	self:SetMinMaxValues(0, 1)
	self:SetValue(1)
	self:SetStatusBarColor(0.3, 0.3, 0.3)
	self.icon:Hide()
end

function onUpdateChallengeTimer (self, elapsed, manual)
	local currentTime = GetTime() - self._startTime

	local currentMedalTime = self._currentMedalTime
	
	if (currentMedalTime) and (currentTime > currentMedalTime) then
		-- manual update or medal expired, force update
		updateChallengeMedal(self, currentTime)
		currentMedalTime = self._currentMedalTime
	end

	if (currentMedalTime) then
		-- update timer
		local timeLeft = currentMedalTime - currentTime

		if (timeLeft < 10) and (not soundPlayed) then
			PlaySoundKitID(34154)
			soundPlayed = true
		elseif (soundPlayed) and (timeLeft > 20) then
			soundPlayed = false
		end

		if (timeLeft < 5) and (timeLeft > 4) then
			local anim = self.barPulserAnim
			if (anim.cycles == 0) and (not anim:IsPlaying()) then
				anim:Play()
				anim.cycles = 4
			end
		end

		-- local timeLeftFloor = floor(timeLeft)
		self:SetValue(timeLeft)
		self.text:SetText(GetTimeStringFromSecondsShort(ceil(timeLeft)))
	else
		-- no medal, do nothing
	end

	-- force a resync every 10 sec for onupdate calls
	-- if not manual then
	-- 	local recheck = self._challengeRecheck + elapsed
	-- 	if recheck > 10.1 then
	-- 		--D("Recheck", recheck, elapsed)
	-- 		self._challengeRecheck = 0
	-- 		self:SetScript("OnUpdate", recheckUpdateTracker)
	-- 	else
	-- 		self._challengeRecheck = recheck
	-- 	end
	-- end
end