local addonName, QuestKing = ...

local C_QuestLog = C_QuestLog
local C_TaskQuest = C_TaskQuest
local C_SuperTrack = C_SuperTrack
local C_CampaignInfo = C_CampaignInfo
local C_QuestInfoSystem = C_QuestInfoSystem
local Enum = Enum
local IS_MAINLINE = _G.WOW_PROJECT_MAINLINE ~= nil
    and _G.WOW_PROJECT_ID == _G.WOW_PROJECT_MAINLINE

local WatchButton = QuestKing and QuestKing.WatchButton
local Compat = QuestKing and QuestKing.Compatibility and QuestKing.Compatibility.Common or {}
local opt = QuestKing and QuestKing.options or {}
local opt_colors = opt.colors or {}

local floor = math.floor
local match = string.match
local concat = table.concat
local sort = table.sort
local tonumber_raw = tonumber
local tostring = tostring
local type = type
local wipe = wipe

local UNKNOWN = UNKNOWN or "Unknown"
local NORMAL_QUEST_HEADER = TRACKER_HEADER_QUESTS or QUESTS_LABEL or "Quests"
local TASK_HEADER = TRACKER_HEADER_OBJECTIVE or "Tasks"
local WORLD_QUEST_HEADER = TRACKER_HEADER_WORLD_QUESTS or "World Quests"
local CAMPAIGN_HEADER = CAMPAIGN or "Campaign"

local QUEST_TAG_CAPSTONE_WORLD_QUEST = 286

local LINE_LEFT_PADDING = 16
local LINE_RIGHT_PADDING = 8
local OBJECTIVE_LINE_LEFT_PADDING = 18
local LEVEL_GAP_X = 6
local COMPLETED_ALPHA = 0.65

local QUEST_KIND = {
    NORMAL = "normal",
    CAMPAIGN = "campaign",
    TASK = "task",
    WORLD_QUEST = "world_quest",
    SPECIAL_ASSIGNMENT = "special_assignment",
    PREY = "prey",
}

QuestKing.QUEST_KIND = QUEST_KIND

local ROW_TYPE_AVAILABLE_CAMPAIGN = "available_campaign"
local ROW_TYPE_TASK_QUEST = "task_quest"

local TRACKER_POPULATION_AUTOMATIC = "automatic"
local TRACKER_POPULATION_WATCHED = "watched"
local TRACKER_POPULATION_ALL = "all"

local IsSecretValue = QuestKing.IsSecretValue or function()
    return false
end

local function IsSafeNumber(value)
    return type(value) == "number" and not IsSecretValue(value)
end

local function SafeNumber(value, fallback)
    if value == nil or IsSecretValue(value) then
        return fallback
    end

    if type(value) == "number" then
        return value
    end

    local ok, numberValue = pcall(tonumber_raw, value)
    if ok and type(numberValue) == "number" and not IsSecretValue(numberValue) then
        return numberValue
    end

    return fallback
end

local function SafeString(value, fallback)
    if value == nil or IsSecretValue(value) then
        return fallback
    end

    if type(value) == "string" then
        return value
    end

    return fallback
end

local function SafeBoolean(value, fallback)
    if value == nil or IsSecretValue(value) then
        return fallback
    end

    return value and true or false
end

local function SafeCall(func, ...)
    if type(func) ~= "function" then
        return false, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil
    end

    local ok, a, b, c, d, e, f, g, h, i, j, k, l, m, n, o = pcall(func, ...)
    if ok then
        return true, a, b, c, d, e, f, g, h, i, j, k, l, m, n, o
    end

    return false, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil
end

local function GetUntrackedCampaignRequirementDB()
    _G.QuestKingDBPerChar = type(_G.QuestKingDBPerChar) == "table"
        and _G.QuestKingDBPerChar
        or {}

    local perCharacter = _G.QuestKingDBPerChar
    perCharacter.untrackedCampaignRequirements =
        type(perCharacter.untrackedCampaignRequirements) == "table"
        and perCharacter.untrackedCampaignRequirements
        or {}

    return perCharacter.untrackedCampaignRequirements
end

local function GetAvailableCampaignRequirementKey(campaignID, questID, mapID, text)
    return "campaign_requirement:"
        .. tostring(SafeNumber(campaignID, 0) or 0)
        .. ":"
        .. tostring(SafeNumber(questID, 0) or 0)
        .. ":"
        .. tostring(SafeNumber(mapID, 0) or 0)
        .. ":"
        .. (SafeString(text, "") or "")
end

local function SetCampaignRequirementUntracked(requirementKey, untracked)
    if type(requirementKey) ~= "string" or requirementKey == "" then
        return
    end

    local db = GetUntrackedCampaignRequirementDB()
    db[requirementKey] = untracked and true or nil
end

local function IsCampaignRequirementUntracked(requirementKey)
    if type(requirementKey) ~= "string" or requirementKey == "" then
        return false
    end

    return GetUntrackedCampaignRequirementDB()[requirementKey] == true
end

local function QueueTrackerRefresh(forceBuild)
    if type(QuestKing.RequestTrackerUpdate) == "function" then
        QuestKing:RequestTrackerUpdate(forceBuild, "quest", false)
        return
    end

    if type(QuestKing.QueueTrackerUpdate) == "function" then
        QuestKing:QueueTrackerUpdate(forceBuild, false, "quest")
        return
    end

    if type(QuestKing.UpdateTracker) == "function" then
        QuestKing:UpdateTracker(forceBuild, false, "quest")
    end
end

local function IsClassicFamilyCompat()
    if Compat and type(Compat.IsClassicFamily) == "function" then
        return Compat.IsClassicFamily() and true or false
    end

    local projectID = _G.WOW_PROJECT_ID
    return projectID ~= nil and projectID ~= _G.WOW_PROJECT_MAINLINE
end

local FINISHED_COLOR = {
    r = (opt_colors.ObjectiveGradientComplete and opt_colors.ObjectiveGradientComplete[1]) or 0.60,
    g = (opt_colors.ObjectiveGradientComplete and opt_colors.ObjectiveGradientComplete[2]) or 1.00,
    b = (opt_colors.ObjectiveGradientComplete and opt_colors.ObjectiveGradientComplete[3]) or 0.60,
}

local UNFINISHED_COLOR = { r = 0.95, g = 0.95, b = 0.95 }
local TITLE_COLOR = { r = 1.00, g = 0.82, b = 0.00 }

local TITLE_COMPLETE_COLOR = {
    r = (opt_colors.ObjectiveComplete and opt_colors.ObjectiveComplete[1]) or 0.20,
    g = (opt_colors.ObjectiveComplete and opt_colors.ObjectiveComplete[2]) or 1.00,
    b = (opt_colors.ObjectiveComplete and opt_colors.ObjectiveComplete[3]) or 0.20,
}

local FAILED_COLOR = {
    r = (opt_colors.ObjectiveFailed and opt_colors.ObjectiveFailed[1]) or 1.00,
    g = (opt_colors.ObjectiveFailed and opt_colors.ObjectiveFailed[2]) or 0.20,
    b = (opt_colors.ObjectiveFailed and opt_colors.ObjectiveFailed[3]) or 0.20,
}

local SECTION_HEADER_COLOR = {
    r = (opt_colors.SectionHeader and opt_colors.SectionHeader[1]) or 1.00,
    g = (opt_colors.SectionHeader and opt_colors.SectionHeader[2]) or 0.82,
    b = (opt_colors.SectionHeader and opt_colors.SectionHeader[3]) or 0.00,
}

local AVAILABLE_CAMPAIGN_COLOR = { r = 0.58, g = 0.82, b = 1.00 }

local function GetQuestInfoByLogIndex(questLogIndex)
    if type(questLogIndex) ~= "number" or questLogIndex <= 0 then
        return nil
    end

    if Compat and type(Compat.GetQuestInfo) == "function" then
        local info = Compat.GetQuestInfo(questLogIndex)
        if type(info) == "table" then
            return info
        end
    end

    if C_QuestLog and C_QuestLog.GetInfo then
        local ok, info = SafeCall(C_QuestLog.GetInfo, questLogIndex)
        if ok and type(info) == "table" then
            return info
        end
    end

    if _G.GetQuestLogTitle then
        local ok, title, level, suggestedGroup, isHeader, isCollapsed, isComplete, frequency, questID, startEvent =
            SafeCall(_G.GetQuestLogTitle, questLogIndex)

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
                startEvent = startEvent,
                isHidden = false,
                isCampaign = nil,
                campaignID = 0,
                isTask = false,
            }
        end
    end

    return nil
end

local function GetQuestLogIndexByIDCompat(questID)
    if type(questID) ~= "number" or questID <= 0 then
        return nil
    end

    if Compat and type(Compat.GetQuestLogIndexByQuestID) == "function" then
        local index = Compat.GetQuestLogIndexByQuestID(questID)
        if type(index) == "number" and index > 0 then
            return index
        end
    end

    if C_QuestLog and C_QuestLog.GetLogIndexForQuestID then
        local ok, index = SafeCall(C_QuestLog.GetLogIndexForQuestID, questID)
        if ok and type(index) == "number" and index > 0 then
            return index
        end
    end

    if _G.GetQuestLogIndexByID then
        local ok, index = SafeCall(_G.GetQuestLogIndexByID, questID)
        if ok and type(index) == "number" and index > 0 then
            return index
        end
    end

    return nil
end

local function GetQuestIDForQuestLogIndex(questLogIndex)
    if Compat and type(Compat.GetQuestIDByLogIndex) == "function" then
        local questID = Compat.GetQuestIDByLogIndex(questLogIndex)
        if type(questID) == "number" and questID > 0 then
            return questID
        end
    end

    local info = GetQuestInfoByLogIndex(questLogIndex)
    if info and type(info.questID) == "number" and info.questID > 0 then
        return info.questID
    end

    return nil
end

local function GetQuestIDForWatchIndex(watchIndex)
    if type(watchIndex) ~= "number" or watchIndex <= 0 then
        return nil
    end

    if Compat and type(Compat.GetQuestIDForWatchIndex) == "function" then
        local questID = Compat.GetQuestIDForWatchIndex(watchIndex)
        if type(questID) == "number" and questID > 0 then
            return questID
        end
    end

    if C_QuestLog and C_QuestLog.GetQuestIDForQuestWatchIndex then
        local ok, questID = SafeCall(C_QuestLog.GetQuestIDForQuestWatchIndex, watchIndex)
        if ok and type(questID) == "number" and questID > 0 then
            return questID
        end
    end

    if _G.GetQuestIndexForWatch then
        local ok, questLogIndex = SafeCall(_G.GetQuestIndexForWatch, watchIndex)
        if ok and type(questLogIndex) == "number" and questLogIndex > 0 then
            return GetQuestIDForQuestLogIndex(questLogIndex)
        end
    end

    return nil
end

local function IsQuestWatchedCompat(questID)
    if type(questID) ~= "number" or questID <= 0 then
        return false
    end

    if Compat and type(Compat.IsQuestWatched) == "function" then
        return Compat.IsQuestWatched(questID) and true or false
    end

    if C_QuestLog and C_QuestLog.GetQuestWatchType then
        local ok, watchType = SafeCall(C_QuestLog.GetQuestWatchType, questID)
        if ok then
            return watchType ~= nil
        end
    end

    local questLogIndex = GetQuestLogIndexByIDCompat(questID)
    if questLogIndex and _G.IsQuestWatched then
        local ok, watched = SafeCall(_G.IsQuestWatched, questLogIndex)
        if ok then
            return watched and true or false
        end
    end

    return false
end

local function AddQuestWatchByID(questID)
    if type(questID) ~= "number" or questID <= 0 then
        return false
    end

    local questLogIndex = GetQuestLogIndexByIDCompat(questID)

    if Compat and type(Compat.AddQuestWatch) == "function" then
        return Compat.AddQuestWatch(questID, questLogIndex) and true or false
    end

    if C_QuestLog and C_QuestLog.AddQuestWatch then
        local ok, wasWatched = SafeCall(C_QuestLog.AddQuestWatch, questID)
        if ok then
            return wasWatched ~= false
        end
    end

    if questLogIndex and _G.AddQuestWatch then
        local ok = SafeCall(_G.AddQuestWatch, questLogIndex)
        return ok and true or false
    end

    return false
end

local function RemoveQuestWatchByID(questID)
    if type(questID) ~= "number" or questID <= 0 then
        return false
    end

    local questLogIndex = GetQuestLogIndexByIDCompat(questID)

    if Compat and type(Compat.RemoveQuestWatch) == "function" then
        return Compat.RemoveQuestWatch(questID, questLogIndex) and true or false
    end

    if C_QuestLog and C_QuestLog.RemoveQuestWatch then
        local ok = SafeCall(C_QuestLog.RemoveQuestWatch, questID)
        return ok and true or false
    end

    if questLogIndex and _G.RemoveQuestWatch then
        local ok = SafeCall(_G.RemoveQuestWatch, questLogIndex)
        return ok and true or false
    end

    return false
end

local function IsPositiveQuestCompletionState(value)
    if IsSafeNumber(value) then
        return value > 0
    end

    return SafeBoolean(value, false)
end

local function IsQuestCompleteCompat(questID, questLogIndex, info)
    if type(questID) ~= "number" or questID <= 0 then
        return false
    end

    if C_QuestLog and C_QuestLog.IsComplete then
        local ok, isComplete = SafeCall(C_QuestLog.IsComplete, questID)
        if ok then
            return IsPositiveQuestCompletionState(isComplete)
        end
    end

    if type(info) == "table" and info.isComplete ~= nil then
        return IsPositiveQuestCompletionState(info.isComplete)
    end

    questLogIndex = questLogIndex or GetQuestLogIndexByIDCompat(questID)
    if questLogIndex and _G.GetQuestLogIsComplete then
        local ok, isComplete = SafeCall(_G.GetQuestLogIsComplete, questLogIndex)
        if ok then
            return IsPositiveQuestCompletionState(isComplete)
        end
    end

    if questLogIndex and _G.GetQuestLogTitle then
        local ok, _, _, _, _, _, isComplete = SafeCall(_G.GetQuestLogTitle, questLogIndex)
        if ok then
            return IsPositiveQuestCompletionState(isComplete)
        end
    end

    return false
end

local function IsQuestFailedCompat(questID, questLogIndex, info)
    if type(questID) ~= "number" or questID <= 0 then
        return false
    end

    if C_QuestLog and C_QuestLog.IsFailed then
        local ok, isFailed = SafeCall(C_QuestLog.IsFailed, questID)
        if ok then
            return SafeBoolean(isFailed, false)
        end
    end

    local completionState = type(info) == "table" and info.isComplete or nil
    if IsSafeNumber(completionState) then
        return completionState < 0
    end

    questLogIndex = questLogIndex or GetQuestLogIndexByIDCompat(questID)
    if questLogIndex and _G.GetQuestLogTitle then
        local ok, _, _, _, _, _, isComplete = SafeCall(_G.GetQuestLogTitle, questLogIndex)
        if ok and IsSafeNumber(isComplete) then
            return isComplete < 0
        end
    end

    return false
end

