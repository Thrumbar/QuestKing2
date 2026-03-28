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

local addonName, QuestKing = ...

-- -----------------------------------------------------------------------------
-- Frame & Tables
-- -----------------------------------------------------------------------------

local EventsFrame = CreateFrame("Frame", "QuestKing_EventsFrame")
local Events = {}

QuestKing.EventsFrame = EventsFrame
QuestKing.Events = Events

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

    if type(kit) == "string" then
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

local function AddQuestWatchCompat(questLogIndex, questID)
    if C_QuestLog and C_QuestLog.AddQuestWatch then
        if not questID then
            questID = GetQuestIDFromQuestLogIndexCompat(questLogIndex)
        end

        if questID then
            if Enum and Enum.QuestWatchType and Enum.QuestWatchType.Automatic ~= nil then
                C_QuestLog.AddQuestWatch(questID, Enum.QuestWatchType.Automatic)
            else
                C_QuestLog.AddQuestWatch(questID)
            end
            return true
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
            C_QuestLog.RemoveQuestWatch(questID)
            return true
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

local function UpdateTracker()
    QuestKing:UpdateTracker()
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

    QuestKing:Init()
end

EventsFrame:SetScript("OnEvent", addonLoaded)
EventsFrame:RegisterEvent("ADDON_LOADED")

QuestKing.HandleEvent = handleEvent

-- -----------------------------------------------------------------------------
-- Loot parsing / popup acquisition
-- -----------------------------------------------------------------------------

Events.CHAT_MSG_LOOT = function(self, event, ...)
    QuestKing:ParseLoot(...)
end

-- -----------------------------------------------------------------------------
-- Money changes
-- -----------------------------------------------------------------------------

Events.PLAYER_MONEY = function()
    if QuestKing.watchMoney then
        QuestKing:UpdateTracker()
    end
end

-- -----------------------------------------------------------------------------
-- Quest / tracker update events
-- -----------------------------------------------------------------------------

Events.QUEST_LOG_UPDATE = UpdateTracker
Events.QUEST_WATCH_LIST_CHANGED = UpdateTracker

Events.QUEST_WATCH_UPDATE = function(self, event, questID)
    if QuestKing.OnQuestObjectivesCompleted then
        QuestKing:OnQuestObjectivesCompleted(questID)
    end
    QuestKing:UpdateTracker()
end

Events.UNIT_QUEST_LOG_CHANGED = function(self, event, unit)
    if unit == "player" then
        QuestKing:UpdateTracker()
    end
end

Events.QUEST_POI_UPDATE = function()
    QuestKing:OnPOIUpdate()
end

Events.TRACKED_ACHIEVEMENT_LIST_CHANGED = UpdateTracker

Events.TRACKED_ACHIEVEMENT_UPDATE = function(self, event, ...)
    QuestKing:OnTrackedAchievementUpdate(...)
end

-- -----------------------------------------------------------------------------
-- Quest accepted / watch management
-- -----------------------------------------------------------------------------

Events.QUEST_ACCEPTED = function(self, event, ...)
    local questLogIndex, questID = ...

    if not questID and questLogIndex then
        questID = GetQuestIDFromQuestLogIndexCompat(questLogIndex)
    end

    if IsTaskQuestCompat(questID) then
        if SOUNDKIT and SOUNDKIT.UI_SCENARIO_STAGE_END then
            PlaySoundSafe(SOUNDKIT.UI_SCENARIO_STAGE_END)
        end
        QuestKing:OnQuestAccepted(questID)
        return
    end

    if GetCVarBoolCompat("autoQuestWatch") then
        if GetNumQuestWatchesCompat() < 25 then
            AddQuestWatchCompat(questLogIndex, questID)
        end
    end

    QuestKing:OnQuestAccepted(questID)
end

Events.QUEST_REMOVED = function(self, event, questID)
    if QuestKing.ClearDummyTask then
        QuestKing:ClearDummyTask(questID)
    end

    QuestKing:UpdateTracker()
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

    QuestKing:UpdateTracker()
end

Events.QUEST_TURNED_IN = function(self, event, questID, xp, money)
    if IsTaskQuestCompat(questID) or IsPreyQuestCompat(questID) then
        QuestKing:OnTaskTurnedIn(questID, xp, money)
    end

    QuestKing:UpdateTracker()
end

Events.QUEST_COMPLETE = UpdateTracker
Events.QUEST_FINISHED = UpdateTracker

-- -----------------------------------------------------------------------------
-- Scenario / bonus-step content
-- -----------------------------------------------------------------------------

Events.SCENARIO_UPDATE = function(self, event, ...)
    QuestKing:OnScenarioUpdate(...)
end

Events.SCENARIO_CRITERIA_UPDATE = UpdateTracker
Events.SCENARIO_SPELL_UPDATE = UpdateTracker
Events.SCENARIO_CRITERIA_SHOW_STATE_UPDATE = UpdateTracker
Events.SCENARIO_POI_UPDATE = UpdateTracker
Events.SCENARIO_BONUS_VISIBILITY_UPDATE = UpdateTracker

Events.CRITERIA_COMPLETE = function(self, event, ...)
    QuestKing:OnCriteriaComplete(...)
end

Events.SCENARIO_COMPLETED = function(self, event, ...)
    QuestKing:OnScenarioCompleted(...)
end

-- -----------------------------------------------------------------------------
-- Challenge / timer content
-- -----------------------------------------------------------------------------

Events.PROVING_GROUNDS_SCORE_UPDATE = function(self, event, score)
    if score then
        QuestKing.ProvingGroundsScoreUpdate(score)
    end
end

Events.WORLD_STATE_TIMER_START = UpdateTracker
Events.WORLD_STATE_TIMER_STOP = UpdateTracker

-- -----------------------------------------------------------------------------
-- World / session transitions
-- -----------------------------------------------------------------------------

Events.PLAYER_ENTERING_WORLD = function()
    QuestKing:OnPlayerEnteringWorld()
    QuestKing:UpdateTracker()
end

Events.PLAYER_LEVEL_UP = function(self, event, ...)
    QuestKing:OnPlayerLevelUp(...)
end

-- -----------------------------------------------------------------------------
-- Super tracking
-- -----------------------------------------------------------------------------

Events.SUPER_TRACKING_CHANGED = function()
    local questID = GetSuperTrackedQuestIDCompat()
    QuestKing:OnSuperTrackedQuestChanged(questID)
end

Events.SUPER_TRACKING_PATH_UPDATED = function()
    QuestKing:UpdateTracker()
end

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