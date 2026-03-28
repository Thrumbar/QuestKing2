local addonName, QuestKing = ...

local opt = QuestKing.options
local WatchButton = QuestKing.WatchButton
local GetTimeStringFromSecondsShort = QuestKing.GetTimeStringFromSecondsShort

local ceil = math.ceil
local GetTime = GetTime

local BACKDROP_TEMPLATE = BackdropTemplateMixin and "BackdropTemplate" or nil
local CHALLENGE_BAR_HEIGHT = 17
local CHALLENGE_BAR_WIDTH_OFFSET = 36
local CHALLENGE_BAR_MIN_WIDTH = 120

local cachedChallengeBar = nil
local soundPlayed = false

local function GetChallengeBarWidth()
    local width = ((opt and opt.buttonWidth) or 230) - CHALLENGE_BAR_WIDTH_OFFSET
    if width < CHALLENGE_BAR_MIN_WIDTH then
        width = CHALLENGE_BAR_MIN_WIDTH
    end
    return width
end

local function ApplyFontStringStyle(fontString, sizeOffset)
    if not fontString then
        return
    end

    local fontPath = opt.fontChallengeTimer or opt.font or STANDARD_TEXT_FONT
    local fontSize = (opt.fontSize or 12) + (sizeOffset or 0)
    local fontStyle = opt.fontStyle or ""

    fontString:SetFont(fontPath, fontSize, fontStyle)
    fontString:SetShadowOffset(1, -1)
    fontString:SetShadowColor(0, 0, 0, 1)
end

local function PlaySoundCompat(soundKitID, legacyName)
    if not PlaySound then
        return
    end

    if SOUNDKIT and soundKitID then
        PlaySound(soundKitID)
        return
    end

    if legacyName then
        PlaySound(legacyName)
    end
end

local function EnsureBackdrop(statusBar)
    if statusBar.SetBackdrop then
        statusBar:SetBackdrop({
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            insets = { left = 0, right = 0, top = 0, bottom = 0 },
        })
        if statusBar.SetBackdropColor then
            statusBar:SetBackdropColor(0, 0, 0, 0.4)
        end
        return
    end

    if not statusBar.background then
        local background = statusBar:CreateTexture(nil, "BACKGROUND")
        background:SetAllPoints(statusBar)
        background:SetColorTexture(0, 0, 0, 0.4)
        statusBar.background = background
    else
        statusBar.background:SetColorTexture(0, 0, 0, 0.4)
        statusBar.background:Show()
    end
end

local function GetWorldElapsedTimerTypeValue(name, fallback)
    if Enum and Enum.WorldElapsedTimerType and Enum.WorldElapsedTimerType[name] ~= nil then
        return Enum.WorldElapsedTimerType[name]
    end

    return fallback
end

local WORLD_ELAPSED_TIMER_TYPE_CHALLENGE_MODE = GetWorldElapsedTimerTypeValue("ChallengeMode", LE_WORLD_ELAPSED_TIMER_TYPE_CHALLENGE_MODE or 2)
local WORLD_ELAPSED_TIMER_TYPE_PROVING_GROUND = GetWorldElapsedTimerTypeValue("ProvingGrounds", LE_WORLD_ELAPSED_TIMER_TYPE_PROVING_GROUND or 1)

local function ResetChallengeBarVisuals(challengeBar)
    if not challengeBar then
        return
    end

    challengeBar:SetWidth(GetChallengeBarWidth())
    challengeBar:SetHeight(CHALLENGE_BAR_HEIGHT)
    challengeBar:SetStatusBarColor(0, 0.33, 0.61)
    challengeBar:SetMinMaxValues(0, 1)
    challengeBar:SetValue(1)
    challengeBar:SetScript("OnUpdate", nil)

    if challengeBar.barPulserAnim then
        challengeBar.barPulserAnim:Stop()
        challengeBar.barPulserAnim.cycles = 0
    end

    challengeBar.duration = nil
    challengeBar.elapsed = nil
    challengeBar._medalTimes = nil
    challengeBar._currentMedalTime = nil
    challengeBar._currentMedal = nil
    challengeBar._startTime = nil

    challengeBar.text:SetText(CHALLENGES_TIMER_NO_MEDAL or "No Medal")
    challengeBar.text:Show()

    challengeBar.icon:SetTexture([[Interface\Challenges\challenges-plat-sm]])
    challengeBar.icon:SetTexCoord(0.25, 0.7, 0.25, 0.7)
    challengeBar.icon:Show()

    challengeBar.extraText:SetText("")
    challengeBar.extraText:Hide()

    challengeBar.score:SetText("0")
    challengeBar.score:Hide()

    challengeBar.bonusHeight = 18
