local addonName, QuestKing = ...

local Compat = QuestKing.Compatibility and QuestKing.Compatibility.Common or {}

local opt = QuestKing.options
local opt_colors = opt.colors

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
local C_QuestInfoSystem = C_QuestInfoSystem

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

local function SafeGetLegacyScenarioInfo()
    if not (C_Scenario and C_Scenario.GetInfo) then
        return nil
    end

    local ok,
        scenarioName,
        currentStage,
        numStages,
        flags,
        legacyHasBonusStep,
        legacyIsBonusStepComplete,
        completed,
        xp,
        money,
        scenarioType,
        areaName,
        textureKit,
        scenarioID = pcall(C_Scenario.GetInfo)

    if not ok then
        return nil
    end

    return scenarioName,
        currentStage,
        numStages,
        flags,
        completed,
        xp,
        money,
        scenarioType,
        areaName,
        textureKit,
        scenarioID
end

local function SafeGetScenarioInfo()
    if C_ScenarioInfo and C_ScenarioInfo.GetScenarioInfo then
        local ok, info = pcall(C_ScenarioInfo.GetScenarioInfo)
        if ok and type(info) == "table" then
            local scenarioName = SafeString(info.name, nil)
            if scenarioName and scenarioName ~= "" then
                return scenarioName,
                    SafeNumber(info.currentStage, 0),
                    SafeNumber(info.numStages, 0),
                    SafeNumber(info.flags, 0),
                    SafeBoolean(info.isComplete, false),
                    SafeNumber(info.xp, 0),
                    SafeNumber(info.money, 0),
                    SafeNumber(info.type, nil),
                    SafeString(info.area, nil),
                    SafeString(info.uiTextureKit, nil),
                    SafeNumber(info.scenarioID, nil)
            end
        end
    end

    local scenarioName,
        currentStage,
        numStages,
        flags,
        completed,
        xp,
        money,
        scenarioType,
        areaName,
        textureKit,
        scenarioID = SafeGetLegacyScenarioInfo()

    if scenarioName ~= nil then
        return SafeString(scenarioName, nil),
            SafeNumber(currentStage, 0),
            SafeNumber(numStages, 0),
            SafeNumber(flags, 0),
            SafeBoolean(completed, false),
            SafeNumber(xp, 0),
            SafeNumber(money, 0),
            SafeNumber(scenarioType, nil),
            SafeString(areaName, nil),
            SafeString(textureKit, nil),
            SafeNumber(scenarioID, nil)
    end

    return nil, 0, 0, 0, false, 0, 0, nil, nil, nil, nil
end

local function SafeGetScenarioStepInfo(stepID, useCurrentStep)
    if not useCurrentStep and (not stepID or stepID <= 0) then
        return nil, nil, 0, false, false, false, nil, nil, nil, nil, nil, nil
    end

    if C_ScenarioInfo and C_ScenarioInfo.GetScenarioStepInfo then
        local ok, info
        if useCurrentStep then
            ok, info = pcall(C_ScenarioInfo.GetScenarioStepInfo)
        else
            ok, info = pcall(C_ScenarioInfo.GetScenarioStepInfo, stepID)
        end

        if ok and type(info) == "table" then
            return SafeString(info.title, nil),
                SafeString(info.description, nil),
                SafeNumber(info.numCriteria, 0),
                SafeBoolean(info.stepFailed, false),
                SafeBoolean(info.isBonusStep, false),
                SafeBoolean(info.isForCurrentStepOnly, false),
                SafeBoolean(info.shouldShowBonusObjective, nil),
                type(info.spells) == "table" and info.spells or nil,
                SafeNumber(info.weightedProgress, nil),
                SafeNumber(info.rewardQuestID, nil),
                SafeNumber(info.widgetSetID, nil),
                SafeNumber(info.stepID, nil)
        end
    end

    if C_Scenario and C_Scenario.GetStepInfo then
        local ok,
            stageName,
            stageDescription,
            numCriteria,
            stepFailed,
            isBonusStep,
            isForCurrentStepOnly,
            shouldShowBonusObjective,
            _,
            allSpellInfo,
            weightedProgress,
            rewardQuestID,
            widgetSetID

        if useCurrentStep then
            ok,
                stageName,
                stageDescription,
                numCriteria,
                stepFailed,
                isBonusStep,
                isForCurrentStepOnly,
                shouldShowBonusObjective,
                _,
                allSpellInfo,
                weightedProgress,
                rewardQuestID,
                widgetSetID = pcall(C_Scenario.GetStepInfo)
        else
            ok,
                stageName,
                stageDescription,
                numCriteria,
                stepFailed,
                isBonusStep,
                isForCurrentStepOnly,
                shouldShowBonusObjective,
                _,
                allSpellInfo,
                weightedProgress,
                rewardQuestID,
                widgetSetID = pcall(C_Scenario.GetStepInfo, stepID)
        end

        if not ok then
            return nil, nil, 0, false, false, false, nil, nil, nil, nil, nil, nil
        end

        return SafeString(stageName, nil),
            SafeString(stageDescription, nil),
            SafeNumber(numCriteria, 0),
            SafeBoolean(stepFailed, false),
            SafeBoolean(isBonusStep, false),
            SafeBoolean(isForCurrentStepOnly, false),
            SafeBoolean(shouldShowBonusObjective, nil),
            allSpellInfo,
            SafeNumber(weightedProgress, nil),
            SafeNumber(rewardQuestID, nil),
            SafeNumber(widgetSetID, nil),
            useCurrentStep and nil or SafeNumber(stepID, nil)
    end

    return nil, nil, 0, false, false, false, nil, nil, nil, nil, nil, nil
