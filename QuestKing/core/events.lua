-- events.lua - QuestKing
-- Patched to support the validated tracker flow:
--   - normal quests
--   - campaign quests
--   - task / bonus objective quests
--   - world quests
--   - special assignments
--   - prey quests
--   - scenarios
--   - timers / challenge content
--
-- Additional scenario integration fixes:
--   - refreshes scenario criteria visibility cache on scenario events
--   - handles SCENARIO_CRITERIA_SHOW_STATE_UPDATE explicitly
--   - keeps scenario tracker state in sync when entering world / completing scenarios

local addonName, QuestKing = ...

-- -----------------------------------------------------------------------------
-- Frame & Tables
-- -----------------------------------------------------------------------------

local EventsFrame = CreateFrame("Frame", "QuestKing_EventsFrame")
local Events = {}

QuestKing.EventsFrame = EventsFrame
QuestKing.Events = Events

local pairs = pairs
local type = type

-- -----------------------------------------------------------------------------
-- Compat / Helpers
-- -----------------------------------------------------------------------------

local function PlaySoundSafe(kit)
    if not kit or not PlaySound then
        return
    end

    if SOUNDKIT then
        PlaySound(kit)
        return
    end

    if type(kit) == "string" or type(kit) == "number" then
        PlaySound(kit)
    end
end

local function IsTaskQuestCompat(questID)
    if not questID then
        return false
    end

    if C_QuestLog and C_QuestLog.IsQuestTask then
        return C_QuestLog.IsQuestTask(questID) and true or false
    end

    if C_TaskQuest and C_TaskQuest.IsActive then
        return C_TaskQuest.IsActive(questID) and true or false
    end

    if _G.IsQuestTask then
        return _G.IsQuestTask(questID) and true or false
    end

    return false
end

local function GetCVarBoolCompat(name)
    if not name or name == "" then
        return false
    end

    if C_CVar and C_CVar.GetCVarBool then
        return C_CVar.GetCVarBool(name) and true or false
    end

    if GetCVar then
        return GetCVar(name) == "1"
    end

    return false
end

local function GetNumQuestWatchesCompat()
    if C_QuestLog and C_QuestLog.GetNumQuestWatches then
        return C_QuestLog.GetNumQuestWatches() or 0
    end

    if _G.GetNumQuestWatches then
        return _G.GetNumQuestWatches() or 0
    end

    return 0
end

local function GetMaxQuestWatchesCompat()
    if type(MAX_WATCHABLE_QUESTS) == "number" and MAX_WATCHABLE_QUESTS > 0 then
        return MAX_WATCHABLE_QUESTS
    end

    return 25
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

    if _G.GetQuestLogIndexByID then
        local index = _G.GetQuestLogIndexByID(questID)
        if index and index > 0 then
            return index
        end
    end

    return nil
end

local function GetQuestIDFromQuestLogIndexCompat(questLogIndex)
    if not questLogIndex or questLogIndex <= 0 then
        return nil
    end

    if C_QuestLog and C_QuestLog.GetInfo then
        local info = C_QuestLog.GetInfo(questLogIndex)
        if info and info.questID then
            return info.questID
        end
    end

    if _G.GetQuestLogTitle then
        local _, _, _, _, _, _, _, questID = _G.GetQuestLogTitle(questLogIndex)
        if questID then
            return questID
        end
    end

    return nil
end

local function NormalizeQuestAcceptedPayload(...)
    local a, b = ...

    -- Mainline / Retail / Midnight:
    -- QUEST_ACCEPTED(questID)
    if b == nil then
        local questID = a
        local questLogIndex = GetQuestLogIndexByIDCompat(questID)
        return questLogIndex, questID
    end

    -- Classic-style payload:
    -- QUEST_ACCEPTED(questLogIndex, questID)
    return a, b
end

local function IsQuestWatchedCompat(questID, questLogIndex)
    if questID and C_QuestLog and C_QuestLog.IsQuestWatched then
        return C_QuestLog.IsQuestWatched(questID) and true or false
    end

    if questLogIndex and _G.IsQuestWatched then
        return _G.IsQuestWatched(questLogIndex) and true or false
    end

    return false
end

local function AddQuestWatchCompat(questLogIndex, questID)
    if C_QuestLog and C_QuestLog.AddQuestWatch then
        if not questID then
            questID = GetQuestIDFromQuestLogIndexCompat(questLogIndex)
        end

        if questID then
            return C_QuestLog.AddQuestWatch(questID) and true or false
        end

        return false
    end

    if _G.AddQuestWatch and questLogIndex then
        _G.AddQuestWatch(questLogIndex)
        return true
    end

    return false
