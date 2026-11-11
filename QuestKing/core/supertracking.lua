local addonName, QuestKing = ...

local _G = _G
local C_QuestLog = C_QuestLog
local C_SuperTrack = C_SuperTrack
local Enum = Enum

local huge = math.huge
local tonumber = tonumber
local type = type

local pendingQuestID = nil
local activeSuperTrackedQuestID = 0
local activeSuperTrackingType = nil
local trackingTrace = {}
local trackingTraceQuestID = 0
local trackingTraceHooks = {}
local TRACKING_TRACE_LIMIT = 24

local function NormalizeQuestID(questID)
    questID = tonumber(questID)
    if not questID or questID < 1 then
        return 0
    end

    return questID
end

local function SafePCall(func, ...)
    if type(func) ~= "function" then
        return false, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil
    end

    local ok, a, b, c, d, e, f, g, h, i, j = pcall(func, ...)
    if ok then
        return true, a, b, c, d, e, f, g, h, i, j
    end

    return false, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil
end

local function QueueTrackerRefresh(forceBuild)
    if type(QuestKing) ~= "table" then
        return
    end

    if type(QuestKing.RequestTrackerUpdate) == "function" then
        QuestKing:RequestTrackerUpdate(false, "supertracking", false)
        return
    end

    if type(QuestKing.QueueTrackerUpdate) == "function" then
        QuestKing:QueueTrackerUpdate(false, false, "supertracking")
        return
    end

    if type(QuestKing.UpdateTracker) == "function" then
        QuestKing:UpdateTracker(false, false, "supertracking")
    end
end

local function GetSuperTrackingQuestType()
    if Enum and Enum.SuperTrackingType and Enum.SuperTrackingType.Quest ~= nil then
        return Enum.SuperTrackingType.Quest
    end

    return 0
end

local function GetHighestPrioritySuperTrackingTypeCompat()
    if C_SuperTrack and C_SuperTrack.GetHighestPrioritySuperTrackingType then
        local ok, trackingType = SafePCall(C_SuperTrack.GetHighestPrioritySuperTrackingType)
        if ok then
            return trackingType
        end
    end

    return nil
end

local function GetSuperTrackedQuestIDCompat()
    if C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID then
        local ok, questID = SafePCall(C_SuperTrack.GetSuperTrackedQuestID)
        if ok then
            return NormalizeQuestID(questID)
        end
    end

    if type(_G.GetSuperTrackedQuestID) == "function" then
        local ok, questID = SafePCall(_G.GetSuperTrackedQuestID)
        if ok then
            return NormalizeQuestID(questID)
        end
    end

    return 0
end

local function SetSuperTrackedQuestIDCompat(questID)
    questID = NormalizeQuestID(questID)

    if C_SuperTrack and C_SuperTrack.SetSuperTrackedQuestID then
        local ok = SafePCall(C_SuperTrack.SetSuperTrackedQuestID, questID)
        return ok and true or false
    end

    if type(_G.SetSuperTrackedQuestID) == "function" then
        local ok = SafePCall(_G.SetSuperTrackedQuestID, questID)
        return ok and true or false
    end

    return false
end

local function GetQuestLogIndexByIDCompat(questID)
    questID = NormalizeQuestID(questID)
    if questID == 0 then
        return nil
    end

    if C_QuestLog and C_QuestLog.GetLogIndexForQuestID then
        local ok, index = SafePCall(C_QuestLog.GetLogIndexForQuestID, questID)
        if ok and type(index) == "number" and index > 0 then
            return index
        end
    end

    if type(_G.GetQuestLogIndexByID) == "function" then
        local ok, index = SafePCall(_G.GetQuestLogIndexByID, questID)
        if ok and type(index) == "number" and index > 0 then
            return index
        end
    end

    return nil
end

