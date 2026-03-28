local addonName, QuestKing = ...

local opt = QuestKing.options

local CQL = C_QuestLog
local CST = C_SuperTrack

local huge = math.huge

local pendingQuestID = nil
local supertrackPending = false
local activeSuperTrackedQuestID = 0

local function NormalizeQuestID(questID)
    questID = tonumber(questID)
    if not questID or questID < 1 then
        return 0
    end
    return questID
end

local function GetSuperTrackedQuestIDCompat()
    if CST and CST.GetSuperTrackedQuestID then
        return NormalizeQuestID(CST.GetSuperTrackedQuestID())
    end

    if GetSuperTrackedQuestID then
        return NormalizeQuestID(GetSuperTrackedQuestID())
    end

    return 0
end

local function SetSuperTrackedQuestIDCompat(questID)
    questID = NormalizeQuestID(questID)

    if CST and CST.SetSuperTrackedQuestID then
        CST.SetSuperTrackedQuestID(questID)
        return
    end

    if SetSuperTrackedQuestID then
        SetSuperTrackedQuestID(questID)
    end
end

local function GetQuestLogIndexByIDCompat(questID)
    questID = NormalizeQuestID(questID)
    if questID == 0 then
        return nil
    end

    if CQL and CQL.GetLogIndexForQuestID then
        local index = CQL.GetLogIndexForQuestID(questID)
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

local function IsQuestInLog(questID)
    return GetQuestLogIndexByIDCompat(questID) ~= nil
end

local function GetNumQuestWatchesCompat()
    if CQL and CQL.GetNumQuestWatches then
        return CQL.GetNumQuestWatches() or 0
    end

    if GetNumQuestWatches then
        return GetNumQuestWatches() or 0
    end

    return 0
end

local function GetQuestIDForWatchIndexCompat(watchIndex)
    if not watchIndex or watchIndex < 1 then
        return nil
    end

    if CQL and CQL.GetQuestIDForQuestWatchIndex then
        local questID = CQL.GetQuestIDForQuestWatchIndex(watchIndex)
        questID = NormalizeQuestID(questID)
        if questID ~= 0 then
            return questID
        end
    end

    if GetQuestIndexForWatch and GetQuestLogTitle then
        local questLogIndex = GetQuestIndexForWatch(watchIndex)
        if questLogIndex and questLogIndex > 0 then
            local _, _, _, _, _, _, _, questID = GetQuestLogTitle(questLogIndex)
            questID = NormalizeQuestID(questID)
            if questID ~= 0 then
                return questID
            end
        end
    end

    return nil
end

local function GetQuestLogEntryCountCompat()
    if CQL and CQL.GetNumQuestLogEntries then
        return CQL.GetNumQuestLogEntries() or 0
    end

    if GetNumQuestLogEntries then
        local count = GetNumQuestLogEntries()
        if type(count) == "number" then
            return count
        end
    end

    return 0
end