end

local function RemoveQuestWatchCompat(questLogIndex, questID)
    if C_QuestLog and C_QuestLog.RemoveQuestWatch then
        if not questID then
            questID = GetQuestIDFromQuestLogIndexCompat(questLogIndex)
        end

        if questID then
            return C_QuestLog.RemoveQuestWatch(questID) and true or false
        end

        return false
    end

    if _G.RemoveQuestWatch and questLogIndex then
        _G.RemoveQuestWatch(questLogIndex)
        return true
    end

    return false
end

local function GetQuestIDForWatchIndexCompat(watchIndex)
    if not watchIndex or watchIndex <= 0 then
        return nil
    end

    if C_QuestLog and C_QuestLog.GetQuestIDForQuestWatchIndex then
        return C_QuestLog.GetQuestIDForQuestWatchIndex(watchIndex)
    end

    if _G.GetQuestIndexForWatch and _G.GetQuestLogTitle then
        local questLogIndex = _G.GetQuestIndexForWatch(watchIndex)
        if questLogIndex then
            local _, _, _, _, _, _, _, questID = _G.GetQuestLogTitle(questLogIndex)
            return questID
        end
    end

    return nil
end

local function GetSuperTrackedQuestIDCompat()
    if C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID then
        return C_SuperTrack.GetSuperTrackedQuestID() or 0
    end

    if _G.GetSuperTrackedQuestID then
        return _G.GetSuperTrackedQuestID() or 0
    end

    return 0
end

local function IsPreyQuestCompat(questID)
    if not questID then
        return false
    end

    if C_QuestLog and C_QuestLog.GetActivePreyQuest then
        return C_QuestLog.GetActivePreyQuest() == questID
    end

    return false
end

local questRefreshToken = 0

local function UpdateTracker()
    if QuestKing and QuestKing.UpdateTracker then
        QuestKing:UpdateTracker()
    end
end

local function QueueQuestStateRefresh()
    if not (C_Timer and C_Timer.After) then
        return
    end

    questRefreshToken = questRefreshToken + 1
    local token = questRefreshToken

    local function RunIfCurrent()
        if token ~= questRefreshToken then
            return
        end

        UpdateTracker()
    end

    C_Timer.After(0, RunIfCurrent)
    C_Timer.After(0.15, RunIfCurrent)
end

local function UpdateTrackerAndQueueQuestStateRefresh()
    UpdateTracker()
    QueueQuestStateRefresh()
end

local function TryAutoWatchQuest(questLogIndex, questID, didRetry)
    if not GetCVarBoolCompat("autoQuestWatch") then
        return false
    end

    if not questID and questLogIndex then
        questID = GetQuestIDFromQuestLogIndexCompat(questLogIndex)
    end

    if not questLogIndex and questID then
        questLogIndex = GetQuestLogIndexByIDCompat(questID)
    end

    if IsQuestWatchedCompat(questID, questLogIndex) then
        return true
    end

    if GetNumQuestWatchesCompat() >= GetMaxQuestWatchesCompat() then
        return false
    end

    if AddQuestWatchCompat(questLogIndex, questID) then
        return true
    end

    if not didRetry and C_Timer and C_Timer.After then
        C_Timer.After(0, function()
            local retryQuestID = questID
            local retryQuestLogIndex = questLogIndex

            if not retryQuestID and retryQuestLogIndex then
                retryQuestID = GetQuestIDFromQuestLogIndexCompat(retryQuestLogIndex)
            end

            if not retryQuestLogIndex and retryQuestID then
                retryQuestLogIndex = GetQuestLogIndexByIDCompat(retryQuestID)
            end

            if TryAutoWatchQuest(retryQuestLogIndex, retryQuestID, true) then
                if QuestKing and QuestKing.UpdateTracker then
                    QuestKing:UpdateTracker()
                end
            end
        end)
    end

    return false
end

local function RefreshScenarioCriteriaState(shouldShow)
    if not QuestKing then
        return nil
    end

    if type(shouldShow) == "boolean" then
        QuestKing.scenarioShouldShowCriteria = shouldShow
        return shouldShow
    end

    if QuestKing.RefreshShouldShowScenarioCriteria then
        return QuestKing:RefreshShouldShowScenarioCriteria()
    end

    return nil
end

function QuestKing:SetScenarioCriteriaVisibility(shouldShow)
    return RefreshScenarioCriteriaState(shouldShow)
end