local function GetQuestIDForLogIndexCompat(questLogIndex)
    if type(questLogIndex) ~= "number" or questLogIndex < 1 then
        return nil
    end

    if C_QuestLog and C_QuestLog.GetQuestIDForLogIndex then
        local ok, questID = SafePCall(C_QuestLog.GetQuestIDForLogIndex, questLogIndex)
        if ok then
            questID = NormalizeQuestID(questID)
            if questID ~= 0 then
                return questID
            end
        end
    end

    if C_QuestLog and C_QuestLog.GetInfo then
        local ok, info = SafePCall(C_QuestLog.GetInfo, questLogIndex)
        if ok and type(info) == "table" then
            local questID = NormalizeQuestID(info.questID)
            if questID ~= 0 then
                return questID
            end
        end
    end

    if type(_G.GetQuestLogTitle) == "function" then
        local ok, _, _, _, _, _, _, _, questID = SafePCall(_G.GetQuestLogTitle, questLogIndex)
        if ok then
            questID = NormalizeQuestID(questID)
            if questID ~= 0 then
                return questID
            end
        end
    end

    return nil
end

local function IsQuestInLog(questID)
    return GetQuestLogIndexByIDCompat(questID) ~= nil
end

local function GetNumQuestWatchesCompat()
    if C_QuestLog and C_QuestLog.GetNumQuestWatches then
        local ok, count = SafePCall(C_QuestLog.GetNumQuestWatches)
        if ok and type(count) == "number" then
            return count
        end
    end

    if type(_G.GetNumQuestWatches) == "function" then
        local ok, count = SafePCall(_G.GetNumQuestWatches)
        if ok and type(count) == "number" then
            return count
        end
    end

    return 0
end

local function GetQuestIDForWatchIndexCompat(watchIndex)
    if type(watchIndex) ~= "number" or watchIndex < 1 then
        return nil
    end

    if C_QuestLog and C_QuestLog.GetQuestIDForQuestWatchIndex then
        local ok, questID = SafePCall(C_QuestLog.GetQuestIDForQuestWatchIndex, watchIndex)
        if ok then
            questID = NormalizeQuestID(questID)
            if questID ~= 0 then
                return questID
            end
        end
    end

    if type(_G.GetQuestIndexForWatch) == "function" then
        local ok, questLogIndex = SafePCall(_G.GetQuestIndexForWatch, watchIndex)
        if ok and type(questLogIndex) == "number" and questLogIndex > 0 then
            return GetQuestIDForLogIndexCompat(questLogIndex)
        end
    end

    return nil
end

local function GetQuestLogEntryCountCompat()
    if C_QuestLog and C_QuestLog.GetNumQuestLogEntries then
        local ok, count = SafePCall(C_QuestLog.GetNumQuestLogEntries)
        if ok and type(count) == "number" then
            return count
        end
    end

    if type(_G.GetNumQuestLogEntries) == "function" then
        local ok, count = SafePCall(_G.GetNumQuestLogEntries)
        if ok and type(count) == "number" then
            return count
        end
    end

    return 0
end

local function GetQuestLogInfoCompat(questLogIndex)
    if type(questLogIndex) ~= "number" or questLogIndex < 1 then
        return nil
    end

    if C_QuestLog and C_QuestLog.GetInfo then
        local ok, info = SafePCall(C_QuestLog.GetInfo, questLogIndex)
        if ok and type(info) == "table" then
            return info
        end
    end

    if type(_G.GetQuestLogTitle) == "function" then
        local ok, title, level, suggestedGroup, isHeader, isCollapsed, isComplete, frequency, questID =
            SafePCall(_G.GetQuestLogTitle, questLogIndex)
        if ok and title then
            return {
                title = title,
                level = level,
                suggestedGroup = suggestedGroup,
                isHeader = isHeader,
                isCollapsed = isCollapsed,
                isComplete = isComplete,
                frequency = frequency,
                questID = questID,
                isHidden = false,
            }
        end
    end

    return nil
end

