local addonName, QuestKing = ...

local EventsFrame = CreateFrame("Frame")
local Events = {}

QuestKing.EventsFrame = EventsFrame
QuestKing.Events = Events

local _G = _G
local C_CVar = C_CVar
local C_QuestLog = C_QuestLog
local C_SuperTrack = C_SuperTrack
local C_TaskQuest = C_TaskQuest
local C_Timer = C_Timer
local Enum = Enum
local SOUNDKIT = SOUNDKIT

local pairs = pairs
local pcall = pcall
local select = select
local type = type
local tonumber = tonumber

local Compat = QuestKing.Compatibility or {}
local WOW_PROJECT_ID = _G.WOW_PROJECT_ID
local WOW_PROJECT_MAINLINE = _G.WOW_PROJECT_MAINLINE
local IS_MAINLINE = WOW_PROJECT_MAINLINE and WOW_PROJECT_ID == WOW_PROJECT_MAINLINE or false

local trackerRefreshQueued = false
local trackerRefreshFollowupQueued = false

local function SafeCall(func, ...)
    if type(func) ~= "function" then
        return false, nil, nil, nil, nil
    end

    local ok, a, b, c, d = pcall(func, ...)
    if ok then
        return true, a, b, c, d
    end

    if _G.geterrorhandler then
        _G.geterrorhandler()(a)
    end

    return false, nil, nil, nil, nil
end

local function SafeCallMethod(target, method, ...)
    if type(target) ~= "table" then
        return false, nil, nil, nil, nil
    end

    local func = target[method]
    if type(func) ~= "function" then
        return false, nil, nil, nil, nil
    end

    return SafeCall(func, target, ...)
end

local function RegisterEventSafe(frame, eventName)
    if not frame or type(eventName) ~= "string" or eventName == "" then
        return false
    end

    local ok = pcall(frame.RegisterEvent, frame, eventName)
    return ok and true or false
end

local function PlaySoundSafe(soundKitID, legacyFallback)
    if type(_G.PlaySound) ~= "function" then
        return
    end

    if soundKitID then
        pcall(_G.PlaySound, soundKitID)
        return
    end

    if legacyFallback then
        pcall(_G.PlaySound, legacyFallback)
    end
end

local function GetCVarBoolCompat(name)
    if type(name) ~= "string" or name == "" then
        return false
    end

    if C_CVar and C_CVar.GetCVarBool then
        local ok, value = SafeCall(C_CVar.GetCVarBool, name)
        if ok then
            return value and true or false
        end
    end

    if type(_G.GetCVar) == "function" then
        local ok, value = SafeCall(_G.GetCVar, name)
        if ok then
            return value == "1"
        end
    end

    return false
end

local function GetNumQuestWatchesCompat()
    if type(Compat.GetNumQuestWatches) == "function" then
        local count = Compat.GetNumQuestWatches()
        return tonumber(count) or 0
    end

    if C_QuestLog and C_QuestLog.GetNumQuestWatches then
        local ok, count = SafeCall(C_QuestLog.GetNumQuestWatches)
        if ok then
            return tonumber(count) or 0
        end
    end

    if type(_G.GetNumQuestWatches) == "function" then
        local ok, count = SafeCall(_G.GetNumQuestWatches)
        if ok then
            return tonumber(count) or 0
        end
    end

    return 0
end

local function GetMaxQuestWatchesCompat()
    return (type(_G.MAX_WATCHABLE_QUESTS) == "number" and _G.MAX_WATCHABLE_QUESTS > 0) and _G.MAX_WATCHABLE_QUESTS or 25
end

local function GetQuestLogIndexByIDCompat(questID)
    if type(Compat.GetQuestLogIndexByID) == "function" then
        return Compat.GetQuestLogIndexByID(questID)
    end

    if type(questID) ~= "number" or questID <= 0 then
        return nil
    end

    if C_QuestLog and C_QuestLog.GetLogIndexForQuestID then
        local ok, index = SafeCall(C_QuestLog.GetLogIndexForQuestID, questID)
        if ok and type(index) == "number" and index > 0 then
            return index
        end
    end

    if type(_G.GetQuestLogIndexByID) == "function" then
        local ok, index = SafeCall(_G.GetQuestLogIndexByID, questID)
        if ok and type(index) == "number" and index > 0 then
            return index
        end
    end

    return nil
end

