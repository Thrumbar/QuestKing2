local addonName, QuestKing = ...

local opt = QuestKing.options
local opt_colors = opt.colors

local WatchButton = QuestKing.WatchButton
local getQuestTaggedTitle = QuestKing.GetQuestTaggedTitle
local getObjectiveColor = QuestKing.GetObjectiveColor

local format = string.format
local match = string.match
local type = type
local pairs = pairs
local UNKNOWN = UNKNOWN or "Unknown"
local C_Scenario = C_Scenario
local C_QuestLog = C_QuestLog
local C_SuperTrack = C_SuperTrack

local addHeader
local setButtonToBonusTask
local setButtonToDummyTask
local getSupersedingStep

local dummyTaskID
local dummyTaskTaggedTitle
local dummyTaskUseNonBonusHeader
local dummyTaskQuestIndex

local supersededObjectives

local mouseHandlerBonusTask = {}

-- -----------------------------------------------------------------------------
-- Compatibility helpers
-- -----------------------------------------------------------------------------

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

local function deleteArrayValue(tbl, value)
    if type(tbl) ~= "table" then
        return false
    end

    for index = #tbl, 1, -1 do
        if tbl[index] == value then
            table.remove(tbl, index)
            return true
        end
    end

    return false
end

local function getTasksTableSafe()
    if GetTasksTable then
        return GetTasksTable() or {}
    end
    return {}
end

local function getTaskInfoSafe(questID)
    if GetTaskInfo then
        local isInArea, isOnMap, numObjectives = GetTaskInfo(questID)
        return isInArea and true or false, isOnMap and true or false, numObjectives or 0
    end
    return false, false, 0
end

local function getQuestLogIndexByIDSafe(questID)
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

local function getQuestTitleAndLevelSafe(questID)
    local questIndex = getQuestLogIndexByIDSafe(questID)
    if questIndex then
        local taggedTitle, level = getQuestTaggedTitle(questIndex, true)
        return taggedTitle or UNKNOWN, level or 0, questIndex
    end

    local fallbackTitle
    if C_QuestLog and C_QuestLog.GetTitleForQuestID then
        fallbackTitle = C_QuestLog.GetTitleForQuestID(questID)
    end

    if not fallbackTitle or fallbackTitle == "" then
        fallbackTitle = UNKNOWN
    end

    return fallbackTitle, (UnitLevel and UnitLevel("player")) or 0, nil
end

local function getSuperTrackedQuestIDSafe()
    if C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID then
        return C_SuperTrack.GetSuperTrackedQuestID() or 0
    end
    if GetSuperTrackedQuestID then
        return GetSuperTrackedQuestID() or 0
    end
    return 0
end

local function hasQuestDataSafe(questID)
    if HaveQuestData then
        return HaveQuestData(questID) and true or false
    end
    return true
end

local function getRewardXPCompat(questID)
    if C_QuestLog and C_QuestLog.GetQuestRewardXP then
        return C_QuestLog.GetQuestRewardXP(questID) or 0
    end
    if GetQuestLogRewardXP then
        return GetQuestLogRewardXP(questID) or 0
    end
    return 0
end

local function getRewardMoneyCompat(questID)
    if C_QuestLog and C_QuestLog.GetQuestLogRewardMoney then
        return C_QuestLog.GetQuestLogRewardMoney(questID) or 0
    end
    if GetQuestLogRewardMoney then
        return GetQuestLogRewardMoney(questID) or 0
    end
    return 0
end

local function getNumRewardCurrenciesCompat(questID)
    if C_QuestLog and C_QuestLog.GetNumQuestLogRewardCurrencies then
        return C_QuestLog.GetNumQuestLogRewardCurrencies(questID) or 0
    end
    if GetNumQuestLogRewardCurrencies then
        return GetNumQuestLogRewardCurrencies(questID) or 0
    end
    return 0
end

