--[[
QuestKing - quest.lua
Validated quest tracker pass for:
- normal quests
- campaign quests
- watched world quests
- special assignments (capstone world quests)
- prey quests
- legacy/retail compatible fallbacks where possible

Notes:
- Task / bonus-objective ambient content is still handled by bonusobjective.lua.
- This file owns the normal quest-log/watch-list based tracker rendering.
- We deliberately classify using direct API predicates first, then safe tag fallbacks.
--]]

local addonName, QuestKing = ...

local CQL = C_QuestLog
local CTQ = C_TaskQuest
local CST = C_SuperTrack

local WatchButton = QuestKing.WatchButton
local opt = QuestKing.options
local opt_colors = opt.colors
local opt_showCompletedObjectives = opt.showCompletedObjectives

local format = string.format
local match = string.match
local sort = table.sort
local floor = math.floor
local tonumber = tonumber
local tostring = tostring
local type = type
local wipe = wipe

local UNKNOWN = UNKNOWN or "Unknown"

local QUEST_KIND = {
    NORMAL = "normal",
    CAMPAIGN = "campaign",
    TASK = "task",
    WORLD_QUEST = "world_quest",
    SPECIAL_ASSIGNMENT = "special_assignment",
    PREY = "prey",
}

QuestKing.QUEST_KIND = QUEST_KIND

local QUEST_TAG_CAPSTONE_WORLD_QUEST = 286

-- ============================================================================
-- Basic compat helpers
-- ============================================================================

local function QK_GetInfo(index)
    return CQL and CQL.GetInfo and CQL.GetInfo(index) or nil
end

local function QK_GetQuestLogIndexByID(questID)
    if not questID then
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

local function QK_GetQuestIDForQuestLogIndex(questLogIndex)
    if not questLogIndex or questLogIndex <= 0 then
        return nil
    end

    if CQL and CQL.GetInfo then
        local info = CQL.GetInfo(questLogIndex)
        if info and info.questID then
            return info.questID
        end
    end

    if GetQuestLogTitle then
        local _, _, _, _, _, _, _, questID = GetQuestLogTitle(questLogIndex)
        return questID
    end

    return nil
end

local function QK_IsWatched(questID)
    if not questID then
        return false
    end

    if CQL and CQL.IsQuestWatched then
        return CQL.IsQuestWatched(questID) and true or false
    end

    local questIndex = QK_GetQuestLogIndexByID(questID)
    if questIndex and IsQuestWatched then
        return IsQuestWatched(questIndex) and true or false
    end

    return false
end

local function QK_AddWatch(questID)
    if not questID then
        return
    end

    if CQL and CQL.AddQuestWatch then
        if Enum and Enum.QuestWatchType and Enum.QuestWatchType.Manual ~= nil then
            CQL.AddQuestWatch(questID, Enum.QuestWatchType.Manual)
        else
            CQL.AddQuestWatch(questID)
        end
        return
    end

    local questIndex = QK_GetQuestLogIndexByID(questID)
    if questIndex and AddQuestWatch then
        AddQuestWatch(questIndex)
    end
end

local function QK_RemoveWatch(questID)
    if not questID then
        return
    end

    if CQL and CQL.RemoveQuestWatch then
        CQL.RemoveQuestWatch(questID)
        return
    end

    local questIndex = QK_GetQuestLogIndexByID(questID)
    if questIndex and RemoveQuestWatch then
        RemoveQuestWatch(questIndex)
    end
end

local function QK_IsComplete(questID)
    if not questID then
        return false
    end

    if CQL and CQL.IsComplete then
        return CQL.IsComplete(questID) and true or false
    end

    local questIndex = QK_GetQuestLogIndexByID(questID)
    if questIndex and GetQuestLogIsComplete then
        return GetQuestLogIsComplete(questIndex) and true or false
    end

    return false
end