local function GetQuestIDFromQuestLogIndexCompat(questLogIndex)
    if type(Compat.GetQuestIDForLogIndex) == "function" then
        return Compat.GetQuestIDForLogIndex(questLogIndex)
    end

    if type(questLogIndex) ~= "number" or questLogIndex <= 0 then
        return nil
    end

    if C_QuestLog and C_QuestLog.GetInfo then
        local ok, info = SafeCall(C_QuestLog.GetInfo, questLogIndex)
        if ok and type(info) == "table" and type(info.questID) == "number" and info.questID > 0 then
            return info.questID
        end
    end

    if type(_G.GetQuestLogTitle) == "function" then
        local ok, _, _, _, _, _, _, _, questID = SafeCall(_G.GetQuestLogTitle, questLogIndex)
        if ok and type(questID) == "number" and questID > 0 then
            return questID
        end
    end

    return nil
end

local function GetQuestIDForWatchIndexCompat(watchIndex)
    if type(Compat.GetQuestIDForWatchIndex) == "function" then
        return Compat.GetQuestIDForWatchIndex(watchIndex)
    end

    if type(watchIndex) ~= "number" or watchIndex <= 0 then
        return nil
    end

    if C_QuestLog and C_QuestLog.GetQuestIDForQuestWatchIndex then
        local ok, questID = SafeCall(C_QuestLog.GetQuestIDForQuestWatchIndex, watchIndex)
        if ok and type(questID) == "number" and questID > 0 then
            return questID
        end
    end

    if type(_G.GetQuestIndexForWatch) == "function" then
        local ok, questLogIndex = SafeCall(_G.GetQuestIndexForWatch, watchIndex)
        if ok and type(questLogIndex) == "number" and questLogIndex > 0 then
            return GetQuestIDFromQuestLogIndexCompat(questLogIndex)
        end
    end

    return nil
end

local function IsQuestWatchedCompat(questID, questLogIndex)
    if type(Compat.IsQuestWatched) == "function" and questID then
        return Compat.IsQuestWatched(questID) and true or false
    end

    if type(questID) == "number" and C_QuestLog and C_QuestLog.IsQuestWatched then
        local ok, watched = SafeCall(C_QuestLog.IsQuestWatched, questID)
        if ok then
            return watched and true or false
        end
    end

    if type(questLogIndex) == "number" and type(_G.IsQuestWatched) == "function" then
        local ok, watched = SafeCall(_G.IsQuestWatched, questLogIndex)
        if ok then
            return watched and true or false
        end
    end

    return false
end

local function AddQuestWatchCompat(questLogIndex, questID)
    if type(Compat.AddQuestWatch) == "function" and questID then
        return Compat.AddQuestWatch(questID) and true or false
    end

    if type(questID) ~= "number" or questID <= 0 then
        questID = GetQuestIDFromQuestLogIndexCompat(questLogIndex)
    end

    if type(questID) == "number" and C_QuestLog and C_QuestLog.AddQuestWatch then
        local ok = SafeCall(C_QuestLog.AddQuestWatch, questID)
        return ok and true or false
    end

    if type(questLogIndex) == "number" and questLogIndex > 0 and type(_G.AddQuestWatch) == "function" then
        local ok = SafeCall(_G.AddQuestWatch, questLogIndex)
        return ok and true or false
    end

    return false
end

local function RemoveQuestWatchCompat(questLogIndex, questID)
    if type(Compat.RemoveQuestWatch) == "function" and questID then
        return Compat.RemoveQuestWatch(questID) and true or false
    end

    if type(questID) ~= "number" or questID <= 0 then
        questID = GetQuestIDFromQuestLogIndexCompat(questLogIndex)
    end

    if type(questID) == "number" and C_QuestLog and C_QuestLog.RemoveQuestWatch then
        local ok = SafeCall(C_QuestLog.RemoveQuestWatch, questID)
        return ok and true or false
    end

    if type(questLogIndex) == "number" and questLogIndex > 0 and type(_G.RemoveQuestWatch) == "function" then
        local ok = SafeCall(_G.RemoveQuestWatch, questLogIndex)
        return ok and true or false
    end

    return false
end

local function GetSuperTrackedQuestIDCompat()
    if type(Compat.GetSuperTrackedQuestID) == "function" then
        local questID = Compat.GetSuperTrackedQuestID()
        return tonumber(questID) or 0
    end

    if C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID then
        local ok, questID = SafeCall(C_SuperTrack.GetSuperTrackedQuestID)
        if ok then
            return tonumber(questID) or 0
        end
    end

    if type(_G.GetSuperTrackedQuestID) == "function" then
        local ok, questID = SafeCall(_G.GetSuperTrackedQuestID)
        if ok then
            return tonumber(questID) or 0
        end
    end

    return 0