local function RefreshScenarioAndUpdate(shouldShow)
    RefreshScenarioCriteriaState(shouldShow)
    UpdateTracker()
end

-- -----------------------------------------------------------------------------
-- Event bootstrap
-- -----------------------------------------------------------------------------

local function handleEvent(self, event, ...)
    local handler = Events[event]
    if handler then
        handler(self, event, ...)
    end
end

local function addonLoaded(self, event, name)
    if name ~= addonName then
        return
    end

    self:UnregisterEvent("ADDON_LOADED")

    for key in pairs(Events) do
        pcall(self.RegisterEvent, self, key)
    end

    self:SetScript("OnEvent", handleEvent)

    if QuestKing and QuestKing.Init then
        QuestKing:Init()
    end
end

EventsFrame:SetScript("OnEvent", addonLoaded)
EventsFrame:RegisterEvent("ADDON_LOADED")

QuestKing.HandleEvent = handleEvent

-- -----------------------------------------------------------------------------
-- Loot parsing / popup acquisition
-- -----------------------------------------------------------------------------

Events.CHAT_MSG_LOOT = function(self, event, ...)
    if QuestKing and QuestKing.ParseLoot then
        QuestKing:ParseLoot(...)
    end
end

-- -----------------------------------------------------------------------------
-- Money changes
-- -----------------------------------------------------------------------------

Events.PLAYER_MONEY = function()
    if QuestKing and QuestKing.watchMoney and QuestKing.UpdateTracker then
        QuestKing:UpdateTracker()
    end
end

-- -----------------------------------------------------------------------------
-- Quest / tracker update events
-- -----------------------------------------------------------------------------

Events.QUEST_LOG_UPDATE = UpdateTrackerAndQueueQuestStateRefresh
Events.QUEST_WATCH_LIST_CHANGED = UpdateTrackerAndQueueQuestStateRefresh

Events.QUEST_WATCH_UPDATE = function(self, event, questID)
    if QuestKing and QuestKing.OnQuestObjectivesCompleted then
        QuestKing:OnQuestObjectivesCompleted(questID)
    end

    UpdateTrackerAndQueueQuestStateRefresh()
end

Events.UNIT_QUEST_LOG_CHANGED = function(self, event, unit)
    if unit == "player" then
        UpdateTrackerAndQueueQuestStateRefresh()
    end
end

Events.QUEST_POI_UPDATE = function()
    if QuestKing and QuestKing.OnPOIUpdate then
        QuestKing:OnPOIUpdate()
    else
        UpdateTracker()
    end
end

Events.TRACKED_ACHIEVEMENT_LIST_CHANGED = UpdateTracker

Events.TRACKED_ACHIEVEMENT_UPDATE = function(self, event, ...)
    if QuestKing and QuestKing.OnTrackedAchievementUpdate then
        QuestKing:OnTrackedAchievementUpdate(...)
    else
        UpdateTracker()
    end
end

-- -----------------------------------------------------------------------------
-- Quest accepted / watch management
-- -----------------------------------------------------------------------------

Events.QUEST_ACCEPTED = function(self, event, ...)
    local questLogIndex, questID = NormalizeQuestAcceptedPayload(...)
    local isTaskQuest = IsTaskQuestCompat(questID)

    -- Respect Blizzard auto-watch for all newly accepted quests, including campaign and task quests.
    TryAutoWatchQuest(questLogIndex, questID, false)

    if isTaskQuest and SOUNDKIT and SOUNDKIT.UI_SCENARIO_STAGE_END then
        PlaySoundSafe(SOUNDKIT.UI_SCENARIO_STAGE_END)
    end

    if QuestKing and QuestKing.OnQuestAccepted then
        QuestKing:OnQuestAccepted(questID)
    else
        UpdateTracker()
    end

    QueueQuestStateRefresh()
end

Events.QUEST_REMOVED = function(self, event, questID)
    if QuestKing and QuestKing.ClearDummyTask then
        QuestKing:ClearDummyTask(questID)
    end

    UpdateTrackerAndQueueQuestStateRefresh()
end

-- -----------------------------------------------------------------------------
-- Quest completion / turn-in
-- -----------------------------------------------------------------------------

Events.QUEST_AUTOCOMPLETE = function(self, event, questID)
    if AddAutoQuestPopUp and AddAutoQuestPopUp(questID, "COMPLETE") then
        if SOUNDKIT and SOUNDKIT.UI_AUTO_QUEST_COMPLETE then
            PlaySoundSafe(SOUNDKIT.UI_AUTO_QUEST_COMPLETE)
        end
    end

    UpdateTrackerAndQueueQuestStateRefresh()