end

QuestKing.GetScenarioStepInfo = SafeGetScenarioStepInfo

local function SafeGetLegacyBonusStepInfo()
    if not (C_Scenario and C_Scenario.GetBonusStepInfo) then
        return nil, nil, 0, false, true, false, true, nil, nil, nil, nil, nil
    end

    local ok,
        title,
        description,
        numCriteria,
        stepFailed = pcall(C_Scenario.GetBonusStepInfo)

    if not ok then
        return nil, nil, 0, false, true, false, true, nil, nil, nil, nil, nil
    end

    local bonusTitle = SafeString(title, nil)
    if not bonusTitle or bonusTitle == "" then
        bonusTitle = SCENARIO_BONUS_OBJECTIVES or "Bonus Objectives"
    end

    return bonusTitle,
        SafeString(description, nil),
        SafeNumber(numCriteria, 0),
        SafeBoolean(stepFailed, false),
        true,
        false,
        true,
        nil,
        nil,
        nil,
        nil,
        nil
end

local function GetLegacyBonusCriteriaInfo(criteriaIndex)
    if not (C_Scenario and C_Scenario.GetBonusCriteriaInfo) then
        return nil, nil, false, 0, 0, nil, nil, nil, nil, 0, 0, false, false, false
    end

    local ok,
        criteriaString,
        criteriaType,
        criteriaCompleted,
        quantity,
        totalQuantity,
        flags,
        assetID,
        quantityString,
        criteriaID,
        timeLeft,
        criteriaFailed = pcall(C_Scenario.GetBonusCriteriaInfo, criteriaIndex)

    if not ok or not criteriaString then
        return nil, nil, false, 0, 0, nil, nil, nil, nil, 0, 0, false, false, false
    end

    return SafeString(criteriaString, ""),
        criteriaType,
        SafeBoolean(criteriaCompleted, false),
        SafeNumber(quantity, 0),
        SafeNumber(totalQuantity, 0),
        SafeNumber(flags, nil),
        SafeNumber(assetID, nil),
        SafeString(quantityString, nil),
        SafeNumber(criteriaID, nil),
        SafeNumber(timeLeft, 0),
        0,
        SafeBoolean(criteriaFailed, false),
        false,
        false
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

local function GetScenarioCriteriaInfo(stepID, criteriaIndex, useCurrentStep)
    if not useCurrentStep and (not stepID or stepID <= 0) then
        return nil, nil, false, 0, 0, nil, nil, nil, nil, 0, 0, false, false, false
    end

    if C_ScenarioInfo then
        local ok, info
        if useCurrentStep and C_ScenarioInfo.GetCriteriaInfo then
            ok, info = pcall(C_ScenarioInfo.GetCriteriaInfo, criteriaIndex)
        elseif not useCurrentStep and C_ScenarioInfo.GetCriteriaInfoByStep then
            ok, info = pcall(
                C_ScenarioInfo.GetCriteriaInfoByStep,
                stepID,
                criteriaIndex
            )
        end

        if ok and type(info) == "table" then
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

    if C_Scenario then
        local ok,
            criteriaString,
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
            isWeightedProgress

        if useCurrentStep and C_Scenario.GetCriteriaInfo then
            ok,
                criteriaString,
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
                isWeightedProgress = pcall(
                    C_Scenario.GetCriteriaInfo,
                    criteriaIndex
                )
        elseif not useCurrentStep and C_Scenario.GetCriteriaInfoByStep then
            ok,
                criteriaString,
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
                isWeightedProgress = pcall(
                    C_Scenario.GetCriteriaInfoByStep,
                    stepID,
                    criteriaIndex
                )
        end

        if ok and criteriaString then
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

QuestKing.GetScenarioCriteriaInfo = GetScenarioCriteriaInfo