end

local function OnUpdateProvingGroundsTimer(self, elapsed)
    local elapsedNew = (self.elapsed or 0) + elapsed
    self.elapsed = elapsedNew

    local duration = self.duration or 0
    local timeLeft = duration - elapsedNew
    if timeLeft < 0 then
        timeLeft = 0
    end

    self:SetValue(timeLeft)
    self.text:SetText(GetTimeStringFromSecondsShort(ceil(timeLeft)))

    if timeLeft < 5 and timeLeft > 4 then
        local anim = self.barPulserAnim
        if anim and anim.cycles == 0 and not anim:IsPlaying() then
            anim.cycles = 4
            anim:Play()
        end
    end
end

local function SetButtonToProvingGroundsTimer(button, elapsed, diffID, currWave, maxWave, duration)
    button.titleButton:EnableMouse(false)
    button.title:SetText("")

    local challengeBar = button:AddChallengeBar()
    local challengeBarIcon = challengeBar.icon

    challengeBar.bonusHeight = 28
    challengeBar.extraText:Show()

    if diffID == 1 then
        challengeBar:SetStatusBarColor(0.76, 0.38, 0.15)
        challengeBarIcon:SetTexture([[Interface\Challenges\challenges-bronze-sm]])
    elseif diffID == 2 then
        challengeBar:SetStatusBarColor(0.64, 0.6, 0.6)
        challengeBarIcon:SetTexture([[Interface\Challenges\challenges-silver-sm]])
    elseif diffID == 3 then
        challengeBar:SetStatusBarColor(0.93, 0.67, 0.25)
        challengeBarIcon:SetTexture([[Interface\Challenges\challenges-gold-sm]])
    elseif diffID == 4 then
        challengeBar:SetStatusBarColor(0.6, 0.75, 0.7)
        challengeBarIcon:SetTexture([[Interface\Challenges\challenges-plat-sm]])
    else
        challengeBar:SetStatusBarColor(0.3, 0.3, 0.3)
    end

    if diffID and diffID < 4 then
        challengeBar.extraText:SetFormattedText("Wave %s/%s", currWave or 0, maxWave or 0)
        challengeBar.score:Hide()
    else
        challengeBar.extraText:SetFormattedText("Wave %s", currWave or 0)
        challengeBar.score:Show()
    end

    if duration and elapsed and elapsed < duration then
        challengeBar:SetMinMaxValues(0, duration)
        challengeBar.duration = duration
        challengeBar.elapsed = elapsed
        OnUpdateProvingGroundsTimer(challengeBar, 0)
        challengeBar:SetScript("OnUpdate", OnUpdateProvingGroundsTimer)
    else
        challengeBar:SetMinMaxValues(0, 1)
        challengeBar:SetValue(1)
        challengeBar.text:SetText("")
        challengeBar:SetScript("OnUpdate", nil)
    end
end

