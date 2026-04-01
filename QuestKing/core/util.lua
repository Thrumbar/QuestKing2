local addonName, QuestKing = ...

_G.QuestKing = QuestKing

QuestKing.newlyAddedQuests = QuestKing.newlyAddedQuests or {}
QuestKing.watchMoney = false
QuestKing.itemButtonAlpha = 1
QuestKing.itemButtonScale = (QuestKing.options and QuestKing.options.itemButtonScale) or 1
QuestKing.updateHooks = QuestKing.updateHooks or {}

local opt = QuestKing.options or {}
local opt_colors = opt.colors or {}

local floor = math.floor
local format = string.format
local gsub = string.gsub
local match = string.match
local modf = math.modf
local select = select
local tostring = tostring

local CQL = C_QuestLog

local QUEST_FREQUENCY_DAILY = (Enum and Enum.QuestFrequency and Enum.QuestFrequency.Daily) or LE_QUEST_FREQUENCY_DAILY
local QUEST_FREQUENCY_WEEKLY = (Enum and Enum.QuestFrequency and Enum.QuestFrequency.Weekly) or LE_QUEST_FREQUENCY_WEEKLY

local objectiveTrackerShowHookInstalled = false

local function SafeGetQuestInfoByIndex(questIndex)
    if not questIndex or questIndex < 1 then
        return nil
    end

    if CQL and CQL.GetInfo then
        local info = CQL.GetInfo(questIndex)
        if info then
            local questID = info.questID
            local level = info.level

            if level == nil and CQL.GetQuestDifficultyLevel and questID then
                level = CQL.GetQuestDifficultyLevel(questID)
            end

            if level == nil then
                level = UnitLevel("player") or 0
            end

            return {
                title = info.title,
                level = level,
                suggestedGroup = info.suggestedGroup,
                frequency = info.frequency,
                questID = questID,
                isHeader = info.isHeader,
                isHidden = info.isHidden,
                isTask = info.isTask,
                campaignID = info.campaignID,
                isCampaign = info.isCampaign,
                questClassification = info.questClassification,
                readyForTranslation = info.readyForTranslation,
            }
        end
    end

    if GetQuestLogTitle then
        local title, level, suggestedGroup, _, isHeader, _, frequency, questID, startEvent = GetQuestLogTitle(questIndex)
        return {
            title = title,
            level = level,
            suggestedGroup = suggestedGroup,
            frequency = frequency,
            questID = questID,
            isHeader = isHeader,
            startEvent = startEvent,
        }
    end

    return nil
end

local function SafeIsAutoComplete(questIndex, questID)
    if CQL and CQL.IsAutoComplete and questID then
        return CQL.IsAutoComplete(questID) and true or false
    end

    if GetQuestLogIsAutoComplete then
        return GetQuestLogIsAutoComplete(questIndex) and true or false
    end

    return false
end

local function SafeGetQuestTagInfo(questID)
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

local function SafeGetQuestTypeTag(questID)
    local info = SafeGetQuestTagInfo(questID)
    return info and info.tagID or 0
end

local function IsFactionRestrictedQuest(questID)
    if not questID or not GetQuestFactionGroup then
        return false
    end

    return GetQuestFactionGroup(questID) ~= nil
end

local function IsEventLikeQuest(info)
    if not info then
        return false
    end

    if info.startEvent then
        return true
    end

    if info.isTask then
        return true
    end

    if info.campaignID and info.campaignID > 0 then
        return false
    end

    return false
end

local matchType = 0

function QuestKing.MatchObjective(objectiveDesc)
    if matchType == 1 then
        return match(objectiveDesc, "^(%d+)%s*/%s*(%d+)%s+(.*)$")
    elseif matchType == 2 then
        local quantName, quantCur, quantMax = match(objectiveDesc, "^(.*):%s+(%d+)%s*/%s*(%d+)")
        return quantCur, quantMax, quantName
    else
        local quantCur, quantMax, quantName = match(objectiveDesc, "^(%d+)%s*/%s*(%d+)%s+(.*)$")
        if quantName then
            matchType = 1
            return quantCur, quantMax, quantName
        end

        quantName, quantCur, quantMax = match(objectiveDesc, "^(.*):%s+(%d+)%s*/%s*(%d+)")
        if quantName then
            matchType = 2
            return quantCur, quantMax, quantName
        end
    end
end

function QuestKing.MatchObjectiveRep(objectiveDesc)
    local quantCur, quantMax, quantName = match(objectiveDesc, "^(%S+)%s*/%s*(%S+)%s+(.*)$")
    if not quantName then
        quantName, quantCur, quantMax = match(objectiveDesc, "^(.*):%s+(%S+)%s*/%s*(%S+)")
    end
    return quantCur, quantMax, quantName
end

