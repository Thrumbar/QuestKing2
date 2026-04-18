local addonName, QuestKing = ...

local opt = QuestKing.options
local opt_colors = opt.colors
local opt_showCompletedObjectives = opt.showCompletedObjectives

local WatchButton = QuestKing.WatchButton
local getObjectiveColor = QuestKing.GetObjectiveColor

local format = string.format
local raw_tonumber = tonumber
local type = type
local min = math.min
local tinsert = table.insert
local tremove = table.remove
local GetTime = GetTime

local bitlib = bit or bit32
local band = bitlib and bitlib.band or function()
    return 0
end

local C_Scenario = C_Scenario
local C_ScenarioInfo = C_ScenarioInfo
local C_QuestLog = C_QuestLog

local enteringWorldQueue = {}
local mouseHandlerScenario = {}

local IsSecretValue = QuestKing.IsSecretValue or function()
    return false
end

local IsSafeNumber = QuestKing.IsSafeNumber or function(value)
    return type(value) == "number" and not IsSecretValue(value)
end

local SafeNumber = QuestKing.SafeNumber or function(value, fallback)
    if value == nil or IsSecretValue(value) then
        return fallback
    end

    if type(value) == "number" then
        return value
    end

    local ok, numberValue = pcall(raw_tonumber, value)
    if ok and type(numberValue) == "number" and not IsSecretValue(numberValue) then
        return numberValue
    end

    return fallback
end

local SafeBoolean = QuestKing.SafeBoolean or function(value, fallback)
    if value == nil or IsSecretValue(value) then
        return fallback
    end

    return value and true or false
end

local SafeString = QuestKing.SafeString or function(value, fallback)
    if value == nil or IsSecretValue(value) then
        return fallback
    end

    if type(value) == "string" then
        return value
    end

    return fallback
end

local function tonumber(value)
    return SafeNumber(value, nil)
end

-- ---------------------------------------------------------------------
-- Option helpers
-- ---------------------------------------------------------------------

local function IsScenarioTrackerEnabled()
    return opt.enableScenarioTracker ~= false
end

local function ShouldRespectScenarioCriteriaVisibility()
    return opt.respectScenarioCriteriaVisibility ~= false
end

local function ShouldPreferRaidScenarioLabel()
    return opt.preferRaidScenarioLabel ~= false
end

local function ShouldShowScenarioObjectivesInRaids()
    return opt.showScenarioObjectivesInRaids ~= false
end

local function ShouldAllowInstanceScenarioFallback()
    return opt.allowInstanceScenarioFallback ~= false
end

local function ShouldShowScenarioSpellsInTooltip()
    return opt.showScenarioSpellsInTooltip ~= false
end

-- ---------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------

local function SafeGetScenarioInfo()
    if C_ScenarioInfo and C_ScenarioInfo.GetScenarioInfo then
        local info = C_ScenarioInfo.GetScenarioInfo()
        if info then
            return SafeString(info.name, nil),
                SafeNumber(info.currentStage, 0),
                SafeNumber(info.numStages, 0),
                SafeNumber(info.flags, 0),
                SafeBoolean(info.hasBonusStep, false),
                SafeBoolean(info.isBonusStepComplete, false),
                SafeBoolean(info.isComplete, false),
                SafeNumber(info.xp, 0),
                SafeNumber(info.money, 0),
                SafeNumber(info.scenarioType, nil),
                SafeNumber(info.areaID, nil),
                SafeString(info.textureKit, nil),
                SafeNumber(info.scenarioID, nil)
        end
    end

    if C_Scenario and C_Scenario.GetInfo then
        local scenarioName,
            currentStage,
            numStages,
            flags,
            hasBonusStep,
            isBonusStepComplete,
            completed,
            xp,
            money,
            scenarioType,
            areaID,
            textureKit,
            scenarioID = C_Scenario.GetInfo()

        return SafeString(scenarioName, nil),
            SafeNumber(currentStage, 0),
            SafeNumber(numStages, 0),
            SafeNumber(flags, 0),
            SafeBoolean(hasBonusStep, false),
            SafeBoolean(isBonusStepComplete, false),
            SafeBoolean(completed, false),
            SafeNumber(xp, 0),
            SafeNumber(money, 0),
            SafeNumber(scenarioType, nil),
            SafeNumber(areaID, nil),
            SafeString(textureKit, nil),
            SafeNumber(scenarioID, nil)
    end

    return nil, 0, 0, 0, false, false, false, 0, 0, nil, nil, nil, nil
end