local function CanCompleteQuestRemotely(questID, questLogIndex, isComplete)
    if Compat and type(Compat.CanCompleteQuestRemotely) == "function" then
        return Compat.CanCompleteQuestRemotely(questID, questLogIndex, isComplete) and true or false
    end

    return false
end

local function ShowQuestCompleteCompat(questID, questLogIndex)
    if Compat and type(Compat.ShowQuestComplete) == "function" then
        return Compat.ShowQuestComplete(questID, questLogIndex) and true or false
    end

    if type(_G.ShowQuestComplete) ~= "function" then
        return false
    end

    local isMainline = Compat
        and type(Compat.IsMainline) == "function"
        and Compat.IsMainline()

    if isMainline and type(questID) == "number" and questID > 0 then
        local ok = SafeCall(_G.ShowQuestComplete, questID)
        return ok and true or false
    end

    if type(questLogIndex) == "number" and questLogIndex > 0 then
        local ok = SafeCall(_G.ShowQuestComplete, questLogIndex)
        return ok and true or false
    end

    return false
end

local function TryInsertQuestLink(questID)
    if not IsShiftKeyDown or not IsShiftKeyDown() then
        return false
    end

    if not ChatEdit_GetActiveWindow or not ChatEdit_InsertLink then
        return false
    end

    local editBox = ChatEdit_GetActiveWindow()
    if not editBox then
        return false
    end

    local link = nil

    if _G.GetQuestLink then
        local questLogIndex = GetQuestLogIndexByIDCompat(questID)
        if questLogIndex then
            local ok, questLink = SafeCall(_G.GetQuestLink, questLogIndex)
            if ok and questLink then
                link = questLink
            end
        end
    end

    if not link and C_QuestLog and C_QuestLog.GetTitleForQuestID then
        local ok, title = SafeCall(C_QuestLog.GetTitleForQuestID, questID)
        if ok and title and title ~= "" then
            link = "|cffffff00|Hquest:" .. tostring(questID) .. "|h[" .. title .. "]|h|r"
        end
    end

    if link then
        local ok, inserted = SafeCall(ChatEdit_InsertLink, link)
        return ok and inserted and true or false
    end

    return false
end

local OpenQuestDetailsFromWatch
local OpenQuestMapFromWatch

local function OpenQuestFromWatch(questID, questLogIndex)
    if type(questID) ~= "number" or questID <= 0 then
        return false
    end

    questLogIndex = questLogIndex or GetQuestLogIndexByIDCompat(questID)

    if TryInsertQuestLink(questID) then
        return true
    end

    if CanCompleteQuestRemotely(questID, questLogIndex) then
        if ShowQuestCompleteCompat(questID, questLogIndex) then
            if Compat
                and type(Compat.GetAutoQuestPopupType) == "function"
                and Compat.GetAutoQuestPopupType(questID) == "COMPLETE"
                and type(_G.RemoveAutoQuestPopUp) == "function" then
                SafeCall(_G.RemoveAutoQuestPopUp, questID)
            end

            return true
        end
    end

    -- Mainline quest-map details change WorldMapFrame's map ID and rebuild its
    -- pooled pins. Entering that Blizzard-owned lifecycle from an addon click
    -- can leave Area POI pins tainted, so use the isolated popup-details path
    -- selected by the compatibility layer instead. Classic-family clients
    -- retain their legacy quest-map behavior.
    if IS_MAINLINE then
        return OpenQuestDetailsFromWatch(questID)
    end

    if OpenQuestMapFromWatch(questID) then
        return true
    end

    return OpenQuestDetailsFromWatch(questID)
end

QuestKing.OpenQuestFromWatch = OpenQuestFromWatch

OpenQuestDetailsFromWatch = function(questID)
    if type(questID) ~= "number" or questID <= 0 then
        return false
    end

    local questLogIndex = GetQuestLogIndexByIDCompat(questID)

    if IS_MAINLINE and type(Compat.OpenQuestDetails) == "function" then
        return Compat.OpenQuestDetails(questID, questLogIndex) and true or false
    end

    local questUtil = _G.QuestUtil

    if questUtil and type(questUtil.OpenQuestDetails) == "function" then
        local ok = SafeCall(questUtil.OpenQuestDetails, questID)
        if ok then
            return true
        end
    end

    if type(_G.QuestLogPopupDetailFrame_Show) == "function" then
        local ok = SafeCall(_G.QuestLogPopupDetailFrame_Show, questID)
        if ok then
            return true
        end
    end

    if questLogIndex and type(_G.QuestLog_OpenToQuest) == "function" then
        local ok = SafeCall(_G.QuestLog_OpenToQuest, questLogIndex, true)
        if ok then
            return true
        end
    end

    if Compat.OpenQuestDetails then
        return Compat.OpenQuestDetails(questID, questLogIndex) and true or false
    end

    return false
end

local function IsInCombatLockdownCompat()
    if type(_G.InCombatLockdown) ~= "function" then
        return false
    end

    local ok, inCombat = SafeCall(_G.InCombatLockdown)
    return ok and SafeBoolean(inCombat, false) or false
end

local function CanOpenQuestMapFromWatch(questID)
    if IS_MAINLINE
        or type(questID) ~= "number"
        or questID <= 0
        or IsInCombatLockdownCompat() then
        return false
    end

    if type(_G.QuestMapFrame_OpenToQuestDetails) == "function" then
        return true
    end

    return GetQuestLogIndexByIDCompat(questID) ~= nil
        and type(_G.QuestObjectiveTracker_OpenQuestMap) == "function"
end

OpenQuestMapFromWatch = function(questID)
    if IS_MAINLINE then
        return false
    end

    if not CanOpenQuestMapFromWatch(questID) then
        return false
    end

    local questLogIndex = GetQuestLogIndexByIDCompat(questID)

    if type(_G.QuestMapFrame_OpenToQuestDetails) == "function" then
        local ok = SafeCall(_G.QuestMapFrame_OpenToQuestDetails, questID)
        if ok then
            return true
        end
    end

    if questLogIndex and type(_G.QuestObjectiveTracker_OpenQuestMap) == "function" then
        local ok = SafeCall(_G.QuestObjectiveTracker_OpenQuestMap, nil, questLogIndex)
        if ok then
            return true
        end
    end

    return false
end

local function GetDifficultyLevel(info)
    if type(info) ~= "table" then
        return nil
    end

    if C_QuestLog and C_QuestLog.GetQuestDifficultyLevel and type(info.questID) == "number" then
        local ok, level = SafeCall(C_QuestLog.GetQuestDifficultyLevel, info.questID)
        if ok and IsSafeNumber(level) then
            return level
        end
    end

    if IsSafeNumber(info.level) then
        return info.level
    end

    return nil
end

local function GetDifficultyColor(level)
    if level and _G.GetQuestDifficultyColor then
        local ok, color = SafeCall(_G.GetQuestDifficultyColor, level)
        if ok and type(color) == "table" then
            return color
        end
    end

    return { r = 1, g = 0.82, b = 0 }
end

local function GetQuestTagInfoCompat(questID)
    if type(questID) ~= "number" or questID <= 0 then
        return nil
    end

    if C_QuestLog and C_QuestLog.GetQuestTagInfo then
        local ok, info = SafeCall(C_QuestLog.GetQuestTagInfo, questID)
        if ok and type(info) == "table" then
            return info
        end
    end

    if _G.GetQuestTagInfo then
        local ok, tagID, tagName, worldQuestType, quality, isElite, tradeskillLineID, displayExpiration =
            SafeCall(_G.GetQuestTagInfo, questID)

        if ok and (tagID or tagName or worldQuestType or quality or isElite) then
            return {
                tagID = tagID,
                tagName = tagName,
                worldQuestType = worldQuestType,
                quality = quality,
                isElite = isElite,
                tradeskillLineID = tradeskillLineID,
                displayExpiration = displayExpiration,
            }
        end
    end

    return nil
end

local function ObjectiveTextAlreadyHasProgress(text)
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

local function GetQuestObjectives(questID)
    local out = {}

    if type(questID) ~= "number" or questID <= 0 then
        return out
    end

    if C_QuestLog and C_QuestLog.GetQuestObjectives then
        local ok, objectives = SafeCall(C_QuestLog.GetQuestObjectives, questID)
        if ok and type(objectives) == "table" then
            for i = 1, #objectives do
                local objective = objectives[i]
                if type(objective) == "table" then
                    out[#out + 1] = {
                        text = SafeString(objective.text, "") or "",
                        type = objective.type or objective.objectiveType,
                        finished = SafeBoolean(objective.finished or objective.completed, false),
                        numFulfilled = SafeNumber(objective.numFulfilled, nil),
                        numRequired = SafeNumber(objective.numRequired, nil),
                    }
                end
            end

            if #out > 0 then
                return out
            end
        end
    end

    local questLogIndex = GetQuestLogIndexByIDCompat(questID)
    if questLogIndex and _G.GetNumQuestLeaderBoards and _G.GetQuestLogLeaderBoard then
        local okNum, numObjectives = SafeCall(_G.GetNumQuestLeaderBoards, questLogIndex)
        if okNum then
            for i = 1, SafeNumber(numObjectives, 0) or 0 do
                local okObj, text, objectiveType, finished = SafeCall(_G.GetQuestLogLeaderBoard, i, questLogIndex, true)
                if okObj and text then
                    out[#out + 1] = {
                        text = SafeString(text, "") or "",
                        type = objectiveType,
                        finished = finished and true or false,
                    }
                end
            end
        end
    elseif _G.GetQuestObjectiveInfo and _G.GetNumQuestLeaderBoards then
        local okNum, numObjectives = SafeCall(_G.GetNumQuestLeaderBoards, questLogIndex or 0)
        if okNum then
            for i = 1, SafeNumber(numObjectives, 0) or 0 do
                local okObj, text, objectiveType, finished = SafeCall(_G.GetQuestObjectiveInfo, questID, i, false)
                if okObj then
                    out[#out + 1] = {
                        text = SafeString(text, "") or "",
                        type = objectiveType,
                        finished = finished and true or false,
                    }
                end
            end
        end
    end

    return out
end

local function GetRequiredMoney(questID)
    if type(questID) ~= "number" or questID <= 0 then
        return 0
    end

    if C_QuestLog and C_QuestLog.GetRequiredMoney then
        local ok, amount = SafeCall(C_QuestLog.GetRequiredMoney, questID)
        if ok then
            return SafeNumber(amount, 0) or 0
        end
    end

    return 0
end

local function GetQuestProgressPercent(questID)
    if type(questID) ~= "number" or questID <= 0 then
        return nil
    end

    if C_QuestLog and C_QuestLog.GetQuestProgressBarPercent then
        local ok, percent = SafeCall(C_QuestLog.GetQuestProgressBarPercent, questID)
        if ok and IsSafeNumber(percent) and percent >= 0 and percent <= 100 then
            return percent
        end
    end

    if _G.GetQuestProgressBarPercent then
        local ok, percent = SafeCall(_G.GetQuestProgressBarPercent, questID)
        if ok and IsSafeNumber(percent) and percent >= 0 and percent <= 100 then
            return percent
        end
    end

    return nil
end

local function GetQuestLogSpecialItemInfoCompat(questLogIndex)
    if type(questLogIndex) ~= "number" or questLogIndex <= 0 then
        return nil, nil, nil, nil
    end

    if _G.GetQuestLogSpecialItemInfo then
        local ok, itemLink, itemTexture, charges, itemShowWhenComplete = SafeCall(_G.GetQuestLogSpecialItemInfo, questLogIndex)
        if ok then
            return itemLink, itemTexture, charges, itemShowWhenComplete
        end
    end

    return nil, nil, nil, nil
end

local function GetActivePreyQuest()
    if C_QuestLog and C_QuestLog.GetActivePreyQuest then
        local ok, questID = SafeCall(C_QuestLog.GetActivePreyQuest)
        if ok and type(questID) == "number" and questID > 0 then
            return questID
        end
    end

    return nil
end

local function IsCampaignClassification(classification)
    return Enum
        and Enum.QuestClassification
        and classification == Enum.QuestClassification.Campaign
end

local function HasCampaignParentHeader(questLogIndex)
    questLogIndex = SafeNumber(questLogIndex, nil)
    if not questLogIndex or questLogIndex <= 1 then
        return false
    end

    for index = questLogIndex - 1, 1, -1 do
        local headerInfo = GetQuestInfoByLogIndex(index)
        if headerInfo and headerInfo.isHeader then
            return IsCampaignClassification(headerInfo.questClassification)
        end
    end

    return false
end

local function IsCampaignQuest(questID, info)
    if type(questID) ~= "number" or questID <= 0 then
        return false
    end

    if type(info) == "table" then
        if IsCampaignClassification(info.questClassification) then
            return true
        end

        if info.isCampaign == true then
            return true
        end

        local campaignID = SafeNumber(info.campaignID, 0) or 0
        if campaignID > 0 then
            return true
        end
    end

    local questLogIndex = GetQuestLogIndexByIDCompat(questID)
    if questLogIndex then
        local liveInfo = GetQuestInfoByLogIndex(questLogIndex)
        if type(liveInfo) == "table" then
            if IsCampaignClassification(liveInfo.questClassification) then
                return true
            end

            if liveInfo.isCampaign == true then
                return true
            end

            local campaignID = SafeNumber(liveInfo.campaignID, 0) or 0
            if campaignID > 0 then
                return true
            end
        end

        if HasCampaignParentHeader(questLogIndex) then
            return true
        end
    end

    if C_QuestInfoSystem and C_QuestInfoSystem.GetQuestClassification then
        local ok, classification = SafeCall(C_QuestInfoSystem.GetQuestClassification, questID)
        if ok and IsCampaignClassification(classification) then
            return true
        end
    end

    if C_CampaignInfo and C_CampaignInfo.GetCampaignID then
        local ok, campaignID = SafeCall(C_CampaignInfo.GetCampaignID, questID)
        campaignID = SafeNumber(campaignID, 0) or 0
        if ok and campaignID > 0 then
            return true
        end
    end

    if C_CampaignInfo and C_CampaignInfo.IsCampaignQuest then
        local ok, isCampaign = SafeCall(C_CampaignInfo.IsCampaignQuest, questID)
        if ok and isCampaign then
            return true
        end
    end

    return false
end

local function IsTaskQuest(questID)
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

    if _G.IsQuestTask then
        local ok, isTask = SafeCall(_G.IsQuestTask, questID)
        if ok then
            return isTask and true or false
        end
    end

    return false
end

local function IsWorldQuest(questID)
    if type(questID) ~= "number" or questID <= 0 then
        return false
    end

    if C_QuestLog and C_QuestLog.IsWorldQuest then
        local ok, isWorldQuest = SafeCall(C_QuestLog.IsWorldQuest, questID)
        if ok then
            return isWorldQuest and true or false
        end
    end

    local tagInfo = GetQuestTagInfoCompat(questID)
    if not tagInfo then
        return false
    end

    if tagInfo.worldQuestType ~= nil then
        return true
    end

    local tagID = tagInfo.tagID
    if tagID == 109 or tagID == 110 or tagID == 111 or tagID == 112 or tagID == 113
        or tagID == 114 or tagID == 115 or tagID == 116 or tagID == 117 or tagID == 118
        or tagID == 119 or tagID == 120 or tagID == 121 or tagID == 270 or tagID == 278
        or tagID == QUEST_TAG_CAPSTONE_WORLD_QUEST then
        return true
    end

    return false
