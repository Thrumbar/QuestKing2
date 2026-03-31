local addonName, QuestKing = ...

local opt = QuestKing.options
local opt_colors = opt.colors
local opt_showCompletedObjectives = opt.showCompletedObjectives

local WatchButton = QuestKing.WatchButton
local getObjectiveColor = QuestKing.GetObjectiveColor

local format = string.format
local type = type
local min = math.min
local max = math.max
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

-- ---------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------

local function SafePublicNumber(value, fallback)
    if type(value) == "number" then
        return value
    end

    if fallback ~= nil then
        return fallback
    end

    return 0
end

local function SafeGetScenarioInfo()
    if C_ScenarioInfo and C_ScenarioInfo.GetScenarioInfo then
        local info = C_ScenarioInfo.GetScenarioInfo()
        if info then
            return info.name,
                info.currentStage or 0,
                info.numStages or 0,
                info.flags or 0,
                false,
                false,
                info.isComplete and true or false,
                info.xp or 0,
                info.money or 0
        end
    end

    if not (C_Scenario and C_Scenario.GetInfo) then
        return nil, 0, 0, 0, false, false, false, 0, 0
    end

    local scenarioName, currentStage, numStages, flags, hasBonusStep, isBonusStepComplete, completed, xp, money =
        C_Scenario.GetInfo()

    return scenarioName,
        currentStage or 0,
        numStages or 0,
        flags or 0,
        hasBonusStep and true or false,
        isBonusStepComplete and true or false,
        completed and true or false,
        xp or 0,
        money or 0
end