local function QK_IsAutoComplete(questID, questLogIndex)
    if not questID and not questLogIndex then
        return false
    end

    if questID and CQL and CQL.IsAutoComplete then
        return CQL.IsAutoComplete(questID) and true or false
    end

    if not questLogIndex and questID then
        questLogIndex = QK_GetQuestLogIndexByID(questID)
    end

    if questLogIndex and GetQuestLogIsAutoComplete then
        return GetQuestLogIsAutoComplete(questLogIndex) and true or false
    end

    return false
end

local function QK_ShowQuestAPICompat(func, questID, questLogIndex)
    if type(func) ~= "function" then
        return false
    end

    if questID then
        local ok = pcall(func, questID)
        if ok then
            return true
        end
    end

    if questLogIndex then
        local ok = pcall(func, questLogIndex)
        if ok then
            return true
        end
    end

    return false
end

local function QK_ShowQuestComplete(questID, questLogIndex)
    return QK_ShowQuestAPICompat(ShowQuestComplete, questID, questLogIndex)
end

local function QK_GetDifficultyLevel(info)
    if not info then
        return nil
    end

    if CQL and CQL.GetQuestDifficultyLevel and info.questID then
        local level = CQL.GetQuestDifficultyLevel(info.questID)
        if type(level) == "number" then
            return level
        end
    end

    if type(info.level) == "number" then
        return info.level
    end

    return nil
end

local function QK_GetDifficultyColor(level)
    if level and GetQuestDifficultyColor then
        return GetQuestDifficultyColor(level)
    end

    return { r = 1, g = 0.82, b = 0 }
end

local function QK_GetTagInfo(questID)
    if CQL and CQL.GetQuestTagInfo and questID then
        return CQL.GetQuestTagInfo(questID)
    end

    if GetQuestTagInfo and questID then
        local tagID, tagName, worldQuestType, quality, isElite, tradeskillLineID, displayExpiration =
            GetQuestTagInfo(questID)

        if tagID or tagName or worldQuestType or quality or isElite then
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

local function QK_ObjectiveTextAlreadyHasProgress(text)
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

local function QK_GetQuestObjectives(questID)
    local out = {}

    if CQL and CQL.GetQuestObjectives and questID then
        local objectives = CQL.GetQuestObjectives(questID)
        if type(objectives) == "table" then
            for i = 1, #objectives do
                local objective = objectives[i]
                if objective then
                    out[#out + 1] = {
                        text = objective.text or "",
                        type = objective.type or objective.objectiveType,
                        finished = (objective.finished or objective.completed) and true or false,
                        numFulfilled = objective.numFulfilled,
                        numRequired = objective.numRequired,
                    }
                end
            end

            if #out > 0 then
                return out
            end
        end
    end

    local questLogIndex = QK_GetQuestLogIndexByID(questID)
    if questLogIndex and GetNumQuestLeaderBoards and GetQuestLogLeaderBoard then
        local numObjectives = GetNumQuestLeaderBoards(questLogIndex) or 0
        for i = 1, numObjectives do
            local text, objectiveType, finished = GetQuestLogLeaderBoard(i, questLogIndex, true)
            if text then
                out[#out + 1] = {
                    text = text or "",
                    type = objectiveType,
                    finished = finished and true or false,
                }
            end
        end
    elseif questID and GetNumQuestLeaderBoards and GetQuestObjectiveInfo then
        local numObjectives = GetNumQuestLeaderBoards(questLogIndex or 0) or 0
        for i = 1, numObjectives do
            local text, objectiveType, finished = GetQuestObjectiveInfo(questID, i, false)
            out[#out + 1] = {
                text = text or "",
                type = objectiveType,
                finished = finished and true or false,
            }
        end
    end

    return out
end

local function QK_GetRequiredMoney(questID)
    if CQL and CQL.GetRequiredMoney and questID then
        return CQL.GetRequiredMoney(questID) or 0
    end

    return 0
end

