local addonName, QuestKing = ...

local opt = QuestKing.options or {}
local WatchButton = QuestKing.WatchButton
local GetTimeStringFromSecondsShort = QuestKing.GetTimeStringFromSecondsShort or function(seconds)
    seconds = tonumber(seconds) or 0
    if seconds < 0 then
        seconds = 0
    end
    return tostring(seconds)
end

local ceil = math.ceil
local max = math.max
local min = math.min
local type = type
local tostring = tostring
local tonumber = tonumber
local unpack = unpack or table.unpack

local GetTime = GetTime
local C_ChallengeMode = C_ChallengeMode
local C_Scenario = C_Scenario
local Enum = Enum

local BACKDROP_TEMPLATE = BackdropTemplateMixin and "BackdropTemplate" or nil
local CHALLENGE_BAR_HEIGHT = 17
local CHALLENGE_BAR_WIDTH_OFFSET = 36
local CHALLENGE_BAR_MIN_WIDTH = 120
local UPDATE_INTERVAL = 0.05

local activeProvingGroundBar = nil

local function SafeCall(func, ...)
    if type(func) ~= "function" then
        return false, nil, nil, nil, nil, nil, nil, nil, nil, nil
    end

    local ok, a, b, c, d, e, f, g, h, i = pcall(func, ...)
    if ok then
        return true, a, b, c, d, e, f, g, h, i
    end

    return false, nil, nil, nil, nil, nil, nil, nil, nil, nil
end

local function SafeNumber(value, fallback)
    if type(value) == "number" then
        return value
    end

    local numberValue = tonumber(value)
    if type(numberValue) == "number" then
        return numberValue
    end

    return fallback
end

local function GetChallengeBarWidth()
    local width = (SafeNumber(opt.buttonWidth, 230) or 230) - CHALLENGE_BAR_WIDTH_OFFSET
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
    local fontSize = (SafeNumber(opt.fontSize, 12) or 12) + (sizeOffset or 0)
    local fontStyle = opt.fontStyle or ""

    fontString:SetFont(fontPath, fontSize, fontStyle)
    fontString:SetShadowOffset(1, -1)
    fontString:SetShadowColor(0, 0, 0, 1)
end

local function PlaySoundCompat(soundKitID, legacyName)
    if type(PlaySound) ~= "function" then
        return
    end

    if SOUNDKIT and soundKitID then
        pcall(PlaySound, soundKitID)
        return
    end

    if legacyName then
        pcall(PlaySound, legacyName)
    end
end

local function EnsureBackdrop(statusBar)
    if not statusBar then
        return
    end

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

local function GetWorldElapsedTimerEnum(name, legacyFallback)
    if Enum and Enum.WorldElapsedTimerTypes and Enum.WorldElapsedTimerTypes[name] ~= nil then
        return Enum.WorldElapsedTimerTypes[name]
    end

    if Enum and Enum.WorldElapsedTimerType and Enum.WorldElapsedTimerType[name] ~= nil then
        return Enum.WorldElapsedTimerType[name]
    end

    return legacyFallback
end

local WORLD_ELAPSED_TIMER_TYPE_NONE = GetWorldElapsedTimerEnum("None", LE_WORLD_ELAPSED_TIMER_TYPE_NONE or 0)
local WORLD_ELAPSED_TIMER_TYPE_PROVING_GROUND = GetWorldElapsedTimerEnum("ProvingGround", LE_WORLD_ELAPSED_TIMER_TYPE_PROVING_GROUND or 1)
local WORLD_ELAPSED_TIMER_TYPE_CHALLENGE_MODE = GetWorldElapsedTimerEnum("ChallengeMode", LE_WORLD_ELAPSED_TIMER_TYPE_CHALLENGE_MODE or 2)

local function StopPulseAnimation(challengeBar)
    local anim = challengeBar and challengeBar.barPulserAnim
    if anim then
        anim.cycles = 0
        anim:Stop()
    end
end

local function TriggerCountdownPulse(challengeBar)
    local anim = challengeBar and challengeBar.barPulserAnim
    if not anim then
        return
    end

    if anim.cycles == 0 and not anim:IsPlaying() then
        anim.cycles = 4
        anim:Play()
    end