local function SafeGetScenarioStepInfo(stepIndex)
    if not stepIndex or stepIndex <= 0 then
        return nil, nil, 0, false, false, false, 0, nil, nil, nil, nil
    end

    if C_ScenarioInfo and C_ScenarioInfo.GetScenarioStepInfo then
        local info = C_ScenarioInfo.GetScenarioStepInfo(stepIndex)
        if info then
            return SafeString(info.title, nil),
                SafeString(info.description, nil),
                SafeNumber(info.numCriteria, 0),
                SafeBoolean(info.stepFailed, false),
                SafeBoolean(info.isBonusStep, false),
                SafeBoolean(info.isForCurrentStepOnly, false),
                (info.spells and #info.spells) or 0,
                info.spells,
                SafeNumber(info.weightedProgress, nil),
                SafeNumber(info.rewardQuestID, nil),
                SafeNumber(info.widgetSetID, nil)
        end
    end

    if C_Scenario and C_Scenario.GetStepInfo then
        local stageName,
            stageDescription,
            numCriteria,
            stepFailed,
            isBonusStep,
            isForCurrentStepOnly,
            _,
            numSpells,
            allSpellInfo,
            weightedProgress,
            rewardQuestID,
            widgetSetID = C_Scenario.GetStepInfo(stepIndex)

        return SafeString(stageName, nil),
            SafeString(stageDescription, nil),
            SafeNumber(numCriteria, 0),
            SafeBoolean(stepFailed, false),
            SafeBoolean(isBonusStep, false),
            SafeBoolean(isForCurrentStepOnly, false),
            SafeNumber(numSpells, 0),
            allSpellInfo,
            SafeNumber(weightedProgress, nil),
            SafeNumber(rewardQuestID, nil),
            SafeNumber(widgetSetID, nil)
    end

    return nil, nil, 0, false, false, false, 0, nil, nil, nil, nil
end

local function GetScenarioInstanceInfo()
    local instanceName,
        instanceType,
        difficultyID,
        difficultyName,
        maxPlayers,
        dynamicDifficulty,
        isDynamic,
        mapID = GetInstanceInfo()

    return instanceName,
        instanceType or "",
        difficultyID,
        difficultyName,
        maxPlayers,
        dynamicDifficulty,
        isDynamic,
        mapID
end

local function GetScenarioFlags(flags, scenarioType)
    flags = flags or 0

    local inChallengeMode = false
    local inProvingGrounds = false
    local dungeonDisplay = false
    local inWarfront = false

    if IsSafeNumber(scenarioType) then
        if LE_SCENARIO_TYPE_CHALLENGE_MODE and scenarioType == LE_SCENARIO_TYPE_CHALLENGE_MODE then
            inChallengeMode = true
        end

        if LE_SCENARIO_TYPE_PROVING_GROUNDS and scenarioType == LE_SCENARIO_TYPE_PROVING_GROUNDS then
            inProvingGrounds = true
        end

        if LE_SCENARIO_TYPE_USE_DUNGEON_DISPLAY and scenarioType == LE_SCENARIO_TYPE_USE_DUNGEON_DISPLAY then
            dungeonDisplay = true
        end

        if LE_SCENARIO_TYPE_WARFRONT and scenarioType == LE_SCENARIO_TYPE_WARFRONT then
            inWarfront = true
        end
    end

    if not inChallengeMode and SCENARIO_FLAG_CHALLENGE_MODE then
        inChallengeMode = band(flags, SCENARIO_FLAG_CHALLENGE_MODE) == SCENARIO_FLAG_CHALLENGE_MODE
    end

    if not inProvingGrounds and SCENARIO_FLAG_PROVING_GROUNDS then
        inProvingGrounds = band(flags, SCENARIO_FLAG_PROVING_GROUNDS) == SCENARIO_FLAG_PROVING_GROUNDS
    end

    if not dungeonDisplay and SCENARIO_FLAG_USE_DUNGEON_DISPLAY then
        dungeonDisplay = band(flags, SCENARIO_FLAG_USE_DUNGEON_DISPLAY) == SCENARIO_FLAG_USE_DUNGEON_DISPLAY
    end

    return inChallengeMode, inProvingGrounds, dungeonDisplay, inWarfront
end

local function IsScenarioStageTextSuppressed(flags)
    if not SCENARIO_FLAG_SUPRESS_STAGE_TEXT then
        return false
    end

    return band(flags or 0, SCENARIO_FLAG_SUPRESS_STAGE_TEXT) == SCENARIO_FLAG_SUPRESS_STAGE_TEXT
end

local function GetScenarioCriteriaInfo(stepIndex, criteriaIndex)
    if C_ScenarioInfo and C_ScenarioInfo.GetCriteriaInfoByStep and stepIndex then
        local info = C_ScenarioInfo.GetCriteriaInfoByStep(stepIndex, criteriaIndex)
        if info then
            return SafeString(info.description, ""),
                info.criteriaType,
                SafeBoolean(info.completed, false),
                SafeNumber(info.quantity, 0),
                SafeNumber(info.totalQuantity, 0),
                SafeNumber(info.flags, nil),
                SafeNumber(info.assetID, nil),
                SafeString(info.quantityString, nil),
                SafeNumber(info.criteriaID, nil),
                SafeNumber(info.duration, 0),
                SafeNumber(info.elapsed, 0),
                SafeBoolean(info.failed, false),
                SafeBoolean(info.isWeightedProgress, false),
                SafeBoolean(info.isFormatted, false)
        end
    end

    if C_ScenarioInfo and C_ScenarioInfo.GetCriteriaInfo then
        local info = C_ScenarioInfo.GetCriteriaInfo(criteriaIndex)
        if info then
            return SafeString(info.description, ""),
                info.criteriaType,
                SafeBoolean(info.completed, false),
                SafeNumber(info.quantity, 0),
                SafeNumber(info.totalQuantity, 0),
                SafeNumber(info.flags, nil),
                SafeNumber(info.assetID, nil),
                SafeString(info.quantityString, nil),
                SafeNumber(info.criteriaID, nil),
                SafeNumber(info.duration, 0),
                SafeNumber(info.elapsed, 0),
                SafeBoolean(info.failed, false),
                SafeBoolean(info.isWeightedProgress, false),
                SafeBoolean(info.isFormatted, false)
        end
    end

    if C_Scenario and C_Scenario.GetCriteriaInfoByStep and stepIndex then
        local criteriaString,
            criteriaType,
            criteriaCompleted,
            quantity,
            totalQuantity,
            flags,
            assetID,
            quantityString,
            criteriaID,
            duration,
            elapsed,
            criteriaFailed,
            isWeightedProgress = C_Scenario.GetCriteriaInfoByStep(stepIndex, criteriaIndex)

        if criteriaString then
            return SafeString(criteriaString, ""),
                criteriaType,
                SafeBoolean(criteriaCompleted, false),
                SafeNumber(quantity, 0),
                SafeNumber(totalQuantity, 0),
                SafeNumber(flags, nil),
                SafeNumber(assetID, nil),
                SafeString(quantityString, nil),
                SafeNumber(criteriaID, nil),
                SafeNumber(duration, 0),
                SafeNumber(elapsed, 0),
                SafeBoolean(criteriaFailed, false),
                SafeBoolean(isWeightedProgress, false),
                false
        end
    end

    if C_Scenario and C_Scenario.GetCriteriaInfo then
        local criteriaString,
            criteriaType,
            criteriaCompleted,
            quantity,
            totalQuantity,
            flags,
            assetID,
            quantityString,
            criteriaID,
            duration,
            elapsed,
            criteriaFailed,
            isWeightedProgress = C_Scenario.GetCriteriaInfo(criteriaIndex)

        if criteriaString then
            return SafeString(criteriaString, ""),
                criteriaType,
                SafeBoolean(criteriaCompleted, false),
                SafeNumber(quantity, 0),
                SafeNumber(totalQuantity, 0),
                SafeNumber(flags, nil),
                SafeNumber(assetID, nil),
                SafeString(quantityString, nil),
                SafeNumber(criteriaID, nil),
                SafeNumber(duration, 0),
                SafeNumber(elapsed, 0),
                SafeBoolean(criteriaFailed, false),
                SafeBoolean(isWeightedProgress, false),
                false
        end
    end

    return nil, nil, false, 0, 0, nil, nil, nil, nil, 0, 0, false, false, false
end

local function GetEffectiveScenarioCriteriaCount(stepIndex, declaredNumCriteria)
    declaredNumCriteria = tonumber(declaredNumCriteria) or 0
    if declaredNumCriteria > 0 then
        return declaredNumCriteria
    end

    for i = 1, 32 do
        local description, _, _, _, _, _, _, _, criteriaID = GetScenarioCriteriaInfo(stepIndex, i)
        if not description and not criteriaID then
            return i - 1
        end
    end

    return 0
end

local function ClampPercent(value)
    value = tonumber(value) or 0
    if value < 0 then
        return 0
    end
    if value > 100 then
        return 100
    end
    return value
end

local function GetCriteriaProgressText(quantity, totalQuantity, quantityString, isFormatted)
    if isFormatted then
        return nil
    end

    if totalQuantity and totalQuantity > 0 then
        return format(": %d/%d", quantity or 0, totalQuantity)
    end

    if quantityString and quantityString ~= "" then
        return ": " .. quantityString
    end

    return nil
end

local function GetCriteriaProgressValue(quantity, totalQuantity, isWeightedProgress)
    quantity = tonumber(quantity) or 0
    totalQuantity = tonumber(totalQuantity) or 0

    if totalQuantity > 0 then
        return min(quantity / totalQuantity, 1)
    end

    if isWeightedProgress and quantity > 0 then
        return min(quantity, 1)
    end

    return 0
end

local function GetScenarioResolvedStage(currentStage)
    currentStage = tonumber(currentStage) or 0
    if currentStage > 0 then
        return currentStage
    end

    local stageName = SafeGetScenarioStepInfo(1)
    if stageName then
        return 1
    end

    return 0
end

local function HasScenarioTrackerData()
    local scenarioName, currentStage, numStages = SafeGetScenarioInfo()
    if not scenarioName or scenarioName == "" then
        return false
    end

    currentStage = tonumber(currentStage) or 0
    numStages = tonumber(numStages) or 0

    if currentStage > 0 or numStages > 0 then
        return true
    end

    if GetScenarioResolvedStage(currentStage) > 0 then
        return true
    end

    if C_Scenario and C_Scenario.GetBonusSteps then
        local bonusSteps = C_Scenario.GetBonusSteps()
        if type(bonusSteps) == "table" and #bonusSteps > 0 then
            return true
        end
    end

    return false
end

function QuestKing:RefreshShouldShowScenarioCriteria()
    if not IsScenarioTrackerEnabled() then
        self.scenarioShouldShowCriteria = false
        return false
    end

    if not ShouldRespectScenarioCriteriaVisibility() then
        self.scenarioShouldShowCriteria = true
        return true
    end

    local shouldShow = true

    if C_Scenario and C_Scenario.ShouldShowCriteria then
        shouldShow = C_Scenario.ShouldShowCriteria() and true or false
    end

    self.scenarioShouldShowCriteria = shouldShow
    return shouldShow
end

function QuestKing:ShouldShowScenarioCriteria()
    if not IsScenarioTrackerEnabled() then
        return false
    end

    if not ShouldRespectScenarioCriteriaVisibility() then
        return true
    end

    if type(self.scenarioShouldShowCriteria) == "boolean" then
        return self.scenarioShouldShowCriteria
    end

    return self:RefreshShouldShowScenarioCriteria()
end

function QuestKing:ShouldShowScenarioTracker()
    if not IsScenarioTrackerEnabled() then
        return false
    end

    if not HasScenarioTrackerData() then
        return false
    end

    local _, instanceType = GetScenarioInstanceInfo()
    local isRaidInstance = instanceType == "raid"

    if isRaidInstance and not ShouldShowScenarioObjectivesInRaids() then
        return false
    end

    if C_Scenario and C_Scenario.IsInScenario and C_Scenario.IsInScenario() then
        return true
    end

    if not ShouldAllowInstanceScenarioFallback() then
        return false
    end

    if instanceType == "party" or instanceType == "scenario" then
        return true
    end

    if isRaidInstance and ShouldShowScenarioObjectivesInRaids() then
        return true
    end

    return false
end

local function GetScenarioDisplayKind(flags, scenarioType)
    local inChallengeMode, inProvingGrounds, dungeonDisplay, inWarfront = GetScenarioFlags(flags, scenarioType)
    local _, instanceType = GetScenarioInstanceInfo()

    if inProvingGrounds then
        return "proving_grounds"
    end

    if inChallengeMode then
        return "challenge_mode"
    end

    if inWarfront then
        return "warfront"
    end

    if instanceType == "raid" and ShouldShowScenarioObjectivesInRaids() and ShouldPreferRaidScenarioLabel() then
        return "raid"
    end

    if dungeonDisplay or instanceType == "party" then
        return "dungeon"
    end

    return "scenario"
end

local function GetScenarioDisplayLabel(displayKind)
    if displayKind == "proving_grounds" then
        return TRACKER_HEADER_PROVINGGROUNDS or "Proving Grounds"
    elseif displayKind == "challenge_mode" then
        return CHALLENGE_MODE or "Challenge Mode"
    elseif displayKind == "warfront" then
        return WARFRONT_LABEL or "Warfront"
    elseif displayKind == "raid" then
        return RAID or "Raid"
    elseif displayKind == "dungeon" then
        return TRACKER_HEADER_DUNGEON or "Dungeon"
    end

    return TRACKER_HEADER_SCENARIO or "Scenario"
end

local function GetScenarioDisplayHeader(currentStage, numStages, displayKind, flags)
    local displayText = GetScenarioDisplayLabel(displayKind)
    currentStage = tonumber(currentStage) or 0
    numStages = tonumber(numStages) or 0

    if IsScenarioStageTextSuppressed(flags) then
        return displayText
    end

    if numStages > 1 and currentStage > 0 then
        if currentStage == numStages then
            return format("%s: Final Stage", displayText)
        end

        return format("%s: Stage %d/%d", displayText, currentStage, numStages)
    end

    return displayText
end

local function GetScenarioCompleteHeader(displayKind)
    if displayKind == "dungeon" and DUNGEON_COMPLETED then
        return DUNGEON_COMPLETED
    end

    return format("%s Complete!", GetScenarioDisplayLabel(displayKind))
end

local function SafePlayScenarioBanner()
    if type(LevelUpDisplay_PlayScenario) ~= "function" then
        return
    end

    if not IsPlayerInWorld() then
        QuestKing:QueuePlayerEnteringWorld(LevelUpDisplay_PlayScenario)
    else
        LevelUpDisplay_PlayScenario()
    end
end

local function PlaySoundCompat(soundKitID, legacyID)
    if not PlaySound then
        return
    end

    if SOUNDKIT and soundKitID then
        PlaySound(soundKitID)
        return
    end

    if legacyID then
        PlaySound(legacyID)
    end
end

local function GetTooltipAnchor()
    return (opt and opt.tooltipAnchor) or "ANCHOR_RIGHT"
end

local function ShouldShowCompletedScenarioObjective(stepFinished)
    if opt_showCompletedObjectives == "always" then
        return true
    end

    if stepFinished then
        return true
    end

    return opt_showCompletedObjectives and true or false
end

local function GetQuestLogIndexByIDCompat(questID)
    if not questID then
        return nil
    end

    if C_QuestLog and C_QuestLog.GetLogIndexForQuestID then
        local index = C_QuestLog.GetLogIndexForQuestID(questID)
        if index and index > 0 then
            return index
        end
    end

    if GetQuestLogIndexByID then
        local index = GetQuestLogIndexByID(questID)
        if index and index > 0 then
            return index
        end
    end

    return nil
end

local function GetScenarioRewardQuestID(stepIndex, rewardQuestIDFromStep)
    rewardQuestIDFromStep = SafeNumber(rewardQuestIDFromStep, nil)
    if rewardQuestIDFromStep and rewardQuestIDFromStep ~= 0 then
        return rewardQuestIDFromStep
    end

    if C_Scenario and C_Scenario.GetBonusStepRewardQuestID and stepIndex then
        local questID = SafeNumber(C_Scenario.GetBonusStepRewardQuestID(stepIndex), nil)
        if questID and questID ~= 0 then
            return questID
        end
    end

    return nil
end

local function AddTooltipRewardText(tooltip, text, r, g, b)
    if tooltip and text and text ~= "" then
        tooltip:AddLine(text, r or 1, g or 1, b or 1)
    end
end

local function AddTooltipMoneyText(tooltip, money)
    money = SafeNumber(money, 0)
    if not tooltip or money <= 0 then
        return
    end

    if GetMoneyString then
        tooltip:AddLine(GetMoneyString(money), 1, 1, 1)
    else
        tooltip:AddLine(format("%d", money), 1, 1, 1)
    end
end

local function AddStageDescriptionFallback(button, stageDescription, stepFinished, stepFailed)
    if not stageDescription or stageDescription == "" then
        return false
    end

    if stepFailed then
        button:AddLine(
            format("  %s", stageDescription),
            nil,
            opt_colors.ObjectiveFailed[1],
            opt_colors.ObjectiveFailed[2],
            opt_colors.ObjectiveFailed[3]
        )
        return true
    end

    if stepFinished then
        if ShouldShowCompletedScenarioObjective(stepFinished) then
            button:AddLine(
                format("  %s", stageDescription),
                nil,
                opt_colors.ObjectiveGradientComplete[1],
                opt_colors.ObjectiveGradientComplete[2],
                opt_colors.ObjectiveGradientComplete[3]
            )
            return true
        end

        return false
    end

    local r, g, b = getObjectiveColor(0)
    button:AddLine(format("  %s", stageDescription), nil, r, g, b)
    return true
end

-- ---------------------------------------------------------------------
-- World entry queue
-- ---------------------------------------------------------------------

function QuestKing:QueuePlayerEnteringWorld(func)
    if type(func) == "function" then
        tinsert(enteringWorldQueue, func)
    end
end

function QuestKing:OnPlayerEnteringWorld()
    local count = #enteringWorldQueue
    for i = 1, count do
        local func = tremove(enteringWorldQueue, 1)
        if type(func) == "function" then
            func()
        end
    end
end

-- ---------------------------------------------------------------------
-- Scenario tracker population
-- ---------------------------------------------------------------------

function QuestKing:UpdateTrackerScenarios()
    if not self:ShouldShowScenarioTracker() then
        return
    end

    local scenarioName,
        currentStage,
        numStages,
        flags,
        hasBonusStep,
        isBonusStepComplete,
        completed,
        xp,
        money,
        scenarioType = SafeGetScenarioInfo()

    local displayKind = GetScenarioDisplayKind(flags, scenarioType)
    local _, _, _, _, _, _, _, mapID = GetScenarioInstanceInfo()
    local stepIndex = GetScenarioResolvedStage(currentStage)

    self:RefreshShouldShowScenarioCriteria()

    if not scenarioName or scenarioName == "" then
        return
    end

    if mapID == 1148 then
        displayKind = "proving_grounds"
    end

    if displayKind == "proving_grounds" and C_Scenario and C_Scenario.GetProvingGroundsInfo then
        local _, _, _, duration = C_Scenario.GetProvingGroundsInfo()
        if duration and duration ~= 0 then
            return
        end
    end

    if stepIndex <= 0 then
        return
    end

    local header = WatchButton:GetKeyed("header", scenarioName)
    header.title:SetText(GetScenarioDisplayHeader(stepIndex, numStages, displayKind, flags))
    header.title:SetTextColor(
        opt_colors.SectionHeader[1],
        opt_colors.SectionHeader[2],
        opt_colors.SectionHeader[3]
    )

    if tonumber(numStages) and numStages > 0 and stepIndex > numStages then
        header.title:SetText(GetScenarioCompleteHeader(displayKind))
        return
    end

    local button = WatchButton:GetKeyed("scenario", scenarioName)
    button.scenarioDisplayKind = displayKind
    QuestKing.SetButtonToScenario(button, stepIndex)
end

function QuestKing.SetButtonToScenario(button, stepIndex)
    button.mouseHandler = mouseHandlerScenario

    local scenarioName,
        currentStage,
        numStages,
        flags,
        hasBonusStep,
        isBonusStepComplete,
        completed,
        xp,
        money,
        scenarioType = SafeGetScenarioInfo()

    local displayKind = GetScenarioDisplayKind(flags, scenarioType)
    local shouldShowCriteria = QuestKing:ShouldShowScenarioCriteria()

    if not stepIndex then
        stepIndex = GetScenarioResolvedStage(currentStage)
    end

    if not stepIndex or stepIndex <= 0 then
        return
    end

    button.stepIndex = stepIndex
    button.scenarioDisplayKind = displayKind

    local lastStepIndex = button._lastStepIndex
    local isNewStep = false
    if lastStepIndex and stepIndex > lastStepIndex and not button.fresh then
        isNewStep = true
    end
    button._lastStepIndex = stepIndex

    local stageName,
        stageDescription,
        declaredNumCriteria,
        stepFailed,
        isBonusStep,
        isForCurrentStepOnly,
        numSpells,
        allSpellInfo,
        weightedProgress,
        rewardQuestID = SafeGetScenarioStepInfo(stepIndex)

    stageName = stageName or scenarioName or GetScenarioDisplayLabel(displayKind)
    stageDescription = stageDescription or ""

    local numCriteria = GetEffectiveScenarioCriteriaCount(stepIndex, declaredNumCriteria)
    local hasWeightedProgress = IsSafeNumber(weightedProgress)
    local weightedPercent = hasWeightedProgress and ClampPercent(weightedProgress) or nil

    local stepFinished = false

    if stepFailed then
        stepFinished = true
    elseif numCriteria > 0 then
        stepFinished = true
        for i = 1, numCriteria do
            local _, _, criteriaCompleted = GetScenarioCriteriaInfo(stepIndex, i)
            if not criteriaCompleted then
                stepFinished = false
                break
            end
        end
    elseif hasWeightedProgress then
        stepFinished = weightedPercent >= 100
    end

    if stepFailed then
        button.title:SetFormattedTextIcon("|TInterface\\RAIDFRAME\\ReadyCheck-NotReady:0:0:1:0|t %s", stageName)
        button.title:SetTextColor(
            opt_colors.ObjectiveFailed[1],
            opt_colors.ObjectiveFailed[2],
            opt_colors.ObjectiveFailed[3]
        )
    elseif stepFinished then
        button.title:SetFormattedTextIcon("|TInterface\\RAIDFRAME\\ReadyCheck-Ready:0:0:1:1|t %s", stageName)
        button.title:SetTextColor(
            opt_colors.ObjectiveComplete[1],
            opt_colors.ObjectiveComplete[2],
            opt_colors.ObjectiveComplete[3]
        )
    else
        button.title:SetText(stageName)
        button.title:SetTextColor(
            opt_colors.ScenarioStageTitle[1],
            opt_colors.ScenarioStageTitle[2],
            opt_colors.ScenarioStageTitle[3]
        )
    end

    local shownLines = 0

    if shouldShowCriteria and hasWeightedProgress then
        local labelText = stageDescription ~= "" and stageDescription or stageName or "Objective"
        local progressValue = weightedPercent / 100
        local colorValue = stepFinished and 1 or progressValue
        local r, g, b = getObjectiveColor(colorValue)

        button:AddLine(format("  %s", labelText), nil, r, g, b)
        shownLines = shownLines + 1

        local progressBar = button:AddProgressBar()
        progressBar:SetPercent(weightedPercent)
    elseif shouldShowCriteria and numCriteria > 0 then
        for i = 1, numCriteria do
            local criteriaString,
                criteriaType,
                criteriaCompleted,
                quantity,
                totalQuantity,
                criteriaFlags,
                assetID,
                quantityString,
                criteriaID,
                duration,
                elapsed,
                criteriaFailed,
                isWeightedProgress,
                isFormatted = GetScenarioCriteriaInfo(stepIndex, i)

            criteriaString = (criteriaString and criteriaString ~= "") and criteriaString or "Objective"

            local line
            local progressText = GetCriteriaProgressText(quantity, totalQuantity, quantityString, isFormatted)
            local progressValue = GetCriteriaProgressValue(quantity, totalQuantity, isWeightedProgress)

            if criteriaCompleted then
                if ShouldShowCompletedScenarioObjective(stepFinished) then
                    line = button:AddLine(
                        format("  %s", criteriaString),
                        progressText,
                        opt_colors.ObjectiveGradientComplete[1],
                        opt_colors.ObjectiveGradientComplete[2],
                        opt_colors.ObjectiveGradientComplete[3]
                    )
                end
            elseif criteriaFailed then
                line = button:AddLineIcon(
                    format("  |TInterface\\RAIDFRAME\\ReadyCheck-NotReady:0|t %s", criteriaString),
                    progressText,
                    opt_colors.ObjectiveFailed[1],
                    opt_colors.ObjectiveFailed[2],
                    opt_colors.ObjectiveFailed[3]
                )
            else
                local r, g, b = getObjectiveColor(progressValue)
                line = button:AddLine(
                    format("  %s", criteriaString),
                    progressText,
                    r, g, b
                )
            end

            if line then
                shownLines = shownLines + 1

                local lastQuant = SafeNumber(line._lastQuant, nil)
                if lastQuant and IsSafeNumber(quantity) and quantity > lastQuant and not isNewStep then
                    line:Flash()
                end
                line._lastQuant = IsSafeNumber(quantity) and quantity or nil
            end

            if IsSafeNumber(duration) and IsSafeNumber(elapsed) and duration > 0 and elapsed < duration then
                local timerBar = button:AddTimerBar(duration, GetTime() - elapsed)
                timerBar:SetStatusBarColor(
                    opt_colors.ScenarioTimer[1],
                    opt_colors.ScenarioTimer[2],
                    opt_colors.ScenarioTimer[3]
                )
            end
        end
    end

    if shownLines == 0 then
        if AddStageDescriptionFallback(button, stageDescription, stepFinished, stepFailed) then
            shownLines = shownLines + 1
        end
    end

    if shownLines == 0 and stepFinished and ShouldShowCompletedScenarioObjective(stepFinished) then
        button:AddLine(
            format("  %s", COMPLETE or "Complete"),
            nil,
            opt_colors.ObjectiveGradientComplete[1],
            opt_colors.ObjectiveGradientComplete[2],
            opt_colors.ObjectiveGradientComplete[3]
        )
    end

    if shownLines == 0 and not stepFinished and not shouldShowCriteria then
        button:AddLine(
            format("  %s", stageDescription ~= "" and stageDescription or stageName),
            nil,
            opt_colors.ScenarioStageTitle[1],
            opt_colors.ScenarioStageTitle[2],
            opt_colors.ScenarioStageTitle[3]
        )
    end

    if isNewStep or button.fresh then
        local lines = button.lines
        for i = 1, #lines do
            if i <= button.currentLine then
                lines[i]:Glow(0.1, 0.7, 0.4)
            end
        end
    end
end

function QuestKing:OnScenarioCompleted(xp, money)
    xp = xp or 0
    money = money or 0

    if xp > 0 or money > 0 then
        local button = nil
        local scenarioName = SafeGetScenarioInfo()
        if scenarioName then
            button = WatchButton:GetKeyedRaw("header", scenarioName)
        end
        QuestKing:AddReward(button, nil, xp, money)
    end
end

function QuestKing:OnScenarioUpdate(newStage)
    local _, currentStage, numStages, flags, _, _, _, _, _, scenarioType = SafeGetScenarioInfo()
    local inChallengeMode = GetScenarioFlags(flags, scenarioType)

    self:RefreshShouldShowScenarioCriteria()

    if newStage then
        if not inChallengeMode then
            if currentStage <= numStages then
                PlaySoundCompat(SOUNDKIT and SOUNDKIT.UI_SCENARIO_STAGE_END, "UI_Scenario_Stage_End")
            end

            if currentStage > 0 then
                SafePlayScenarioBanner()
            end
        end
    end

    QuestKing:UpdateTracker()
end

-- ---------------------------------------------------------------------
-- Mouse handlers
-- ---------------------------------------------------------------------

function mouseHandlerScenario:TitleButtonOnClick(mouse, down)
    local button = self.parent
    local stepIndex = button.stepIndex

    if mouse == "RightButton" then
        return
    end

    if not stepIndex or stepIndex <= 0 then
        return
    end

    local _, _, _, _, _, _, _, _, _, rewardQuestIDFromStep = SafeGetScenarioStepInfo(stepIndex)
    local rewardQuestID = GetScenarioRewardQuestID(stepIndex, rewardQuestIDFromStep)
    local rewardQuestLogIndex = rewardQuestID and GetQuestLogIndexByIDCompat(rewardQuestID) or nil

    if rewardQuestID and QuestMapFrame_OpenToQuestDetails then
        QuestMapFrame_OpenToQuestDetails(rewardQuestID)
        return
    end

    if rewardQuestLogIndex and QuestObjectiveTracker_OpenQuestMap then
        QuestObjectiveTracker_OpenQuestMap(nil, rewardQuestLogIndex)
    end
end

function mouseHandlerScenario:TitleButtonOnEnter(motion)
    local button = self.parent
    local stepIndex = button.stepIndex

    local scenarioName,
        currentStage,
        numStages,
        flags,
        hasBonusStep,
        isBonusStepComplete,
        completed,
        xp,
        money,
        scenarioType = SafeGetScenarioInfo()

    local stageName,
        stageDescription,
        declaredNumCriteria,
        stepFailed,
        isBonusStep,
        isForCurrentStepOnly,
        numSpells,
        allSpellInfo,
        weightedProgress,
        rewardQuestIDFromStep = SafeGetScenarioStepInfo(stepIndex)

    local numCriteria = GetEffectiveScenarioCriteriaCount(stepIndex, declaredNumCriteria)
    local displayKind = button.scenarioDisplayKind or GetScenarioDisplayKind(flags, scenarioType)
    local displayLabel = GetScenarioDisplayLabel(displayKind)
    local tooltip = QuestKing.PrepareTooltip and QuestKing:PrepareTooltip(self, GetTooltipAnchor())

    if not scenarioName or not tooltip then
        return
    end

    tooltip:AddLine(scenarioName, NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, 1)
    tooltip:AddLine(
        stageName or displayLabel,
        opt_colors.ScenarioStageTitle[1],
        opt_colors.ScenarioStageTitle[2],
        opt_colors.ScenarioStageTitle[3],
        1
    )

    if isBonusStep then
        tooltip:AddLine("Bonus Objective", 1, 0.914, 0.682, 1)
    elseif tonumber(numStages) and numStages > 1 and tonumber(currentStage) and currentStage > 0 and not IsScenarioStageTextSuppressed(flags) then
        tooltip:AddLine(format("%s - Stage %d/%d", displayLabel, currentStage, numStages), 1, 0.914, 0.682, 1)
    else
        tooltip:AddLine(displayLabel, 1, 0.914, 0.682, 1)
    end

    tooltip:AddLine(" ")

    if stageDescription and stageDescription ~= "" then
        tooltip:AddLine(stageDescription, 1, 1, 1, 1)
    end

    if IsSafeNumber(weightedProgress) then
        tooltip:AddLine(" ")
        tooltip:AddLine(format("Progress: %d%%", ClampPercent(weightedProgress)), 1, 1, 1, 1)
    end

    if QuestKing:ShouldShowScenarioCriteria() and numCriteria > 0 then
        tooltip:AddLine(" ")
        tooltip:AddLine(QUEST_TOOLTIP_REQUIREMENTS, NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, 1)

        for i = 1, numCriteria do
            local criteriaString,
                criteriaType,
                criteriaCompleted,
                quantity,
                totalQuantity,
                criteriaFlags,
                assetID,
                quantityString,
                criteriaID,
                duration,
                elapsed,
                criteriaFailed = GetScenarioCriteriaInfo(stepIndex, i)

            criteriaString = (criteriaString and criteriaString ~= "") and criteriaString or "Objective"

            if criteriaCompleted then
                if totalQuantity and totalQuantity > 0 then
                    tooltip:AddLine(
                        format("- %s: %d/%d |cff808080(%s)|r", criteriaString, quantity or 0, totalQuantity, COMPLETE),
                        0.2, 0.9, 0.2
                    )
                elseif quantityString and quantityString ~= "" then
                    tooltip:AddLine(
                        format("- %s: %s |cff808080(%s)|r", criteriaString, quantityString, COMPLETE),
                        0.2, 0.9, 0.2
                    )
                else
                    tooltip:AddLine(
                        format("- %s |cff808080(%s)|r", criteriaString, COMPLETE),
                        0.2, 0.9, 0.2
                    )
                end
            elseif criteriaFailed then
                if totalQuantity and totalQuantity > 0 then
                    tooltip:AddLine(
                        format("- %s: %d/%d |cff808080(%s)|r", criteriaString, quantity or 0, totalQuantity, FAILED),
                        1, 0.2, 0.2
                    )
                elseif quantityString and quantityString ~= "" then
                    tooltip:AddLine(
                        format("- %s: %s |cff808080(%s)|r", criteriaString, quantityString, FAILED),
                        1, 0.2, 0.2
                    )
                else
                    tooltip:AddLine(
                        format("- %s |cff808080(%s)|r", criteriaString, FAILED),
                        1, 0.2, 0.2
                    )
                end
            else
                if totalQuantity and totalQuantity > 0 then
                    tooltip:AddLine(
                        format("- %s: %d/%d", criteriaString, quantity or 0, totalQuantity),
                        1, 1, 1
                    )
                elseif quantityString and quantityString ~= "" then
                    tooltip:AddLine(
                        format("- %s: %s", criteriaString, quantityString),
                        1, 1, 1
                    )
                else
                    tooltip:AddLine(
                        format("- %s", criteriaString),
                        1, 1, 1
                    )
                end
            end
        end
    end

    if ShouldShowScenarioSpellsInTooltip() and allSpellInfo and #allSpellInfo > 0 then
        tooltip:AddLine(" ")
        for i = 1, #allSpellInfo do
            local spellInfo = allSpellInfo[i]
            if spellInfo and spellInfo.spellName then
                tooltip:AddLine(format("Spell: %s", spellInfo.spellName), 0.8, 0.9, 1)
            end
        end
    end

    local blankLine = false
    local rewardQuestID = GetScenarioRewardQuestID(stepIndex, rewardQuestIDFromStep)
    local rewardQuestLogIndex = rewardQuestID and GetQuestLogIndexByIDCompat(rewardQuestID) or nil

    if rewardQuestLogIndex then
        local rewardXP = GetQuestLogRewardXP and (GetQuestLogRewardXP(rewardQuestLogIndex) or 0) or 0
        if rewardXP > 0 then
            tooltip:AddLine(" ")
            blankLine = true
            AddTooltipRewardText(tooltip, format(BONUS_OBJECTIVE_EXPERIENCE_FORMAT, rewardXP), 1, 1, 1)
        end

        local numQuestCurrencies = GetNumQuestLogRewardCurrencies and (GetNumQuestLogRewardCurrencies(rewardQuestLogIndex) or 0) or 0
        for i = 1, numQuestCurrencies do
            local name, texture, numItems = GetQuestLogRewardCurrencyInfo(i, rewardQuestLogIndex)
            if name and texture and numItems then
                local text = format(BONUS_OBJECTIVE_REWARD_WITH_COUNT_FORMAT, texture, numItems, name)
                if not blankLine then
                    tooltip:AddLine(" ")
                    blankLine = true
                end
                AddTooltipRewardText(tooltip, text, 1, 1, 1)
            end
        end

        local numQuestRewards = GetNumQuestLogRewards and (GetNumQuestLogRewards(rewardQuestLogIndex) or 0) or 0
        for i = 1, numQuestRewards do
            local name, texture, numItems, quality = GetQuestLogRewardInfo(i, rewardQuestLogIndex)
            local text

            if numItems and numItems > 1 and texture and name then
                text = format(BONUS_OBJECTIVE_REWARD_WITH_COUNT_FORMAT, texture, numItems, name)
            elseif texture and name then
                text = format(BONUS_OBJECTIVE_REWARD_FORMAT, texture, name)
            end

            if text then
                local color = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality or 1] or NORMAL_FONT_COLOR
                if not blankLine then
                    tooltip:AddLine(" ")
                    blankLine = true
                end
                AddTooltipRewardText(tooltip, text, color.r, color.g, color.b)
            end
        end

        local rewardMoney = GetQuestLogRewardMoney and (GetQuestLogRewardMoney(rewardQuestLogIndex) or 0) or 0
        if rewardMoney > 0 then
            if not blankLine then
                tooltip:AddLine(" ")
                blankLine = true
            end
            AddTooltipMoneyText(tooltip, rewardMoney)
        end
    else
        if xp and xp > 0 then
            if not blankLine then
                tooltip:AddLine(" ")
                blankLine = true
            end
            AddTooltipRewardText(tooltip, format(BONUS_OBJECTIVE_EXPERIENCE_FORMAT, xp), 1, 1, 1)
        end

        if money and money > 0 then
            if not blankLine then
                tooltip:AddLine(" ")
                blankLine = true
            end
            AddTooltipMoneyText(tooltip, money)
        end
    end

    tooltip:Show()
end