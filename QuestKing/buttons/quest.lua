local addonName, QuestKing = ...

local C_QuestLog = C_QuestLog
local C_TaskQuest = C_TaskQuest
local C_SuperTrack = C_SuperTrack
local C_CampaignInfo = C_CampaignInfo

local WatchButton = QuestKing.WatchButton
local opt = QuestKing.options or {}
local opt_colors = opt.colors or {}
local opt_showCompletedObjectives = opt.showCompletedObjectives

local floor = math.floor
local format = string.format
local match = string.match
local sort = table.sort
local tonumber_raw = tonumber
local tostring = tostring
local type = type
local wipe = wipe
local pairs = pairs

local UNKNOWN = UNKNOWN or "Unknown"
local NORMAL_QUEST_HEADER = TRACKER_HEADER_QUESTS or QUESTS_LABEL or "Quests"
local TASK_HEADER = TRACKER_HEADER_OBJECTIVE or "Tasks"
local WORLD_QUEST_HEADER = TRACKER_HEADER_WORLD_QUESTS or "World Quests"
local CAMPAIGN_HEADER = CAMPAIGN or "Campaign"

local QUEST_TAG_CAPSTONE_WORLD_QUEST = 286

local LINE_LEFT_PADDING = 16
local LINE_RIGHT_PADDING = 8
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
        return false, nil, nil, nil, nil, nil, nil, nil, nil
    end

    local ok, a, b, c, d, e, f, g, h = pcall(func, ...)
    if ok then
        return true, a, b, c, d, e, f, g, h
    end

    return false, nil, nil, nil, nil, nil, nil, nil, nil
end

local function QueueTrackerRefresh(forceBuild)
    if type(QuestKing.QueueTrackerUpdate) == "function" then
        QuestKing:QueueTrackerUpdate(forceBuild, false)
        return
    end

    if type(QuestKing.UpdateTracker) == "function" then
        QuestKing:UpdateTracker(forceBuild, false)
    end
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

local SECTION_HEADER_COLOR = {
    r = (opt_colors.SectionHeader and opt_colors.SectionHeader[1]) or 1.00,
    g = (opt_colors.SectionHeader and opt_colors.SectionHeader[2]) or 0.82,
    b = (opt_colors.SectionHeader and opt_colors.SectionHeader[3]) or 0.00,
}

local function GetQuestInfoByLogIndex(questLogIndex)
    if type(questLogIndex) ~= "number" or questLogIndex <= 0 then
        return nil
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
                isCampaign = false,
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

    if C_QuestLog and C_QuestLog.IsQuestWatched then
        local ok, watched = SafeCall(C_QuestLog.IsQuestWatched, questID)
        if ok then
            return watched and true or false
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

    if C_QuestLog and C_QuestLog.AddQuestWatch then
        local ok = SafeCall(C_QuestLog.AddQuestWatch, questID)
        return ok and true or false
    end

    local questLogIndex = GetQuestLogIndexByIDCompat(questID)
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

    if C_QuestLog and C_QuestLog.RemoveQuestWatch then
        local ok = SafeCall(C_QuestLog.RemoveQuestWatch, questID)
        return ok and true or false
    end

    local questLogIndex = GetQuestLogIndexByIDCompat(questID)
    if questLogIndex and _G.RemoveQuestWatch then
        local ok = SafeCall(_G.RemoveQuestWatch, questLogIndex)
        return ok and true or false
    end

    return false
end

local function IsQuestCompleteCompat(questID)
    if type(questID) ~= "number" or questID <= 0 then
        return false
    end

    if C_QuestLog and C_QuestLog.IsComplete then
        local ok, isComplete = SafeCall(C_QuestLog.IsComplete, questID)
        if ok then
            return isComplete and true or false
        end
    end

    local questLogIndex = GetQuestLogIndexByIDCompat(questID)
    if questLogIndex and _G.GetQuestLogIsComplete then
        local ok, isComplete = SafeCall(_G.GetQuestLogIsComplete, questLogIndex)
        if ok then
            return isComplete and true or false
        end
    end

    return false
end

local function IsQuestAutoComplete(questID, questLogIndex)
    if type(questID) == "number" and C_QuestLog and C_QuestLog.IsAutoComplete then
        local ok, isAutoComplete = SafeCall(C_QuestLog.IsAutoComplete, questID)
        if ok then
            return isAutoComplete and true or false
        end
    end

    if (not questLogIndex or questLogIndex <= 0) and type(questID) == "number" then
        questLogIndex = GetQuestLogIndexByIDCompat(questID)
    end

    if questLogIndex and _G.GetQuestLogIsAutoComplete then
        local ok, isAutoComplete = SafeCall(_G.GetQuestLogIsAutoComplete, questLogIndex)
        if ok then
            return isAutoComplete and true or false
        end
    end

    return false