end

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

    StopPulseAnimation(challengeBar)

    challengeBar.mode = nil
    challengeBar.timerID = nil
    challengeBar.mapID = nil
    challengeBar.timeLimit = nil
    challengeBar.duration = nil
    challengeBar.elapsedBase = nil
    challengeBar.startTime = nil
    challengeBar.nextUpdate = 0
    challengeBar.finalCountdownPlayed = false

    challengeBar.medalTimes = nil
    challengeBar.currentMedalIndex = nil
    challengeBar.currentMedalStart = nil
    challengeBar.currentMedalEnd = nil
    challengeBar.lastDeathCount = nil
    challengeBar.lastTimeLost = nil

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

local function CreateChallengeBar(button)
    local challengeBar = CreateFrame("StatusBar", nil, button, BACKDROP_TEMPLATE)
    challengeBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")

    local statusTexture = challengeBar:GetStatusBarTexture()
    if statusTexture and statusTexture.SetHorizTile then
        statusTexture:SetHorizTile(false)
    end

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

    ResetChallengeBarVisuals(challengeBar)
    return challengeBar
end

function WatchButton:AddChallengeBar()
    local button = self
    local challengeBar = button._challengeBarPersistent

    if not challengeBar then
        challengeBar = CreateChallengeBar(button)
        button._challengeBarPersistent = challengeBar
    else
        challengeBar:ClearAllPoints()
        EnsureBackdrop(challengeBar)
        ResetChallengeBarVisuals(challengeBar)
    end

    challengeBar:SetParent(button)
    challengeBar:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 26, 5)
    challengeBar:SetWidth(GetChallengeBarWidth())
    challengeBar:Show()

    button.challengeBar = challengeBar
    button.challengeBarIcon = challengeBar.icon
    button.challengeBarText = challengeBar.text

    return challengeBar
end

local function SetChallengeTitleState(button)
    if not button then
        return
    end

    button.titleButton:EnableMouse(false)
    button.title:SetText("")
end

local function GetActiveChallengeMapInfo()
    if not C_ChallengeMode then
        return nil, nil, nil
    end

    local okMap, mapID = SafeCall(C_ChallengeMode.GetActiveChallengeMapID)
    mapID = okMap and SafeNumber(mapID, nil) or nil
    if not mapID then
        return nil, nil, nil
    end

    local okInfo, name, _, timeLimit = SafeCall(C_ChallengeMode.GetMapUIInfo, mapID)
    if okInfo then
        return mapID, name, SafeNumber(timeLimit, nil)
    end

    return mapID, nil, nil
end