local function GetScenarioButtonCriteriaInfo(
    useLegacyBonusStep,
    stepID,
    criteriaIndex,
    useCurrentStep
)
    if useLegacyBonusStep then
        return GetLegacyBonusCriteriaInfo(criteriaIndex)
    end

    return GetScenarioCriteriaInfo(stepID, criteriaIndex, useCurrentStep)
end

local function GetEffectiveScenarioCriteriaCount(stepID, declaredNumCriteria, useCurrentStep)
    declaredNumCriteria = tonumber(declaredNumCriteria) or 0
    if declaredNumCriteria < 0 then
        return 0
    end

    -- ScenarioStepInfo.numCriteria is authoritative, including zero.
    return declaredNumCriteria
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

local function GetCriteriaDisplayText(
    criteriaString,
    quantity,
    totalQuantity,
    quantityString,
    isWeightedProgress,
    isFormatted
)
    if isFormatted or isWeightedProgress then
        return criteriaString
    end

    if totalQuantity and totalQuantity > 0 then
        return format("%d/%d %s", quantity or 0, totalQuantity, criteriaString)
    end

    if quantityString and quantityString ~= "" then
        return format("%s %s", quantityString, criteriaString)
    end

    return criteriaString
end

local function GetCriteriaProgressValue(quantity, totalQuantity, isWeightedProgress)
    quantity = tonumber(quantity) or 0
    totalQuantity = tonumber(totalQuantity) or 0

    if isWeightedProgress then
        return ClampPercent(quantity) / 100
    end

    if totalQuantity > 0 then
        return min(quantity / totalQuantity, 1)
    end

    return 0
end

local function GetScenarioResolvedStage(currentStage)
    currentStage = tonumber(currentStage) or 0
    if currentStage > 0 then
        return currentStage
    end

    local stageName = SafeGetScenarioStepInfo(nil, true)
    if stageName then
        return 1
    end

    return 0
end

local function HasScenarioTrackerData()
    local scenarioName, currentStage, numStages, _, completed =
        SafeGetScenarioInfo()
    if not scenarioName or scenarioName == "" then
        return false
    end

    currentStage = tonumber(currentStage) or 0
    numStages = tonumber(numStages) or 0

    if completed then
        return true
    end

    if currentStage > 0 or numStages > 0 then
        return true
    end

    if GetScenarioResolvedStage(currentStage) > 0 then
        return true
    end

    if C_Scenario and C_Scenario.GetBonusSteps then
        local ok, bonusSteps = pcall(C_Scenario.GetBonusSteps)
        if ok and type(bonusSteps) == "table" and #bonusSteps > 0 then
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
        local ok, result = pcall(C_Scenario.ShouldShowCriteria)
        if ok then
            shouldShow = result and true or false
        end
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

    if C_Scenario and C_Scenario.IsInScenario then
        local ok, inScenario = pcall(C_Scenario.IsInScenario)
        if ok and inScenario then
            return true
        end
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
    if QuestKing.ShouldShowCompletedObjective then
        return QuestKing.ShouldShowCompletedObjective(stepFinished)
    end

    local mode = opt.showCompletedObjectives
    if mode == "always" then
        return true
    end

    return not stepFinished and mode == true
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

local function GetScenarioRewardQuestID(stepID, rewardQuestIDFromStep, isBonusStep)
    rewardQuestIDFromStep = SafeNumber(rewardQuestIDFromStep, nil)
    if rewardQuestIDFromStep and rewardQuestIDFromStep ~= 0 then
        return rewardQuestIDFromStep
    end

    if isBonusStep and C_Scenario and C_Scenario.GetBonusStepRewardQuestID and stepID then
        local ok, rewardQuestID = pcall(
            C_Scenario.GetBonusStepRewardQuestID,
            stepID
        )
        if ok then
            local questID = SafeNumber(rewardQuestID, nil)
            if questID and questID ~= 0 then
                return questID
            end
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