function WatchButton:AddChallengeBar()
    local button = self

    if button.challengeBar then
        button.challengeBar:SetWidth(GetChallengeBarWidth())
        return button.challengeBar
    end

    local challengeBar = cachedChallengeBar
    if not challengeBar then
        challengeBar = CreateFrame("StatusBar", "QuestKing_ChallengeBar", QuestKing.Tracker, BACKDROP_TEMPLATE)
        challengeBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
        challengeBar:GetStatusBarTexture():SetHorizTile(false)
        challengeBar:SetWidth(GetChallengeBarWidth())
        challengeBar:SetHeight(CHALLENGE_BAR_HEIGHT)
        EnsureBackdrop(challengeBar)

        local barPulser = challengeBar:CreateTexture(nil, "OVERLAY")
        barPulser:SetAllPoints(challengeBar)
        barPulser:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
        barPulser:SetVertexColor(1, 0.9, 0.7, 0)
        barPulser:SetBlendMode("ADD")
        challengeBar.barPulser = barPulser

        do
            local animGroup = barPulser:CreateAnimationGroup()

            local a1 = animGroup:CreateAnimation("Alpha")
            a1:SetDuration(0.25)
            a1:SetFromAlpha(0)
            a1:SetToAlpha(1)
            a1:SetOrder(1)

            local a2 = animGroup:CreateAnimation("Alpha")
            a2:SetDuration(0.3)
            a2:SetFromAlpha(1)
            a2:SetToAlpha(0)
            a2:SetOrder(2)
            a2:SetEndDelay(0.45)

            animGroup.cycles = 0
            animGroup:SetScript("OnFinished", function(selfAnim)
                if selfAnim.cycles > 0 then
                    selfAnim.cycles = selfAnim.cycles - 1
                    selfAnim:Play()
                else
                    selfAnim.cycles = 0
                end
            end)

            challengeBar.barPulserAnim = animGroup
        end

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
        ApplyFontStringStyle(text, 0)
        text:SetJustifyH("CENTER")
        text:SetJustifyV("MIDDLE")
        text:SetAllPoints(challengeBar)
        text:SetTextColor(1, 1, 1)
        text:SetWordWrap(false)
        text:SetText(CHALLENGES_TIMER_NO_MEDAL or "No Medal")
        challengeBar.text = text

        local extraText = challengeBar:CreateFontString(nil, "OVERLAY")
        ApplyFontStringStyle(extraText, -0.5)
        extraText:SetPoint("BOTTOMLEFT", challengeBar, "TOPLEFT", 2, 4)
        extraText:SetTextColor(1, 1, 1)
        extraText:SetJustifyH("LEFT")
        extraText:SetJustifyV("MIDDLE")
        extraText:SetWordWrap(false)
        extraText:SetText("")
        extraText:Hide()
        challengeBar.extraText = extraText

        local score = challengeBar:CreateFontString(nil, "OVERLAY")
        ApplyFontStringStyle(score, -0.5)
        score:SetJustifyH("RIGHT")
        score:SetJustifyV("MIDDLE")
        score:SetPoint("BOTTOMRIGHT", challengeBar, "TOPRIGHT", -2, 4)
        score:SetTextColor(1, 1, 1)
        score:SetWordWrap(false)
        score:SetText("0")
        score:Hide()
        challengeBar.score = score

        cachedChallengeBar = challengeBar
    else
        challengeBar:ClearAllPoints()
        EnsureBackdrop(challengeBar)
    end

    ResetChallengeBarVisuals(challengeBar)
    challengeBar:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 26, 5)
    challengeBar:Show()

    button.challengeBar = challengeBar
    button.challengeBarIcon = challengeBar.icon
    button.challengeBarText = challengeBar.text

    return challengeBar
end

function QuestKing.ProvingGroundsScoreUpdate(score)
    if cachedChallengeBar and cachedChallengeBar:IsShown() then
        cachedChallengeBar.score:SetText(score or "0")
    end
end

local function UpdateChallengeMedal(self, elapsedTime)
    local prevMedal = self._currentMedal
    local prevMedalTime = 0

    for i = #self._medalTimes, 1, -1 do
        local curMedalTime = self._medalTimes[i]
        if elapsedTime < curMedalTime then
            self._currentMedalTime = curMedalTime
            self._currentMedal = i
            self:SetMinMaxValues(0, curMedalTime - prevMedalTime)

            if i == 1 then
                self:SetStatusBarColor(0.76, 0.38, 0.15)
                self.icon:SetTexture([[Interface\Challenges\challenges-bronze-sm]])
                self.icon:Show()
                if prevMedal then
                    PlaySoundCompat(SOUNDKIT and SOUNDKIT.UI_CHALLENGES_MEDAL_EXPIRES_SILVER_TO_BRONZE, "UI_Challenges_MedalExpires_SilvertoBronze")
                end
            elseif i == 2 then
                self:SetStatusBarColor(0.68, 0.64, 0.64)
                self.icon:SetTexture([[Interface\Challenges\challenges-silver-sm]])
                self.icon:Show()
                if prevMedal then
                    PlaySoundCompat(SOUNDKIT and SOUNDKIT.UI_CHALLENGES_MEDAL_EXPIRES_GOLD_TO_SILVER, "UI_Challenges_MedalExpires_GoldtoSilver")
                end
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

    if prevMedal then
        PlaySoundCompat(SOUNDKIT and SOUNDKIT.UI_CHALLENGES_MEDAL_EXPIRES, "UI_Challenges_MedalExpires")
    end

    self._currentMedalTime = nil
    self._currentMedal = nil
    self:SetScript("OnUpdate", nil)
    self.text:SetText(CHALLENGES_TIMER_NO_MEDAL or "No Medal")
    self:SetMinMaxValues(0, 1)
    self:SetValue(1)
    self:SetStatusBarColor(0.3, 0.3, 0.3)
    self.icon:Hide()