end

local function ShowQuestCompleteCompat(questID, questLogIndex)
    if type(_G.ShowQuestComplete) ~= "function" then
        return false
    end

    if type(questID) == "number" and questID > 0 then
        local ok = SafeCall(_G.ShowQuestComplete, questID)
        if ok then
            return true
        end
    end

    if type(questLogIndex) == "number" and questLogIndex > 0 then
        local ok = SafeCall(_G.ShowQuestComplete, questLogIndex)
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
    elseif _G.GetQuestObjectiveInfo then
        local questLogIndexCompat = questLogIndex or 0
        local okNum, numObjectives = SafeCall(_G.GetNumQuestLeaderBoards, questLogIndexCompat)
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

local function IsCampaignQuest(questID, info)
    if type(questID) ~= "number" or questID <= 0 then
        return false
    end

    if type(info) == "table" then
        if info.isCampaign ~= nil then
            return info.isCampaign and true or false
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
            if liveInfo.isCampaign ~= nil then
                return liveInfo.isCampaign and true or false
            end

            local campaignID = SafeNumber(liveInfo.campaignID, 0) or 0
            if campaignID > 0 then
                return true
            end
        end
    end

    if C_CampaignInfo and C_CampaignInfo.IsCampaignQuest then
        local ok, isCampaign = SafeCall(C_CampaignInfo.IsCampaignQuest, questID)
        if ok then
            return isCampaign and true or false
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

    if opt_showCompletedObjectives == "always" then
        return true
    end

    if isQuestComplete then
        return true
    end

    return opt_showCompletedObjectives and true or false
end

local function GetQuestCompletionLineText(questID, isAutoComplete)
    if isAutoComplete then
        if questID and IsTaskQuest(questID) then
            return QUEST_WATCH_POPUP_CLICK_TO_COMPLETE_TASK
                or QUEST_WATCH_POPUP_CLICK_TO_COMPLETE
                or QUEST_WATCH_QUEST_READY
                or QUEST_WATCH_QUEST_COMPLETE
                or COMPLETE
                or "Complete"
        end

        return QUEST_WATCH_POPUP_CLICK_TO_COMPLETE
            or QUEST_WATCH_QUEST_READY
            or QUEST_WATCH_QUEST_COMPLETE
            or COMPLETE
            or "Complete"
    end

    return QUEST_WATCH_QUEST_READY
        or QUEST_WATCH_QUEST_COMPLETE
        or COMPLETE
        or "Complete"
end

local function AddQuestObjectiveLine(button, row, isNewQuest)
    if not button or not row then
        return nil
    end

    local color = row.finished and FINISHED_COLOR or UNFINISHED_COLOR
    local line = button:AddLine(("  %s"):format(row.text or ""), nil, color.r, color.g, color.b)

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

local function AddQuestProgressBar(button, percent)
    if not button or not IsSafeNumber(percent) then
        return nil
    end

    local progressBar = button:AddProgressBar()
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

local mouseHandlerQuest = {}

function mouseHandlerQuest:TitleButtonOnClick(mouse)
    local button = self.parent
    local questID = button.questID
    local questLogIndex = button.questLogIndex

    if not questID then
        return
    end

    if _G.IsModifiedClick and _G.IsModifiedClick("CHATLINK") and _G.ChatEdit_GetActiveWindow then
        local activeWindow = _G.ChatEdit_GetActiveWindow()
        if activeWindow then
            local link = nil

            if _G.GetQuestLink and questLogIndex then
                local ok, questLink = SafeCall(_G.GetQuestLink, questLogIndex)
                if ok and questLink then
                    link = questLink
                end
            end

            if link then
                _G.ChatEdit_InsertLink(link)
                return
            end
        end
    end

    if mouse == "RightButton" then
        if QuestKing.SetSuperTrackedQuestID then
            local currentID = GetSuperTrackedQuestIDCompat()
            if currentID == questID then
                QuestKing:SetSuperTrackedQuestID(0)
            else
                QuestKing:SetSuperTrackedQuestID(questID)
            end

            QueueTrackerRefresh(true)
        end
        return
    end

    local isAutoCompleteQuest = IsQuestAutoComplete(questID, questLogIndex)
    if isAutoCompleteQuest and IsQuestCompleteCompat(questID) and ShowQuestCompleteCompat(questID, questLogIndex) then
        return
    end

    if _G.QuestObjectiveTracker_OpenQuestMap and questLogIndex then
        local ok = SafeCall(_G.QuestObjectiveTracker_OpenQuestMap, nil, questLogIndex)
        if ok then
            return
        end
    end

    if _G.QuestMapFrame_OpenToQuestDetails and questID then
        local ok = SafeCall(_G.QuestMapFrame_OpenToQuestDetails, questID)
        if ok then
            return
        end
    end

    if _G.ToggleQuestLog and questLogIndex then
        SafeCall(_G.ToggleQuestLog)
    end