local function getRewardCurrencyInfoCompat(index, questID)
    if C_QuestLog and C_QuestLog.GetQuestLogRewardCurrencyInfo then
        local info = C_QuestLog.GetQuestLogRewardCurrencyInfo(index, questID)
        if info then
            return info.name, info.texture, info.numItems
        end
    end
    if GetQuestLogRewardCurrencyInfo then
        return GetQuestLogRewardCurrencyInfo(index, questID)
    end
    return nil, nil, nil
end

local function getNumRewardsCompat(questID)
    if C_QuestLog and C_QuestLog.GetNumQuestLogRewards then
        return C_QuestLog.GetNumQuestLogRewards(questID) or 0
    end
    if GetNumQuestLogRewards then
        return GetNumQuestLogRewards(questID) or 0
    end
    return 0
end

local function getRewardInfoCompat(index, questID)
    if C_QuestLog and C_QuestLog.GetQuestLogRewardInfo then
        local info = C_QuestLog.GetQuestLogRewardInfo(index, questID)
        if info then
            return info.name, info.texture, info.numItems, info.quality, info.isUsable
        end
    end
    if GetQuestLogRewardInfo then
        return GetQuestLogRewardInfo(index, questID)
    end
    return nil, nil, nil, nil, nil
end

local function getQuestObjectiveInfoCompat(questID, objectiveIndex, displayComplete)
    if C_QuestLog and C_QuestLog.GetQuestObjectives then
        local objectives = C_QuestLog.GetQuestObjectives(questID)
        if objectives and objectives[objectiveIndex] then
            local objective = objectives[objectiveIndex]
            local text = objective.text or UNKNOWN
            local objectiveType = objective.type or objective.objectiveType
            local isDone = (objective.finished or objective.completed) and true or false
            local displayAsObjective = objective.useFullPositionTooltip and true or false

            return text, objectiveType, isDone, displayAsObjective, objective
        end
    end

    if GetQuestObjectiveInfo then
        return GetQuestObjectiveInfo(questID, objectiveIndex, displayComplete)
    end

    return nil, nil, nil, nil, nil
end

local function getQuestProgressBarPercentCompat(questID)
    if C_QuestLog and C_QuestLog.GetQuestProgressBarPercent then
        return C_QuestLog.GetQuestProgressBarPercent(questID) or 0
    end
    if GetQuestProgressBarPercent then
        return GetQuestProgressBarPercent(questID) or 0
    end
    return 0
end

local function shouldSkipTrackedTaskQuest(questID)
    if QuestKing.ShouldSkipBonusTask then
        return QuestKing:ShouldSkipBonusTask(questID)
    end
    return false
end

local function SafePublicNumber(value, fallback)
    if type(value) == "number" then
        return value
    end

    if fallback ~= nil then
        return fallback
    end

    return 0
end

local function clamp01(value)
    value = SafePublicNumber(value, 0)
    if value < 0 then
        return 0
    end
    if value > 1 then
        return 1
    end
    return value
end

local function normalizeObjectiveNumbers(curValue, maxValue)
    if type(curValue) ~= "number" or type(maxValue) ~= "number" or maxValue <= 0 then
        return nil, nil
    end

    if curValue < 0 then
        curValue = 0
    elseif curValue > maxValue then
        curValue = maxValue
    end

    return curValue, maxValue
end

local function objectiveTextAlreadyHasProgress(text)
    if type(text) ~= "string" or text == "" then
        return false
    end

    if match(text, "%d+%s*/%s*%d+") then
        return true
    end

    if match(text, "%(%d+%s*/%s*%d+%)") then
        return true
    end

    return false
end

local function buildObjectiveDisplayText(desc, currentValue, maxValue, objectiveInfo)
    if not desc or desc == "" then
        desc = UNKNOWN
    end

    if objectiveTextAlreadyHasProgress(desc) then
        return desc, nil
    end

    if currentValue and maxValue and maxValue > 0 then
        return desc, format(": %d/%d", currentValue, maxValue)
    end

    if objectiveInfo and objectiveInfo.numRequired and objectiveInfo.numRequired > 0 and objectiveInfo.numFulfilled ~= nil then
        local fulfilled, required = normalizeObjectiveNumbers(objectiveInfo.numFulfilled, objectiveInfo.numRequired)
        if fulfilled and required then
            return desc, format(": %d/%d", fulfilled, required)
        end
    end

    return desc, nil