end

local function IsTaskQuestCompat(questID)
    if type(questID) ~= "number" or questID <= 0 then
        return false
    end

    if C_QuestLog and C_QuestLog.IsQuestTask then
        local ok, isTask = SafeCall(C_QuestLog.IsQuestTask, questID)
        if ok then
            return isTask and true or false
        end
    end

    if C_TaskQuest and C_TaskQuest.IsActive then
        local ok, isTask = SafeCall(C_TaskQuest.IsActive, questID)
        if ok then
            return isTask and true or false
        end
    end

    if type(_G.IsQuestTask) == "function" then
        local ok, isTask = SafeCall(_G.IsQuestTask, questID)
        if ok then
            return isTask and true or false
        end
    end

    return false
end

local function IsPreyQuestCompat(questID)
    if type(questID) ~= "number" or questID <= 0 then
        return false
    end

    if C_QuestLog and C_QuestLog.GetActivePreyQuest then
        local ok, activeQuestID = SafeCall(C_QuestLog.GetActivePreyQuest)
        if ok and activeQuestID == questID then
            return true
        end
    end

    return false
end

local function IsAutoCompleteQuestCompat(questID, questLogIndex)
    if type(questID) == "number" and C_QuestLog and C_QuestLog.IsAutoComplete then
        local ok, isAutoComplete = SafeCall(C_QuestLog.IsAutoComplete, questID)
        if ok then
            return isAutoComplete and true or false
        end
    end

    if (type(questLogIndex) ~= "number" or questLogIndex <= 0) and type(questID) == "number" then
        questLogIndex = GetQuestLogIndexByIDCompat(questID)
    end

    if type(questLogIndex) == "number" and type(_G.GetQuestLogIsAutoComplete) == "function" then
        local ok, isAutoComplete = SafeCall(_G.GetQuestLogIsAutoComplete, questLogIndex)
        if ok then
            return isAutoComplete and true or false
        end
    end

    return false
end

local function NormalizeQuestAcceptedPayload(...)
    local arg1 = select(1, ...)
    local arg2 = select(2, ...)

    if type(arg2) == "number" and arg2 > 0 then
        local questLogIndex = type(arg1) == "number" and arg1 or nil
        local questID = arg2

        if type(questLogIndex) ~= "number" or questLogIndex <= 0 then
            questLogIndex = GetQuestLogIndexByIDCompat(questID)
        end

        return questLogIndex, questID
    end

    if type(arg1) ~= "number" or arg1 <= 0 then
        return nil, nil
    end

    if IS_MAINLINE then
        return GetQuestLogIndexByIDCompat(arg1), arg1
    end

    local questIDFromIndex = GetQuestIDFromQuestLogIndexCompat(arg1)
    if type(questIDFromIndex) == "number" and questIDFromIndex > 0 then
        return arg1, questIDFromIndex
    end

    local questLogIndexFromID = GetQuestLogIndexByIDCompat(arg1)
    if type(questLogIndexFromID) == "number" and questLogIndexFromID > 0 then
        return questLogIndexFromID, arg1
    end

    return arg1, nil
end

local function QueueTrackerRefresh(delay, isFollowup)
    if not (C_Timer and C_Timer.After) then
        SafeCallMethod(QuestKing, "QueueTrackerUpdate", false, false)
        SafeCallMethod(QuestKing, "UpdateTracker")
        return
    end

    if isFollowup then
        if trackerRefreshFollowupQueued then
            return
        end
        trackerRefreshFollowupQueued = true
    else
        if trackerRefreshQueued then
            return
        end
        trackerRefreshQueued = true
    end

    C_Timer.After(delay or 0, function()
        if isFollowup then
            trackerRefreshFollowupQueued = false
        else
            trackerRefreshQueued = false
        end

        if not SafeCallMethod(QuestKing, "QueueTrackerUpdate", false, false) then
            SafeCallMethod(QuestKing, "UpdateTracker")
        end
    end)
end

local function UpdateTracker(forceBuild)
    if not SafeCallMethod(QuestKing, "QueueTrackerUpdate", forceBuild and true or false, false) then
        SafeCallMethod(QuestKing, "UpdateTracker", forceBuild and true or false, false)
    end
end

local function QueueQuestStateRefresh()
    QueueTrackerRefresh(0, false)
    QueueTrackerRefresh(0.15, true)
end