end

local function IsSpecialAssignment(questID)
    local tagInfo = GetQuestTagInfoCompat(questID)
    return tagInfo and tagInfo.tagID == QUEST_TAG_CAPSTONE_WORLD_QUEST or false
end

local function IsPreyQuest(questID)
    return type(questID) == "number" and questID > 0 and GetActivePreyQuest() == questID
end

local function GetSuperTrackedQuestIDCompat()
    if Compat and type(Compat.GetSuperTrackedQuestID) == "function" then
        return Compat.GetSuperTrackedQuestID() or 0
    end

    if C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID then
        local ok, questID = SafeCall(C_SuperTrack.GetSuperTrackedQuestID)
        if ok then
            return SafeNumber(questID, 0) or 0
        end
    end

    if _G.GetSuperTrackedQuestID then
        local ok, questID = SafeCall(_G.GetSuperTrackedQuestID)
        if ok then
            return SafeNumber(questID, 0) or 0
        end
    end

    return 0
end

local function SetSuperTrackedQuestIDCompat(questID)
    if Compat and type(Compat.SetSuperTrackedQuestID) == "function" then
        if Compat.SetSuperTrackedQuestID(questID) then
            return true
        end
    end

    if C_SuperTrack and C_SuperTrack.SetSuperTrackedQuestID then
        local ok = SafeCall(C_SuperTrack.SetSuperTrackedQuestID, questID)
        return ok and true or false
    end

    if _G.SetSuperTrackedQuestID then
        local ok = SafeCall(_G.SetSuperTrackedQuestID, questID)
        return ok and true or false
    end

    return false
end

local function CanSetSuperTrackedQuestIDCompat()
    return (C_SuperTrack and type(C_SuperTrack.SetSuperTrackedQuestID) == "function")
        or type(_G.SetSuperTrackedQuestID) == "function"
end

local function GetSuperTrackedQuestOfferIDCompat()
    if not (C_SuperTrack and C_SuperTrack.GetSuperTrackedMapPin) then
        return nil
    end

    local ok, pinType, pinID = SafeCall(C_SuperTrack.GetSuperTrackedMapPin)
    if not ok
        or not (Enum and Enum.SuperTrackingMapPinType)
        or pinType ~= Enum.SuperTrackingMapPinType.QuestOffer then
        return nil
    end

    pinID = SafeNumber(pinID, nil)
    return pinID and pinID > 0 and pinID or nil
end

local function SetSuperTrackedQuestOfferCompat(questID)
    questID = SafeNumber(questID, nil)
    if not questID or questID <= 0 then
        return false
    end

    if not (C_SuperTrack
        and C_SuperTrack.SetSuperTrackedMapPin
        and Enum
        and Enum.SuperTrackingMapPinType
        and Enum.SuperTrackingMapPinType.QuestOffer ~= nil) then
        return false
    end

    local ok = SafeCall(
        C_SuperTrack.SetSuperTrackedMapPin,
        Enum.SuperTrackingMapPinType.QuestOffer,
        questID
    )
    return ok and GetSuperTrackedQuestOfferIDCompat() == questID
end

local function ClearMatchingSuperTrackedQuestOfferCompat(questID)
    questID = SafeNumber(questID, nil)
    if not questID
        or questID <= 0
        or GetSuperTrackedQuestOfferIDCompat() ~= questID
        or not (C_SuperTrack and C_SuperTrack.ClearSuperTrackedMapPin) then
        return false
    end

    local ok = SafeCall(C_SuperTrack.ClearSuperTrackedMapPin)
    return ok and GetSuperTrackedQuestOfferIDCompat() ~= questID
end

local function GetStalledCampaignState()
    if Enum and Enum.CampaignState and Enum.CampaignState.Stalled ~= nil then
        return Enum.CampaignState.Stalled
    end

    return 3
end

local function GetAvailableCampaignIDsCompat()
    if not C_CampaignInfo or type(C_CampaignInfo.GetAvailableCampaigns) ~= "function" then
        return nil
    end

    local ok, campaignIDs = SafeCall(C_CampaignInfo.GetAvailableCampaigns)
    if ok and type(campaignIDs) == "table" then
        return campaignIDs
    end

    return nil
end

local function GetCampaignInfoCompat(campaignID)
    if type(campaignID) ~= "number" or campaignID <= 0 then
        return nil
    end

    if not C_CampaignInfo or type(C_CampaignInfo.GetCampaignInfo) ~= "function" then
        return nil
    end

    local ok, info = SafeCall(C_CampaignInfo.GetCampaignInfo, campaignID)
    if ok and type(info) == "table" then
        return info
    end

    return nil
end

local function GetCampaignStateCompat(campaignID)
    if type(campaignID) ~= "number" or campaignID <= 0 then
        return nil
    end

    if not C_CampaignInfo or type(C_CampaignInfo.GetState) ~= "function" then
        return nil
    end

    local ok, state = SafeCall(C_CampaignInfo.GetState, campaignID)
    if ok then
        return SafeNumber(state, nil)
    end

    return nil
end

local function GetCampaignFailureReasonCompat(campaignID)
    if type(campaignID) ~= "number" or campaignID <= 0 then
        return nil
    end

    if not C_CampaignInfo or type(C_CampaignInfo.GetFailureReason) ~= "function" then
        return nil
    end

    local ok, failureReason = SafeCall(C_CampaignInfo.GetFailureReason, campaignID)
    if ok and type(failureReason) == "table" then
        return failureReason
    end

    return nil
end

local function IsQuestFlaggedCompletedCompat(questID)
    questID = SafeNumber(questID, nil)
    if not questID or questID <= 0 then
        return false
    end

    if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then
        local ok, completed = SafeCall(C_QuestLog.IsQuestFlaggedCompleted, questID)
        if ok then
            return completed and true or false
        end
    end

    if type(_G.IsQuestFlaggedCompleted) == "function" then
        local ok, completed = SafeCall(_G.IsQuestFlaggedCompleted, questID)
        if ok then
            return completed and true or false
        end
    end

    return false
end

local function ShouldDisplayAvailableCampaignStep(failureReason)
    if type(failureReason) ~= "table" then
        return false
    end

    local text = SafeString(failureReason.text, nil)
    if not text or text == "" then
        return false
    end

    local questID = SafeNumber(failureReason.questID, nil)
    if questID
        and (GetQuestLogIndexByIDCompat(questID)
            or IsQuestFlaggedCompletedCompat(questID)) then
        return false
    end

    return true
end

local availableCampaignSeenIDs = {}
local activeCampaignRequirementKeys = {}

local function AddAvailableCampaignSortRows(rows, seenQuestIDs)
    if opt.showAvailableCampaignSteps == false then
        return
    end

    local campaignIDs = GetAvailableCampaignIDsCompat()
    if not campaignIDs then
        return
    end

    local stalledState = GetStalledCampaignState()
    local seenCampaignIDs = availableCampaignSeenIDs
    local activeRequirementKeys = activeCampaignRequirementKeys
    wipe(seenCampaignIDs)
    wipe(activeRequirementKeys)

    for i = 1, #campaignIDs do
        local campaignID = SafeNumber(campaignIDs[i], nil)
        if campaignID and not seenCampaignIDs[campaignID] then
            seenCampaignIDs[campaignID] = true

            local state = GetCampaignStateCompat(campaignID)
            if state == stalledState then
                local failureReason = GetCampaignFailureReasonCompat(campaignID)
                if ShouldDisplayAvailableCampaignStep(failureReason) then
                    local info = GetCampaignInfoCompat(campaignID)
                    local questID = SafeNumber(failureReason.questID, nil)
                    local mapID = SafeNumber(failureReason.mapID, nil)
                    local failureText = SafeString(failureReason.text, "") or ""
                    local requirementKey = GetAvailableCampaignRequirementKey(
                        campaignID,
                        questID,
                        mapID,
                        failureText
                    )

                    if not questID or not seenQuestIDs[questID] then
                        activeRequirementKeys[requirementKey] = true

                        if not IsCampaignRequirementUntracked(requirementKey) then
                            rows[#rows + 1] = {
                                rowType = ROW_TYPE_AVAILABLE_CAMPAIGN,
                                kind = QUEST_KIND.CAMPAIGN,
                                campaignID = campaignID,
                                requirementKey = requirementKey,
                                questID = questID,
                                mapID = mapID,
                                title = SafeString(info and info.name, CAMPAIGN_HEADER) or CAMPAIGN_HEADER,
                                text = failureText,
                                sortText = SafeString(info and info.name, "") or "",
                            }
                        end

                        if questID then
                            seenQuestIDs[questID] = true
                        end
                    end
                end
            end
        end
    end

    local untrackedRequirements = GetUntrackedCampaignRequirementDB()
    for requirementKey in pairs(untrackedRequirements) do
        if activeRequirementKeys[requirementKey] ~= true then
            untrackedRequirements[requirementKey] = nil
        end
    end
end

local function OpenAvailableCampaignStep(row)
    if type(row) ~= "table" then
        return false
    end

    local questID = SafeNumber(row.questID, nil)
    if questID then
        if GetQuestLogIndexByIDCompat(questID) then
            if SetSuperTrackedQuestIDCompat(questID) then
                QueueTrackerRefresh(false)
                return true
            end
        elseif SetSuperTrackedQuestOfferCompat(questID) then
            QueueTrackerRefresh(false)
            return true
        end
    end

    -- A map-only continuation cannot be opened safely from QuestKing on
    -- Mainline because OpenWorldMap(mapID) enters the same pooled map-pin
    -- refresh path as QuestMapFrame_OpenToQuestDetails. QuestOffer
    -- supertracking above remains available whenever Blizzard supplies a
    -- quest ID. Classic-family clients retain the legacy map fallback.
    if IS_MAINLINE then
        return false
    end

    local mapID = SafeNumber(row.mapID, nil)
    if mapID and type(_G.OpenWorldMap) == "function" and not (type(_G.InCombatLockdown) == "function" and _G.InCombatLockdown()) then
        local ok = SafeCall(_G.OpenWorldMap, mapID)
        return ok and true or false
    end

    return false
end

local function GetKindHeader(kind)
    if kind == QUEST_KIND.CAMPAIGN then
        return CAMPAIGN_HEADER
    elseif kind == QUEST_KIND.WORLD_QUEST then
        return WORLD_QUEST_HEADER
    elseif kind == QUEST_KIND.SPECIAL_ASSIGNMENT then
        return "Special Assignments"
    elseif kind == QUEST_KIND.PREY then
        return "Prey"
    elseif kind == QUEST_KIND.TASK then
        return TASK_HEADER
    end

    return NORMAL_QUEST_HEADER
end

local function GetKindOrder(kind)
    if kind == QUEST_KIND.CAMPAIGN then
        return 10
    elseif kind == QUEST_KIND.PREY then
        return 20
    elseif kind == QUEST_KIND.SPECIAL_ASSIGNMENT then
        return 30
    elseif kind == QUEST_KIND.WORLD_QUEST then
        return 40
    elseif kind == QUEST_KIND.TASK then
        return 50
    end

    return 60
end

local function GetKindPrefix(kind)
    if kind == QUEST_KIND.CAMPAIGN then
        return "[Campaign]"
    elseif kind == QUEST_KIND.WORLD_QUEST then
        return "[World]"
    elseif kind == QUEST_KIND.SPECIAL_ASSIGNMENT then
        return "[Special]"
    elseif kind == QUEST_KIND.PREY then
        return "[Prey]"
    elseif kind == QUEST_KIND.TASK then
        return "[Task]"
    end

    return nil
end

function QuestKing:GetQuestKind(questID, info)
    if type(questID) ~= "number" or questID <= 0 then
        return QUEST_KIND.NORMAL
    end

    if IsPreyQuest(questID) then
        return QUEST_KIND.PREY
    end

    if IsSpecialAssignment(questID) then
        return QUEST_KIND.SPECIAL_ASSIGNMENT
    end

    if IsWorldQuest(questID) then
        return QUEST_KIND.WORLD_QUEST
    end

    if IsCampaignQuest(questID, info) then
        return QUEST_KIND.CAMPAIGN
    end

    if IsTaskQuest(questID) then
        return QUEST_KIND.TASK
    end

    return QUEST_KIND.NORMAL
end

function QuestKing:GetQuestTagBracket(questID)
    local info = GetQuestTagInfoCompat(questID)
    if not info then
        return nil
    end

    if info.tagName and info.tagName ~= "" then
        return ("[%s]"):format(info.tagName)
    end

    if info.isElite then
        return "[Elite]"
    end

    return nil
end

function QuestKing:GetQuestObjectivesText(questID)
    local out = {}
    local objectives = GetQuestObjectives(questID)
    local hasProgressBarObjective = false

    for index = 1, #objectives do
        local objective = objectives[index]
        if objective then
            local text = objective.text or ""
            local objectiveType = objective.type or objective.objectiveType
            local numFulfilled = SafeNumber(objective.numFulfilled, nil)
            local numRequired = SafeNumber(objective.numRequired, nil)

            if objectiveType == "progressbar" then
                hasProgressBarObjective = true
            elseif IsSafeNumber(numRequired)
                and numRequired > 0
                and text ~= ""
                and not ObjectiveTextAlreadyHasProgress(text) then
                text = ("%s (%d/%d)"):format(text, numFulfilled or 0, numRequired)
            end

            out[#out + 1] = {
                index = index,
                text = text,
                type = objectiveType,
                finished = SafeBoolean(objective.finished or objective.completed, false),
                numFulfilled = numFulfilled,
                numRequired = numRequired,
            }
        end
    end

    local requiredMoney = GetRequiredMoney(questID)
    if requiredMoney > 0 then
        local playerMoney = SafeNumber(_G.GetMoney and _G.GetMoney() or 0, 0) or 0
        local complete = playerMoney >= requiredMoney
        local moneyText = _G.GetMoneyString and _G.GetMoneyString(requiredMoney) or tostring(requiredMoney)

        out[#out + 1] = {
            index = #out + 1,
            text = moneyText,
            type = "money",
            finished = complete,
            numFulfilled = playerMoney,
            numRequired = requiredMoney,
        }

        QuestKing.watchMoney = true
    end

    return out, hasProgressBarObjective
end

local function FreeLineBars(line)
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

local function ShouldShowQuestObjective(row, isQuestComplete)
    if not row then
        return false
    end

    if not row.finished then
        return true
    end

    if QuestKing.ShouldShowCompletedObjective then
        return QuestKing.ShouldShowCompletedObjective(isQuestComplete)
    end

    local mode = opt.showCompletedObjectives
    if mode == "always" then
        return true
    end

    return not isQuestComplete and mode == true
end

local function GetQuestCompletionLineText()
    return QUEST_WATCH_QUEST_READY
        or QUEST_WATCH_QUEST_COMPLETE
        or COMPLETE
        or "Complete"
end