end

Events.QUEST_TURNED_IN = function(self, event, questID, xp, money)
    if QuestKing and QuestKing.OnTaskTurnedIn then
        if IsTaskQuestCompat(questID) or IsPreyQuestCompat(questID) then
            QuestKing:OnTaskTurnedIn(questID, xp, money)
        end
    end

    UpdateTrackerAndQueueQuestStateRefresh()
end

Events.QUEST_COMPLETE = UpdateTrackerAndQueueQuestStateRefresh
Events.QUEST_FINISHED = UpdateTrackerAndQueueQuestStateRefresh

-- -----------------------------------------------------------------------------
-- Scenario / bonus-step content
-- -----------------------------------------------------------------------------

Events.SCENARIO_UPDATE = function(self, event, ...)
    RefreshScenarioCriteriaState()

    if QuestKing and QuestKing.OnScenarioUpdate then
        QuestKing:OnScenarioUpdate(...)
    else
        UpdateTracker()
    end
end

Events.SCENARIO_CRITERIA_UPDATE = function()
    RefreshScenarioAndUpdate()
end

Events.SCENARIO_SPELL_UPDATE = function()
    RefreshScenarioAndUpdate()
end

Events.SCENARIO_CRITERIA_SHOW_STATE_UPDATE = function(self, event, shouldShow)
    RefreshScenarioAndUpdate(shouldShow)
end

Events.SCENARIO_POI_UPDATE = function()
    RefreshScenarioAndUpdate()
end

Events.SCENARIO_BONUS_VISIBILITY_UPDATE = function()
    RefreshScenarioAndUpdate()
end

Events.CRITERIA_COMPLETE = function(self, event, ...)
    if QuestKing and QuestKing.OnCriteriaComplete then
        QuestKing:OnCriteriaComplete(...)
    else
        RefreshScenarioAndUpdate()
    end
end

Events.SCENARIO_COMPLETED = function(self, event, ...)
    RefreshScenarioCriteriaState()

    if QuestKing and QuestKing.OnScenarioCompleted then
        QuestKing:OnScenarioCompleted(...)
    end

    UpdateTracker()
end

-- -----------------------------------------------------------------------------
-- Challenge / timer content
-- -----------------------------------------------------------------------------

Events.PROVING_GROUNDS_SCORE_UPDATE = function(self, event, score)
    if score and QuestKing and QuestKing.ProvingGroundsScoreUpdate then
        QuestKing.ProvingGroundsScoreUpdate(score)
    else
        UpdateTracker()
    end
end

Events.WORLD_STATE_TIMER_START = UpdateTracker
Events.WORLD_STATE_TIMER_STOP = UpdateTracker

-- -----------------------------------------------------------------------------
-- World / session transitions
-- -----------------------------------------------------------------------------

Events.PLAYER_ENTERING_WORLD = function()
    RefreshScenarioCriteriaState()

    if QuestKing and QuestKing.OnPlayerEnteringWorld then
        QuestKing:OnPlayerEnteringWorld()
    end

    UpdateTracker()
end

Events.PLAYER_LEVEL_UP = function(self, event, ...)
    if QuestKing and QuestKing.OnPlayerLevelUp then
        QuestKing:OnPlayerLevelUp(...)
    else
        UpdateTracker()
    end
end

-- -----------------------------------------------------------------------------
-- Super tracking
-- -----------------------------------------------------------------------------

Events.SUPER_TRACKING_CHANGED = function()
    local questID = GetSuperTrackedQuestIDCompat()

    if QuestKing and QuestKing.OnSuperTrackedQuestChanged then
        QuestKing:OnSuperTrackedQuestChanged(questID)
    else
        UpdateTracker()
    end
end

Events.SUPER_TRACKING_PATH_UPDATED = UpdateTracker

-- -----------------------------------------------------------------------------
-- Optional quest watch helpers exposed on addon table
-- -----------------------------------------------------------------------------

function QuestKing:AddQuestWatchByID(questID)
    local questLogIndex = GetQuestLogIndexByIDCompat(questID)
    return AddQuestWatchCompat(questLogIndex, questID)
end

function QuestKing:RemoveQuestWatchByID(questID)
    local questLogIndex = GetQuestLogIndexByIDCompat(questID)
    return RemoveQuestWatchCompat(questLogIndex, questID)
end

function QuestKing:GetQuestIDForWatchIndex(watchIndex)
    return GetQuestIDForWatchIndexCompat(watchIndex)
end