local function AddLegacyBonusRewardsToTooltip(tooltip)
    if not tooltip
        or type(GetPartyLFGID) ~= "function"
        or type(GetLFGDungeonRewards) ~= "function"
        or type(GetLFGDungeonRewardInfo) ~= "function" then
        return false
    end

    local okParty, dungeonID, randomID = pcall(GetPartyLFGID)
    if not okParty then
        return false
    end

    if randomID then
        dungeonID = randomID
    end

    dungeonID = SafeNumber(dungeonID, nil)
    if not dungeonID then
        return false
    end

    local okRewards, _, _, _, _, _, numRewards =
        pcall(GetLFGDungeonRewards, dungeonID)
    if not okRewards then
        return false
    end

    numRewards = SafeNumber(numRewards, 0) or 0
    local addedReward = false

    for i = 1, numRewards do
        local okReward,
            name,
            texturePath,
            quantity,
            isBonusCurrency =
            pcall(GetLFGDungeonRewardInfo, dungeonID, i)

        if okReward and isBonusCurrency and name then
            if not addedReward then
                tooltip:AddLine(" ")
                tooltip:AddLine(
                    SCENARIO_BONUS_REWARD or "Bonus Reward",
                    1,
                    0.831,
                    0.380
                )
                addedReward = true
            end

            quantity = SafeNumber(quantity, 0) or 0
            local rewardText
            if SCENARIO_BONUS_CURRENCY_FORMAT then
                rewardText = format(
                    SCENARIO_BONUS_CURRENCY_FORMAT,
                    quantity,
                    name
                )
            else
                rewardText = format("%d %s", quantity, name)
            end

            tooltip:AddLine(rewardText, 1, 1, 1)
            if texturePath and type(tooltip.AddTexture) == "function" then
                tooltip:AddTexture(texturePath)
            end
        end
    end

    return addedReward
end


local function GetRewardCurrencyTable(questID)
    questID = SafeNumber(questID, nil)
    if not questID or questID <= 0 then
        return nil
    end

    if C_QuestLog and type(C_QuestLog.GetQuestRewardCurrencies) == "function" then
        local ok, data = pcall(C_QuestLog.GetQuestRewardCurrencies, questID)
        if ok and type(data) == "table" then
            return data
        end
    end

    if C_QuestInfoSystem and type(C_QuestInfoSystem.GetQuestRewardCurrencies) == "function" then
        local ok, data = pcall(C_QuestInfoSystem.GetQuestRewardCurrencies, questID)
        if ok and type(data) == "table" then
            return data
        end
    end

    return nil
end

local function GetNumRewardCurrenciesCompat(questID)
    local rewards = GetRewardCurrencyTable(questID)
    if rewards then
        return #rewards
    end

    if type(GetNumQuestLogRewardCurrencies) == "function" then
        return SafeNumber(GetNumQuestLogRewardCurrencies(questID), 0) or 0
    end

    return 0
end

local function GetRewardCurrencyInfoCompat(index, questID)
    local rewards = GetRewardCurrencyTable(questID)
    local reward = rewards and rewards[index]
    if type(reward) == "table" then
        return SafeString(reward.name, nil),
            SafeNumber(reward.texture, nil),
            SafeNumber(reward.totalRewardAmount, nil)
                or SafeNumber(reward.numItems, nil)
                or SafeNumber(reward.quantity, nil)
                or SafeNumber(reward.baseRewardAmount, 0)
                or 0,
            SafeNumber(reward.quality, nil)
                or SafeNumber(reward.rarity, nil)
    end

    if C_QuestLog and type(C_QuestLog.GetQuestRewardCurrencyInfo) == "function" then
        local ok, info = pcall(C_QuestLog.GetQuestRewardCurrencyInfo, questID, index, false)
        if ok and type(info) == "table" then
            return SafeString(info.name, nil),
                SafeNumber(info.texture, nil),
                SafeNumber(info.totalRewardAmount, nil)
                    or SafeNumber(info.numItems, nil)
                    or SafeNumber(info.quantity, nil)
                    or SafeNumber(info.baseRewardAmount, 0)
                    or 0,
                SafeNumber(info.quality, nil)
                    or SafeNumber(info.rarity, nil)
        end
    end

    if type(GetQuestLogRewardCurrencyInfo) == "function" then
        return GetQuestLogRewardCurrencyInfo(index, questID)
    end

    return nil, nil, nil, nil
end

local function GetQuestRewardXPCompat(questID)
    if type(GetQuestLogRewardXP) == "function" then
        return SafeNumber(GetQuestLogRewardXP(questID), 0) or 0
    end

    return 0
end

local function IsPlayerAtEffectiveMaxLevelCompat()
    if GameRulesUtil and type(GameRulesUtil.IsPlayerAtEffectiveMaxLevel) == "function" then
        local ok, atMax = pcall(GameRulesUtil.IsPlayerAtEffectiveMaxLevel)
        if ok then
            return atMax and true or false
        end
    end

    if type(IsPlayerAtEffectiveMaxLevel) == "function" then
        local ok, atMax = pcall(IsPlayerAtEffectiveMaxLevel)
        if ok then
            return atMax and true or false
        end
    end

    return false
end

local function GetNumQuestRewardsCompat(questID)
    if type(GetNumQuestLogRewards) == "function" then
        return SafeNumber(GetNumQuestLogRewards(questID), 0) or 0
    end

    return 0
end

local function GetQuestRewardInfoCompat(index, questID)
    if type(GetQuestLogRewardInfo) == "function" then
        return GetQuestLogRewardInfo(index, questID)
    end

    return nil, nil, nil, nil