end

local function getObjectiveDisplayState(desc, isDone, objectiveInfo)
    local quantCur, quantMax, quantName = QuestKing.MatchObjective(desc)
    if quantName then
        local currentValue, maxValue = normalizeObjectiveNumbers(quantCur, quantMax)
        if currentValue and maxValue then
            return quantName, currentValue, maxValue, clamp01(currentValue / maxValue), true
        end
    end

    if objectiveInfo and objectiveInfo.numRequired and objectiveInfo.numRequired > 0 and objectiveInfo.numFulfilled ~= nil then
        local fulfilled, required = normalizeObjectiveNumbers(objectiveInfo.numFulfilled, objectiveInfo.numRequired)
        if fulfilled and required then
            return desc, fulfilled, required, clamp01(fulfilled / required), true
        end
    end

    return desc, nil, nil, isDone and 1 or 0, false
end

-- -----------------------------------------------------------------------------
-- Header
-- -----------------------------------------------------------------------------

function addHeader()
    local header = WatchButton:GetKeyed("header", "Bonus Objectives")
    header.title:SetText(TRACKER_HEADER_BONUS_OBJECTIVES)
    header.title:SetTextColor(
        opt_colors.SectionHeader[1],
        opt_colors.SectionHeader[2],
        opt_colors.SectionHeader[3]
    )
    return header
end

-- -----------------------------------------------------------------------------
-- Tracker population
-- -----------------------------------------------------------------------------