local function GetQuestLogInfoCompat(questLogIndex)
    if not questLogIndex or questLogIndex < 1 then
        return nil
    end

    if CQL and CQL.GetInfo then
        return CQL.GetInfo(questLogIndex)
    end

    if GetQuestLogTitle then
        local title, level, suggestedGroup, isHeader, isCollapsed, isComplete, frequency, questID = GetQuestLogTitle(questLogIndex)
        if title then
            return {
                title = title,
                level = level,
                suggestedGroup = suggestedGroup,
                isHeader = isHeader,
                isCollapsed = isCollapsed,
                isComplete = isComplete,
                frequency = frequency,
                questID = questID,
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

    if CQL and CQL.GetDistanceSqToQuest then
        local distSqr, onContinent = CQL.GetDistanceSqToQuest(questID)
        return distSqr, onContinent == true
    end

    if GetDistanceSqToQuest then
        local distSqr, onContinent = GetDistanceSqToQuest(questID)
        return distSqr, onContinent == true
    end

    return nil, false
end

local function QuestHasDistance(questID)
    local distSqr, onContinent = GetQuestDistanceInfoCompat(questID)
    return type(distSqr) == "number" and onContinent == true
end

local function IsBetterCandidate(questID, distSqr, bestQuestID, bestDistSqr, preferredQuestID)
    if type(distSqr) ~= "number" then
        return false
    end

    if not bestQuestID then
        return true
    end

    if distSqr < bestDistSqr then
        return true
    end

    if distSqr > bestDistSqr then
        return false
    end

    if preferredQuestID and questID == preferredQuestID and bestQuestID ~= preferredQuestID then
        return true
    end

    return questID < bestQuestID
end

local function FindClosestWatchedQuest(preferredQuestID)
    local bestQuestID = nil
    local bestDistSqr = huge
    local watchCount = GetNumQuestWatchesCompat()

    for watchIndex = 1, watchCount do
        local questID = GetQuestIDForWatchIndexCompat(watchIndex)
        if questID and QuestHasDistance(questID) then
            local distSqr = GetQuestDistanceInfoCompat(questID)
            if IsBetterCandidate(questID, distSqr, bestQuestID, bestDistSqr, preferredQuestID) then
                bestQuestID = questID
                bestDistSqr = distSqr
            end
        end
    end

    return bestQuestID, bestDistSqr
end

local function FindClosestQuestInLog(preferredQuestID)
    local bestQuestID = nil
    local bestDistSqr = huge
    local numEntries = GetQuestLogEntryCountCompat()

    for questLogIndex = 1, numEntries do
        local info = GetQuestLogInfoCompat(questLogIndex)
        if info and not info.isHeader and not info.isHidden and info.questID then
            local questID = NormalizeQuestID(info.questID)
            if questID ~= 0 and QuestHasDistance(questID) then
                local distSqr = GetQuestDistanceInfoCompat(questID)
                if IsBetterCandidate(questID, distSqr, bestQuestID, bestDistSqr, preferredQuestID) then
                    bestQuestID = questID
                    bestDistSqr = distSqr
                end
            end
        end
    end

    return bestQuestID, bestDistSqr
end

function QuestKing:GetSuperTrackedQuestID()
    local currentQuestID = GetSuperTrackedQuestIDCompat()
    if currentQuestID ~= activeSuperTrackedQuestID then
        activeSuperTrackedQuestID = currentQuestID
    end
    return activeSuperTrackedQuestID
end

function QuestKing:SetSuperTrackedQuestID(questID)
    questID = NormalizeQuestID(questID)

    if questID == activeSuperTrackedQuestID and questID == GetSuperTrackedQuestIDCompat() then
        return false, questID
    end

    activeSuperTrackedQuestID = questID
    SetSuperTrackedQuestIDCompat(questID)

    return true, questID
end

function QuestKing:TrackClosestQuest()
    local preferredQuestID = self:GetSuperTrackedQuestID()
    local closestQuestID = nil

    closestQuestID = FindClosestWatchedQuest(preferredQuestID)
    if not closestQuestID then
        closestQuestID = FindClosestQuestInLog(preferredQuestID)
    end

    if not closestQuestID then
        closestQuestID = 0
    end

    return self:SetSuperTrackedQuestID(closestQuestID)
end

function QuestKing:OnQuestAccepted(questID)
    questID = NormalizeQuestID(questID)

    if questID == 0 then
        self:UpdateTracker()
        return
    end

    if QuestHasDistance(questID) then
        pendingQuestID = nil
        self:TrackClosestQuest()
    else
        pendingQuestID = questID
    end

    self:UpdateTracker()
end

function QuestKing:OnPOIUpdate()
    if type(QuestPOIUpdateIcons) == "function" then
        pcall(QuestPOIUpdateIcons)
    end

    if not pendingQuestID then
        return
    end

    if not IsQuestInLog(pendingQuestID) then
        pendingQuestID = nil
        return
    end

    if QuestHasDistance(pendingQuestID) then
        pendingQuestID = nil
        self:TrackClosestQuest()
        self:UpdateTracker()
    end
end

function QuestKing:PreCheckQuestTracking()
    local trackedQuestID = self:GetSuperTrackedQuestID()
    if trackedQuestID ~= 0 and not IsQuestInLog(trackedQuestID) then
        self:TrackClosestQuest()
    end
end

function QuestKing:OnQuestObjectivesCompleted(questID)
    questID = NormalizeQuestID(questID)
    if questID == 0 then
        return
    end

    if self:GetSuperTrackedQuestID() ~= 0 then
        supertrackPending = true
    end
end

function QuestKing:PostCheckQuestTracking()
    if not supertrackPending then
        return
    end

    supertrackPending = false

    if self:GetSuperTrackedQuestID() ~= 0 then
        local changed = self:TrackClosestQuest()
        if changed then
            self:UpdateTracker()
        end
    end
end

function QuestKing:OnSuperTrackedQuestChanged(newQuestID)
    newQuestID = NormalizeQuestID(newQuestID)

    if newQuestID == 0 then
        newQuestID = GetSuperTrackedQuestIDCompat()
    end

    if newQuestID ~= activeSuperTrackedQuestID then
        activeSuperTrackedQuestID = newQuestID
        self:UpdateTracker()
    end
end