local function UpdateTrackerAndQueueQuestStateRefresh()
    UpdateTracker(false)
    QueueQuestStateRefresh()
end

local function TryAutoWatchQuest(questLogIndex, questID, didRetry)
    if not GetCVarBoolCompat("autoQuestWatch") then
        return false
    end

    if (type(questID) ~= "number" or questID <= 0) and type(questLogIndex) == "number" then
        questID = GetQuestIDFromQuestLogIndexCompat(questLogIndex)
    end

    if (type(questLogIndex) ~= "number" or questLogIndex <= 0) and type(questID) == "number" then
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

            if (type(retryQuestID) ~= "number" or retryQuestID <= 0) and type(retryQuestLogIndex) == "number" then
                retryQuestID = GetQuestIDFromQuestLogIndexCompat(retryQuestLogIndex)
            end

            if (type(retryQuestLogIndex) ~= "number" or retryQuestLogIndex <= 0) and type(retryQuestID) == "number" then
                retryQuestLogIndex = GetQuestLogIndexByIDCompat(retryQuestID)
            end

            if TryAutoWatchQuest(retryQuestLogIndex, retryQuestID, true) then
                UpdateTracker(true)
            end
        end)
    end

    return false
end

local function RefreshScenarioCriteriaState(shouldShow)
    if type(shouldShow) == "boolean" then
        QuestKing.scenarioShouldShowCriteria = shouldShow
        return shouldShow
    end

    local ok, result = SafeCallMethod(QuestKing, "RefreshShouldShowScenarioCriteria")
    if ok then
        return result
    end

    return nil
end

function QuestKing:SetScenarioCriteriaVisibility(shouldShow)
    return RefreshScenarioCriteriaState(shouldShow)
end

local function RefreshScenarioAndUpdate(shouldShow)
    RefreshScenarioCriteriaState(shouldShow)
    UpdateTracker(false)
end

local function DispatchEvent(self, event, ...)
    local handler = Events[event]
    if type(handler) ~= "function" then
        return
    end

    local ok, err = pcall(handler, self, event, ...)
    if not ok and _G.geterrorhandler then
        _G.geterrorhandler()(err)
    end
end

local function OnAddonLoaded(self, event, loadedAddonName)
    if loadedAddonName ~= addonName then
        return
    end

    self:UnregisterEvent("ADDON_LOADED")

    for eventName in pairs(Events) do
        RegisterEventSafe(self, eventName)
    end

    self:SetScript("OnEvent", DispatchEvent)
    SafeCallMethod(QuestKing, "Init")
end

EventsFrame:SetScript("OnEvent", OnAddonLoaded)
EventsFrame:RegisterEvent("ADDON_LOADED")

QuestKing.HandleEvent = DispatchEvent

Events.CHAT_MSG_LOOT = function(self, event, ...)
    SafeCallMethod(QuestKing, "ParseLoot", ...)
end

Events.PLAYER_MONEY = function()
    if QuestKing.watchMoney then
        UpdateTracker(false)
    end
end

Events.QUEST_LOG_UPDATE = UpdateTrackerAndQueueQuestStateRefresh
Events.QUEST_WATCH_LIST_CHANGED = UpdateTrackerAndQueueQuestStateRefresh
Events.QUEST_DATA_LOAD_RESULT = UpdateTrackerAndQueueQuestStateRefresh
Events.CONTENT_TRACKING_UPDATE = function()
    SafeCallMethod(QuestKing, "OnTrackedAchievementListChanged")
    UpdateTracker(false)
end
Events.TRACKED_ACHIEVEMENT_LIST_CHANGED = function()
    if not SafeCallMethod(QuestKing, "OnTrackedAchievementListChanged") then
        UpdateTracker(false)
    end
end
Events.TRACKED_ACHIEVEMENT_UPDATE = function(self, event, ...)
    if not SafeCallMethod(QuestKing, "OnTrackedAchievementUpdate", ...) then
        UpdateTracker(false)
    end
end
Events.CRITERIA_UPDATE = function()
    SafeCallMethod(QuestKing, "OnAchievementCriteriaUpdate")
end
Events.ACHIEVEMENT_EARNED = function()
    SafeCallMethod(QuestKing, "OnAchievementEarned")
end

Events.QUEST_WATCH_UPDATE = function(self, event, questID)
    SafeCallMethod(QuestKing, "OnQuestObjectivesCompleted", questID)
    UpdateTrackerAndQueueQuestStateRefresh()
end