local function QK_GetQuestPercent(questID)
    if CQL and CQL.GetQuestProgressBarPercent and questID then
        local percent = CQL.GetQuestProgressBarPercent(questID)
        if type(percent) == "number" and percent >= 0 and percent <= 100 then
            return percent
        end
    end

    if GetQuestProgressBarPercent and questID then
        local percent = GetQuestProgressBarPercent(questID)
        if type(percent) == "number" and percent >= 0 and percent <= 100 then
            return percent
        end
    end

    return nil
end

local function QK_GetQuestLogSpecialItemInfo(questLogIndex)
    if not questLogIndex or questLogIndex <= 0 then
        return nil, nil, nil, nil
    end

    if GetQuestLogSpecialItemInfo then
        return GetQuestLogSpecialItemInfo(questLogIndex)
    end

    return nil, nil, nil, nil
end

local function QK_GetActivePreyQuest()
    if CQL and CQL.GetActivePreyQuest then
        return CQL.GetActivePreyQuest()
    end

    return nil
end

local function QK_IsCampaignQuest(questID)
    if not questID then
        return false
    end

    if C_CampaignInfo and C_CampaignInfo.IsCampaignQuest then
        return C_CampaignInfo.IsCampaignQuest(questID) and true or false
    end

    return false
end

local function QK_IsTaskQuest(questID)
    if not questID then
        return false
    end

    if CQL and CQL.IsQuestTask then
        return CQL.IsQuestTask(questID) and true or false
    end

    if CTQ and CTQ.IsActive then
        return CTQ.IsActive(questID) and true or false
    end

    if IsQuestTask then
        return IsQuestTask(questID) and true or false
    end

    return false
end

local function QK_IsWorldQuest(questID)
    if not questID then
        return false
    end

    if CQL and CQL.IsWorldQuest then
        return CQL.IsWorldQuest(questID) and true or false
    end

    local tagInfo = QK_GetTagInfo(questID)
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

local function QK_IsSpecialAssignment(questID)
    local tagInfo = QK_GetTagInfo(questID)
    return tagInfo and tagInfo.tagID == QUEST_TAG_CAPSTONE_WORLD_QUEST or false
end

local function QK_IsPreyQuest(questID)
    if not questID then
        return false
    end

    return QK_GetActivePreyQuest() == questID
end

local function QK_GetSuperTrackedQuestID()
    if CST and CST.GetSuperTrackedQuestID then
        return CST.GetSuperTrackedQuestID() or 0
    end

    if GetSuperTrackedQuestID then
        return GetSuperTrackedQuestID() or 0
    end

    return 0
end

function QuestKing:GetQuestKind(questID, info)
    if not questID then
        return QUEST_KIND.NORMAL
    end

    if QK_IsPreyQuest(questID) then
        return QUEST_KIND.PREY
    end

    if QK_IsSpecialAssignment(questID) then
        return QUEST_KIND.SPECIAL_ASSIGNMENT
    end

    if QK_IsWorldQuest(questID) then
        return QUEST_KIND.WORLD_QUEST
    end

    if QK_IsCampaignQuest(questID) then
        return QUEST_KIND.CAMPAIGN
    end

    if QK_IsTaskQuest(questID) then
        return QUEST_KIND.TASK
    end

    return QUEST_KIND.NORMAL
end

local function GetKindHeader(kind)
    if kind == QUEST_KIND.CAMPAIGN then
        return CAMPAIGN or "Campaign"
    elseif kind == QUEST_KIND.WORLD_QUEST then
        return TRACKER_HEADER_WORLD_QUESTS or "World Quests"
    elseif kind == QUEST_KIND.SPECIAL_ASSIGNMENT then
        return "Special Assignments"
    elseif kind == QUEST_KIND.PREY then
        return "Prey"
    elseif kind == QUEST_KIND.TASK then
        return TRACKER_HEADER_OBJECTIVE or "Tasks"
    end

    return TRACKER_HEADER_QUESTS or "Quests"
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

-- ============================================================================
-- Quest title / objective text
-- ============================================================================