local function SafeGetScenarioStepInfo(stepIndex)
    if not stepIndex or stepIndex <= 0 then
        return nil, nil, 0, false, false, false, 0, nil, nil, nil, nil
    end

    if C_ScenarioInfo and C_ScenarioInfo.GetScenarioStepInfo then
        local info = C_ScenarioInfo.GetScenarioStepInfo(stepIndex)
        if info then
            return info.title or nil,
                info.description or nil,
                SafePublicNumber(info.numCriteria, 0),
                info.stepFailed and true or false,
                info.isBonusStep and true or false,
                info.isForCurrentStepOnly and true or false,
                (info.spells and #info.spells) or 0,
                info.spells,
                info.weightedProgress,
                info.rewardQuestID,
                info.widgetSetID
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

        return stageName,
            stageDescription,
            numCriteria or 0,
            stepFailed and true or false,
            isBonusStep and true or false,
            isForCurrentStepOnly and true or false,
            numSpells or 0,
            allSpellInfo,
            weightedProgress,
            rewardQuestID,
            widgetSetID
    end

    return nil, nil, 0, false, false, false, 0, nil, nil, nil, nil
end

local function GetScenarioFlags(flags)
    flags = flags or 0

    local inChallengeMode = false
    local inProvingGrounds = false
    local dungeonDisplay = false

    if SCENARIO_FLAG_CHALLENGE_MODE then
        inChallengeMode = band(flags, SCENARIO_FLAG_CHALLENGE_MODE) == SCENARIO_FLAG_CHALLENGE_MODE
    end

    if SCENARIO_FLAG_PROVING_GROUNDS then
        inProvingGrounds = band(flags, SCENARIO_FLAG_PROVING_GROUNDS) == SCENARIO_FLAG_PROVING_GROUNDS
    end

    if SCENARIO_FLAG_USE_DUNGEON_DISPLAY then
        dungeonDisplay = band(flags, SCENARIO_FLAG_USE_DUNGEON_DISPLAY) == SCENARIO_FLAG_USE_DUNGEON_DISPLAY
    end

    return inChallengeMode, inProvingGrounds, dungeonDisplay
end

local function GetScenarioCriteriaInfo(stepIndex, criteriaIndex)
    if C_ScenarioInfo then
        if C_ScenarioInfo.GetCriteriaInfo then
            local info = C_ScenarioInfo.GetCriteriaInfo(criteriaIndex)
            if info then
                return info.description or "",
                    info.criteriaType,
                    info.completed and true or false,
                    SafePublicNumber(info.quantity, 0),
                    SafePublicNumber(info.totalQuantity, 0),
                    info.flags,
                    info.assetID,
                    info.quantityString,
                    info.criteriaID,
                    SafePublicNumber(info.duration, 0),
                    SafePublicNumber(info.elapsed, 0),
                    info.failed and true or false,
                    info.isWeightedProgress and true or false
            end
        end

        if C_ScenarioInfo.GetCriteriaInfoByStep then
            local info = C_ScenarioInfo.GetCriteriaInfoByStep(stepIndex, criteriaIndex)
            if info then
                return info.description or "",
                    info.criteriaType,
                    info.completed and true or false,
                    SafePublicNumber(info.quantity, 0),
                    SafePublicNumber(info.totalQuantity, 0),
                    info.flags,
                    info.assetID,
                    info.quantityString,
                    info.criteriaID,
                    SafePublicNumber(info.duration, 0),
                    SafePublicNumber(info.elapsed, 0),
                    info.failed and true or false,
                    info.isWeightedProgress and true or false
            end
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
            return criteriaString or "",
                criteriaType,
                criteriaCompleted and true or false,
                SafePublicNumber(quantity, 0),
                SafePublicNumber(totalQuantity, 0),
                flags,
                assetID,
                quantityString,
                criteriaID,
                SafePublicNumber(duration, 0),
                SafePublicNumber(elapsed, 0),
                criteriaFailed and true or false,
                isWeightedProgress and true or false
        end
    end

    if C_Scenario and C_Scenario.GetCriteriaInfoByStep then
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

        return criteriaString or "",
            criteriaType,
            criteriaCompleted and true or false,
            SafePublicNumber(quantity, 0),
            SafePublicNumber(totalQuantity, 0),
            flags,
            assetID,
            quantityString,
            criteriaID,
            SafePublicNumber(duration, 0),
            SafePublicNumber(elapsed, 0),
            criteriaFailed and true or false,
            isWeightedProgress and true or false
    end

    return nil, nil, false, 0, 0, nil, nil, nil, nil, 0, 0, false, false
end

local function GetEffectiveScenarioCriteriaCount(stepIndex, declaredNumCriteria)
    declaredNumCriteria = SafePublicNumber(declaredNumCriteria, 0)
    if declaredNumCriteria > 0 then
        return declaredNumCriteria
    end

    for i = 1, 20 do
        local description, _, _, _, _, _, _, _, criteriaID = GetScenarioCriteriaInfo(stepIndex, i)
        if not description and not criteriaID then
            return i - 1
        end
    end

    return 0
end

local function ClampPercent(value)
    value = SafePublicNumber(value, 0)
    if value < 0 then
        return 0
    end
    if value > 100 then
        return 100
    end
    return value
end

local function GetCriteriaProgressText(quantity, totalQuantity, quantityString)
    if totalQuantity and totalQuantity > 0 then
        return format(": %d/%d", quantity or 0, totalQuantity)
    end

    if quantityString and quantityString ~= "" then
        return ": " .. quantityString
    end

    return nil
end

local function GetCriteriaProgressValue(quantity, totalQuantity, isWeightedProgress)
    quantity = SafePublicNumber(quantity, 0)
    totalQuantity = SafePublicNumber(totalQuantity, 0)

    if totalQuantity > 0 then
        return min(quantity / totalQuantity, 1)
    end

    if isWeightedProgress and quantity > 0 then
        return min(quantity, 1)
    end

    return 0
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
    if rewardQuestIDFromStep and rewardQuestIDFromStep ~= 0 then
        return rewardQuestIDFromStep
    end

    if C_Scenario and C_Scenario.GetBonusStepRewardQuestID and stepIndex then
        local questID = C_Scenario.GetBonusStepRewardQuestID(stepIndex)
        if questID and questID ~= 0 then
            return questID
        end
    end

    return nil
end

local function AddTooltipRewardText(text, r, g, b)
    if text and text ~= "" then
        GameTooltip:AddLine(text, r or 1, g or 1, b or 1)
    end
end

local function GetScenarioDisplayHeader(currentStage, numStages, inChallengeMode, inProvingGrounds, dungeonDisplay)
    if inProvingGrounds then
        return "Proving Grounds"
    end

    local displayText = "Scenario"

    if dungeonDisplay then
        displayText = "Dungeon"
    elseif inChallengeMode then
        displayText = "Challenge Mode"
    end

    if numStages > 1 then
        if currentStage == numStages then
            return format("%s: Final Stage", displayText)
        end
        return format("%s: Stage %d/%d", displayText, currentStage, numStages)
    end

    return displayText
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
-- Misc
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
-- Scenarios
-- ---------------------------------------------------------------------

function QuestKing:UpdateTrackerScenarios()
    local scenarioName, currentStage, numStages, flags = SafeGetScenarioInfo()
    local inChallengeMode, inProvingGrounds, dungeonDisplay = GetScenarioFlags(flags)

    if not scenarioName or scenarioName == "" then
        return
    end

    local _, _, _, _, _, _, _, mapID = GetInstanceInfo()
    if mapID == 1148 then
        inProvingGrounds = true
    end

    if inProvingGrounds and C_Scenario and C_Scenario.GetProvingGroundsInfo then
        local _, _, _, duration = C_Scenario.GetProvingGroundsInfo()
        if duration and duration ~= 0 then
            return
        end
    end

    if currentStage <= 0 then
        return
    end

    local header = WatchButton:GetKeyed("header", scenarioName)
    header.title:SetText(GetScenarioDisplayHeader(currentStage, numStages, inChallengeMode, inProvingGrounds, dungeonDisplay))
    header.title:SetTextColor(
        opt_colors.SectionHeader[1],
        opt_colors.SectionHeader[2],
        opt_colors.SectionHeader[3]
    )

    if currentStage > numStages then
        if inChallengeMode then
            header.title:SetText("Challenge Mode Complete!")
        elseif dungeonDisplay then
            header.title:SetText("Dungeon Complete!")
        else
            header.title:SetText("Scenario Complete!")
        end
        return
    end

    local button = WatchButton:GetKeyed("scenario", scenarioName)
    QuestKing.SetButtonToScenario(button, currentStage)
end

function QuestKing.SetButtonToScenario(button, stepIndex)
    button.mouseHandler = mouseHandlerScenario

    local scenarioName, currentStage = SafeGetScenarioInfo()

    if not stepIndex then
        stepIndex = currentStage
    end

    if not stepIndex or stepIndex <= 0 then
        return
    end

    button.stepIndex = stepIndex

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

    stageName = stageName or scenarioName or "Scenario"
    stageDescription = stageDescription or ""

    local numCriteria = GetEffectiveScenarioCriteriaCount(stepIndex, declaredNumCriteria)
    local hasWeightedProgress = type(weightedProgress) == "number"
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

    if hasWeightedProgress then
        local labelText = stageDescription ~= "" and stageDescription or stageName or "Objective"
        local progressValue = weightedPercent / 100
        local colorValue = stepFinished and 1 or progressValue
        local r, g, b = getObjectiveColor(colorValue)

        button:AddLine(format("  %s", labelText), nil, r, g, b)
        shownLines = shownLines + 1

        local progressBar = button:AddProgressBar()
        progressBar:SetPercent(weightedPercent)
    elseif numCriteria > 0 then
        for i = 1, numCriteria do
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
                isWeightedProgress =
                GetScenarioCriteriaInfo(stepIndex, i)

            criteriaString = (criteriaString and criteriaString ~= "") and criteriaString or "Objective"

            local line
            local progressText = GetCriteriaProgressText(quantity, totalQuantity, quantityString)
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

                local lastQuant = type(line._lastQuant) == "number" and line._lastQuant or nil
                if lastQuant and quantity > lastQuant and not isNewStep then
                    line:Flash()
                end
                line._lastQuant = quantity
            end

            if duration and elapsed and duration > 0 and elapsed < duration then
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
    local _, currentStage, numStages, flags = SafeGetScenarioInfo()
    local inChallengeMode = GetScenarioFlags(flags)

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
        money = SafeGetScenarioInfo()

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

    if not scenarioName then
        return
    end

    GameTooltip:SetOwner(self, GetTooltipAnchor())

    if opt.tooltipScale then
        if not GameTooltip.__QuestKingPreviousScale then
            GameTooltip.__QuestKingPreviousScale = GameTooltip:GetScale()
        end
        GameTooltip:SetScale(opt.tooltipScale)
    end

    GameTooltip:AddLine(scenarioName, NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, 1)
    GameTooltip:AddLine(
        stageName or "Scenario",
        opt_colors.ScenarioStageTitle[1],
        opt_colors.ScenarioStageTitle[2],
        opt_colors.ScenarioStageTitle[3],
        1
    )

    if isBonusStep then
        GameTooltip:AddLine("Bonus Objective", 1, 0.914, 0.682, 1)
    else
        GameTooltip:AddLine(format(SCENARIO_STAGE_STATUS, currentStage, numStages), 1, 0.914, 0.682, 1)
    end

    GameTooltip:AddLine(" ")

    if stageDescription and stageDescription ~= "" then
        GameTooltip:AddLine(stageDescription, 1, 1, 1, 1)
    end

    if type(weightedProgress) == "number" then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(format("Progress: %d%%", ClampPercent(weightedProgress)), 1, 1, 1, 1)
    end

    if numCriteria > 0 then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(QUEST_TOOLTIP_REQUIREMENTS, NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, 1)

        for i = 1, numCriteria do
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
                criteriaFailed =
                GetScenarioCriteriaInfo(stepIndex, i)

            criteriaString = (criteriaString and criteriaString ~= "") and criteriaString or "Objective"

            if criteriaCompleted then
                if totalQuantity > 0 then
                    GameTooltip:AddLine(
                        format("- %s: %d/%d |cff808080(%s)|r", criteriaString, quantity, totalQuantity, COMPLETE),
                        0.2, 0.9, 0.2
                    )
                elseif quantityString and quantityString ~= "" then
                    GameTooltip:AddLine(
                        format("- %s: %s |cff808080(%s)|r", criteriaString, quantityString, COMPLETE),
                        0.2, 0.9, 0.2
                    )
                else
                    GameTooltip:AddLine(
                        format("- %s |cff808080(%s)|r", criteriaString, COMPLETE),
                        0.2, 0.9, 0.2
                    )
                end
            elseif criteriaFailed then
                if totalQuantity > 0 then
                    GameTooltip:AddLine(
                        format("- %s: %d/%d |cff808080(%s)|r", criteriaString, quantity, totalQuantity, FAILED),
                        1, 0.2, 0.2
                    )
                elseif quantityString and quantityString ~= "" then
                    GameTooltip:AddLine(
                        format("- %s: %s |cff808080(%s)|r", criteriaString, quantityString, FAILED),
                        1, 0.2, 0.2
                    )
                else
                    GameTooltip:AddLine(
                        format("- %s |cff808080(%s)|r", criteriaString, FAILED),
                        1, 0.2, 0.2
                    )
                end
            else
                if totalQuantity > 0 then
                    GameTooltip:AddLine(format("- %s: %d/%d", criteriaString, quantity, totalQuantity), 1, 1, 1)
                elseif quantityString and quantityString ~= "" then
                    GameTooltip:AddLine(format("- %s: %s", criteriaString, quantityString), 1, 1, 1)
                else
                    GameTooltip:AddLine(format("- %s", criteriaString), 1, 1, 1)
                end
            end
        end
    end

    local blankLine = false
    local rewardQuestID = GetScenarioRewardQuestID(stepIndex, rewardQuestIDFromStep)
    local rewardQuestLogIndex = rewardQuestID and GetQuestLogIndexByIDCompat(rewardQuestID) or nil

    if rewardQuestLogIndex then
        local rewardXP = GetQuestLogRewardXP and (GetQuestLogRewardXP(rewardQuestLogIndex) or 0) or 0
        if rewardXP > 0 then
            if not blankLine then
                GameTooltip:AddLine(" ")
                blankLine = true
            end
            AddTooltipRewardText(format(BONUS_OBJECTIVE_EXPERIENCE_FORMAT, rewardXP), 1, 1, 1)
        end

        local numQuestCurrencies = GetNumQuestLogRewardCurrencies and (GetNumQuestLogRewardCurrencies(rewardQuestLogIndex) or 0) or 0
        for i = 1, numQuestCurrencies do
            local name, texture, numItems = GetQuestLogRewardCurrencyInfo(i, rewardQuestLogIndex)
            if name and texture and numItems then
                local text = format(BONUS_OBJECTIVE_REWARD_WITH_COUNT_FORMAT, texture, numItems, name)
                if not blankLine then
                    GameTooltip:AddLine(" ")
                    blankLine = true
                end
                AddTooltipRewardText(text, 1, 1, 1)
            end
        end

        local numQuestRewards = GetNumQuestLogRewards and (GetNumQuestLogRewards(rewardQuestLogIndex) or 0) or 0
        for i = 1, numQuestRewards do
            local name, texture, numItems, quality = GetQuestLogRewardInfo(i, rewardQuestLogIndex)
            local text

            if numItems and numItems > 1 then
                text = format(BONUS_OBJECTIVE_REWARD_WITH_COUNT_FORMAT, texture, numItems, name)
            elseif texture and name then
                text = format(BONUS_OBJECTIVE_REWARD_FORMAT, texture, name)
            end

            if text then
                local color = ITEM_QUALITY_COLORS[quality or 1] or NORMAL_FONT_COLOR
                if not blankLine then
                    GameTooltip:AddLine(" ")
                    blankLine = true
                end
                AddTooltipRewardText(text, color.r, color.g, color.b)
            end
        end

        local rewardMoney = GetQuestLogRewardMoney and (GetQuestLogRewardMoney(rewardQuestLogIndex) or 0) or 0
        if rewardMoney > 0 then
            if not blankLine then
                GameTooltip:AddLine(" ")
                blankLine = true
            end
            SetTooltipMoney(GameTooltip, rewardMoney, nil)
        end
    else
        if xp and xp > 0 then
            if not blankLine then
                GameTooltip:AddLine(" ")
                blankLine = true
            end
            AddTooltipRewardText(format(BONUS_OBJECTIVE_EXPERIENCE_FORMAT, xp), 1, 1, 1)
        end

        if money and money > 0 then
            if not blankLine then
                GameTooltip:AddLine(" ")
                blankLine = true
            end
            SetTooltipMoney(GameTooltip, money, nil)
        end
    end

    GameTooltip:Show()
end