end

local function GetQuestRewardMoneyCompat(questID)
    if type(GetQuestLogRewardMoney) == "function" then
        return SafeNumber(GetQuestLogRewardMoney(questID), 0) or 0
    end

    return 0
end

local function FreeScenarioLineBars(line)
    if not line then
        return
    end

    if line.timerBar then
        line.timerBar:Free()
    end

    if line.progressBar then
        line.progressBar:Free()
    end
end

local function AddScenarioTextLine(button, text, rightText, r, g, b, useIcon)
    local line
    if useIcon then
        line = button:AddLineIcon(text, rightText, r, g, b)
    else
        line = button:AddLine(text, rightText, r, g, b)
    end

    FreeScenarioLineBars(line)
    return line
end

local function AddScenarioProgressBar(button, progressKey)
    local progressBar = button:AddProgressBar(progressKey)
    local line = progressBar and progressBar.baseLine
    if line and line.timerBar then
        line.timerBar:Free()
    end
    return progressBar
end

local function AddScenarioTimerBar(button, duration, startTime)
    local timerBar = button:AddTimerBar(duration, startTime)
    local line = timerBar and timerBar.baseLine
    if line and line.progressBar then
        line.progressBar:Free()
    end
    return timerBar
end

local function AddStageDescriptionFallback(button, stageDescription, stepFinished, stepFailed)
    if not stageDescription or stageDescription == "" then
        return false
    end

    if stepFailed then
        AddScenarioTextLine(
            button,
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
            AddScenarioTextLine(
                button,
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
    AddScenarioTextLine(button, format("  %s", stageDescription), nil, r, g, b)
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

function QuestKing:UpdateTrackerScenarios(knownShown)
    if not knownShown and not self:ShouldShowScenarioTracker() then
        return
    end

    local scenarioName,
        currentStage,
        numStages,
        flags,
        completed,
        xp,
        money,
        scenarioType,
        areaName,
        textureKit,
        scenarioID = SafeGetScenarioInfo()

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
        local ok, _, _, _, duration = pcall(C_Scenario.GetProvingGroundsInfo)
        if ok and duration and duration ~= 0 then
            return
        end
    end

    if not completed and stepIndex <= 0 then
        return
    end

    local header = WatchButton:GetKeyed("header", scenarioName)
    header.title:SetTextColor(
        opt_colors.SectionHeader[1],
        opt_colors.SectionHeader[2],
        opt_colors.SectionHeader[3]
    )

    local scenarioComplete = completed
        or (tonumber(numStages) and numStages > 0 and stepIndex > numStages)

    if scenarioComplete then
        header.title:SetText(GetScenarioCompleteHeader(displayKind))
        if not ShouldShowCompletedScenarioObjective(true) then
            return
        end

        if stepIndex <= 0 or (tonumber(numStages) and numStages > 0 and stepIndex > numStages) then
            stepIndex = tonumber(numStages) or 0
            if stepIndex <= 0 then
                stepIndex = 1
            end
        end
    else
        header.title:SetText(GetScenarioDisplayHeader(stepIndex, numStages, displayKind, flags))
    end

    local button = WatchButton:GetKeyed("scenario", scenarioName)
    button.scenarioDisplayKind = displayKind
    QuestKing.SetButtonToScenario(button, stepIndex, true, false, false, scenarioComplete)
end

function QuestKing.SetButtonToScenario(
    button,
    stepIndex,
    useCurrentStep,
    useLegacyBonusStep,
    legacyBonusComplete,
    containerComplete
)
    button.mouseHandler = mouseHandlerScenario

    local scenarioName,
        currentStage,
        numStages,
        flags,
        completed,
        xp,
        money,
        scenarioType,
        areaName,
        textureKit,
        scenarioID = SafeGetScenarioInfo()

    local displayKind = GetScenarioDisplayKind(flags, scenarioType)
    local shouldShowCriteria = QuestKing:ShouldShowScenarioCriteria()

    if not stepIndex and not useLegacyBonusStep then
        stepIndex = GetScenarioResolvedStage(currentStage)
        useCurrentStep = true
    end

    if not useLegacyBonusStep and (not stepIndex or stepIndex <= 0) then
        return
    end

    useCurrentStep = useCurrentStep and true or false
    useLegacyBonusStep = useLegacyBonusStep and true or false

    button.stepIndex = stepIndex
    button.scenarioDisplayKind = displayKind
    button.scenarioUseCurrentStep = useCurrentStep
    button.scenarioUseLegacyBonusStep = useLegacyBonusStep
    button.scenarioType = scenarioType
    button.scenarioArea = areaName
    button.scenarioTextureKit = textureKit
    button.scenarioID = scenarioID

    local lastStepIndex = button._lastStepIndex
    local isNewStep = false
    if not useLegacyBonusStep
        and lastStepIndex
        and stepIndex > lastStepIndex
        and not button.fresh then
        isNewStep = true
    end
    button._lastStepIndex = useLegacyBonusStep and nil or stepIndex

    local stageName,
        stageDescription,
        declaredNumCriteria,
        stepFailed,
        isBonusStep,
        isForCurrentStepOnly,
        shouldShowBonusObjective,
        allSpellInfo,
        weightedProgress,
        rewardQuestID,
        widgetSetID,
        resolvedStepID

    if useLegacyBonusStep then
        stageName,
            stageDescription,
            declaredNumCriteria,
            stepFailed,
            isBonusStep,
            isForCurrentStepOnly,
            shouldShowBonusObjective,
            allSpellInfo,
            weightedProgress,
            rewardQuestID,
            widgetSetID,
            resolvedStepID = SafeGetLegacyBonusStepInfo()
    else
        stageName,
            stageDescription,
            declaredNumCriteria,
            stepFailed,
            isBonusStep,
            isForCurrentStepOnly,
            shouldShowBonusObjective,
            allSpellInfo,
            weightedProgress,
            rewardQuestID,
            widgetSetID,
            resolvedStepID = SafeGetScenarioStepInfo(stepIndex, useCurrentStep)
    end

    stageName = stageName or scenarioName or GetScenarioDisplayLabel(displayKind)
    stageDescription = stageDescription or ""

    local criteriaStepID = useCurrentStep and nil
        or SafeNumber(resolvedStepID, nil)
        or SafeNumber(stepIndex, nil)

    button.scenarioCriteriaStepID = criteriaStepID
    button.scenarioIsBonusStep = isBonusStep
    button.scenarioShouldShowBonusObjective = shouldShowBonusObjective

    local numCriteria
    if useLegacyBonusStep then
        numCriteria = SafeNumber(declaredNumCriteria, 0) or 0
    else
        numCriteria = GetEffectiveScenarioCriteriaCount(
            criteriaStepID,
            declaredNumCriteria,
            useCurrentStep
        )
    end

    local hasWeightedProgress = IsSafeNumber(weightedProgress)
    local weightedPercent = hasWeightedProgress and ClampPercent(weightedProgress) or nil

    local stepFinished = containerComplete and true or (legacyBonusComplete and true or false)

    if not stepFinished and stepFailed then
        stepFinished = true
    elseif not stepFinished and hasWeightedProgress then
        stepFinished = weightedPercent >= 100
    elseif not stepFinished and numCriteria > 0 then
        stepFinished = true
        for i = 1, numCriteria do
            local _, _, criteriaCompleted =
                GetScenarioButtonCriteriaInfo(
                    useLegacyBonusStep,
                    criteriaStepID,
                    i,
                    useCurrentStep
                )
            if not criteriaCompleted then
                stepFinished = false
                break
            end
        end
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
        if not stepFinished
            or stepFailed
            or ShouldShowCompletedScenarioObjective(stepFinished) then
            local labelText = stageDescription ~= "" and stageDescription or stageName or "Objective"
            local progressValue = weightedPercent / 100
            local r, g, b

            if stepFailed then
                r = opt_colors.ObjectiveFailed[1]
                g = opt_colors.ObjectiveFailed[2]
                b = opt_colors.ObjectiveFailed[3]
            else
                local colorValue = stepFinished and 1 or progressValue
                r, g, b = getObjectiveColor(colorValue)
            end

            AddScenarioTextLine(button, format("  %s", labelText), nil, r, g, b)
            shownLines = shownLines + 1

            local progressBar = AddScenarioProgressBar(
                button,
                format(
                    "scenario:%s:weighted",
                    tostring(criteriaStepID or stepIndex or 0)
                )
            )
            progressBar:SetPercent(weightedPercent)
        end
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
                isFormatted = GetScenarioButtonCriteriaInfo(
                    useLegacyBonusStep,
                    criteriaStepID,
                    i,
                    useCurrentStep
                )

            criteriaString = (criteriaString and criteriaString ~= "") and criteriaString or "Objective"

            local line
            local displayText = GetCriteriaDisplayText(
                criteriaString,
                quantity,
                totalQuantity,
                quantityString,
                isWeightedProgress,
                isFormatted
            )
            local progressValue = GetCriteriaProgressValue(quantity, totalQuantity, isWeightedProgress)

            if criteriaCompleted then
                if ShouldShowCompletedScenarioObjective(stepFinished) then
                    line = AddScenarioTextLine(
                        button,
                        format("  %s", displayText),
                        nil,
                        opt_colors.ObjectiveGradientComplete[1],
                        opt_colors.ObjectiveGradientComplete[2],
                        opt_colors.ObjectiveGradientComplete[3]
                    )
                end
            elseif criteriaFailed then
                line = AddScenarioTextLine(
                    button,
                    format("  |TInterface\\RAIDFRAME\\ReadyCheck-NotReady:0|t %s", displayText),
                    nil,
                    opt_colors.ObjectiveFailed[1],
                    opt_colors.ObjectiveFailed[2],
                    opt_colors.ObjectiveFailed[3],
                    true
                )
            else
                local r, g, b = getObjectiveColor(progressValue)
                line = AddScenarioTextLine(
                    button,
                    format("  %s", displayText),
                    nil,
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

            if line and isWeightedProgress and not criteriaCompleted and not criteriaFailed then
                local progressBar = AddScenarioProgressBar(
                    button,
                    format(
                        "scenario:%s:%s",
                        tostring(criteriaStepID or stepIndex or 0),
                        tostring(criteriaID or assetID or i)
                    )
                )
                progressBar:SetPercent(ClampPercent(quantity))
            end

            if line
                and not criteriaCompleted
                and not criteriaFailed
                and IsSafeNumber(duration)
                and IsSafeNumber(elapsed)
                and duration > 0
                and elapsed < duration then
                local timerBar = AddScenarioTimerBar(button, duration, GetTime() - elapsed)
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
        AddScenarioTextLine(
            button,
            format("  %s", COMPLETE or "Complete"),
            nil,
            opt_colors.ObjectiveGradientComplete[1],
            opt_colors.ObjectiveGradientComplete[2],
            opt_colors.ObjectiveGradientComplete[3]
        )
    end

    if shownLines == 0 and not stepFinished and not shouldShowCriteria then
        AddScenarioTextLine(
            button,
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

function QuestKing:OnScenarioCompleted(questID, xp, money)
    xp = SafeNumber(xp, 0) or 0
    money = SafeNumber(money, 0) or 0

    if xp > 0 or money > 0 then
        local button = nil
        local scenarioName = SafeGetScenarioInfo()
        if scenarioName then
            button = WatchButton:GetKeyedRaw("header", scenarioName)
        end

        -- Blizzard's scenario tracker displays the event's XP and money
        -- directly. The quest ID is not a substitute for either payload.
        QuestKing:AddReward(button, nil, xp, money)
    end
end

function QuestKing:OnScenarioUpdate(newStage)
    local _, currentStage, numStages, flags, _, _, _, scenarioType = SafeGetScenarioInfo()
    local inChallengeMode = GetScenarioFlags(flags, scenarioType)

    self:RefreshShouldShowScenarioCriteria()

    if newStage then
        if not inChallengeMode then
            if currentStage > 1 and currentStage <= numStages then
                PlaySoundCompat(SOUNDKIT and SOUNDKIT.UI_SCENARIO_STAGE_END, "UI_Scenario_Stage_End")
            end

            if currentStage > 1 then
                SafePlayScenarioBanner()
            end
        end
    end

    QuestKing:UpdateTracker(false, false, "scenario")
end

-- ---------------------------------------------------------------------
-- Mouse handlers
-- ---------------------------------------------------------------------

function mouseHandlerScenario:TitleButtonOnClick(mouse, down)
    local button = self.parent
    local stepIndex = button.stepIndex
    local useCurrentStep = button.scenarioUseCurrentStep

    if mouse == "RightButton" then
        return
    end

    if not useCurrentStep and (not stepIndex or stepIndex <= 0) then
        return
    end

    local _, _, _, _, isBonusStep, _, _, _, _, rewardQuestIDFromStep =
        SafeGetScenarioStepInfo(stepIndex, useCurrentStep)
    local rewardQuestID = GetScenarioRewardQuestID(
        stepIndex,
        rewardQuestIDFromStep,
        isBonusStep
    )
    local rewardQuestLogIndex = rewardQuestID and GetQuestLogIndexByIDCompat(rewardQuestID) or nil

    if rewardQuestID and Compat.OpenQuestDetails and Compat.OpenQuestDetails(rewardQuestID, rewardQuestLogIndex) then
        return
    end
end

function mouseHandlerScenario:TitleButtonOnEnter(motion)
    local button = self.parent or self
    local stepIndex = button.stepIndex
    local useCurrentStep = button.scenarioUseCurrentStep
    local useLegacyBonusStep = button.scenarioUseLegacyBonusStep
    local criteriaStepID = button.scenarioCriteriaStepID

    local scenarioName,
        currentStage,
        numStages,
        flags,
        completed,
        xp,
        money,
        scenarioType,
        areaName,
        textureKit,
        scenarioID = SafeGetScenarioInfo()

    local stageName,
        stageDescription,
        declaredNumCriteria,
        stepFailed,
        isBonusStep,
        isForCurrentStepOnly,
        shouldShowBonusObjective,
        allSpellInfo,
        weightedProgress,
        rewardQuestIDFromStep

    if useLegacyBonusStep then
        stageName,
            stageDescription,
            declaredNumCriteria,
            stepFailed,
            isBonusStep,
            isForCurrentStepOnly,
            shouldShowBonusObjective,
            allSpellInfo,
            weightedProgress,
            rewardQuestIDFromStep = SafeGetLegacyBonusStepInfo()
    else
        stageName,
            stageDescription,
            declaredNumCriteria,
            stepFailed,
            isBonusStep,
            isForCurrentStepOnly,
            shouldShowBonusObjective,
            allSpellInfo,
            weightedProgress,
            rewardQuestIDFromStep = SafeGetScenarioStepInfo(stepIndex, useCurrentStep)
    end

    local numCriteria
    if useLegacyBonusStep then
        numCriteria = SafeNumber(declaredNumCriteria, 0) or 0
    else
        numCriteria = GetEffectiveScenarioCriteriaCount(
            criteriaStepID,
            declaredNumCriteria,
            useCurrentStep
        )
    end
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
                criteriaFailed,
                isWeightedProgress,
                isFormatted = GetScenarioButtonCriteriaInfo(
                    useLegacyBonusStep,
                    criteriaStepID,
                    i,
                    useCurrentStep
                )

            criteriaString = (criteriaString and criteriaString ~= "") and criteriaString or "Objective"
            local criteriaDisplayText = GetCriteriaDisplayText(
                criteriaString,
                quantity,
                totalQuantity,
                quantityString,
                isWeightedProgress,
                isFormatted
            )

            if isWeightedProgress then
                criteriaDisplayText = format(
                    "%s: %d%%",
                    criteriaDisplayText,
                    ClampPercent(quantity)
                )
            end

            if criteriaCompleted then
                tooltip:AddLine(
                    format("- %s |cff808080(%s)|r", criteriaDisplayText, COMPLETE),
                    0.2, 0.9, 0.2
                )
            elseif criteriaFailed then
                tooltip:AddLine(
                    format("- %s |cff808080(%s)|r", criteriaDisplayText, FAILED),
                    1, 0.2, 0.2
                )
            else
                tooltip:AddLine(format("- %s", criteriaDisplayText), 1, 1, 1)
            end
        end
    end

    if ShouldShowScenarioSpellsInTooltip() and allSpellInfo and #allSpellInfo > 0 then
        tooltip:AddLine(" ")
        for i = 1, #allSpellInfo do
            local spellInfo = allSpellInfo[i]
            local spellName = spellInfo and (spellInfo.name or spellInfo.spellName)
            if spellName then
                tooltip:AddLine(format("Spell: %s", spellName), 0.8, 0.9, 1)
            end
        end
    end

    local blankLine = false
    local rewardQuestID = GetScenarioRewardQuestID(
        stepIndex,
        rewardQuestIDFromStep,
        isBonusStep
    )

    if useLegacyBonusStep then
        AddLegacyBonusRewardsToTooltip(tooltip)
    elseif rewardQuestID then
        local rewardXP = GetQuestRewardXPCompat(rewardQuestID)
        if rewardXP > 0 and not IsPlayerAtEffectiveMaxLevelCompat() then
            tooltip:AddLine(" ")
            blankLine = true
            AddTooltipRewardText(tooltip, format(BONUS_OBJECTIVE_EXPERIENCE_FORMAT, rewardXP), 1, 1, 1)
        end

        local numQuestCurrencies = GetNumRewardCurrenciesCompat(rewardQuestID)
        for i = 1, numQuestCurrencies do
            local name, texture, numItems = GetRewardCurrencyInfoCompat(i, rewardQuestID)
            if name and texture and numItems then
                local text = format(BONUS_OBJECTIVE_REWARD_WITH_COUNT_FORMAT, texture, numItems, name)
                if not blankLine then
                    tooltip:AddLine(" ")
                    blankLine = true
                end
                AddTooltipRewardText(tooltip, text, 1, 1, 1)
            end
        end

        local numQuestRewards = GetNumQuestRewardsCompat(rewardQuestID)
        for i = 1, numQuestRewards do
            local name, texture, numItems, quality = GetQuestRewardInfoCompat(i, rewardQuestID)
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

        local rewardMoney = GetQuestRewardMoneyCompat(rewardQuestID)
        if rewardMoney > 0 then
            if not blankLine then
                tooltip:AddLine(" ")
                blankLine = true
            end
            AddTooltipMoneyText(tooltip, rewardMoney)
        end
    elseif not isBonusStep then
        if xp and xp > 0 and not IsPlayerAtEffectiveMaxLevelCompat() then
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