function QuestKing:GetQuestTagBracket(questID)
    local info = QK_GetTagInfo(questID)
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
    local objectives = QK_GetQuestObjectives(questID)
    local hasProgressBarObjective = false

    for index = 1, #objectives do
        local objective = objectives[index]
        if objective then
            local text = objective.text or ""
            local objectiveType = objective.type or objective.objectiveType
            local numFulfilled = objective.numFulfilled
            local numRequired = objective.numRequired

            if objectiveType == "progressbar" then
                hasProgressBarObjective = true
            elseif type(numRequired) == "number"
                and numRequired > 0
                and text ~= ""
                and not QK_ObjectiveTextAlreadyHasProgress(text) then
                text = ("%s (%d/%d)"):format(text, numFulfilled or 0, numRequired)
            end

            out[#out + 1] = {
                index = index,
                text = text,
                type = objectiveType,
                finished = (objective.finished or objective.completed) and true or false,
                numFulfilled = numFulfilled,
                numRequired = numRequired,
            }
        end
    end

    local reqMoney = QK_GetRequiredMoney(questID)
    if reqMoney and reqMoney > 0 then
        local have = GetMoney and GetMoney() or 0
        local done = have >= reqMoney
        local moneyText = GetMoneyString and GetMoneyString(reqMoney) or tostring(reqMoney)

        out[#out + 1] = {
            index = #out + 1,
            text = moneyText,
            type = "money",
            finished = done,
            numFulfilled = have,
            numRequired = reqMoney,
        }

        QuestKing.watchMoney = true
    end

    return out, hasProgressBarObjective
end

-- ============================================================================
-- Button rendering helpers
-- ============================================================================

local LINE_LEFT_PADDING = 16
local LINE_RIGHT_PADDING = 8
local LEVEL_GAP_X = 6
local COMPLETED_ALPHA = 0.65

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
        if questID and QK_IsTaskQuest(questID) then
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

local function AddQuestObjectiveLine(button, row, isQuestComplete, isNewQuest)
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

    if not row.finished and not isNewQuest and type(row.numFulfilled) == "number" then
        local lastQuant = tonumber(line._lastQuant)
        if lastQuant and row.numFulfilled > lastQuant and line.Flash then
            line:Flash()
        end
    end

    line._lastQuant = row.numFulfilled
    return line
end

local function AddQuestProgressBar(button, percent)
    if not button or type(percent) ~= "number" then
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

-- ============================================================================
-- Tooltip helpers
-- ============================================================================

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
        if row then
            local text = row.text or ""
            if text ~= "" then
                if row.finished then
                    AddTooltipLine(tooltip, "- " .. text, FINISHED_COLOR.r, FINISHED_COLOR.g, FINISHED_COLOR.b)
                else
                    AddTooltipLine(tooltip, "- " .. text, 1, 1, 1)
                end
            end
        end
    end
end

-- ============================================================================
-- Mouse / tooltip behavior for quest buttons
-- ============================================================================

local mouseHandlerQuest = {}

function mouseHandlerQuest:TitleButtonOnClick(mouse)
    local button = self.parent
    local questID = button.questID
    local questLogIndex = button.questLogIndex

    if not questID then
        return
    end

    if IsModifiedClick and IsModifiedClick("CHATLINK") and ChatEdit_GetActiveWindow then
        local activeWindow = ChatEdit_GetActiveWindow()
        if activeWindow then
            local link
            if GetQuestLink and questLogIndex then
                link = GetQuestLink(questLogIndex)
            end
            if link then
                ChatEdit_InsertLink(link)
                return
            end
        end
    end

    if mouse == "RightButton" then
        if QuestKing.SetSuperTrackedQuestID then
            local currentID = QK_GetSuperTrackedQuestID()

            if currentID == questID then
                QuestKing:SetSuperTrackedQuestID(0)
            else
                QuestKing:SetSuperTrackedQuestID(questID)
            end

            QuestKing:UpdateTracker()
        end
        return
    end

    local isAutoCompleteQuest = QK_IsAutoComplete(questID, questLogIndex)
    if isAutoCompleteQuest and QK_IsComplete(questID) and QK_ShowQuestComplete(questID, questLogIndex) then
        return
    end

    if QuestObjectiveTracker_OpenQuestMap and questLogIndex then
        QuestObjectiveTracker_OpenQuestMap(nil, questLogIndex)
        return
    end

    if QuestMapFrame_OpenToQuestDetails and questID then
        QuestMapFrame_OpenToQuestDetails(questID)
        return
    end

    if ToggleQuestLog and questLogIndex then
        ToggleQuestLog()
    end