end

function mouseHandlerQuest:TitleButtonOnEnter()
    local button = self.parent
    local questID = button.questID
    local questLogIndex = button.questLogIndex

    if not questID then
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

    if GetSuperTrackedQuestIDCompat() == questID then
        AddTooltipLine(tooltip, "Super tracked", 1, 0.82, 0.2)
    end

    AddTooltipLine(tooltip, "Left-click to open quest", 0.7, 0.7, 0.7)
    AddTooltipLine(tooltip, "Right-click to toggle super tracking", 0.7, 0.7, 0.7)

    AddQuestTooltipObjectives(tooltip, questID)
    tooltip:Show()
end

function mouseHandlerQuest:TitleButtonOnLeave()
    if QuestKing.HideTooltip then
        QuestKing:HideTooltip()
    end
end

function QuestKing:GetQuestDisplayData(questLogIndex)
    local info = GetQuestInfoByLogIndex(questLogIndex)
    if not info or info.isHeader then
        return nil
    end

    local questID = SafeNumber(info.questID, nil)
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
        isComplete = IsQuestCompleteCompat(questID),
        tagBracket = self:GetQuestTagBracket(questID),
        objectives = objectives,
        hasProgressBarObjective = hasProgressBarObjective,
        percent = percent,
    }
end

function QuestKing:SetButtonToQuest(button, questLogIndex)
    if not button or not questLogIndex then
        return
    end

    local data = self:GetQuestDisplayData(questLogIndex)
    if not data then
        return
    end

    local isAutoCompleteQuest = IsQuestAutoComplete(data.questID, questLogIndex)

    local itemLink, itemTexture, itemCharges, itemShowWhenComplete = GetQuestLogSpecialItemInfoCompat(questLogIndex)
    if itemShowWhenComplete == false and data.isComplete then
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
        if data.isComplete and isAutoCompleteQuest then
            button.title:SetText("|TInterface\\RAIDFRAME\\ReadyCheck-Ready:0:0:1:1|t " .. displayTitle)
            button.title:SetTextColor(TITLE_COMPLETE_COLOR.r, TITLE_COMPLETE_COLOR.g, TITLE_COMPLETE_COLOR.b)
        else
            button.title:SetText(displayTitle)
            if data.isComplete then
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
        button.completed:SetShown(data.isComplete)
    end

    local visibleObjectives = 0
    local isNewQuest = button.fresh or (self.newlyAddedQuests and self.newlyAddedQuests[data.questID])

    for i = 1, #data.objectives do
        local row = data.objectives[i]
        if ShouldShowQuestObjective(row, data.isComplete) then
            if row.type ~= "progressbar" then
                AddQuestObjectiveLine(button, row, isNewQuest)
            end
            visibleObjectives = visibleObjectives + 1
        end
    end

    if data.hasProgressBarObjective
        and IsSafeNumber(data.percent)
        and (not data.isComplete or opt_showCompletedObjectives or opt_showCompletedObjectives == "always") then
        AddQuestProgressBar(button, data.percent)
        visibleObjectives = visibleObjectives + 1
    end

    if data.isComplete then
        local line = button:AddLine(
            ("  %s"):format(GetQuestCompletionLineText(data.questID, isAutoCompleteQuest)),
            nil,
            FINISHED_COLOR.r,
            FINISHED_COLOR.g,
            FINISHED_COLOR.b
        )
        FreeLineBars(line)
        line:SetAlpha(COMPLETED_ALPHA)
        if line.right then
            line.right:SetAlpha(COMPLETED_ALPHA)
        end
        visibleObjectives = visibleObjectives + 1
    end

    if itemLink and itemTexture then
        button:SetItemButton(questLogIndex, itemLink, itemTexture, itemCharges, visibleObjectives)
    else
        button:RemoveItemButton()
    end
end

local function AddSectionHeader(headerText)
    local header = WatchButton:GetKeyed("header", "quest_header_" .. tostring(headerText))
    header.title:SetText(headerText)
    header.title:SetTextColor(SECTION_HEADER_COLOR.r, SECTION_HEADER_COLOR.g, SECTION_HEADER_COLOR.b)
    header.titleButton:EnableMouse(false)
    return header