end

local function OnUpdateChallengeTimer(self)
    local startTime = self._startTime
    if not startTime then
        return
    end

    local currentTime = GetTime() - startTime
    local currentMedalTime = self._currentMedalTime

    if currentMedalTime and currentTime > currentMedalTime then
        UpdateChallengeMedal(self, currentTime)
        currentMedalTime = self._currentMedalTime
    end

    if currentMedalTime then
        local timeLeft = currentMedalTime - currentTime

        if timeLeft < 10 and not soundPlayed then
            PlaySoundCompat(SOUNDKIT and SOUNDKIT.UI_SCENARIO_STAGE_END, nil)
            soundPlayed = true
        elseif soundPlayed and timeLeft > 20 then
            soundPlayed = false
        end

        if timeLeft < 5 and timeLeft > 4 then
            local anim = self.barPulserAnim
            if anim and anim.cycles == 0 and not anim:IsPlaying() then
                anim.cycles = 4
                anim:Play()
            end
        end

        self:SetValue(timeLeft)
        self.text:SetText(GetTimeStringFromSecondsShort(ceil(timeLeft)))
    end
end

local function SetButtonToChallengeTimer(button, timerID, elapsedTime, ...)
    button.titleButton:EnableMouse(false)
    button.title:SetText("")

    local challengeBar = button:AddChallengeBar()
    challengeBar._medalTimes = challengeBar._medalTimes or {}

    for i = 1, select("#", ...) do
        challengeBar._medalTimes[i] = select(i, ...)
    end

    challengeBar._currentMedalTime = -1
    challengeBar._currentMedal = nil
    challengeBar._startTime = GetTime() - (elapsedTime or 0)

    UpdateChallengeMedal(challengeBar, elapsedTime or 0)
    OnUpdateChallengeTimer(challengeBar)

    if challengeBar._currentMedalTime then
        challengeBar:SetScript("OnUpdate", OnUpdateChallengeTimer)
    else
        challengeBar:SetScript("OnUpdate", nil)
    end
end

local function ParseChallengeTimers(...)
    for i = 1, select("#", ...) do
        local timerID = select(i, ...)
        local description, elapsedTime, timerType = GetWorldElapsedTime(timerID)
        local _, _, _, _, _, _, _, mapID = GetInstanceInfo()

        if timerID == 1 and timerType == 0 and mapID == 1148 then
            description, elapsedTime, timerType = GetWorldElapsedTime(2)
        end

        if timerType == WORLD_ELAPSED_TIMER_TYPE_CHALLENGE_MODE then
            if mapID and GetChallengeModeMapTimes then
                local button = WatchButton:GetKeyed("challengetimer", mapID)
                SetButtonToChallengeTimer(button, timerID, elapsedTime, GetChallengeModeMapTimes(mapID))
                return
            end
        elseif timerType == WORLD_ELAPSED_TIMER_TYPE_PROVING_GROUND then
            if C_Scenario and C_Scenario.GetProvingGroundsInfo then
                local diffID, currWave, maxWave, duration = C_Scenario.GetProvingGroundsInfo()
                if duration and duration > 0 then
                    local key = mapID or "provinggrounds"
                    local button = WatchButton:GetKeyed("provinggrounds", key)
                    SetButtonToProvingGroundsTimer(button, elapsedTime, diffID, currWave, maxWave, duration)
                    return
                end
            end
        end
    end
end

function QuestKing:UpdateTrackerChallengeTimers()
    if not (GetWorldElapsedTimers and GetWorldElapsedTime) then
        return
    end

    local hasTimer = GetWorldElapsedTimers()
    if hasTimer then
        ParseChallengeTimers(GetWorldElapsedTimers())
    end
end