local function GetRemoteQuestCompletionText()
    return QUEST_WATCH_QUEST_COMPLETE
        or COMPLETE
        or "Quest Complete"
end

local function GetClickToCompleteText(questID)
    if questID and IsTaskQuest(questID) then
        return QUEST_WATCH_POPUP_CLICK_TO_COMPLETE_TASK
            or QUEST_WATCH_CLICK_TO_COMPLETE
            or QUEST_WATCH_POPUP_CLICK_TO_COMPLETE
            or "Click to complete"
    end

    return QUEST_WATCH_CLICK_TO_COMPLETE
        or QUEST_WATCH_POPUP_CLICK_TO_COMPLETE
        or "Click to complete"
end

local function ApplyObjectiveLineIndent(line)
    if line and type(line.SetLayoutInsets) == "function" then
        line:SetLayoutInsets(OBJECTIVE_LINE_LEFT_PADDING, 0)
    end
end

local function AddQuestObjectiveLine(button, row, isNewQuest)
    if not button or not row then
        return nil
    end

    local color = row.finished and FINISHED_COLOR or UNFINISHED_COLOR
    local line = button:AddLine(row.text or "", nil, color.r, color.g, color.b)
    ApplyObjectiveLineIndent(line)

    FreeLineBars(line)

    line:SetAlpha(row.finished and COMPLETED_ALPHA or 1)
    if line.right then
        line.right:SetAlpha(row.finished and COMPLETED_ALPHA or 1)
    end

    if not row.finished and not isNewQuest and IsSafeNumber(row.numFulfilled) then
        local lastQuant = SafeNumber(line._lastQuant, nil)
        if lastQuant and row.numFulfilled > lastQuant and line.Flash then
            line:Flash()
        end
    end

    line._lastQuant = IsSafeNumber(row.numFulfilled) and row.numFulfilled or nil
    return line
end

local function AddQuestProgressBar(button, percent, questID)
    if not button or not IsSafeNumber(percent) then
        return nil
    end

    local progressBar = button:AddProgressBar(questID)
    local line = progressBar and progressBar.baseLine or nil
    if line and line.timerBar then
        line.timerBar:Free()
    end

    if progressBar.SetPercent then
        progressBar:SetPercent(percent)
    elseif progressBar.SetValue then
        progressBar:SetValue(percent)
    end

    if progressBar.SetStatusBarColor then
        progressBar:SetStatusBarColor(0.20, 0.65, 1.00)
    end

    return progressBar
end

local function AddTooltipLine(tooltip, text, r, g, b)
    if tooltip and text and text ~= "" then
        tooltip:AddLine(text, r or 1, g or 1, b or 1, true)
    end
end

local function AddQuestTypeLine(tooltip, kind)
    if kind == QUEST_KIND.CAMPAIGN then
        AddTooltipLine(tooltip, "Campaign quest", 0.8, 0.9, 1)
    elseif kind == QUEST_KIND.WORLD_QUEST then
        AddTooltipLine(tooltip, "World quest", 0.8, 0.9, 1)
    elseif kind == QUEST_KIND.SPECIAL_ASSIGNMENT then
        AddTooltipLine(tooltip, "Special Assignment", 0.8, 0.9, 1)
    elseif kind == QUEST_KIND.PREY then
        AddTooltipLine(tooltip, "Prey quest", 0.8, 0.9, 1)
    elseif kind == QUEST_KIND.TASK then
        AddTooltipLine(tooltip, "Task / objective quest", 0.8, 0.9, 1)
    end
end

local function AddQuestTooltipObjectives(tooltip, questID)
    local objectives = QuestKing:GetQuestObjectivesText(questID)
    if not objectives or #objectives == 0 then
        return
    end

    AddTooltipLine(tooltip, " ")
    AddTooltipLine(
        tooltip,
        QUEST_TOOLTIP_REQUIREMENTS or "Objectives",
        NORMAL_FONT_COLOR and NORMAL_FONT_COLOR.r or 1,
        NORMAL_FONT_COLOR and NORMAL_FONT_COLOR.g or 0.82,
        NORMAL_FONT_COLOR and NORMAL_FONT_COLOR.b or 0
    )

    for i = 1, #objectives do
        local row = objectives[i]
        if row and row.text and row.text ~= "" then
            if row.finished then
                AddTooltipLine(tooltip, "- " .. row.text, FINISHED_COLOR.r, FINISHED_COLOR.g, FINISHED_COLOR.b)
            else
                AddTooltipLine(tooltip, "- " .. row.text, 1, 1, 1)
            end
        end
    end
end

local function IsInGroupCompat()
    if type(_G.IsInGroup) == "function" then
        local ok, inGroup = SafeCall(_G.IsInGroup)
        if ok then
            return SafeBoolean(inGroup, false)
        end
    end

    if type(_G.GetNumGroupMembers) == "function" then
        local ok, count = SafeCall(_G.GetNumGroupMembers)
        if ok then
            return (SafeNumber(count, 0) or 0) > 0
        end
    end

    return false
end

local function CallWithLegacyQuestSelection(questLogIndex, func)
    if type(questLogIndex) ~= "number"
        or questLogIndex <= 0
        or type(func) ~= "function"
        or type(_G.SelectQuestLogEntry) ~= "function" then
        return false, nil
    end

    local hasOldSelection = false
    local oldSelection = nil

    if type(_G.GetQuestLogSelection) == "function" then
        local ok, selectedIndex = SafeCall(_G.GetQuestLogSelection)
        if ok then
            hasOldSelection = true
            oldSelection = selectedIndex
        end
    end

    local selected = SafeCall(_G.SelectQuestLogEntry, questLogIndex)
    if not selected then
        return false, nil
    end

    local ok, result = SafeCall(func)

    if hasOldSelection and type(oldSelection) == "number" then
        SafeCall(_G.SelectQuestLogEntry, oldSelection)
    end

    return ok, result
end

local function CanRemoveQuestWatch(questID)
    if type(questID) ~= "number" or questID <= 0 then
        return false
    end

    if not IsQuestWatchedCompat(questID) then
        return false
    end

    local questLogIndex = GetQuestLogIndexByIDCompat(questID)

    local questUtil = _G.QuestUtil
    if questUtil and type(questUtil.CanRemoveQuestWatch) == "function" then
        local ok, canRemove = SafeCall(questUtil.CanRemoveQuestWatch)
        if ok and not SafeBoolean(canRemove, false) then
            return false
        end
    end

    if IsClassicFamilyCompat() then
        return questLogIndex ~= nil and type(_G.RemoveQuestWatch) == "function"
    end

    if IsWorldQuest(questID) then
        local questUtil = _G.QuestUtil
        return (questUtil and type(questUtil.UntrackWorldQuest) == "function")
            or (C_QuestLog and type(C_QuestLog.RemoveWorldQuestWatch) == "function")
    end

    return questLogIndex ~= nil
        and (
            (Compat and type(Compat.RemoveQuestWatch) == "function")
            or (C_QuestLog and type(C_QuestLog.RemoveQuestWatch) == "function")
            or type(_G.RemoveQuestWatch) == "function"
        )
end

local function RemoveQuestFromWatchList(questID)
    if not CanRemoveQuestWatch(questID) then
        return false
    end

    local removed = false

    if IsWorldQuest(questID) then
        local questUtil = _G.QuestUtil
        if questUtil and type(questUtil.UntrackWorldQuest) == "function" then
            local ok = SafeCall(questUtil.UntrackWorldQuest, questID)
            removed = ok and true or false
        elseif C_QuestLog and type(C_QuestLog.RemoveWorldQuestWatch) == "function" then
            local ok, wasRemoved = SafeCall(C_QuestLog.RemoveWorldQuestWatch, questID)
            removed = ok and wasRemoved ~= false
        end
    end

    if not removed then
        removed = RemoveQuestWatchByID(questID)
    end

    if removed then
        QueueTrackerRefresh(true)
    end

    return removed
end

local function CanAddQuestWatch(questID)
    if type(questID) ~= "number"
        or questID <= 0
        or IsQuestWatchedCompat(questID) then
        return false
    end

    if IsWorldQuest(questID) then
        local questUtil = _G.QuestUtil
        return (questUtil and type(questUtil.TrackWorldQuest) == "function")
            or (C_QuestLog and type(C_QuestLog.AddWorldQuestWatch) == "function")
    end

    local questLogIndex = GetQuestLogIndexByIDCompat(questID)
    if not questLogIndex then
        return false
    end

    if IsClassicFamilyCompat() then
        return type(_G.AddQuestWatch) == "function"
    end

    return (Compat and type(Compat.AddQuestWatch) == "function")
        or (C_QuestLog and type(C_QuestLog.AddQuestWatch) == "function")
        or type(_G.AddQuestWatch) == "function"
end

local function GetQuestWatchLimit()
    local constants = _G.Constants
    local questWatchConsts = constants and constants.QuestWatchConsts
    local limit = questWatchConsts and questWatchConsts.MAX_QUEST_WATCHES
    if IsSafeNumber(limit) then
        return limit
    end

    return SafeNumber(_G.MAX_WATCHABLE_QUESTS, nil)
end

local function GetQuestWatchCount()
    if Compat and type(Compat.GetNumQuestWatches) == "function" then
        local count = SafeNumber(Compat.GetNumQuestWatches(), nil)
        if count then
            return count
        end
    end

    if C_QuestLog and type(C_QuestLog.GetNumQuestWatches) == "function" then
        local ok, count = SafeCall(C_QuestLog.GetNumQuestWatches)
        if ok then
            return SafeNumber(count, 0) or 0
        end
    end

    if type(_G.GetNumQuestWatches) == "function" then
        local ok, count = SafeCall(_G.GetNumQuestWatches)
        if ok then
            return SafeNumber(count, 0) or 0
        end
    end

    return 0
end

local function GetManualWorldQuestWatchCount()
    if not C_QuestLog
        or type(C_QuestLog.GetNumWorldQuestWatches) ~= "function"
        or type(C_QuestLog.GetQuestIDForWorldQuestWatchIndex) ~= "function"
        or type(C_QuestLog.GetQuestWatchType) ~= "function"
        or not Enum
        or not Enum.QuestWatchType
        or Enum.QuestWatchType.Manual == nil then
        return nil
    end

    local ok, count = SafeCall(C_QuestLog.GetNumWorldQuestWatches)
    count = ok and SafeNumber(count, nil) or nil
    if not count then
        return nil
    end

    local manualCount = 0
    for watchIndex = 1, count do
        local questOK, watchedQuestID = SafeCall(
            C_QuestLog.GetQuestIDForWorldQuestWatchIndex,
            watchIndex
        )
        if questOK and IsSafeNumber(watchedQuestID) then
            local typeOK, watchType = SafeCall(C_QuestLog.GetQuestWatchType, watchedQuestID)
            if typeOK and watchType == Enum.QuestWatchType.Manual then
                manualCount = manualCount + 1
            end
        end
    end

    return manualCount
end

local function IsQuestWatchLimitReached(questID)
    if IsWorldQuest(questID) then
        local limit = SafeNumber(_G.MAX_WORLD_QUEST_WATCHES_MANUAL, nil)
        local count = GetManualWorldQuestWatchCount()
        return limit ~= nil and count ~= nil and count >= limit
    end

    local limit = GetQuestWatchLimit()
    return limit ~= nil and GetQuestWatchCount() >= limit
end

local function ShowQuestWatchLimitError()
    local message = OBJECTIVES_WATCH_TOO_MANY
    if IsClassicFamilyCompat() and QUEST_WATCH_TOO_MANY then
        local limit = GetQuestWatchLimit()
        if limit then
            message = QUEST_WATCH_TOO_MANY:format(limit)
        end
    end

    if not message or message == "" then
        return
    end

    local errorsFrame = _G.UIErrorsFrame
    if errorsFrame and type(errorsFrame.AddMessage) == "function" then
        SafeCall(errorsFrame.AddMessage, errorsFrame, message, 1.0, 0.1, 0.1, 1.0)
    end
end

local function AddQuestToWatchList(questID)
    if not CanAddQuestWatch(questID) then
        return false
    end

    if IsQuestWatchLimitReached(questID) then
        ShowQuestWatchLimitError()
        return false
    end

    local tracked = false
    if IsWorldQuest(questID) then
        local watchType = Enum
            and Enum.QuestWatchType
            and Enum.QuestWatchType.Manual
            or nil
        local questUtil = _G.QuestUtil

        if questUtil and type(questUtil.TrackWorldQuest) == "function" then
            local ok = SafeCall(questUtil.TrackWorldQuest, questID, watchType)
            tracked = ok and true or false
        elseif C_QuestLog and type(C_QuestLog.AddWorldQuestWatch) == "function" then
            local ok, wasWatched
            if watchType ~= nil then
                ok, wasWatched = SafeCall(C_QuestLog.AddWorldQuestWatch, questID, watchType)
            else
                ok, wasWatched = SafeCall(C_QuestLog.AddWorldQuestWatch, questID)
            end
            tracked = ok and wasWatched ~= false
        end
    else
        tracked = AddQuestWatchByID(questID)
    end

    if tracked then
        QueueTrackerRefresh(true)
    end

    return tracked
end

local function CanShareQuestCompat(questID)
    if not IsInGroupCompat() then
        return false
    end

    local questLogIndex = GetQuestLogIndexByIDCompat(questID)
    if not questLogIndex then
        return false
    end

    if C_QuestLog and type(C_QuestLog.IsPushableQuest) == "function" then
        local ok, pushable = SafeCall(C_QuestLog.IsPushableQuest, questID)
        return ok and SafeBoolean(pushable, false)
    end

    if type(_G.GetQuestLogPushable) ~= "function" then
        return false
    end

    local ok, pushable = CallWithLegacyQuestSelection(questLogIndex, _G.GetQuestLogPushable)
    return ok and SafeBoolean(pushable, false)
end

local function ShareQuestCompat(questID)
    if not CanShareQuestCompat(questID) then
        return false
    end

    local questLogIndex = GetQuestLogIndexByIDCompat(questID)
    if not questLogIndex then
        return false
    end

    local questUtil = _G.QuestUtil
    if C_QuestLog
        and type(C_QuestLog.IsPushableQuest) == "function"
        and questUtil
        and type(questUtil.ShareQuest) == "function" then
        local ok = SafeCall(questUtil.ShareQuest, questID)
        return ok and true or false
    end

    if C_QuestLog
        and type(C_QuestLog.IsPushableQuest) == "function"
        and type(_G.QuestLogPushQuest) == "function" then
        local ok = SafeCall(_G.QuestLogPushQuest, questLogIndex)
        return ok and true or false
    end

    if type(_G.QuestLogPushQuest) ~= "function" then
        return false
    end

    local ok, shared = CallWithLegacyQuestSelection(questLogIndex, function()
        local canPush, pushable = SafeCall(_G.GetQuestLogPushable)
        if not canPush or not SafeBoolean(pushable, false) then
            return false
        end

        return SafeCall(_G.QuestLogPushQuest)
    end)

    return ok and shared and true or false
end