local function GetLegacyChallengeMedalTimes(mapID)
    if not mapID then
        return nil
    end

    if C_ChallengeMode and type(C_ChallengeMode.GetChallengeModeMapTimes) == "function" then
        local ok, bronzeTime, silverTime, goldTime = SafeCall(C_ChallengeMode.GetChallengeModeMapTimes, mapID)
        if ok and bronzeTime then
            local times = {}

            if SafeNumber(bronzeTime, nil) then
                times[#times + 1] = bronzeTime
            end
            if SafeNumber(silverTime, nil) then
                times[#times + 1] = silverTime
            end
            if SafeNumber(goldTime, nil) then
                times[#times + 1] = goldTime
            end

            if #times > 0 then
                return times
            end
        end
    end

    if type(GetChallengeModeMapTimes) == "function" then
        local ok, bronzeTime, silverTime, goldTime = SafeCall(GetChallengeModeMapTimes, mapID)
        if ok and bronzeTime then
            local times = {}

            if SafeNumber(bronzeTime, nil) then
                times[#times + 1] = bronzeTime
            end
            if SafeNumber(silverTime, nil) then
                times[#times + 1] = silverTime
            end
            if SafeNumber(goldTime, nil) then
                times[#times + 1] = goldTime
            end

            if #times > 0 then
                return times
            end
        end
    end

    return nil
end

local function SetModernChallengeMeta(challengeBar)
    local level
    if C_ChallengeMode and type(C_ChallengeMode.GetActiveKeystoneInfo) == "function" then
        local ok, activeLevel = SafeCall(C_ChallengeMode.GetActiveKeystoneInfo)
        if ok then
            level = SafeNumber(activeLevel, nil)
        end
    end

    if level and level > 0 then
        if CHALLENGE_MODE_POWER_LEVEL then
            challengeBar.extraText:SetText(CHALLENGE_MODE_POWER_LEVEL:format(level))
        else
            challengeBar.extraText:SetText("+" .. level)
        end
        challengeBar.extraText:Show()
    else
        challengeBar.extraText:SetText(MYTHIC_PLUS_SEASON_BEST or "Mythic+")
        challengeBar.extraText:Show()
    end

    if C_ChallengeMode and type(C_ChallengeMode.GetDeathCount) == "function" then
        local ok, deathCount, timeLost = SafeCall(C_ChallengeMode.GetDeathCount)
        deathCount = ok and (SafeNumber(deathCount, 0) or 0) or 0
        timeLost = ok and (SafeNumber(timeLost, 0) or 0) or 0

        challengeBar.lastDeathCount = deathCount
        challengeBar.lastTimeLost = timeLost

        if deathCount > 0 then
            challengeBar.score:SetText(tostring(deathCount))
            challengeBar.score:Show()
        else
            challengeBar.score:SetText("0")
            challengeBar.score:Hide()
        end
    else
        challengeBar.score:Hide()
    end
end

local function UpdateModernChallengeDeathCount(challengeBar)
    if not (challengeBar and C_ChallengeMode and type(C_ChallengeMode.GetDeathCount) == "function") then
        return
    end

    local ok, deathCount, timeLost = SafeCall(C_ChallengeMode.GetDeathCount)
    if not ok then
        return
    end

    deathCount = SafeNumber(deathCount, 0) or 0
    timeLost = SafeNumber(timeLost, 0) or 0

    if deathCount ~= challengeBar.lastDeathCount or timeLost ~= challengeBar.lastTimeLost then
        challengeBar.lastDeathCount = deathCount
        challengeBar.lastTimeLost = timeLost

        if deathCount > 0 then
            challengeBar.score:SetText(tostring(deathCount))
            challengeBar.score:Show()
        else
            challengeBar.score:SetText("0")
            challengeBar.score:Hide()
        end
    end
end

local function UpdateFinalCountdownEffects(challengeBar, timeLeft)
    if timeLeft <= 10 and not challengeBar.finalCountdownPlayed then
        challengeBar.finalCountdownPlayed = true
        PlaySoundCompat(SOUNDKIT and SOUNDKIT.UI_SCENARIO_STAGE_END, nil)
    elseif timeLeft > 20 then
        challengeBar.finalCountdownPlayed = false
    end

    if timeLeft <= 5 and timeLeft > 4 then
        TriggerCountdownPulse(challengeBar)
    end
end

local function OnUpdateModernChallengeTimer(self, elapsed)
    self.nextUpdate = (self.nextUpdate or 0) - elapsed
    if self.nextUpdate > 0 then
        return
    end
    self.nextUpdate = UPDATE_INTERVAL

    local startTime = self.startTime or GetTime()
    local elapsedTime = GetTime() - startTime
    local timeLimit = SafeNumber(self.timeLimit, 0) or 0
    local timeLeft = max(0, timeLimit - elapsedTime)

    self:SetMinMaxValues(0, timeLimit > 0 and timeLimit or 1)
    self:SetValue(timeLeft)
    self.text:SetText(GetTimeStringFromSecondsShort(ceil(timeLeft)))

    UpdateModernChallengeDeathCount(self)
    UpdateFinalCountdownEffects(self, timeLeft)
end

local function SetModernChallengeTimer(button, timerID, elapsedTime, mapID, timeLimit)
    SetChallengeTitleState(button)

    local challengeBar = button:AddChallengeBar()
    challengeBar.mode = "modern_challenge"
    challengeBar.timerID = timerID
    challengeBar.mapID = mapID
    challengeBar.timeLimit = timeLimit
    challengeBar.startTime = GetTime() - (elapsedTime or 0)
    challengeBar.nextUpdate = 0
    challengeBar.bonusHeight = 28

    challengeBar:SetStatusBarColor(0.10, 0.45, 0.85)
    challengeBar.icon:SetTexture([[Interface\Challenges\challenges-plat-sm]])
    challengeBar.icon:Show()

    SetModernChallengeMeta(challengeBar)
    OnUpdateModernChallengeTimer(challengeBar, 0)
    challengeBar:SetScript("OnUpdate", OnUpdateModernChallengeTimer)
end

local function SetLegacyMedalVisual(challengeBar, medalIndex)
    if medalIndex == 1 then
        challengeBar:SetStatusBarColor(0.76, 0.38, 0.15)
        challengeBar.icon:SetTexture([[Interface\Challenges\challenges-bronze-sm]])
        challengeBar.icon:Show()
    elseif medalIndex == 2 then
        challengeBar:SetStatusBarColor(0.68, 0.64, 0.64)
        challengeBar.icon:SetTexture([[Interface\Challenges\challenges-silver-sm]])
        challengeBar.icon:Show()
    elseif medalIndex == 3 then
        challengeBar:SetStatusBarColor(0.93, 0.67, 0.25)
        challengeBar.icon:SetTexture([[Interface\Challenges\challenges-gold-sm]])
        challengeBar.icon:Show()
    elseif medalIndex == 4 then
        challengeBar:SetStatusBarColor(0.60, 0.75, 0.70)
        challengeBar.icon:SetTexture([[Interface\Challenges\challenges-plat-sm]])
        challengeBar.icon:Show()
    else
        challengeBar:SetStatusBarColor(0.30, 0.30, 0.30)
        challengeBar.icon:Hide()
    end
end

local function PlayLegacyMedalTransitionSound(previousIndex, newIndex)
    if previousIndex == nil or previousIndex == newIndex then
        return
    end

    if previousIndex == 3 and newIndex == 2 then
        PlaySoundCompat(
            SOUNDKIT and SOUNDKIT.UI_CHALLENGES_MEDAL_EXPIRES_GOLD_TO_SILVER,
            "UI_Challenges_MedalExpires_GoldtoSilver"
        )
    elseif previousIndex == 2 and newIndex == 1 then
        PlaySoundCompat(
            SOUNDKIT and SOUNDKIT.UI_CHALLENGES_MEDAL_EXPIRES_SILVER_TO_BRONZE,
            "UI_Challenges_MedalExpires_SilvertoBronze"
        )
    elseif previousIndex and not newIndex then
        PlaySoundCompat(
            SOUNDKIT and SOUNDKIT.UI_CHALLENGES_MEDAL_EXPIRES,
            "UI_Challenges_MedalExpires"
        )
    end
end

local function UpdateLegacyChallengeState(challengeBar, elapsedTime)
    local medalTimes = challengeBar.medalTimes
    if type(medalTimes) ~= "table" or #medalTimes == 0 then
        challengeBar.currentMedalIndex = nil
        challengeBar.currentMedalStart = nil
        challengeBar.currentMedalEnd = nil
        challengeBar:SetStatusBarColor(0.30, 0.30, 0.30)
        challengeBar.icon:Hide()
        challengeBar:SetMinMaxValues(0, 1)
        challengeBar:SetValue(1)
        challengeBar.text:SetText(CHALLENGES_TIMER_NO_MEDAL or "No Medal")
        return
    end

    local previousMedalIndex = challengeBar.currentMedalIndex
    local currentMedalIndex
    local currentMedalStart = 0
    local currentMedalEnd

    for index = #medalTimes, 1, -1 do
        local medalTime = SafeNumber(medalTimes[index], nil)
        if medalTime and elapsedTime < medalTime then
            currentMedalIndex = index
            currentMedalEnd = medalTime
            currentMedalStart = SafeNumber(medalTimes[index - 1], 0) or 0
            break
        end
    end

    if currentMedalIndex ~= previousMedalIndex then
        PlayLegacyMedalTransitionSound(previousMedalIndex, currentMedalIndex)
    end

    challengeBar.currentMedalIndex = currentMedalIndex
    challengeBar.currentMedalStart = currentMedalStart
    challengeBar.currentMedalEnd = currentMedalEnd

    if currentMedalIndex then
        SetLegacyMedalVisual(challengeBar, currentMedalIndex)

        local segmentDuration = max(1, currentMedalEnd - currentMedalStart)
        local timeLeft = max(0, currentMedalEnd - elapsedTime)

        challengeBar:SetMinMaxValues(0, segmentDuration)
        challengeBar:SetValue(timeLeft)
        challengeBar.text:SetText(GetTimeStringFromSecondsShort(ceil(timeLeft)))

        UpdateFinalCountdownEffects(challengeBar, timeLeft)
    else
        SetLegacyMedalVisual(challengeBar, nil)
        challengeBar:SetMinMaxValues(0, 1)
        challengeBar:SetValue(1)
        challengeBar.text:SetText(CHALLENGES_TIMER_NO_MEDAL or "No Medal")
        challengeBar:SetScript("OnUpdate", nil)
    end
end

local function OnUpdateLegacyChallengeTimer(self, elapsed)
    self.nextUpdate = (self.nextUpdate or 0) - elapsed
    if self.nextUpdate > 0 then
        return
    end
    self.nextUpdate = UPDATE_INTERVAL

    local elapsedTime = GetTime() - (self.startTime or GetTime())
    UpdateLegacyChallengeState(self, elapsedTime)
end

local function SetLegacyChallengeTimer(button, timerID, elapsedTime, mapID, medalTimes)
    SetChallengeTitleState(button)

    local challengeBar = button:AddChallengeBar()
    challengeBar.mode = "legacy_challenge"
    challengeBar.timerID = timerID
    challengeBar.mapID = mapID
    challengeBar.startTime = GetTime() - (elapsedTime or 0)
    challengeBar.medalTimes = medalTimes
    challengeBar.nextUpdate = 0

    challengeBar.extraText:SetText("")
    challengeBar.extraText:Hide()
    challengeBar.score:Hide()

    UpdateLegacyChallengeState(challengeBar, elapsedTime or 0)

    if challengeBar.currentMedalEnd then
        challengeBar:SetScript("OnUpdate", OnUpdateLegacyChallengeTimer)
    else
        challengeBar:SetScript("OnUpdate", nil)
    end
end

local function OnUpdateProvingGroundsTimer(self, elapsed)
    self.nextUpdate = (self.nextUpdate or 0) - elapsed
    if self.nextUpdate > 0 then
        return
    end
    self.nextUpdate = UPDATE_INTERVAL

    local elapsedTime = GetTime() - (self.startTime or GetTime())
    local duration = SafeNumber(self.duration, 0) or 0
    local timeLeft = max(0, duration - elapsedTime)

    self:SetValue(timeLeft)
    self.text:SetText(GetTimeStringFromSecondsShort(ceil(timeLeft)))
    UpdateFinalCountdownEffects(self, timeLeft)
end

local function SetProvingGroundsTimer(button, timerID, elapsedTime, diffID, currWave, maxWave, duration)
    SetChallengeTitleState(button)

    local challengeBar = button:AddChallengeBar()
    local challengeBarIcon = challengeBar.icon

    challengeBar.mode = "proving_grounds"
    challengeBar.timerID = timerID
    challengeBar.duration = duration
    challengeBar.startTime = GetTime() - (elapsedTime or 0)
    challengeBar.nextUpdate = 0
    challengeBar.bonusHeight = 28
    challengeBar.extraText:Show()

    if diffID == 1 then
        challengeBar:SetStatusBarColor(0.76, 0.38, 0.15)
        challengeBarIcon:SetTexture([[Interface\Challenges\challenges-bronze-sm]])
    elseif diffID == 2 then
        challengeBar:SetStatusBarColor(0.64, 0.60, 0.60)
        challengeBarIcon:SetTexture([[Interface\Challenges\challenges-silver-sm]])
    elseif diffID == 3 then
        challengeBar:SetStatusBarColor(0.93, 0.67, 0.25)
        challengeBarIcon:SetTexture([[Interface\Challenges\challenges-gold-sm]])
    elseif diffID == 4 then
        challengeBar:SetStatusBarColor(0.60, 0.75, 0.70)
        challengeBarIcon:SetTexture([[Interface\Challenges\challenges-plat-sm]])
    else
        challengeBar:SetStatusBarColor(0.30, 0.30, 0.30)
    end

    if diffID and diffID < 4 then
        challengeBar.extraText:SetFormattedText("Wave %s/%s", currWave or 0, maxWave or 0)
        challengeBar.score:Hide()
    else
        challengeBar.extraText:SetFormattedText("Wave %s", currWave or 0)
        challengeBar.score:Show()
    end

    challengeBar:SetMinMaxValues(0, duration > 0 and duration or 1)
    OnUpdateProvingGroundsTimer(challengeBar, 0)
    challengeBar:SetScript("OnUpdate", OnUpdateProvingGroundsTimer)

    activeProvingGroundBar = challengeBar
end

function QuestKing.ProvingGroundsScoreUpdate(score)
    if activeProvingGroundBar and activeProvingGroundBar:IsShown() then
        activeProvingGroundBar.score:SetText(score or "0")
    end
end

local function ResolveTimerDetails(timerID)
    local okTimer, _, elapsedTime, timerType = SafeCall(GetWorldElapsedTime, timerID)
    if not okTimer then
        return nil
    end

    elapsedTime = SafeNumber(elapsedTime, 0) or 0
    timerType = SafeNumber(timerType, WORLD_ELAPSED_TIMER_TYPE_NONE) or WORLD_ELAPSED_TIMER_TYPE_NONE

    if timerType == WORLD_ELAPSED_TIMER_TYPE_CHALLENGE_MODE then
        local mapID, _, timeLimit = GetActiveChallengeMapInfo()

        if mapID and timeLimit and timeLimit > 0 then
            return "modern_challenge", mapID, elapsedTime, timeLimit
        end

        local legacyMapID = mapID
        if not legacyMapID and type(GetInstanceInfo) == "function" then
            local okInstance, _, _, _, _, _, _, _, instanceMapID = SafeCall(GetInstanceInfo)
            if okInstance then
                legacyMapID = SafeNumber(instanceMapID, nil)
            end
        end

        if legacyMapID then
            local medalTimes = GetLegacyChallengeMedalTimes(legacyMapID)
            if medalTimes and #medalTimes > 0 then
                return "legacy_challenge", legacyMapID, elapsedTime, medalTimes
            end
        end
    elseif timerType == WORLD_ELAPSED_TIMER_TYPE_PROVING_GROUND then
        if C_Scenario and type(C_Scenario.GetProvingGroundsInfo) == "function" then
            local okPG, diffID, currWave, maxWave, duration = SafeCall(C_Scenario.GetProvingGroundsInfo)
            if okPG then
                diffID = SafeNumber(diffID, 0) or 0
                currWave = SafeNumber(currWave, 0) or 0
                maxWave = SafeNumber(maxWave, 0) or 0
                duration = SafeNumber(duration, 0) or 0

                if duration > 0 then
                    return "proving_grounds", nil, elapsedTime, diffID, currWave, maxWave, duration
                end
            end
        end
    end

    return nil
end

local function ParseChallengeTimers(...)
    for index = 1, select("#", ...) do
        local timerID = select(index, ...)
        timerID = SafeNumber(timerID, nil)

        if timerID then
            local mode, arg1, arg2, arg3, arg4, arg5, arg6 = ResolveTimerDetails(timerID)

            if mode == "modern_challenge" then
                local mapID = arg1
                local elapsedTime = arg2
                local timeLimit = arg3
                local button = WatchButton:GetKeyed("challengetimer", mapID or timerID)
                SetModernChallengeTimer(button, timerID, elapsedTime, mapID, timeLimit)
                return
            elseif mode == "legacy_challenge" then
                local mapID = arg1
                local elapsedTime = arg2
                local medalTimes = arg3
                local button = WatchButton:GetKeyed("challengetimer", mapID or timerID)
                SetLegacyChallengeTimer(button, timerID, elapsedTime, mapID, medalTimes)
                return
            elseif mode == "proving_grounds" then
                local elapsedTime = arg2
                local diffID = arg3
                local currWave = arg4
                local maxWave = arg5
                local duration = arg6
                local key = "provinggrounds"

                if type(GetInstanceInfo) == "function" then
                    local okInstance, _, _, _, _, _, _, _, mapID = SafeCall(GetInstanceInfo)
                    if okInstance and mapID then
                        key = mapID
                    end
                end

                local button = WatchButton:GetKeyed("provinggrounds", key)
                SetProvingGroundsTimer(button, timerID, elapsedTime, diffID, currWave, maxWave, duration)
                return
            end
        end
    end
end

function QuestKing:UpdateTrackerChallengeTimers()
    if type(GetWorldElapsedTimers) ~= "function" or type(GetWorldElapsedTime) ~= "function" then
        return
    end

    local timers = { GetWorldElapsedTimers() }
    if timers[1] == nil then
        return
    end

    ParseChallengeTimers(unpack(timers))
end