end

function QuestKing:BuildQuestSortTable()
    self.questSortTable = self.questSortTable or {}
    local questSortTable = self.questSortTable
    wipe(questSortTable)

    local seenQuestIDs = {}
    local rows = {}

    local numWatches = 0
    if C_QuestLog and C_QuestLog.GetNumQuestWatches then
        local ok, count = SafeCall(C_QuestLog.GetNumQuestWatches)
        if ok then
            numWatches = SafeNumber(count, 0) or 0
        end
    elseif _G.GetNumQuestWatches then
        local ok, count = SafeCall(_G.GetNumQuestWatches)
        if ok then
            numWatches = SafeNumber(count, 0) or 0
        end
    end

    for i = 1, numWatches do
        local questID = GetQuestIDForWatchIndex(i)
        if questID and not seenQuestIDs[questID] then
            local questLogIndex = GetQuestLogIndexByIDCompat(questID)
            local info = questLogIndex and GetQuestInfoByLogIndex(questLogIndex) or nil
            if info and not info.isHeader and not info.isHidden then
                seenQuestIDs[questID] = true
                rows[#rows + 1] = {
                    questID = questID,
                    questLogIndex = questLogIndex,
                    kind = self:GetQuestKind(questID, info),
                    sortText = SafeString(info.title, "") or "",
                }
            end
        end
    end

    local preyQuestID = GetActivePreyQuest()
    if preyQuestID and not seenQuestIDs[preyQuestID] then
        local preyIndex = GetQuestLogIndexByIDCompat(preyQuestID)
        local preyInfo = preyIndex and GetQuestInfoByLogIndex(preyIndex) or nil
        if preyInfo and not preyInfo.isHeader and not preyInfo.isHidden then
            seenQuestIDs[preyQuestID] = true
            rows[#rows + 1] = {
                questID = preyQuestID,
                questLogIndex = preyIndex,
                kind = self:GetQuestKind(preyQuestID, preyInfo),
                sortText = SafeString(preyInfo.title, "") or "",
            }
        end
    end

    sort(rows, function(a, b)
        local aOrder = GetKindOrder(a.kind)
        local bOrder = GetKindOrder(b.kind)
        if aOrder ~= bOrder then
            return aOrder < bOrder
        end

        local aTracked = GetSuperTrackedQuestIDCompat() == a.questID and 1 or 0
        local bTracked = GetSuperTrackedQuestIDCompat() == b.questID and 1 or 0
        if aTracked ~= bTracked then
            return aTracked > bTracked
        end

        return (a.sortText or "") < (b.sortText or "")
    end)

    for i = 1, #rows do
        questSortTable[i] = rows[i]
    end

    return questSortTable
end

function QuestKing:ShouldSkipBonusTask(questID)
    if not questID then
        return false
    end

    local questLogIndex = GetQuestLogIndexByIDCompat(questID)
    if not questLogIndex then
        return false
    end

    if not IsQuestWatchedCompat(questID) and not IsPreyQuest(questID) then
        return false
    end

    local info = GetQuestInfoByLogIndex(questLogIndex)
    local kind = self:GetQuestKind(questID, info)

    return kind == QUEST_KIND.TASK
        or kind == QUEST_KIND.WORLD_QUEST
        or kind == QUEST_KIND.SPECIAL_ASSIGNMENT
        or kind == QUEST_KIND.PREY
        or kind == QUEST_KIND.CAMPAIGN
end

function QuestKing:UpdateTrackerQuests()
    local rows = self:BuildQuestSortTable()
    if not rows or #rows == 0 then
        return
    end

    local lastKind = nil
    local currentHeader = nil

    for i = 1, #rows do
        local row = rows[i]
        if row and row.questLogIndex then
            if row.kind ~= lastKind then
                currentHeader = AddSectionHeader(GetKindHeader(row.kind))
                lastKind = row.kind
            end

            local button = WatchButton:GetKeyed("quest", row.questID)
            button._previousHeader = currentHeader
            self:SetButtonToQuest(button, row.questLogIndex)

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

    if C_QuestLog and C_QuestLog.GetNumQuestWatches then
        local ok, count = SafeCall(C_QuestLog.GetNumQuestWatches)
        if ok then
            n = SafeNumber(count, 0) or 0
        end
    elseif _G.GetNumQuestWatches then
        local ok, count = SafeCall(_G.GetNumQuestWatches)
        if ok then
            n = SafeNumber(count, 0) or 0
        end
    end

    return function()
        i = i + 1
        if i <= n then
            return i, GetQuestIDForWatchIndex(i)
        end
    end
end