local function CanAbandonQuestCompat(questID)
    if not GetQuestLogIndexByIDCompat(questID) then
        return false
    end

    if C_QuestLog and type(C_QuestLog.CanAbandonQuest) == "function" then
        local ok, canAbandon = SafeCall(C_QuestLog.CanAbandonQuest, questID)
        return ok and SafeBoolean(canAbandon, false)
    end

    if type(_G.CanAbandonQuest) == "function" then
        local ok, canAbandon = SafeCall(_G.CanAbandonQuest, questID)
        return ok and SafeBoolean(canAbandon, false)
    end

    return true
end

local function GetAbandonQuestItemNames(items)
    if type(items) == "string" and items ~= "" then
        return items
    end

    if type(items) ~= "table" then
        return nil
    end

    local names = {}
    for i = 1, #items do
        local itemID = SafeNumber(items[i], nil)
        if itemID then
            local itemName = nil

            if _G.C_Item and type(_G.C_Item.GetItemNameByID) == "function" then
                local ok, name = SafeCall(_G.C_Item.GetItemNameByID, itemID)
                if ok then
                    itemName = SafeString(name, nil)
                end
            end

            if not itemName and type(_G.GetItemInfo) == "function" then
                local ok, name = SafeCall(_G.GetItemInfo, itemID)
                if ok then
                    itemName = SafeString(name, nil)
                end
            end

            names[#names + 1] = itemName or ("Item " .. tostring(itemID))
        end
    end

    if #names > 0 then
        return table.concat(names, ", ")
    end

    return nil
end

local function ShowAbandonQuestPopup(title, items)
    if type(_G.StaticPopup_Show) ~= "function" then
        return false
    end

    local itemNames = GetAbandonQuestItemNames(items)
    if itemNames then
        if type(_G.StaticPopup_Hide) == "function" then
            SafeCall(_G.StaticPopup_Hide, "ABANDON_QUEST")
        end

        local ok = SafeCall(
            _G.StaticPopup_Show,
            "ABANDON_QUEST_WITH_ITEMS",
            SafeString(title, UNKNOWN) or UNKNOWN,
            itemNames
        )
        return ok and true or false
    end

    if type(_G.StaticPopup_Hide) == "function" then
        SafeCall(_G.StaticPopup_Hide, "ABANDON_QUEST_WITH_ITEMS")
    end

    local ok = SafeCall(
        _G.StaticPopup_Show,
        "ABANDON_QUEST",
        SafeString(title, UNKNOWN) or UNKNOWN
    )
    return ok and true or false
end

local function ShowAbandonQuestConfirmationCompat(questID)
    if not CanAbandonQuestCompat(questID) then
        return false
    end

    if type(_G.QuestMapQuestOptions_AbandonQuest) == "function" then
        local ok = SafeCall(_G.QuestMapQuestOptions_AbandonQuest, questID)
        if ok then
            return true
        end
    end

    local questLogIndex = GetQuestLogIndexByIDCompat(questID)
    if not questLogIndex then
        return false
    end

    if C_QuestLog
        and type(C_QuestLog.SetSelectedQuest) == "function"
        and type(C_QuestLog.SetAbandonQuest) == "function" then
        local hadOldSelection = false
        local oldSelectedQuest = nil

        if type(C_QuestLog.GetSelectedQuest) == "function" then
            local ok, selectedQuest = SafeCall(C_QuestLog.GetSelectedQuest)
            if ok then
                hadOldSelection = true
                oldSelectedQuest = selectedQuest
            end
        end

        local selected = SafeCall(C_QuestLog.SetSelectedQuest, questID)
        local prepared = selected and SafeCall(C_QuestLog.SetAbandonQuest)
        if not prepared then
            if hadOldSelection and type(oldSelectedQuest) == "number" then
                SafeCall(C_QuestLog.SetSelectedQuest, oldSelectedQuest)
            end
            return false
        end

        local items = nil
        if type(C_QuestLog.GetAbandonQuestItems) == "function" then
            local ok, abandonItems = SafeCall(C_QuestLog.GetAbandonQuestItems)
            if ok then
                items = abandonItems
            end
        end

        local title = nil
        if type(C_QuestLog.GetTitleForQuestID) == "function" then
            local ok, questTitle = SafeCall(C_QuestLog.GetTitleForQuestID, questID)
            if ok then
                title = questTitle
            end
        end

        local shown = ShowAbandonQuestPopup(title, items)

        if hadOldSelection and type(oldSelectedQuest) == "number" then
            SafeCall(C_QuestLog.SetSelectedQuest, oldSelectedQuest)
        end

        return shown
    end

    if type(_G.SetAbandonQuest) ~= "function" then
        return false
    end

    local ok, shown = CallWithLegacyQuestSelection(questLogIndex, function()
        local prepared = SafeCall(_G.SetAbandonQuest)
        if not prepared then
            return false
        end

        local items = nil
        if type(_G.GetAbandonQuestItems) == "function" then
            local gotItems, abandonItems = SafeCall(_G.GetAbandonQuestItems)
            if gotItems then
                items = abandonItems
            end
        end

        local title = nil
        if type(_G.GetAbandonQuestName) == "function" then
            local gotTitle, questTitle = SafeCall(_G.GetAbandonQuestName)
            if gotTitle then
                title = questTitle
            end
        end

        return ShowAbandonQuestPopup(title, items)
    end)

    return ok and shown and true or false
end

local questContextMenu
local lastQuestContextMenuQuestID
local lastQuestContextMenuOpenTime = 0
local QUEST_CONTEXT_MENU_GUARD_SECONDS = 0.25
local ResolveMatchingQuestLogIndex

local QUEST_TRACKING_BACKEND_SUPERTRACK = "supertrack"
local QUEST_TRACKING_BACKEND_WATCH = "watch"

local function GetQuestTrackingBackend()
    if CanSetSuperTrackedQuestIDCompat() then
        return QUEST_TRACKING_BACKEND_SUPERTRACK
    end

    return QUEST_TRACKING_BACKEND_WATCH
end

local function GetQuestTrackingState(questID)
    local backend = GetQuestTrackingBackend()

    if backend == QUEST_TRACKING_BACKEND_SUPERTRACK then
        return GetSuperTrackedQuestIDCompat() == questID, backend
    end

    return IsQuestWatchedCompat(questID), backend
end

local function CanToggleQuestTracking(questID)
    if type(questID) ~= "number" or questID <= 0 then
        return false
    end

    local isTracked, backend = GetQuestTrackingState(questID)
    if backend == QUEST_TRACKING_BACKEND_SUPERTRACK then
        return true
    end

    if isTracked then
        return CanRemoveQuestWatch(questID)
    end

    return CanAddQuestWatch(questID)
end

local function ToggleQuestTracking(questID)
    if type(questID) ~= "number" or questID <= 0 then
        return false
    end

    local isTracked, backend = GetQuestTrackingState(questID)
    if backend == QUEST_TRACKING_BACKEND_SUPERTRACK then
        local nextQuestID = isTracked and 0 or questID
        if SetSuperTrackedQuestIDCompat(nextQuestID) then
            QueueTrackerRefresh(false)
            return true
        end

        return false
    end

    if isTracked then
        return RemoveQuestFromWatchList(questID)
    end

    return AddQuestToWatchList(questID)
end

local function GetQuestContextMenuClock()
    local getTime = _G.GetTimePreciseSec or _G.GetTime
    local ok, now = SafeCall(getTime)
    if ok then
        return SafeNumber(now, 0) or 0
    end

    return 0
end

local function IsQuestContextMenuOpenForQuest(menu, questID)
    local listFrame = _G.DropDownList1
    return menu
        and menu.questID == questID
        and _G.UIDROPDOWNMENU_OPEN_MENU == menu
        and listFrame
        and listFrame.IsShown
        and listFrame:IsShown()
end

local function AddQuestContextMenuButton(text, func, disabled, checked)
    if type(_G.UIDropDownMenu_CreateInfo) ~= "function"
        or type(_G.UIDropDownMenu_AddButton) ~= "function" then
        return
    end

    local info = _G.UIDropDownMenu_CreateInfo()
    info.text = text
    info.func = func
    info.disabled = disabled and true or false
    info.checked = checked and true or false
    info.notCheckable = checked == nil
    _G.UIDropDownMenu_AddButton(info, 1)
end

local function EnsureQuestContextMenu()
    if questContextMenu then
        return questContextMenu
    end

    if type(_G.UIDropDownMenu_Initialize) ~= "function"
        or type(_G.ToggleDropDownMenu) ~= "function" then
        return nil
    end

    questContextMenu = CreateFrame(
        "Frame",
        "QuestKingQuestContextMenu",
        _G.UIParent,
        "UIDropDownMenuTemplate"
    )

    _G.UIDropDownMenu_Initialize(questContextMenu, function(menu, level)
        if level ~= 1 then
            return
        end

        local questID = menu.questID
        if not questID then
            return
        end

        local title = menu.questTitle or UNKNOWN
        AddQuestContextMenuButton(title, nil, true, nil)

        AddQuestContextMenuButton(OBJECTIVES_VIEW_IN_QUESTLOG or "Open Quest Details", function()
            OpenQuestDetailsFromWatch(questID)
        end, false, nil)

        if not IS_MAINLINE then
            AddQuestContextMenuButton(OBJECTIVES_SHOW_QUEST_MAP or "Open Quest Map", function()
                OpenQuestMapFromWatch(questID)
            end, not CanOpenQuestMapFromWatch(questID), nil)
        end

        local isTracked = GetQuestTrackingState(questID)
        local trackingActionText = isTracked
            and (UNTRACK_QUEST or "Untrack Quest")
            or (TRACK_QUEST or "Track Quest")

        AddQuestContextMenuButton(trackingActionText, function()
            ToggleQuestTracking(questID)
        end, not CanToggleQuestTracking(questID), nil)

        local canShare = CanShareQuestCompat(questID)
        AddQuestContextMenuButton(SHARE_QUEST or "Share Quest", function()
            ShareQuestCompat(questID)
        end, not canShare, nil)

        local canAbandon = CanAbandonQuestCompat(questID)
        AddQuestContextMenuButton(ABANDON_QUEST or "Abandon Quest", function()
            ShowAbandonQuestConfirmationCompat(questID)
        end, not canAbandon, nil)
    end, "MENU")

    return questContextMenu
end

local function OpenQuestContextMenu(button, questID, questLogIndex)
    local menu = EnsureQuestContextMenu()
    if not menu then
        return false
    end

    -- A quest row has a clickable title child inside a clickable body parent.
    -- Some clients can dispatch the same hardware click through both regions.
    -- Also ignore any repeated group-driven dispatch while this quest menu is open.
    if IsQuestContextMenuOpenForQuest(menu, questID) then
        return true
    end

    local now = GetQuestContextMenuClock()
    if now > 0
        and lastQuestContextMenuQuestID == questID
        and now - lastQuestContextMenuOpenTime < QUEST_CONTEXT_MENU_GUARD_SECONDS then
        return true
    end

    lastQuestContextMenuQuestID = questID
    lastQuestContextMenuOpenTime = now

    if type(_G.CloseDropDownMenus) == "function" then
        _G.CloseDropDownMenus(1)
    end

    menu.questID = questID
    menu.questLogIndex = questLogIndex
    menu.questTitle = button and button.title and button.title:GetText() or UNKNOWN

    local shown = _G.ToggleDropDownMenu(1, nil, menu, button.titleButton or button, 0, 0)
    return shown ~= false
end

local mouseHandlerQuest = {}

local function ResolveQuestClickSource(source)
    local button = source

    if source and source.parent then
        button = source.parent
    end

    if not button then
        return nil, nil, nil
    end

    local questID = button.questID
    local questLogIndex = button.questLogIndex

    if not questID and questLogIndex then
        questID = GetQuestIDForQuestLogIndex(questLogIndex)
        button.questID = questID
    end

    if questID then
        if ResolveMatchingQuestLogIndex then
            questLogIndex = ResolveMatchingQuestLogIndex(questID, questLogIndex)
        else
            questLogIndex = GetQuestLogIndexByIDCompat(questID)
        end
        button.questLogIndex = questLogIndex
    end

    return button, questID, questLogIndex
end

function mouseHandlerQuest:HandleQuestClick(mouse)
    local button, questID, questLogIndex = ResolveQuestClickSource(self)

    if not button or not questID then
        return
    end

    if mouse == "RightButton" then
        OpenQuestContextMenu(button, questID, questLogIndex)
        return
    end

    OpenQuestFromWatch(questID, questLogIndex)
end

function mouseHandlerQuest:TitleButtonOnClick(mouse)
    mouseHandlerQuest.HandleQuestClick(self, mouse)
end

function mouseHandlerQuest:ButtonOnClick(mouse)
    mouseHandlerQuest.HandleQuestClick(self, mouse)
end

function mouseHandlerQuest:TitleButtonOnEnter()
    local button, questID, questLogIndex = ResolveQuestClickSource(self)

    if not button or not questID then
        return
    end

    local tooltip = QuestKing.PrepareTooltip and QuestKing:PrepareTooltip(self, opt.tooltipAnchor or "ANCHOR_RIGHT")
    if not tooltip then
        return
    end

    local titleText = nil

    if _G.QuestUtils_GetQuestName then
        local ok, questName = SafeCall(_G.QuestUtils_GetQuestName, questID)
        if ok and questName and questName ~= "" then
            titleText = questName
        end
    end

    if (not titleText or titleText == "") and questLogIndex then
        local info = GetQuestInfoByLogIndex(questLogIndex)
        if info then
            titleText = SafeString(info.title, nil)
        end
    end

    if not titleText or titleText == "" then
        titleText = button.title and button.title:GetText() or UNKNOWN
    end

    tooltip:SetText(titleText, 1, 0.82, 0)

    AddQuestTypeLine(tooltip, button.questKind)

    local tagBracket = QuestKing:GetQuestTagBracket(questID)
    if tagBracket then
        AddTooltipLine(tooltip, tagBracket, 0.85, 0.85, 0.85)
    end

    local isTracked, trackingBackend = GetQuestTrackingState(questID)
    if isTracked then
        if trackingBackend == QUEST_TRACKING_BACKEND_SUPERTRACK then
            AddTooltipLine(tooltip, "Tracked for navigation", 1, 0.82, 0.2)
        else
            AddTooltipLine(tooltip, "Tracked in the quest watch list", 1, 0.82, 0.2)
        end
    end

    if CanCompleteQuestRemotely(questID, questLogIndex) then
        AddTooltipLine(tooltip, "Left-click to complete quest", FINISHED_COLOR.r, FINISHED_COLOR.g, FINISHED_COLOR.b)
    elseif IS_MAINLINE then
        AddTooltipLine(tooltip, "Left-click to open quest details", 0.7, 0.7, 0.7)
    else
        AddTooltipLine(tooltip, "Left-click to open quest map", 0.7, 0.7, 0.7)
    end
    AddTooltipLine(tooltip, "Right-click for quest options", 0.7, 0.7, 0.7)

    AddQuestTooltipObjectives(tooltip, questID)
    tooltip:Show()
end

function mouseHandlerQuest:TitleButtonOnLeave()
    if QuestKing.HideTooltip then
        QuestKing:HideTooltip()
    end
end

local availableCampaignContextMenu
local lastAvailableCampaignContextKey
local lastAvailableCampaignContextOpenTime = 0

local function StopTrackingAvailableCampaign(row)
    if type(row) ~= "table" then
        return
    end

    local requirementKey = SafeString(row.requirementKey, nil)
    if not requirementKey then
        return
    end

    SetCampaignRequirementUntracked(requirementKey, true)

    local questID = SafeNumber(row.questID, nil)
    if questID then
        ClearMatchingSuperTrackedQuestOfferCompat(questID)
    end

    QueueTrackerRefresh(true)
end

local function EnsureAvailableCampaignContextMenu()
    if availableCampaignContextMenu then
        return availableCampaignContextMenu
    end

    if type(_G.UIDropDownMenu_Initialize) ~= "function"
        or type(_G.ToggleDropDownMenu) ~= "function" then
        return nil
    end

    availableCampaignContextMenu = CreateFrame(
        "Frame",
        "QuestKingAvailableCampaignContextMenu",
        _G.UIParent,
        "UIDropDownMenuTemplate"
    )

    _G.UIDropDownMenu_Initialize(availableCampaignContextMenu, function(menu, level)
        if level ~= 1 or type(menu.campaignRow) ~= "table" then
            return
        end

        local row = menu.campaignRow
        AddQuestContextMenuButton(row.title or CAMPAIGN_HEADER, nil, true, nil)
        AddQuestContextMenuButton(
            OBJECTIVES_STOP_TRACKING or "Stop Tracking",
            function()
                StopTrackingAvailableCampaign(row)
            end,
            false,
            nil
        )
    end, "MENU")

    return availableCampaignContextMenu
end

local function IsAvailableCampaignContextMenuOpen(menu, requirementKey)
    local listFrame = _G.DropDownList1
    return menu
        and menu.requirementKey == requirementKey
        and _G.UIDROPDOWNMENU_OPEN_MENU == menu
        and listFrame
        and listFrame.IsShown
        and listFrame:IsShown()
end

local function OpenAvailableCampaignContextMenu(button, row)
    if not button or type(row) ~= "table" then
        return false
    end

    local requirementKey = SafeString(row.requirementKey, nil)
    local menu = EnsureAvailableCampaignContextMenu()
    if not requirementKey or not menu then
        return false
    end

    if IsAvailableCampaignContextMenuOpen(menu, requirementKey) then
        return true
    end

    local now = GetQuestContextMenuClock()
    if now > 0
        and lastAvailableCampaignContextKey == requirementKey
        and now - lastAvailableCampaignContextOpenTime < QUEST_CONTEXT_MENU_GUARD_SECONDS then
        return true
    end

    lastAvailableCampaignContextKey = requirementKey
    lastAvailableCampaignContextOpenTime = now

    if type(_G.CloseDropDownMenus) == "function" then
        _G.CloseDropDownMenus(1)
    end

    menu.requirementKey = requirementKey
    menu.campaignRow = row

    local shown = _G.ToggleDropDownMenu(1, nil, menu, button.titleButton or button, 0, 0)
    return shown ~= false
end

local mouseHandlerAvailableCampaign = {}

local function ResolveAvailableCampaignClickSource(source)
    local button = source
    if source and source.parent then
        button = source.parent
    end

    if not button then
        return nil, nil
    end

    return button, button._availableCampaignRow
end

function mouseHandlerAvailableCampaign:HandleCampaignClick(mouse)
    local button, row = ResolveAvailableCampaignClickSource(self)
    if not button or not row then
        return
    end

    if mouse == "RightButton" then
        OpenAvailableCampaignContextMenu(button, row)
        return
    end

    OpenAvailableCampaignStep(row)
end

function mouseHandlerAvailableCampaign:TitleButtonOnClick(mouse)
    mouseHandlerAvailableCampaign.HandleCampaignClick(self, mouse)
end

function mouseHandlerAvailableCampaign:ButtonOnClick(mouse)
    mouseHandlerAvailableCampaign.HandleCampaignClick(self, mouse)
end

function mouseHandlerAvailableCampaign:TitleButtonOnEnter()
    local _, row = ResolveAvailableCampaignClickSource(self)
    if not row then
        return
    end

    local tooltip = QuestKing.PrepareTooltip and QuestKing:PrepareTooltip(self, opt.tooltipAnchor or "ANCHOR_RIGHT")
    if not tooltip then
        return
    end

    tooltip:SetText(row.title or CAMPAIGN_HEADER, 1, 0.82, 0)
    AddTooltipLine(tooltip, row.text, AVAILABLE_CAMPAIGN_COLOR.r, AVAILABLE_CAMPAIGN_COLOR.g, AVAILABLE_CAMPAIGN_COLOR.b)

    if row.questID then
        if GetSuperTrackedQuestOfferIDCompat() == row.questID then
            AddTooltipLine(tooltip, "Pickup is being tracked", 1, 0.82, 0.2)
        end
        AddTooltipLine(tooltip, "Left-click to focus the next campaign quest", 0.7, 0.7, 0.7)
    elseif row.mapID and not IS_MAINLINE then
        AddTooltipLine(tooltip, "Left-click to open the campaign area map", 0.7, 0.7, 0.7)
    end
    AddTooltipLine(tooltip, "Right-click for campaign options", 0.7, 0.7, 0.7)

    tooltip:Show()
end

function mouseHandlerAvailableCampaign:TitleButtonOnLeave()
    if QuestKing.HideTooltip then
        QuestKing:HideTooltip()
    end
end

function QuestKing:GetQuestDisplayData(questLogIndex)
    if type(self.RecordPerformanceMetric) == "function" then
        self:RecordPerformanceMetric("objectiveScanCount", 1)
    end

    local info = GetQuestInfoByLogIndex(questLogIndex)
    if not info or info.isHeader then
        return nil
    end

    local questID = SafeNumber(info.questID, nil)
    if not questID then
        questID = GetQuestIDForQuestLogIndex(questLogIndex)
    end

    if not questID then
        return nil
    end

    local kind = self:GetQuestKind(questID, info)
    local objectives, hasProgressBarObjective = self:GetQuestObjectivesText(questID)
    local percent = nil

    if hasProgressBarObjective then
        percent = GetQuestProgressPercent(questID)
    end

    return {
        questID = questID,
        kind = kind,
        title = SafeString(info.title, UNKNOWN) or UNKNOWN,
        level = GetDifficultyLevel(info),
        isComplete = IsQuestCompleteCompat(questID, questLogIndex, info),
        isFailed = IsQuestFailedCompat(questID, questLogIndex, info),
        tagBracket = self:GetQuestTagBracket(questID),
        objectives = objectives,
        hasProgressBarObjective = hasProgressBarObjective,
        percent = percent,
    }
end

local function GetTaskQuestTitle(questID)
    if C_QuestLog and C_QuestLog.GetTitleForQuestID then
        local ok, title = SafeCall(C_QuestLog.GetTitleForQuestID, questID)
        title = SafeString(title, nil)
        if ok and title then
            return title
        end
    end

    if type(_G.GetTaskInfo) == "function" then
        local ok, _, _, _, taskName = SafeCall(_G.GetTaskInfo, questID)
        taskName = SafeString(taskName, nil)
        if ok and taskName then
            return taskName
        end
    end

    return UNKNOWN
end

function QuestKing:GetTaskQuestDisplayData(questID, kindOverride)
    questID = SafeNumber(questID, nil)
    if not questID or questID <= 0 then
        return nil
    end

    if type(self.RecordPerformanceMetric) == "function" then
        self:RecordPerformanceMetric("objectiveScanCount", 1)
    end

    local kind = kindOverride or self:GetQuestKind(questID)
    local objectives, hasProgressBarObjective = self:GetQuestObjectivesText(questID)
    local percent = nil

    if hasProgressBarObjective then
        percent = GetQuestProgressPercent(questID)
    end

    return {
        questID = questID,
        kind = kind,
        title = GetTaskQuestTitle(questID),
        level = GetDifficultyLevel({ questID = questID }),
        isComplete = IsQuestCompleteCompat(questID),
        isFailed = IsQuestFailedCompat(questID),
        tagBracket = self:GetQuestTagBracket(questID),
        objectives = objectives,
        hasProgressBarObjective = hasProgressBarObjective,
        percent = percent,
    }
end

ResolveMatchingQuestLogIndex = function(questID, questLogIndex)
    if type(questID) ~= "number" or questID <= 0 then
        return nil
    end

    local function IndexMatches(index)
        if type(index) ~= "number" or index <= 0 then
            return false
        end

        local info = GetQuestInfoByLogIndex(index)
        if not info or info.isHeader then
            return false
        end

        local indexedQuestID = SafeNumber(info.questID, nil)
            or GetQuestIDForQuestLogIndex(index)
        return indexedQuestID == questID
    end

    if IndexMatches(questLogIndex) then
        return questLogIndex
    end

    local resolvedIndex = GetQuestLogIndexByIDCompat(questID)
    if IndexMatches(resolvedIndex) then
        return resolvedIndex
    end

    return nil
end

function QuestKing:SetButtonToQuest(button, questLogIndex, displayData)
    if not button then
        return
    end

    local data = type(displayData) == "table"
        and displayData
        or self:GetQuestDisplayData(questLogIndex)
    if not data then
        return
    end

    questLogIndex = ResolveMatchingQuestLogIndex(data.questID, questLogIndex)

    local isFailed = data.isFailed and true or false
    local canCompleteRemotely = not isFailed
        and CanCompleteQuestRemotely(data.questID, questLogIndex, data.isComplete)
        or false
    local isEffectivelyComplete = not isFailed and (data.isComplete or canCompleteRemotely)

    local itemLink, itemTexture, itemCharges, itemShowWhenComplete = GetQuestLogSpecialItemInfoCompat(questLogIndex)
    if itemShowWhenComplete == false and isEffectivelyComplete then
        itemLink = nil
        itemTexture = nil
        itemCharges = nil
    end

    local itemAnchorSide = (opt.itemAnchorSide == "left") and "left" or "right"
    local itemScale = SafeNumber(QuestKing.itemButtonScale, nil) or SafeNumber(opt.itemButtonScale, nil) or 1
    if itemScale <= 0 then
        itemScale = 1
    end

    local itemInset = 0
    if itemLink and itemTexture then
        itemInset = floor(((opt.lineHeight or 16) * 2 * itemScale) + 10)
    end

    button.currentLine = 0
    button.mouseHandler = mouseHandlerQuest
    button.questID = data.questID
    button.questLogIndex = questLogIndex
    button.questKind = data.kind

    if button.SetMouseMode then
        button:SetMouseMode(true, true)
    end

    local kindPrefix = GetKindPrefix(data.kind)
    local title = SafeString(data.title, UNKNOWN) or UNKNOWN
    local displayTitle = title

    if kindPrefix then
        displayTitle = ("%s %s"):format(kindPrefix, title)
    end

    if data.tagBracket and data.kind == QUEST_KIND.NORMAL then
        displayTitle = ("%s %s"):format(title, data.tagBracket)
    end

    local titleLeftInset = LINE_LEFT_PADDING
    local titleRightInset = LINE_RIGHT_PADDING

    if itemInset > 0 then
        if itemAnchorSide == "right" then
            titleRightInset = titleRightInset + itemInset
        else
            titleLeftInset = titleLeftInset + itemInset
        end
    end

    if button.title then
        if isFailed then
            button.title:SetText(displayTitle)
            button.title:SetTextColor(FAILED_COLOR.r, FAILED_COLOR.g, FAILED_COLOR.b)
        elseif canCompleteRemotely then
            button.title:SetText("|TInterface\\RAIDFRAME\\ReadyCheck-Ready:0:0:1:1|t " .. displayTitle)
            button.title:SetTextColor(TITLE_COMPLETE_COLOR.r, TITLE_COMPLETE_COLOR.g, TITLE_COMPLETE_COLOR.b)
        else
            button.title:SetText(displayTitle)
            if isEffectivelyComplete then
                button.title:SetTextColor(TITLE_COMPLETE_COLOR.r, TITLE_COMPLETE_COLOR.g, TITLE_COMPLETE_COLOR.b)
            else
                button.title:SetTextColor(TITLE_COLOR.r, TITLE_COLOR.g, TITLE_COLOR.b)
            end
        end

        button.title:ClearAllPoints()
        button.title:SetPoint("TOPLEFT", button, "TOPLEFT", titleLeftInset, -4)
        button.title:SetPoint("RIGHT", button, "RIGHT", -titleRightInset, 0)
        button.title:SetJustifyH("LEFT")
    end

    if button.level then
        local col = GetDifficultyColor(data.level)
        local lvlText = (IsSafeNumber(data.level) and data.level > 0) and ("[" .. tostring(data.level) .. "]") or ""
        local levelLeftInset = 4

        if itemInset > 0 and itemAnchorSide == "left" then
            levelLeftInset = levelLeftInset + itemInset
        end

        button.level:SetText(lvlText)
        button.level:SetTextColor(col.r or 1, col.g or 0.82, col.b or 0)
        button.level:ClearAllPoints()
        button.level:SetPoint("TOPLEFT", button, "TOPLEFT", levelLeftInset, -4)

        if button.title and lvlText ~= "" then
            button.title:ClearAllPoints()
            button.title:SetPoint("TOPLEFT", button.level, "TOPRIGHT", LEVEL_GAP_X, 0)
            button.title:SetPoint("RIGHT", button, "RIGHT", -titleRightInset, 0)
        end
    end

    if button.completed then
        button.completed:SetShown(isEffectivelyComplete)
    end

    local visibleObjectives = 0
    local showProgressBar = false
    local isNewQuest = button.fresh or (self.newlyAddedQuests and self.newlyAddedQuests[data.questID])

    if isFailed then
        local line = button:AddLine(
            _G.FAILED or "Failed",
            nil,
            FAILED_COLOR.r,
            FAILED_COLOR.g,
            FAILED_COLOR.b
        )
        ApplyObjectiveLineIndent(line)
        FreeLineBars(line)
        visibleObjectives = visibleObjectives + 1
    else
        for i = 1, #data.objectives do
            local row = data.objectives[i]
            if ShouldShowQuestObjective(row, isEffectivelyComplete) then
                if row.type == "progressbar" then
                    showProgressBar = true
                else
                    AddQuestObjectiveLine(button, row, isNewQuest)
                end
                visibleObjectives = visibleObjectives + 1
            end
        end

        if data.hasProgressBarObjective
            and showProgressBar
            and IsSafeNumber(data.percent) then
            AddQuestProgressBar(button, data.percent, data.questID)
            visibleObjectives = visibleObjectives + 1
        end

        if isEffectivelyComplete then
            local line = button:AddLine(
                canCompleteRemotely and GetRemoteQuestCompletionText() or GetQuestCompletionLineText(),
                nil,
                FINISHED_COLOR.r,
                FINISHED_COLOR.g,
                FINISHED_COLOR.b
            )
            ApplyObjectiveLineIndent(line)
            FreeLineBars(line)
            line:SetAlpha(COMPLETED_ALPHA)
            if line.right then
                line.right:SetAlpha(COMPLETED_ALPHA)
            end
            visibleObjectives = visibleObjectives + 1

            if canCompleteRemotely then
                local clickLine = button:AddLine(
                    GetClickToCompleteText(data.questID),
                    nil,
                    FINISHED_COLOR.r,
                    FINISHED_COLOR.g,
                    FINISHED_COLOR.b
                )
                ApplyObjectiveLineIndent(clickLine)
                FreeLineBars(clickLine)
                visibleObjectives = visibleObjectives + 1
            end
        end
    end

    if itemLink and itemTexture then
        button:SetItemButton(questLogIndex, itemLink, itemTexture, itemCharges, visibleObjectives)
    else
        button:RemoveItemButton()
    end
end

function QuestKing:SetButtonToAvailableCampaign(button, row)
    if not button or type(row) ~= "table" then
        return
    end

    button.currentLine = 0
    button.mouseHandler = mouseHandlerAvailableCampaign
    button.questID = SafeNumber(row.questID, nil)
    button.questLogIndex = nil
    button.questKind = QUEST_KIND.CAMPAIGN
    button.campaignID = SafeNumber(row.campaignID, nil)
    button.campaignMapID = SafeNumber(row.mapID, nil)
    button.campaignRequirementKey = SafeString(row.requirementKey, nil)
    button._availableCampaignRow = row

    if button.SetMouseMode then
        button:SetMouseMode(true, true)
    end

    if button.title then
        local title = SafeString(row.title, CAMPAIGN_HEADER) or CAMPAIGN_HEADER
        local kindPrefix = GetKindPrefix(QUEST_KIND.CAMPAIGN)
        if kindPrefix then
            title = ("%s %s"):format(kindPrefix, title)
        end

        button.title:SetText(title)
        button.title:SetTextColor(TITLE_COLOR.r, TITLE_COLOR.g, TITLE_COLOR.b)
        button.title:ClearAllPoints()
        button.title:SetPoint("TOPLEFT", button, "TOPLEFT", LINE_LEFT_PADDING, -4)
        button.title:SetPoint("RIGHT", button, "RIGHT", -LINE_RIGHT_PADDING, 0)
        button.title:SetJustifyH("LEFT")
    end

    if button.level then
        button.level:SetText("")
    end

    if button.completed then
        button.completed:SetShown(false)
    end

    if button.SetIcon then
        button:SetIcon(QUEST_ICON_EXCLAMATION)
    end

    local line = button:AddLine(
        SafeString(row.text, "") or "",
        nil,
        AVAILABLE_CAMPAIGN_COLOR.r,
        AVAILABLE_CAMPAIGN_COLOR.g,
        AVAILABLE_CAMPAIGN_COLOR.b
    )
    ApplyObjectiveLineIndent(line)
    FreeLineBars(line)
    line:SetAlpha(1)
    if line.right then
        line.right:SetAlpha(1)
    end

    button:RemoveItemButton()
end

local function AddSectionHeader(headerText)
    if not WatchButton or type(WatchButton.GetKeyed) ~= "function" then
        return nil
    end

    local header = WatchButton:GetKeyed("header", "quest_header_" .. tostring(headerText))
    if not header then
        return nil
    end

    if header.title then
        header.title:SetText(headerText)
        header.title:SetTextColor(SECTION_HEADER_COLOR.r, SECTION_HEADER_COLOR.g, SECTION_HEADER_COLOR.b)
    end

    if header.SetMouseMode then
        header:SetMouseMode(false, false)
    end

    return header
end

local function GetNumQuestWatchesCompat()
    if C_QuestLog and C_QuestLog.GetNumQuestWatches then
        local ok, count = SafeCall(C_QuestLog.GetNumQuestWatches)
        count = SafeNumber(count, nil)
        if ok and IsSafeNumber(count) and count >= 0 then
            return count, true
        end
    end

    if _G.GetNumQuestWatches then
        local ok, count = SafeCall(_G.GetNumQuestWatches)
        count = SafeNumber(count, nil)
        if ok and IsSafeNumber(count) and count >= 0 then
            return count, true
        end
    end

    return 0, false
end

local function GetNumWorldQuestWatchesCompat()
    if C_QuestLog and C_QuestLog.GetNumWorldQuestWatches then
        local ok, count = SafeCall(C_QuestLog.GetNumWorldQuestWatches)
        if ok then
            return SafeNumber(count, 0) or 0
        end
    end

    return 0
end

local function GetWorldQuestIDForWatchIndex(watchIndex)
    if type(watchIndex) ~= "number" or watchIndex <= 0 then
        return nil
    end

    if C_QuestLog and C_QuestLog.GetQuestIDForWorldQuestWatchIndex then
        local ok, questID = SafeCall(C_QuestLog.GetQuestIDForWorldQuestWatchIndex, watchIndex)
        if ok and type(questID) == "number" and questID > 0 then
            return questID
        end
    end

    return nil
end

local localWorldQuestIDScratch = {}
local localWorldQuestSeenScratch = {}
local populationFingerprintPartsScratch = {}

local function GetLocalWorldQuestIDs()
    local worldQuestIDs = localWorldQuestIDScratch
    local seenQuestIDs = localWorldQuestSeenScratch
    wipe(worldQuestIDs)
    wipe(seenQuestIDs)

    if type(_G.GetTasksTable) ~= "function" then
        return worldQuestIDs
    end

    local ok, tasks = SafeCall(_G.GetTasksTable)
    if not ok or type(tasks) ~= "table" then
        return worldQuestIDs
    end

    for i = 1, #tasks do
        local questID = SafeNumber(tasks[i], nil)
        if questID
            and questID > 0
            and not seenQuestIDs[questID]
            and IsWorldQuest(questID) then
            seenQuestIDs[questID] = true
            worldQuestIDs[#worldQuestIDs + 1] = questID
        end
    end

    sort(worldQuestIDs)
    return worldQuestIDs
end

local function GetTrackerPopulationFingerprint()
    local numWatches, watchAPIAvailable = GetNumQuestWatchesCompat()
    local numWorldQuestWatches = GetNumWorldQuestWatchesCompat()
    local localWorldQuestIDs = GetLocalWorldQuestIDs()
    local parts = populationFingerprintPartsScratch
    wipe(parts)
    parts[1] = watchAPIAvailable and "watch-api" or "watch-fallback"
    parts[2] = tostring(numWatches)

    for watchIndex = 1, numWatches do
        local questID = GetQuestIDForWatchIndex(watchIndex)
        parts[#parts + 1] = tostring(SafeNumber(questID, 0) or 0)
    end

    parts[#parts + 1] = "world"
    parts[#parts + 1] = tostring(numWorldQuestWatches)
    for watchIndex = 1, numWorldQuestWatches do
        local questID = GetWorldQuestIDForWatchIndex(watchIndex)
        parts[#parts + 1] = tostring(SafeNumber(questID, 0) or 0)
    end

    parts[#parts + 1] = "local-world"
    parts[#parts + 1] = tostring(#localWorldQuestIDs)
    for i = 1, #localWorldQuestIDs do
        parts[#parts + 1] = tostring(localWorldQuestIDs[i])
    end

    parts[#parts + 1] = "prey"
    parts[#parts + 1] = tostring(SafeNumber(GetActivePreyQuest(), 0) or 0)

    return concat(parts, ":"),
        numWatches,
        watchAPIAvailable,
        numWorldQuestWatches,
        localWorldQuestIDs
end

local function GetNumQuestLogEntriesCompat()
    if C_QuestLog and C_QuestLog.GetNumQuestLogEntries then
        local ok, count = SafeCall(C_QuestLog.GetNumQuestLogEntries)
        if ok then
            return SafeNumber(count, 0) or 0
        end
    end

    if _G.GetNumQuestLogEntries then
        local ok, count = SafeCall(_G.GetNumQuestLogEntries)
        if ok then
            return SafeNumber(count, 0) or 0
        end
    end

    return 0
end

local function GetQuestHeaderState(questLogIndex)
    if C_QuestLog and C_QuestLog.GetInfo then
        local ok, info = SafeCall(C_QuestLog.GetInfo, questLogIndex)
        if ok and type(info) == "table" then
            return SafeBoolean(info.isHeader, false), SafeBoolean(info.isCollapsed, false)
        end
    end

    if _G.GetQuestLogTitle then
        local ok, _, _, _, isHeader, isCollapsed = SafeCall(_G.GetQuestLogTitle, questLogIndex)
        if ok then
            return SafeBoolean(isHeader, false), SafeBoolean(isCollapsed, false)
        end
    end

    return false, false
end

local function ExpandCollapsedQuestLogHeaders()
    local collapsedHeaderIndices = {}
    if type(_G.ExpandQuestHeader) ~= "function"
        or type(_G.CollapseQuestHeader) ~= "function" then
        return collapsedHeaderIndices
    end

    local questLogIndex = 1
    local numEntries = GetNumQuestLogEntriesCompat()

    while questLogIndex <= numEntries do
        local isHeader, isCollapsed = GetQuestHeaderState(questLogIndex)
        if isHeader and isCollapsed then
            collapsedHeaderIndices[#collapsedHeaderIndices + 1] = questLogIndex
            SafeCall(_G.ExpandQuestHeader, questLogIndex)
            numEntries = GetNumQuestLogEntriesCompat()
        end

        questLogIndex = questLogIndex + 1
    end

    return collapsedHeaderIndices
end

local function RestoreCollapsedQuestLogHeaders(collapsedHeaderIndices)
    if type(collapsedHeaderIndices) ~= "table"
        or type(_G.CollapseQuestHeader) ~= "function" then
        return
    end

    for i = #collapsedHeaderIndices, 1, -1 do
        SafeCall(_G.CollapseQuestHeader, collapsedHeaderIndices[i])
    end
end

local function RunQuestLogPopulationScan(expandHeaders, callback)
    local previousScanDepth = SafeNumber(QuestKing._questLogPopulationScanDepth, 0) or 0
    local collapsedHeaderIndices = {}

    if expandHeaders then
        QuestKing._questLogPopulationScanDepth = previousScanDepth + 1
        collapsedHeaderIndices = ExpandCollapsedQuestLogHeaders()
    end

    local ok, scanError = pcall(callback)

    if expandHeaders then
        RestoreCollapsedQuestLogHeaders(collapsedHeaderIndices)
        QuestKing._questLogPopulationScanDepth = previousScanDepth
    end

    if not ok then
        error(scanError, 0)
    end
end

function QuestKing:GetTrackerPopulationPolicy()
    local configuredPolicy = opt.trackerPopulationPolicy
    if configuredPolicy ~= TRACKER_POPULATION_WATCHED
        and configuredPolicy ~= TRACKER_POPULATION_ALL then
        configuredPolicy = TRACKER_POPULATION_AUTOMATIC
    end

    local resolvedPolicy = configuredPolicy
    if resolvedPolicy == TRACKER_POPULATION_AUTOMATIC then
        resolvedPolicy = IsClassicFamilyCompat()
            and TRACKER_POPULATION_ALL
            or TRACKER_POPULATION_WATCHED
    end

    return configuredPolicy, resolvedPolicy
end

local function AddQuestSortRow(
    rows,
    seenQuestIDs,
    self,
    questID,
    questLogIndex,
    info,
    includeDisplayData
)
    if type(questID) ~= "number" or questID <= 0 then
        return false
    end

    if seenQuestIDs[questID] then
        return true
    end

    if not questLogIndex then
        questLogIndex = GetQuestLogIndexByIDCompat(questID)
    end

    if not info and questLogIndex then
        info = GetQuestInfoByLogIndex(questLogIndex)
    end

    if info and not info.isHeader and not info.isHidden then
        seenQuestIDs[questID] = true
        rows[#rows + 1] = {
            questID = questID,
            questLogIndex = questLogIndex,
            kind = self:GetQuestKind(questID, info),
            sortText = SafeString(info.title, "") or "",
            displayData = includeDisplayData and self:GetQuestDisplayData(questLogIndex) or nil,
        }
        return true
    end

    return false
end

local function AddTaskQuestSortRow(
    rows,
    seenQuestIDs,
    self,
    questID,
    includeDisplayData
)
    if type(questID) ~= "number" or questID <= 0 then
        return false
    end

    if seenQuestIDs[questID] then
        return true
    end

    local kind = self:GetQuestKind(questID)
    if kind ~= QUEST_KIND.SPECIAL_ASSIGNMENT
        and kind ~= QUEST_KIND.PREY then
        kind = QUEST_KIND.WORLD_QUEST
    end

    local displayData = includeDisplayData
        and self:GetTaskQuestDisplayData(questID, kind)
        or nil
    local title = displayData and displayData.title or GetTaskQuestTitle(questID)

    seenQuestIDs[questID] = true
    rows[#rows + 1] = {
        rowType = ROW_TYPE_TASK_QUEST,
        questID = questID,
        questLogIndex = nil,
        kind = kind,
        sortText = SafeString(title, "") or "",
        displayData = displayData,
    }
    return true
end

local function AddQuestLogRows(rows, seenQuestIDs, self, includeDisplayData)
    local numEntries = GetNumQuestLogEntriesCompat()
    for questLogIndex = 1, numEntries do
        local info = GetQuestInfoByLogIndex(questLogIndex)
        if info and not info.isHeader and not info.isHidden then
            local questID = SafeNumber(info.questID, nil) or GetQuestIDForQuestLogIndex(questLogIndex)
            AddQuestSortRow(
                rows,
                seenQuestIDs,
                self,
                questID,
                questLogIndex,
                info,
                includeDisplayData
            )
        end
    end
end

local function SortQuestRows(rows)
    local focusedQuestID = GetSuperTrackedQuestIDCompat()

    sort(rows, function(a, b)
        local aOrder = GetKindOrder(a.kind)
        local bOrder = GetKindOrder(b.kind)
        if aOrder ~= bOrder then
            return aOrder < bOrder
        end

        local aFocused = focusedQuestID == a.questID and 1 or 0
        local bFocused = focusedQuestID == b.questID and 1 or 0
        if aFocused ~= bFocused then
            return aFocused > bFocused
        end

        return (a.sortText or "") < (b.sortText or "")
    end)
end

local function RefreshCachedQuestRows(
    self,
    refreshDisplayData,
    populationFingerprint
)
    local rows = self.questSortTable
    if self._questSortTableReady ~= true or type(rows) ~= "table" then
        return false
    end

    if type(populationFingerprint) ~= "string"
        or populationFingerprint ~= self._questSortPopulationFingerprint then
        return false
    end

    local currentEntryCount = GetNumQuestLogEntriesCompat()
    if currentEntryCount ~= self._questSortLogEntryCount then
        return false
    end

    if not refreshDisplayData then
        if type(self.RecordPerformanceMetric) == "function" then
            self:RecordPerformanceMetric("cachedPopulationRefreshCount", 1)
        end
        SortQuestRows(rows)
        return true
    end

    local refreshed = false
    local shouldExpandHeaders = self.trackerQuestPopulationResolvedPolicy == TRACKER_POPULATION_ALL
        or IsClassicFamilyCompat()

    RunQuestLogPopulationScan(shouldExpandHeaders, function()
        refreshed = true

        for i = 1, #rows do
            local row = rows[i]
            if row and row.rowType ~= ROW_TYPE_AVAILABLE_CAMPAIGN then
                if row.rowType == ROW_TYPE_TASK_QUEST then
                    local kind = self:GetQuestKind(row.questID)
                    if kind ~= QUEST_KIND.SPECIAL_ASSIGNMENT
                        and kind ~= QUEST_KIND.PREY then
                        kind = QUEST_KIND.WORLD_QUEST
                    end

                    local displayData = self:GetTaskQuestDisplayData(row.questID, kind)
                    if not displayData then
                        refreshed = false
                        return
                    end

                    local sortText = SafeString(displayData.title, "") or ""
                    if kind ~= row.kind or sortText ~= row.sortText then
                        refreshed = false
                        return
                    end

                    row.questLogIndex = nil
                    row.displayData = displayData
                else
                    local questLogIndex = ResolveMatchingQuestLogIndex(row.questID, row.questLogIndex)
                    if not questLogIndex then
                        refreshed = false
                        return
                    end

                    local info = GetQuestInfoByLogIndex(questLogIndex)
                    if not info or info.isHeader or info.isHidden then
                        refreshed = false
                        return
                    end

                    local kind = self:GetQuestKind(row.questID, info)
                    local sortText = SafeString(info.title, "") or ""
                    if kind ~= row.kind or sortText ~= row.sortText then
                        refreshed = false
                        return
                    end

                    local displayData = self:GetQuestDisplayData(questLogIndex)
                    if not displayData then
                        refreshed = false
                        return
                    end

                    row.questLogIndex = questLogIndex
                    row.displayData = displayData
                end
            end
        end
    end)

    if not refreshed then
        return false
    end

    self._questSortDisplayDataReady = true
    if type(self.RecordPerformanceMetric) == "function" then
        self:RecordPerformanceMetric("cachedPopulationRefreshCount", 1)
    end
    SortQuestRows(rows)
    return true
end

function QuestKing:BuildQuestSortTable(forceBuild, refreshDisplayData)
    self.questSortTable = self.questSortTable or {}
    local questSortTable = self.questSortTable
    refreshDisplayData = refreshDisplayData ~= false
    local configuredPolicy, resolvedPolicy = self:GetTrackerPopulationPolicy()
    local populationFingerprint,
        numWatches,
        watchAPIAvailable,
        numWorldQuestWatches,
        localWorldQuestIDs = GetTrackerPopulationFingerprint()

    if resolvedPolicy == TRACKER_POPULATION_WATCHED and not watchAPIAvailable then
        resolvedPolicy = TRACKER_POPULATION_ALL
    end
    populationFingerprint = populationFingerprint
        .. ":policy:"
        .. tostring(resolvedPolicy)

    if refreshDisplayData then
        self.watchMoney = false
    end

    if not forceBuild
        and RefreshCachedQuestRows(
            self,
            refreshDisplayData,
            populationFingerprint
        ) then
        return questSortTable
    end

    -- A failed cached refresh can have inspected only part of the old
    -- population. Start the authoritative full pass with a clean money-watch
    -- state so removed money objectives cannot leave PLAYER_MONEY armed.
    if refreshDisplayData then
        self.watchMoney = false
    end

    if type(self.RecordPerformanceMetric) == "function" then
        self:RecordPerformanceMetric("fullRebuildCount", 1)
        self:RecordPerformanceMetric("questLogScanCount", 1)
    end

    wipe(questSortTable)

    self.trackerQuestPopulationQuestIDs = self.trackerQuestPopulationQuestIDs or {}
    wipe(self.trackerQuestPopulationQuestIDs)
    self.trackerQuestPopulationKinds = self.trackerQuestPopulationKinds or {}
    wipe(self.trackerQuestPopulationKinds)
    self.trackerWorldQuestFallbackIDs = self.trackerWorldQuestFallbackIDs or {}
    wipe(self.trackerWorldQuestFallbackIDs)
    self.trackerWorldQuestFallbackQuestIDs = self.trackerWorldQuestFallbackQuestIDs or {}
    wipe(self.trackerWorldQuestFallbackQuestIDs)
    self.trackerQuestPopulationCount = 0
    self.trackerQuestHasContent = false

    self._questSortSeenQuestIDs = self._questSortSeenQuestIDs or {}
    self._questSortSeenWorldQuestFallbackIDs = self._questSortSeenWorldQuestFallbackIDs or {}
    local seenQuestIDs = self._questSortSeenQuestIDs
    local seenWorldQuestFallbackIDs = self._questSortSeenWorldQuestFallbackIDs
    wipe(seenQuestIDs)
    wipe(seenWorldQuestFallbackIDs)

    local rows = questSortTable

    self.trackerQuestPopulationPolicy = configuredPolicy
    self.trackerQuestPopulationResolvedPolicy = resolvedPolicy

    local shouldExpandHeaders = resolvedPolicy == TRACKER_POPULATION_ALL
        or IsClassicFamilyCompat()

    RunQuestLogPopulationScan(shouldExpandHeaders, function()
        for i = 1, numWatches do
            local questID = GetQuestIDForWatchIndex(i)
            AddQuestSortRow(
                rows,
                seenQuestIDs,
                self,
                questID,
                nil,
                nil,
                refreshDisplayData
            )
        end

        if resolvedPolicy == TRACKER_POPULATION_ALL then
            AddQuestLogRows(rows, seenQuestIDs, self, refreshDisplayData)
        end

        for i = 1, numWorldQuestWatches do
            local questID = GetWorldQuestIDForWatchIndex(i)
            local hasNormalQuestRow = AddQuestSortRow(
                rows,
                seenQuestIDs,
                self,
                questID,
                nil,
                nil,
                refreshDisplayData
            )
            if type(questID) == "number"
                and questID > 0
                and not hasNormalQuestRow
                and not seenWorldQuestFallbackIDs[questID] then
                AddTaskQuestSortRow(
                    rows,
                    seenQuestIDs,
                    self,
                    questID,
                    refreshDisplayData
                )
                seenWorldQuestFallbackIDs[questID] = true
                self.trackerWorldQuestFallbackIDs[#self.trackerWorldQuestFallbackIDs + 1] = questID
                self.trackerWorldQuestFallbackQuestIDs[questID] = true
            end
        end

        for i = 1, #localWorldQuestIDs do
            local questID = localWorldQuestIDs[i]
            if not seenQuestIDs[questID] then
                local hasNormalQuestRow = AddQuestSortRow(
                    rows,
                    seenQuestIDs,
                    self,
                    questID,
                    nil,
                    nil,
                    refreshDisplayData
                )
                if not hasNormalQuestRow then
                    AddTaskQuestSortRow(
                        rows,
                        seenQuestIDs,
                        self,
                        questID,
                        refreshDisplayData
                    )
                end
            end
        end
    end)

    AddAvailableCampaignSortRows(rows, seenQuestIDs)

    local preyQuestID = GetActivePreyQuest()
    local shouldAddPreyQuest = resolvedPolicy == TRACKER_POPULATION_ALL
        or (preyQuestID and IsQuestWatchedCompat(preyQuestID))
    if preyQuestID and shouldAddPreyQuest and not seenQuestIDs[preyQuestID] then
        local preyIndex = GetQuestLogIndexByIDCompat(preyQuestID)
        local preyInfo = preyIndex and GetQuestInfoByLogIndex(preyIndex) or nil
        if preyInfo and not preyInfo.isHeader and not preyInfo.isHidden then
            AddQuestSortRow(
                rows,
                seenQuestIDs,
                self,
                preyQuestID,
                preyIndex,
                preyInfo,
                refreshDisplayData
            )
        end
    end

    for i = 1, #rows do
        local row = rows[i]
        if row
            and row.rowType ~= ROW_TYPE_AVAILABLE_CAMPAIGN
            and type(row.questID) == "number"
            and row.questID > 0 then
            self.trackerQuestPopulationQuestIDs[row.questID] = true
            self.trackerQuestPopulationKinds[row.questID] = row.kind
            self.trackerQuestPopulationCount = self.trackerQuestPopulationCount + 1
        end
    end

    for i = 1, #self.trackerWorldQuestFallbackIDs do
        local questID = self.trackerWorldQuestFallbackIDs[i]
        if self.trackerQuestPopulationQuestIDs[questID] ~= true then
            self.trackerQuestPopulationCount = self.trackerQuestPopulationCount + 1
        end
    end

    self.trackerQuestHasContent = #rows > 0
        or #self.trackerWorldQuestFallbackIDs > 0

    SortQuestRows(rows)
    self._questSortLogEntryCount = GetNumQuestLogEntriesCompat()
    self._questSortPopulationFingerprint = populationFingerprint
    self._questSortTableReady = true
    self._questSortDisplayDataReady = refreshDisplayData

    return questSortTable
end

function QuestKing:IsQuestInCachedTrackerPopulation(questID)
    questID = SafeNumber(questID, nil)
    if not questID or questID <= 0 then
        return false
    end

    local populationQuestIDs = self.trackerQuestPopulationQuestIDs
    if type(populationQuestIDs) == "table"
        and populationQuestIDs[questID] == true then
        return true
    end

    local fallbackQuestIDs = self.trackerWorldQuestFallbackQuestIDs
    if type(fallbackQuestIDs) == "table"
        and fallbackQuestIDs[questID] == true then
        return true
    end

    local rows = self.questSortTable
    if self._questSortTableReady == true and type(rows) == "table" then
        for i = 1, #rows do
            if rows[i] and rows[i].questID == questID then
                return true
            end
        end
    end

    return false
end

function QuestKing:IsQuestInTrackerPopulation(questID)
    questID = SafeNumber(questID, nil)
    if not questID or questID <= 0 then
        return false
    end

    if self:IsQuestInCachedTrackerPopulation(questID) then
        return true
    end

    -- A quest-data result can arrive after Blizzard's watch APIs become ready
    -- but before the first cached population has been rebuilt. Consult the live
    -- watch lists so the event that can repair an empty startup snapshot is not
    -- filtered out by that stale snapshot.
    local numWatches, watchAPIAvailable = GetNumQuestWatchesCompat()
    for watchIndex = 1, numWatches do
        if GetQuestIDForWatchIndex(watchIndex) == questID then
            return true
        end
    end

    local numWorldQuestWatches = GetNumWorldQuestWatchesCompat()
    for watchIndex = 1, numWorldQuestWatches do
        if GetWorldQuestIDForWatchIndex(watchIndex) == questID then
            return true
        end
    end

    local _, resolvedPolicy = self:GetTrackerPopulationPolicy()
    if resolvedPolicy == TRACKER_POPULATION_WATCHED and not watchAPIAvailable then
        resolvedPolicy = TRACKER_POPULATION_ALL
    end

    local activePreyQuestID = GetActivePreyQuest()
    local shouldCheckLiveQuestLog = resolvedPolicy == TRACKER_POPULATION_ALL
        or (
            activePreyQuestID == questID
            and IsQuestWatchedCompat(questID)
        )

    if shouldCheckLiveQuestLog then
        local isLivePopulationMember = false
        RunQuestLogPopulationScan(
            resolvedPolicy == TRACKER_POPULATION_ALL
                or IsClassicFamilyCompat(),
            function()
                local questLogIndex = GetQuestLogIndexByIDCompat(questID)
                local info = questLogIndex
                    and GetQuestInfoByLogIndex(questLogIndex)
                    or nil
                isLivePopulationMember = info ~= nil
                    and not info.isHeader
                    and not info.isHidden
            end
        )

        if isLivePopulationMember then
            return true
        end
    end

    return false
end

function QuestKing:ShouldSkipBonusTask(questID)
    if not questID then
        return false
    end

    -- Blizzard feeds both bonus objectives and World Quests through
    -- GetTasksTable(), but renders World Quests in their own tracker module.
    -- They must never fall through to QuestKing's Bonus Objectives section.
    if IsWorldQuest(questID) then
        return true
    end

    local fallbackQuestIDs = self.trackerWorldQuestFallbackQuestIDs
    if type(fallbackQuestIDs) == "table" and fallbackQuestIDs[questID] == true then
        return true
    end

    local populationQuestIDs = self.trackerQuestPopulationQuestIDs
    local kind = nil
    if type(populationQuestIDs) == "table" then
        if populationQuestIDs[questID] ~= true then
            return false
        end
        local populationKinds = self.trackerQuestPopulationKinds
        kind = type(populationKinds) == "table" and populationKinds[questID] or nil
    elseif not IsQuestWatchedCompat(questID) and not IsPreyQuest(questID) then
        return false
    end

    if not kind then
        local questLogIndex = GetQuestLogIndexByIDCompat(questID)
        local info = questLogIndex and GetQuestInfoByLogIndex(questLogIndex) or nil
        kind = self:GetQuestKind(questID, info)
    end

    return kind == QUEST_KIND.TASK
        or kind == QUEST_KIND.WORLD_QUEST
        or kind == QUEST_KIND.SPECIAL_ASSIGNMENT
        or kind == QUEST_KIND.PREY
        or kind == QUEST_KIND.CAMPAIGN
end

function QuestKing:UpdateTrackerQuests(rows)
    if not WatchButton or type(WatchButton.GetKeyed) ~= "function" then
        return
    end

    if type(rows) ~= "table" then
        rows = self:BuildQuestSortTable(true, true)
    end

    if not rows or #rows == 0 then
        self.newlyAddedQuests = {}
        return
    end

    local lastKind = nil
    local currentHeader = nil

    for i = 1, #rows do
        local row = rows[i]
        if row then
            if row.kind ~= lastKind then
                currentHeader = AddSectionHeader(GetKindHeader(row.kind))
                lastKind = row.kind
            end

            if row.rowType == ROW_TYPE_AVAILABLE_CAMPAIGN then
                local button = WatchButton:GetKeyed("available_campaign", row.campaignID)
                if button then
                    button._previousHeader = currentHeader
                    self:SetButtonToAvailableCampaign(button, row)
                end
            elseif row.questID then
                local button = WatchButton:GetKeyed("quest", row.questID)
                if button then
                    button._previousHeader = currentHeader
                    self:SetButtonToQuest(button, row.questLogIndex, row.displayData)

                    if button.fresh and self.newlyAddedQuests and self.newlyAddedQuests[row.questID] then
                        if button.Pulse and opt_colors.ObjectiveAlertGlow then
                            button:Pulse(
                                opt_colors.ObjectiveAlertGlow[1],
                                opt_colors.ObjectiveAlertGlow[2],
                                opt_colors.ObjectiveAlertGlow[3]
                            )
                        end
                    end
                end
            end
        end
    end

    self.newlyAddedQuests = {}
end

function QuestKing:AddWatch(questLogIndex)
    local info = GetQuestInfoByLogIndex(questLogIndex)
    if info and info.questID then
        AddQuestWatchByID(info.questID)
    end
end

function QuestKing:RemoveWatch(questLogIndex)
    local info = GetQuestInfoByLogIndex(questLogIndex)
    if info and info.questID then
        RemoveQuestWatchByID(info.questID)
    end
end

function QuestKing:IterateWatched()
    local i = 0
    local n = 0

    n = GetNumQuestWatchesCompat()

    return function()
        i = i + 1
        if i <= n then
            return i, GetQuestIDForWatchIndex(i)
        end
    end
end