end

function mouseHandlerQuest:TitleButtonOnEnter()
    local button = self.parent
    local questLogIndex = button.questLogIndex
    local questID = button.questID

    if not questID then
        return
    end

    local tooltip = QuestKing.PrepareTooltip and QuestKing:PrepareTooltip(self, opt.tooltipAnchor or "ANCHOR_RIGHT")
    if not tooltip then
        return
    end

    local titleText = nil

    if questLogIndex and questLogIndex > 0 and QuestUtils_GetQuestName then
        titleText = QuestUtils_GetQuestName(questID)
    end

    if not titleText or titleText == "" then
        titleText = button.title and button.title:GetText() or QUESTS_LABEL or UNKNOWN
    end

    tooltip:SetText(titleText, 1, 0.82, 0)

    AddQuestTypeLine(tooltip, button.questKind)

    local tagBracket = QuestKing:GetQuestTagBracket(questID)
    if tagBracket then
        AddTooltipLine(tooltip, tagBracket, 0.85, 0.85, 0.85)
    end

    local superTrackedQuestID = QK_GetSuperTrackedQuestID()
    if superTrackedQuestID == questID then
        AddTooltipLine(tooltip, "Super tracked", 1, 0.82, 0.2)
    end

    AddQuestTooltipObjectives(tooltip, questID)

    tooltip:Show()
end

-- ============================================================================
-- Public rendering API
-- ============================================================================