local function GetQuestDistanceInfoCompat(questID)
    questID = NormalizeQuestID(questID)
    if questID == 0 then
        return nil, false
    end

    if C_QuestLog and C_QuestLog.GetDistanceSqToQuest then
        local ok, distanceSq, onContinent = SafePCall(C_QuestLog.GetDistanceSqToQuest, questID)
        if ok then
            return distanceSq, onContinent == true
        end
    end

    if type(_G.GetDistanceSqToQuest) == "function" then
        local ok, distanceSq, onContinent = SafePCall(_G.GetDistanceSqToQuest, questID)
        if ok then
            return distanceSq, onContinent == true
        end
    end

    return nil, false
end

local function QuestHasDistance(questID)
    local distanceSq, onContinent = GetQuestDistanceInfoCompat(questID)
    return type(distanceSq) == "number" and onContinent == true
end

function QuestKing:RecordQuestTrackingTrace(reason, questID, argument, includeStack)
    if not self.trackingTraceEnabled then
        return
    end

    questID = NormalizeQuestID(questID)
    if questID ~= 0 then
        trackingTraceQuestID = questID
    else
        questID = trackingTraceQuestID
    end

    local common = self.Compatibility and self.Compatibility.Common
    local questLogIndex = GetQuestLogIndexByIDCompat(questID)
    local watched = "?"
    if common and type(common.IsQuestWatched) == "function" then
        local ok, result = SafePCall(common.IsQuestWatched, questID, questLogIndex)
        if ok then
            watched = result and "yes" or "no"
        end
    end

    local timer = "none"
    if type(_G.QUEST_WATCH_LIST) == "table" then
        for index = 1, #_G.QUEST_WATCH_LIST do
            local watch = _G.QUEST_WATCH_LIST[index]
            if type(watch) == "table" and watch.id == questID then
                timer = tostring(watch.timer)
                break
            end
        end
    end

    local _, now = SafePCall(_G.GetTime)
    local _, inCombat = SafePCall(_G.InCombatLockdown)
    local entry = string.format(
        "%.2f %s quest=%d watched=%s focus=%d log=%s timer=%s combat=%s arg=%s",
        tonumber(now) or 0, reason, questID, watched,
        GetSuperTrackedQuestIDCompat(), tostring(questLogIndex), timer,
        inCombat and "yes" or "no", tostring(argument)
    )
    if includeStack and type(_G.debugstack) == "function" then
        local ok, stack = SafePCall(_G.debugstack, 3, 5, 0)
        if ok and type(stack) == "string" then
            entry = entry .. " caller=" .. stack:gsub("\n", " <- "):sub(1, 500)
        end
    end

    if #trackingTrace == TRACKING_TRACE_LIMIT then
        table.remove(trackingTrace, 1)
    end
    trackingTrace[#trackingTrace + 1] = entry
end

local function InstallTrackingTraceHook(owner, method, label, isLogIndex, includeStack)
    if trackingTraceHooks[label] or type(_G.hooksecurefunc) ~= "function" then
        return
    end

    local func
    if owner then
        func = owner[method]
    else
        func = _G[method]
    end
    if type(func) ~= "function" then
        return
    end

    local callback = function(argument)
        if not QuestKing.trackingTraceEnabled then
            return
        end
        local questID = argument
        if isLogIndex then
            questID = GetQuestIDForLogIndexCompat(argument)
        end
        QuestKing:RecordQuestTrackingTrace(label, questID, argument, includeStack)
    end
    local ok
    if owner then
        ok = pcall(_G.hooksecurefunc, owner, method, callback)
    else
        ok = pcall(_G.hooksecurefunc, method, callback)
    end
    trackingTraceHooks[label] = ok and true or false
end

function QuestKing:SetQuestTrackingTraceEnabled(enabled)
    if enabled then
        trackingTrace = {}
        trackingTraceQuestID = GetSuperTrackedQuestIDCompat()
        self.trackingTraceEnabled = true
        InstallTrackingTraceHook(nil, "AddQuestWatch", "legacy watch add", true, false)
        InstallTrackingTraceHook(nil, "RemoveQuestWatch", "legacy watch remove", true, true)
        if C_QuestLog then
            InstallTrackingTraceHook(C_QuestLog, "AddQuestWatch", "quest watch add", false, false)
            InstallTrackingTraceHook(C_QuestLog, "RemoveQuestWatch", "quest watch remove", false, true)
        end
        InstallTrackingTraceHook(nil, "SetSuperTrackedQuestID", "legacy focus set", false, true)
        if C_SuperTrack then
            InstallTrackingTraceHook(C_SuperTrack, "SetSuperTrackedQuestID", "quest focus set", false, true)
        end
        self:RecordQuestTrackingTrace("trace on", trackingTraceQuestID)
    else
        self:RecordQuestTrackingTrace("trace off")
        self.trackingTraceEnabled = false
    end
end

function QuestKing:GetQuestTrackingTrace()
    self:RecordQuestTrackingTrace("status")
    return trackingTrace
end

local function SyncSuperTrackingCache()
    activeSuperTrackedQuestID = GetSuperTrackedQuestIDCompat()
    activeSuperTrackingType = GetHighestPrioritySuperTrackingTypeCompat()
    return activeSuperTrackedQuestID, activeSuperTrackingType
end

local function IsQuestSuperTrackingContested()
    local trackingType = GetHighestPrioritySuperTrackingTypeCompat()
    local questType = GetSuperTrackingQuestType()

    if trackingType == nil then
        return false
    end

    return trackingType ~= questType
end

local function CanControlQuestSuperTrack()
    return not IsQuestSuperTrackingContested()
end

local function IsBetterCandidate(questID, distanceSq, bestQuestID, bestDistanceSq, preferredQuestID)
    if type(distanceSq) ~= "number" then
        return false
    end

    if preferredQuestID and questID == preferredQuestID then
        if not bestQuestID then
            return true
        end

        if bestQuestID ~= preferredQuestID then
            return true
        end
    end

    if not bestQuestID then
        return true
    end

    if distanceSq < bestDistanceSq then
        return true
    end

    if distanceSq > bestDistanceSq then
        return false
    end

    return questID < bestQuestID
end

local function FindClosestWatchedQuest(preferredQuestID)
    local bestQuestID = nil
    local bestDistanceSq = huge
    local watchCount = GetNumQuestWatchesCompat()

    for watchIndex = 1, watchCount do
        local questID = GetQuestIDForWatchIndexCompat(watchIndex)
        if questID and QuestHasDistance(questID) then
            local distanceSq = GetQuestDistanceInfoCompat(questID)
            if IsBetterCandidate(questID, distanceSq, bestQuestID, bestDistanceSq, preferredQuestID) then
                bestQuestID = questID
                bestDistanceSq = distanceSq
            end
        end
    end

    return bestQuestID, bestDistanceSq
end

local function FindClosestQuestInLog(preferredQuestID)
    local bestQuestID = nil
    local bestDistanceSq = huge
    local entryCount = GetQuestLogEntryCountCompat()

    if type(QuestKing.RecordPerformanceMetric) == "function" then
        QuestKing:RecordPerformanceMetric("questLogScanCount", 1)
    end

    for questLogIndex = 1, entryCount do
        local info = GetQuestLogInfoCompat(questLogIndex)
        if info and not info.isHeader and not info.isHidden then
            local questID = NormalizeQuestID(info.questID)
            if questID ~= 0 and QuestHasDistance(questID) then
                local distanceSq = GetQuestDistanceInfoCompat(questID)
                if IsBetterCandidate(questID, distanceSq, bestQuestID, bestDistanceSq, preferredQuestID) then
                    bestQuestID = questID
                    bestDistanceSq = distanceSq
                end
            end
        end
    end

    return bestQuestID, bestDistanceSq
end

local function ResolveClosestQuest(preferredQuestID)
    local closestQuestID = FindClosestWatchedQuest(preferredQuestID)
    if closestQuestID then
        return closestQuestID
    end

    return FindClosestQuestInLog(preferredQuestID)
end

function QuestKing:GetSuperTrackedQuestID()
    SyncSuperTrackingCache()
    return activeSuperTrackedQuestID
end

function QuestKing:GetHighestPrioritySuperTrackingType()
    SyncSuperTrackingCache()
    return activeSuperTrackingType
end

function QuestKing:IsQuestSuperTrackingContested()
    return IsQuestSuperTrackingContested()
end

function QuestKing:CanControlQuestSuperTrack()
    return CanControlQuestSuperTrack()
end

function QuestKing:SetSuperTrackedQuestID(questID)
    questID = NormalizeQuestID(questID)

    SyncSuperTrackingCache()

    if questID ~= 0 and not CanControlQuestSuperTrack() then
        return false, activeSuperTrackedQuestID
    end

    if questID == activeSuperTrackedQuestID and questID == GetSuperTrackedQuestIDCompat() then
        return false, questID
    end

    if not SetSuperTrackedQuestIDCompat(questID) then
        return false, activeSuperTrackedQuestID
    end

    activeSuperTrackedQuestID = questID
    activeSuperTrackingType = GetHighestPrioritySuperTrackingTypeCompat()

    return true, questID
end

function QuestKing:FocusClosestQuest()
    SyncSuperTrackingCache()

    if not CanControlQuestSuperTrack() then
        return false, activeSuperTrackedQuestID
    end

    local preferredQuestID = activeSuperTrackedQuestID
    if preferredQuestID ~= 0 and not IsQuestInLog(preferredQuestID) then
        preferredQuestID = nil
    end

    local closestQuestID = ResolveClosestQuest(preferredQuestID)
    if not closestQuestID then
        -- Missing Classic POI/distance data does not invalidate an accepted
        -- quest that the player already selected.
        if preferredQuestID and preferredQuestID ~= 0 then
            return false, preferredQuestID
        end
        closestQuestID = 0
    end

    return self:SetSuperTrackedQuestID(closestQuestID)
end

function QuestKing:OnQuestAccepted(questID)
    questID = NormalizeQuestID(questID)

    if questID == 0 then
        QueueTrackerRefresh(true)
        return
    end

    if QuestHasDistance(questID) and CanControlQuestSuperTrack() then
        pendingQuestID = nil
        self:FocusClosestQuest()
    else
        pendingQuestID = questID
    end

    QueueTrackerRefresh(true)
end

function QuestKing:OnPOIUpdate()
    if type(_G.QuestPOIUpdateIcons) == "function" then
        SafePCall(_G.QuestPOIUpdateIcons)
    end

    if not pendingQuestID then
        return
    end

    if not IsQuestInLog(pendingQuestID) then
        pendingQuestID = nil
        return
    end

    if CanControlQuestSuperTrack() and QuestHasDistance(pendingQuestID) then
        pendingQuestID = nil
        self:FocusClosestQuest()
        QueueTrackerRefresh(true)
    end
end

function QuestKing:PreCheckQuestFocus()
    SyncSuperTrackingCache()

    if activeSuperTrackedQuestID ~= 0 and not IsQuestInLog(activeSuperTrackedQuestID) and CanControlQuestSuperTrack() then
        self:FocusClosestQuest()
        return
    end

    if pendingQuestID and CanControlQuestSuperTrack() and QuestHasDistance(pendingQuestID) then
        pendingQuestID = nil
        self:FocusClosestQuest()
    end
end

function QuestKing:OnSuperTrackedQuestChanged(newQuestID)
    newQuestID = NormalizeQuestID(newQuestID)

    local previousQuestID = activeSuperTrackedQuestID
    SyncSuperTrackingCache()

    if newQuestID ~= 0 then
        activeSuperTrackedQuestID = newQuestID
    end

    if previousQuestID ~= activeSuperTrackedQuestID then
        QueueTrackerRefresh(true)
    elseif pendingQuestID and CanControlQuestSuperTrack() and QuestHasDistance(pendingQuestID) then
        pendingQuestID = nil
        self:FocusClosestQuest()
        QueueTrackerRefresh(true)
    end
end