function QuestKing:DisableBlizzard()
    pcall(function()
        if ScenarioBlocksFrame then
            ScenarioBlocksFrame:UnregisterAllEvents()
            ScenarioBlocksFrame:Hide()
        end
    end)

    pcall(function()
        if ObjectiveTrackerBlocksFrame then
            ObjectiveTrackerBlocksFrame:UnregisterAllEvents()
            ObjectiveTrackerBlocksFrame:Hide()
        end
    end)

    pcall(function()
        if ObjectiveTrackerFrame then
            ObjectiveTrackerFrame:UnregisterAllEvents()
            ObjectiveTrackerFrame:Hide()

            if not objectiveTrackerShowHookInstalled and hooksecurefunc then
                hooksecurefunc(ObjectiveTrackerFrame, "Show", function(frame)
                    if frame then
                        frame:Hide()
                    end
                end)
                objectiveTrackerShowHookInstalled = true
            end
        end
    end)
end

local function colorGradient(perc, ...)
    if perc >= 1 then
        local r, g, b = select(select("#", ...) - 2, ...)
        return r, g, b
    elseif perc <= 0 then
        local r, g, b = ...
        return r, g, b
    end

    local num = select("#", ...) / 3
    local segment, relperc = modf(perc * (num - 1))
    local r1, g1, b1, r2, g2, b2 = select((segment * 3) + 1, ...)

    return r1 + (r2 - r1) * relperc,
           g1 + (g2 - g1) * relperc,
           b1 + (b2 - b1) * relperc
end

function QuestKing.GetObjectiveColor(progress)
    local complete = opt_colors.ObjectiveGradientComplete or { 0.6, 1.0, 0.6 }
    local g0 = opt_colors.ObjectiveGradient0 or { 1.0, 0.2, 0.2 }
    local g50 = opt_colors.ObjectiveGradient50 or { 1.0, 0.82, 0.0 }
    local g99 = opt_colors.ObjectiveGradient99 or { 0.2, 1.0, 0.2 }

    if progress >= 1 then
        return complete[1], complete[2], complete[3]
    end

    return colorGradient(
        progress,
        g0[1], g0[2], g0[3],
        g50[1], g50[2], g50[3],
        g99[1], g99[2], g99[3]
    )
end

function QuestKing.GetTimeStringFromSecondsShort(timeAmount)
    local seconds = tonumber(timeAmount) or 0
    if seconds < 0 then
        seconds = 0
    end

    local hours = floor(seconds / 3600)
    local minutes = floor((seconds / 60) - (hours * 60))
    seconds = seconds - hours * 3600 - minutes * 60

    if hours > 0 then
        return format("%d:%.2d:%.2d", hours, minutes, seconds)
    end

    return format("%d:%.2d", minutes, seconds)
end

local knownTypesTag = {
    [0] = "",
    [1] = "G",
    [21] = "C",
    [41] = "P",
    [62] = "R",
    [81] = "D",
    [82] = "V",
    [83] = "L",
    [84] = "E",
    [85] = "H",
    [88] = "R10",
    [89] = "R25",
    [98] = "S",
    [102] = "A",
}

function QuestKing.GetQuestTaggedTitle(questIndex, isBonus)
    local info = SafeGetQuestInfoByIndex(questIndex)
    if not info then
        if isBonus then
            return "[0] <Unknown>", 0
        end
        return "[0] <Unknown>"
    end

    local questTitle = info.title or "<Unknown>"
    local level = info.level or 0
    local suggestedGroup = info.suggestedGroup
    local frequency = info.frequency
    local questID = info.questID

    local questTypeID = SafeGetQuestTypeTag(questID) or 0
    local typeTag = knownTypesTag[questTypeID]

    if typeTag == nil then
        typeTag = format("|cffff00ff(%s)|r", tostring(questTypeID))
    end

    local levelString
    if questTypeID == 1 and suggestedGroup and suggestedGroup > 1 then
        levelString = format("%d%s%d", level, typeTag, suggestedGroup)
    elseif questTypeID == 102 then
        if IsFactionRestrictedQuest(questID) then
            levelString = format("%d%s", level, "F")
        else
            levelString = format("%d%s", level, typeTag)
        end
    elseif questTypeID > 0 then
        levelString = format("%d%s", level, typeTag)
    else
        levelString = tostring(level)
    end

    if frequency == QUEST_FREQUENCY_DAILY then
        levelString = format("%sY", levelString)
    elseif frequency == QUEST_FREQUENCY_WEEKLY then
        levelString = format("%sW", levelString)
    end

    if IsEventLikeQuest(info) then
        levelString = format("%se", levelString)
    end

    if SafeIsAutoComplete(questIndex, questID) and not isBonus then
        levelString = format("%sa", levelString)
    end

    if isBonus then
        questTitle = gsub(questTitle, "^Bonus Objective:%s*", "")
        return format("[%s] %s", levelString, questTitle), level
    end

    return format("[%s] %s", levelString, questTitle)
end