Events.UNIT_QUEST_LOG_CHANGED = function(self, event, unit)
    if unit == "player" then
        UpdateTrackerAndQueueQuestStateRefresh()
    end
end

Events.QUEST_POI_UPDATE = function()
    if not SafeCallMethod(QuestKing, "OnPOIUpdate") then
        UpdateTracker(false)
    end
end

Events.QUEST_ACCEPTED = function(self, event, ...)
    local questLogIndex, questID = NormalizeQuestAcceptedPayload(...)
    local isTaskQuest = IsTaskQuestCompat(questID)

    TryAutoWatchQuest(questLogIndex, questID, false)

    if isTaskQuest then
        PlaySoundSafe(SOUNDKIT and SOUNDKIT.UI_SCENARIO_STAGE_END, nil)
    end

    if not SafeCallMethod(QuestKing, "OnQuestAccepted", questID) then
        UpdateTracker(false)
    end

    QueueQuestStateRefresh()
end

Events.QUEST_REMOVED = function(self, event, questID)
    SafeCallMethod(QuestKing, "ClearDummyTask", questID)
    UpdateTrackerAndQueueQuestStateRefresh()
end

Events.QUEST_AUTOCOMPLETE = function(self, event, questID)
    local questLogIndex = GetQuestLogIndexByIDCompat(questID)

    if IsAutoCompleteQuestCompat(questID, questLogIndex) and type(_G.AddAutoQuestPopUp) == "function" then
        local ok, shown = SafeCall(_G.AddAutoQuestPopUp, questID, "COMPLETE")
        if ok and shown then
            PlaySoundSafe(SOUNDKIT and SOUNDKIT.UI_AUTO_QUEST_COMPLETE, nil)
        end
    end

    UpdateTrackerAndQueueQuestStateRefresh()
end

Events.QUEST_TURNED_IN = function(self, event, questID, xp, money)
    if IsTaskQuestCompat(questID) or IsPreyQuestCompat(questID) then
        SafeCallMethod(QuestKing, "OnTaskTurnedIn", questID, xp, money)
    end

    UpdateTrackerAndQueueQuestStateRefresh()
end

Events.QUEST_COMPLETE = UpdateTrackerAndQueueQuestStateRefresh
Events.QUEST_FINISHED = UpdateTrackerAndQueueQuestStateRefresh

Events.SCENARIO_UPDATE = function(self, event, ...)
    RefreshScenarioCriteriaState()

    if not SafeCallMethod(QuestKing, "OnScenarioUpdate", ...) then
        UpdateTracker(false)
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
    if not SafeCallMethod(QuestKing, "OnCriteriaComplete", ...) then
        RefreshScenarioAndUpdate()
    end
end

Events.SCENARIO_COMPLETED = function(self, event, ...)
    RefreshScenarioCriteriaState()
    SafeCallMethod(QuestKing, "OnScenarioCompleted", ...)
    UpdateTracker(false)
end

Events.PROVING_GROUNDS_SCORE_UPDATE = function(self, event, score)
    if not SafeCallMethod(QuestKing, "ProvingGroundsScoreUpdate", score) then
        UpdateTracker(false)
    end
end

Events.WORLD_STATE_TIMER_START = function()
    UpdateTracker(false)
end
Events.WORLD_STATE_TIMER_STOP = function()
    UpdateTracker(false)
end

Events.PLAYER_ENTERING_WORLD = function()
    RefreshScenarioCriteriaState()
    SafeCallMethod(QuestKing, "OnPlayerEnteringWorld")
    UpdateTrackerAndQueueQuestStateRefresh()
end

Events.PLAYER_LEVEL_UP = function(self, event, ...)
    if not SafeCallMethod(QuestKing, "OnPlayerLevelUp", ...) then
        UpdateTracker(false)
    end
end

Events.PLAYER_DEAD = UpdateTrackerAndQueueQuestStateRefresh
Events.PLAYER_ALIVE = UpdateTrackerAndQueueQuestStateRefresh
Events.PLAYER_UNGHOST = UpdateTrackerAndQueueQuestStateRefresh
Events.ZONE_CHANGED_NEW_AREA = function()
    UpdateTracker(false)
end

Events.SUPER_TRACKING_CHANGED = function()
    local questID = GetSuperTrackedQuestIDCompat()
    if not SafeCallMethod(QuestKing, "OnSuperTrackedQuestChanged", questID) then
        UpdateTracker(false)
    end
end

Events.SUPER_TRACKING_PATH_UPDATED = function()
    UpdateTracker(false)
end

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