function QuestKing:GetQuestDisplayData(questLogIndex)
    local info = QK_GetInfo(questLogIndex)
    if not info or info.isHeader then
        return nil
    end

    local questID = info.questID
    local kind = self:GetQuestKind(questID, info)
    local objectives, hasProgressBarObjective = self:GetQuestObjectivesText(questID)
    local percent = nil

    if hasProgressBarObjective then
        percent = QK_GetQuestPercent(questID)
    end

    return {
        questID = questID,
        kind = kind,
        title = info.title or UNKNOWN,
        level = QK_GetDifficultyLevel(info),
        isComplete = QK_IsComplete(questID),
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

    local isAutoCompleteQuest = QK_IsAutoComplete(data.questID, questLogIndex)

    local itemLink, itemTexture, itemCharges = QK_GetQuestLogSpecialItemInfo(questLogIndex)
    local itemAnchorSide = (opt.itemAnchorSide == "left") and "left" or "right"
    local itemScale = tonumber(QuestKing.itemButtonScale) or tonumber(opt.itemButtonScale) or 1
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
    local title = data.title
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
        if data.isComplete and isAutoCompleteQuest and button.title.SetFormattedTextIcon then
            button.title:SetFormattedTextIcon("|TInterface\\RAIDFRAME\\ReadyCheck-Ready:0:0:1:1|t %s", displayTitle)
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
        local col = QK_GetDifficultyColor(data.level)
        local lvlText = (data.level and data.level > 0) and ("[" .. tostring(data.level) .. "]") or ""
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
                AddQuestObjectiveLine(button, row, data.isComplete, isNewQuest)
            end
            visibleObjectives = visibleObjectives + 1
        end
    end

    if data.hasProgressBarObjective
        and type(data.percent) == "number"
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
        button:SetItemButton(
            questLogIndex,
            itemLink,
            itemTexture,
            itemCharges,
            visibleObjectives
        )
    else
        button:RemoveItemButton()
    end
end

-- ============================================================================
-- Section / sort / tracker pass
-- ============================================================================

local function AddSectionHeader(headerText)
    local header = WatchButton:GetKeyed("header", "quest_header_" .. tostring(headerText))
    header.title:SetText(headerText)
    header.title:SetTextColor(
        opt_colors.SectionHeader[1],
        opt_colors.SectionHeader[2],
        opt_colors.SectionHeader[3]
    )
    header.titleButton:EnableMouse(false)
    return header
end

local function GetQuestIDForWatchIndexCompat(watchIndex)
    if CQL and CQL.GetQuestIDForQuestWatchIndex then
        return CQL.GetQuestIDForQuestWatchIndex(watchIndex)
    end

    if GetQuestIndexForWatch and GetQuestLogTitle then
        local questLogIndex = GetQuestIndexForWatch(watchIndex)
        if questLogIndex then
            return QK_GetQuestIDForQuestLogIndex(questLogIndex)
        end
    end

    return nil
end

function QuestKing:BuildQuestSortTable()
    self.questSortTable = self.questSortTable or {}
    local questSortTable = self.questSortTable
    wipe(questSortTable)

    local seenQuestIDs = {}
    local rows = {}

    local numWatches = 0
    if CQL and CQL.GetNumQuestWatches then
        numWatches = CQL.GetNumQuestWatches() or 0
    elseif GetNumQuestWatches then
        numWatches = GetNumQuestWatches() or 0
    end

    for i = 1, numWatches do
        local questID = GetQuestIDForWatchIndexCompat(i)
        if questID and not seenQuestIDs[questID] then
            local questLogIndex = QK_GetQuestLogIndexByID(questID)
            local info = questLogIndex and QK_GetInfo(questLogIndex) or nil
            if info and not info.isHeader and not info.isHidden then
                seenQuestIDs[questID] = true
                rows[#rows + 1] = {
                    questID = questID,
                    questLogIndex = questLogIndex,
                    kind = self:GetQuestKind(questID, info),
                    sortText = info.title or "",
                }
            end
        end
    end

    local preyQuestID = QK_GetActivePreyQuest()
    if preyQuestID and not seenQuestIDs[preyQuestID] then
        local preyIndex = QK_GetQuestLogIndexByID(preyQuestID)
        local preyInfo = preyIndex and QK_GetInfo(preyIndex) or nil
        if preyInfo and not preyInfo.isHeader and not preyInfo.isHidden then
            seenQuestIDs[preyQuestID] = true
            rows[#rows + 1] = {
                questID = preyQuestID,
                questLogIndex = preyIndex,
                kind = self:GetQuestKind(preyQuestID, preyInfo),
                sortText = preyInfo.title or "",
            }
        end
    end

    sort(rows, function(a, b)
        local ao = GetKindOrder(a.kind)
        local bo = GetKindOrder(b.kind)
        if ao ~= bo then
            return ao < bo
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

    local questLogIndex = QK_GetQuestLogIndexByID(questID)
    if not questLogIndex then
        return false
    end

    if not QK_IsWatched(questID) and not QK_IsPreyQuest(questID) then
        return false
    end

    local info = QK_GetInfo(questLogIndex)
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
                if button.Pulse then
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

-- ============================================================================
-- Public watch controls
-- ============================================================================

function QuestKing:AddWatch(questLogIndex)
    local info = QK_GetInfo(questLogIndex)
    if info and info.questID then
        QK_AddWatch(info.questID)
    end
end

function QuestKing:RemoveWatch(questLogIndex)
    local info = QK_GetInfo(questLogIndex)
    if info and info.questID then
        QK_RemoveWatch(info.questID)
    end
end

function QuestKing:IterateWatched()
    local i = 0
    local n = (CQL and CQL.GetNumQuestWatches and CQL.GetNumQuestWatches()) or 0

    return function()
        i = i + 1
        if i <= n then
            local qid = GetQuestIDForWatchIndexCompat(i)
            return i, qid
        end
    end
end