function QuestKing:UpdateTrackerBonusObjectives()
    local tasksTable = getTasksTableSafe()
    local header

    if dummyTaskID then
        header = addHeader()

        local button = WatchButton:GetKeyed("bonus_task_dummy", dummyTaskID)
        button._previousHeader = header
        setButtonToDummyTask(button, dummyTaskID)
    end

    for i = 1, #tasksTable do
        local questID = tasksTable[i]
        local isInArea = false

        if questID then
            isInArea = getTaskInfoSafe(questID)
        end

        if isInArea and questID ~= dummyTaskID then
            if not shouldSkipTrackedTaskQuest(questID) then
                if not header then
                    header = addHeader()
                end

                local button = WatchButton:GetKeyed("bonus_task", questID)
                button._previousHeader = header
                setButtonToBonusTask(button, questID)
            end
        end
    end

    if not C_Scenario or not C_Scenario.IsInScenario or not C_Scenario.GetBonusSteps then
        return
    end

    if not C_Scenario.IsInScenario() then
        return
    end

    local tblBonusSteps = C_Scenario.GetBonusSteps() or {}

    supersededObjectives = C_Scenario.GetSupersededObjectives and C_Scenario.GetSupersededObjectives() or nil
    if supersededObjectives and opt.hideSupersedingObjectives then
        local hiddenSteps = {}

        for i = 1, #tblBonusSteps do
            local bonusStepIndex = tblBonusSteps[i]
            local supersededIndex = getSupersedingStep(bonusStepIndex)
            if supersededIndex then
                local _, _, numCriteria, stepFailed = C_Scenario.GetStepInfo(bonusStepIndex)
                numCriteria = SafePublicNumber(numCriteria, 0)

                local completed = true

                if stepFailed then
                    completed = false
                else
                    for criteriaIndex = 1, numCriteria do
                        local criteriaString, _, criteriaCompleted = C_Scenario.GetCriteriaInfoByStep(bonusStepIndex, criteriaIndex)
                        if criteriaString and not criteriaCompleted then
                            completed = false
                            break
                        end
                    end
                end

                if not completed then
                    hiddenSteps[#hiddenSteps + 1] = supersededIndex
                end
            end
        end

        for i = 1, #hiddenSteps do
            deleteArrayValue(tblBonusSteps, hiddenSteps[i])
        end
    end

    for i = 1, #tblBonusSteps do
        local bonusStepIndex = tblBonusSteps[i]

        if not header then
            header = addHeader()
        end

        local button = WatchButton:GetKeyed("bonus_step", bonusStepIndex)
        button._previousHeader = header
        QuestKing.SetButtonToScenario(button, bonusStepIndex)
    end
end

function getSupersedingStep(bonusStepIndex)
    supersededObjectives = C_Scenario and C_Scenario.GetSupersededObjectives and C_Scenario.GetSupersededObjectives() or nil
    if not supersededObjectives then
        return nil
    end

    for i = 1, #supersededObjectives do
        local set = supersededObjectives[i]
        if set and set[2] == bonusStepIndex then
            return set[1]
        end
    end

    return nil
end

-- -----------------------------------------------------------------------------
-- Bonus task button population
-- -----------------------------------------------------------------------------

function setButtonToBonusTask(button, questID)
    button.mouseHandler = mouseHandlerBonusTask

    local taggedTitle, level, questIndex = getQuestTitleAndLevelSafe(questID)
    local color = GetQuestDifficultyColor(level or 0)

    button.questID = questID
    button.questIndex = questIndex
    button.questLogIndex = questIndex

    if getSuperTrackedQuestIDSafe() == questID then
        taggedTitle = taggedTitle .. " |TInterface\\Scenarios\\ScenarioIcon-Combat:10:10:-1:0|t"
    end

    button.title:SetTextIcon(taggedTitle)
    button.title:SetTextColor(color.r, color.g, color.b)

    local _, _, numObjectives = getTaskInfoSafe(questID)
    local useNonBonusHeader = false
    local visibleObjectives = 0

    for i = 1, numObjectives do
        local desc, objectiveType, isDone, displayAsObjective, objectiveInfo = getQuestObjectiveInfoCompat(questID, i, false)
        useNonBonusHeader = useNonBonusHeader or displayAsObjective

        if desc == nil or desc == "" then
            desc = UNKNOWN
        end

        if objectiveType == "progressbar" then
            local percent = SafePublicNumber(getQuestProgressBarPercentCompat(questID), 0)
            if percent < 0 then
                percent = 0
            elseif percent > 100 then
                percent = 100
            end

            local barLabel = desc
            local r, g, b = getObjectiveColor(isDone and 1 or clamp01(percent / 100))
            button:AddLine(format("  %s", barLabel), nil, r, g, b)

            local progressBar = button:AddProgressBar()
            progressBar:SetPercent(percent)
            visibleObjectives = visibleObjectives + 1
        else
            local displayText, currentValue, maxValue, progress, hasCount = getObjectiveDisplayState(desc, isDone, objectiveInfo)
            local leftText, rightText = buildObjectiveDisplayText(displayText, currentValue, maxValue, objectiveInfo)
            local r, g, b = getObjectiveColor(progress)
            local line = button:AddLine(format("  %s", leftText), rightText, r, g, b)

            if line and currentValue then
                local lastQuant = type(line._lastQuant) == "number" and line._lastQuant or nil
                if lastQuant and currentValue > lastQuant then
                    line:Flash()
                end
                line._lastQuant = currentValue
            end

            visibleObjectives = visibleObjectives + 1
        end
    end

    if visibleObjectives == 0 then
        button:AddLine(
            format("  %s", COMPLETE or "Complete"),
            nil,
            opt_colors.ObjectiveGradientComplete[1],
            opt_colors.ObjectiveGradientComplete[2],
            opt_colors.ObjectiveGradientComplete[3]
        )
    end

    if useNonBonusHeader and button._previousHeader then
        button._previousHeader.title:SetText(TRACKER_HEADER_OBJECTIVE)
    end

    if button.fresh then
        local lines = button.lines
        for i = 1, #lines do
            local line = lines[i]
            line:Glow(
                opt_colors.ObjectiveAlertGlow[1],
                opt_colors.ObjectiveAlertGlow[2],
                opt_colors.ObjectiveAlertGlow[3]
            )
        end
    end
end

-- -----------------------------------------------------------------------------
-- Dummy task handling
-- -----------------------------------------------------------------------------

function QuestKing:SetDummyTask(questID)
    local taggedTitle, _, questIndex = getQuestTitleAndLevelSafe(questID)

    local _, _, numObjectives = getTaskInfoSafe(questID)
    numObjectives = numObjectives or 0

    local useNonBonusHeader = false
    for i = 1, numObjectives do
        local _, _, _, displayAsObjective = getQuestObjectiveInfoCompat(questID, i, false)
        useNonBonusHeader = useNonBonusHeader or displayAsObjective
    end

    dummyTaskUseNonBonusHeader = useNonBonusHeader and true or false
    dummyTaskID = questID
    dummyTaskTaggedTitle = taggedTitle
    dummyTaskQuestIndex = questIndex
end

function QuestKing:ClearDummyTask(questID)
    if questID then
        if questID == dummyTaskID then
            dummyTaskID = nil
            dummyTaskTaggedTitle = nil
            dummyTaskQuestIndex = nil
            dummyTaskUseNonBonusHeader = nil
        end
    else
        dummyTaskID = nil
        dummyTaskTaggedTitle = nil
        dummyTaskQuestIndex = nil
        dummyTaskUseNonBonusHeader = nil
    end
end

function setButtonToDummyTask(button, questID)
    button.questID = questID
    button.questIndex = dummyTaskQuestIndex or getQuestLogIndexByIDSafe(questID)
    button.questLogIndex = button.questIndex
    button.title:SetFormattedTextIcon("|TInterface\\RAIDFRAME\\ReadyCheck-Ready:0:0:1:1|t %s", dummyTaskTaggedTitle or UNKNOWN)
    button.title:SetTextColor(
        opt_colors.ObjectiveComplete[1],
        opt_colors.ObjectiveComplete[2],
        opt_colors.ObjectiveComplete[3]
    )

    if dummyTaskUseNonBonusHeader and button._previousHeader then
        button._previousHeader.title:SetText(TRACKER_HEADER_OBJECTIVE)
    end
end

function QuestKing:OnTaskTurnedIn(questID, xp, money)
    local button = WatchButton:GetKeyedRaw("bonus_task", questID)
    QuestKing:AddReward(button, questID, xp or 0, money or 0)
    QuestKing:SetDummyTask(questID)
end

-- -----------------------------------------------------------------------------
-- Scenario criteria completion
-- -----------------------------------------------------------------------------

function QuestKing:OnCriteriaComplete(id)
    if not id or id == 0 then
        return
    end

    if not C_Scenario or not C_Scenario.GetBonusSteps then
        return
    end

    local tblBonusSteps = C_Scenario.GetBonusSteps() or {}
    for i = 1, #tblBonusSteps do
        local bonusStepIndex = tblBonusSteps[i]
        local button = WatchButton:GetKeyedRaw("bonus_step", bonusStepIndex)

        local _, _, numCriteria = C_Scenario.GetStepInfo(bonusStepIndex)
        numCriteria = SafePublicNumber(numCriteria, 0)

        local matchedCriteria = false
        local allCriteriaComplete = numCriteria > 0

        for criteriaIndex = 1, numCriteria do
            local _, _, criteriaCompleted, _, _, _, _, _, criteriaID = C_Scenario.GetCriteriaInfoByStep(bonusStepIndex, criteriaIndex)

            if criteriaID == id then
                matchedCriteria = true
            end

            if not criteriaCompleted then
                allCriteriaComplete = false
            end
        end

        if matchedCriteria and allCriteriaComplete then
            PlaySoundCompat(SOUNDKIT and SOUNDKIT.UI_SCENARIO_BONUS_OBJECTIVE_COMPLETE, "UI_Scenario_BonusObjective_Success")

            local questID = C_Scenario.GetBonusStepRewardQuestID and C_Scenario.GetBonusStepRewardQuestID(bonusStepIndex) or 0
            if questID ~= 0 then
                QuestKing:AddReward(button, questID)
            end
            return
        end
    end
end

-- -----------------------------------------------------------------------------
-- Mouse handlers
-- -----------------------------------------------------------------------------

function mouseHandlerBonusTask:TitleButtonOnClick(mouse, down)
    local button = self.parent

    if IsModifiedClick and IsModifiedClick("CHATLINK") and ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow() then
        local questLink
        if button.questIndex and GetQuestLink then
            questLink = GetQuestLink(button.questIndex)
        end
        if questLink then
            ChatEdit_InsertLink(questLink)
            return
        end
    end

    if IsShiftKeyDown and IsShiftKeyDown() and ClassicQuestLog and button.questIndex then
        SelectQuestLogEntry(button.questIndex)
        if ClassicQuestLog:IsVisible() then
            ClassicQuestLog:OnShow()
        else
            ClassicQuestLog:SetShown(true)
        end
        return
    end

    if mouse == "RightButton" then
        if getSuperTrackedQuestIDSafe() == button.questID then
            QuestKing:SetSuperTrackedQuestID(0)
        else
            QuestKing:SetSuperTrackedQuestID(button.questID)
        end
        QuestKing:UpdateTracker()
        return
    end

    if QuestObjectiveTracker_OpenQuestMap and button.questIndex then
        QuestObjectiveTracker_OpenQuestMap(nil, button.questIndex)
    elseif QuestMapFrame_OpenToQuestDetails and button.questID then
        QuestMapFrame_OpenToQuestDetails(button.questID)
    end
end

function mouseHandlerBonusTask:TitleButtonOnEnter(motion)
    local button = self.parent
    local questID = button.questID

    local hasQuestData = hasQuestDataSafe(questID)
    local xp = getRewardXPCompat(questID)
    local numQuestCurrencies = getNumRewardCurrenciesCompat(questID)
    local numQuestRewards = getNumRewardsCompat(questID)
    local money = getRewardMoneyCompat(questID)

    if hasQuestData and xp == 0 and numQuestCurrencies == 0 and numQuestRewards == 0 and money == 0 then
        GameTooltip:Hide()
        return
    end

    GameTooltip:ClearAllPoints()
    GameTooltip:SetOwner(button, opt.tooltipAnchor)
    GameTooltip:SetText(REWARDS, 1, 0.831, 0.380)

    if opt.tooltipScale then
        GameTooltip:SetScale(opt.tooltipScale)
    end

    if not hasQuestData then
        GameTooltip:AddLine(RETRIEVING_DATA, RED_FONT_COLOR.r, RED_FONT_COLOR.g, RED_FONT_COLOR.b)
    else
        GameTooltip:AddLine(BONUS_OBJECTIVE_TOOLTIP_DESCRIPTION, 1, 1, 1, 1)
        GameTooltip:AddLine(" ")

        if xp > 0 then
            GameTooltip:AddLine(format(BONUS_OBJECTIVE_EXPERIENCE_FORMAT, xp), 1, 1, 1)
        end

        for i = 1, numQuestCurrencies do
            local name, texture, numItems = getRewardCurrencyInfoCompat(i, questID)
            if name and texture and numItems then
                local text = format(BONUS_OBJECTIVE_REWARD_WITH_COUNT_FORMAT, texture, numItems, name)
                GameTooltip:AddLine(text, 1, 1, 1)
            end
        end

        for i = 1, numQuestRewards do
            local name, texture, numItems, quality = getRewardInfoCompat(i, questID)
            local text

            if numItems and numItems > 1 and texture and name then
                text = format(BONUS_OBJECTIVE_REWARD_WITH_COUNT_FORMAT, texture, numItems, name)
            elseif texture and name then
                text = format(BONUS_OBJECTIVE_REWARD_FORMAT, texture, name)
            end

            if text then
                local color = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
                if color then
                    GameTooltip:AddLine(text, color.r, color.g, color.b)
                else
                    GameTooltip:AddLine(text, 1, 1, 1)
                end
            end
        end

        if money > 0 and SetTooltipMoney then
            SetTooltipMoney(GameTooltip, money, nil)
        end
    end

    GameTooltip:Show()
end