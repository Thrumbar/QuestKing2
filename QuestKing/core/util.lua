local addonName, QuestKing = ...

_G.QuestKing = QuestKing

QuestKing.newlyAddedQuests = QuestKing.newlyAddedQuests or {}
QuestKing.watchMoney = QuestKing.watchMoney or false
QuestKing.itemButtonAlpha = QuestKing.itemButtonAlpha or 1
QuestKing.itemButtonScale = QuestKing.itemButtonScale or ((QuestKing.options and QuestKing.options.itemButtonScale) or 1)
QuestKing.updateHooks = QuestKing.updateHooks or {}

local opt = QuestKing.options or {}
local fallbackColors = {
    ObjectiveGradientComplete = { 0.6, 1.0, 0.6 },
    ObjectiveGradient0 = { 1.0, 0.2, 0.2 },
    ObjectiveGradient50 = { 1.0, 0.82, 0.0 },
    ObjectiveGradient99 = { 0.2, 1.0, 0.2 },
}

local floor = math.floor
local format = string.format
local gsub = string.gsub
local match = string.match
local modf = math.modf
local select = select
local tonumber = tonumber
local tostring = tostring
local type = type

local CQL = C_QuestLog
local issecretvalue = _G.issecretvalue

local WOW_PROJECT_ID = _G.WOW_PROJECT_ID
local WOW_PROJECT_MAINLINE = _G.WOW_PROJECT_MAINLINE
local WOW_PROJECT_CLASSIC = _G.WOW_PROJECT_CLASSIC
local WOW_PROJECT_BURNING_CRUSADE_CLASSIC = _G.WOW_PROJECT_BURNING_CRUSADE_CLASSIC
local WOW_PROJECT_WRATH_CLASSIC = _G.WOW_PROJECT_WRATH_CLASSIC
local WOW_PROJECT_CATACLYSM_CLASSIC = _G.WOW_PROJECT_CATACLYSM_CLASSIC
local WOW_PROJECT_MISTS_CLASSIC = _G.WOW_PROJECT_MISTS_CLASSIC

local IS_MAINLINE = WOW_PROJECT_MAINLINE and WOW_PROJECT_ID == WOW_PROJECT_MAINLINE or false
local IS_CLASSIC_ERA = WOW_PROJECT_CLASSIC and WOW_PROJECT_ID == WOW_PROJECT_CLASSIC or false
local IS_TBC_CLASSIC = WOW_PROJECT_BURNING_CRUSADE_CLASSIC and WOW_PROJECT_ID == WOW_PROJECT_BURNING_CRUSADE_CLASSIC or false
local IS_WRATH_CLASSIC = WOW_PROJECT_WRATH_CLASSIC and WOW_PROJECT_ID == WOW_PROJECT_WRATH_CLASSIC or false
local IS_CATACLYSM_CLASSIC = WOW_PROJECT_CATACLYSM_CLASSIC and WOW_PROJECT_ID == WOW_PROJECT_CATACLYSM_CLASSIC or false
local IS_MISTS_CLASSIC = WOW_PROJECT_MISTS_CLASSIC and WOW_PROJECT_ID == WOW_PROJECT_MISTS_CLASSIC or false
local IS_CLASSIC_FAMILY = IS_CLASSIC_ERA or IS_TBC_CLASSIC or IS_WRATH_CLASSIC or IS_CATACLYSM_CLASSIC or IS_MISTS_CLASSIC

local QUEST_FREQUENCY_DAILY = (Enum and Enum.QuestFrequency and Enum.QuestFrequency.Daily) or _G.LE_QUEST_FREQUENCY_DAILY
local QUEST_FREQUENCY_WEEKLY = (Enum and Enum.QuestFrequency and Enum.QuestFrequency.Weekly) or _G.LE_QUEST_FREQUENCY_WEEKLY

local TOOLTIP_BACKDROP = {
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 16,
    insets = {
        left = 4,
        right = 4,
        top = 4,
        bottom = 4,
    },
}

local MAINLINE_TOOLTIP_WIDTH = 320
local MAINLINE_TOOLTIP_PADDING = 10
local MAINLINE_TOOLTIP_LINE_SPACING = 2
local MAINLINE_TOOLTIP_MIN_LINE_HEIGHT = 12
local MAINLINE_TOOLTIP_ICON_SIZE = 14

local trackerVisualHooksInstalled = false
local trackerVisualEventsRegistered = false
local trackerVisualRefreshQueued = false
local trackerVisualRecoveryScheduled = false
local trackerVisualStateFrame = CreateFrame("Frame")

local function GetOptions()
    return QuestKing.options or opt
end

local function GetOptionColors()
    local options = GetOptions()
    return (options and options.colors) or fallbackColors
end

local function SafeCall(func, ...)
    if type(func) ~= "function" then
        return false, nil
    end

    local ok, result = pcall(func, ...)
    if ok then
        return true, result
    end

    return false, nil
end

local function IsSecretValue(value)
    if type(issecretvalue) == "function" then
        local ok, result = pcall(issecretvalue, value)
        if ok then
            return result and true or false
        end
    end

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

    local ok, converted = pcall(tonumber, value)
    if ok and type(converted) == "number" and not IsSecretValue(converted) then
        return converted
    end

    return fallback
end

local function SafeBoolean(value, fallback)
    if value == nil or IsSecretValue(value) then
        return fallback
    end

    return value and true or false
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

QuestKing.IsSecretValue = IsSecretValue
QuestKing.IsSafeNumber = IsSafeNumber
QuestKing.SafeNumber = SafeNumber
QuestKing.SafeBoolean = SafeBoolean
QuestKing.SafeString = SafeString
QuestKing.IsMainline = IS_MAINLINE
QuestKing.IsClassicEra = IS_CLASSIC_ERA
QuestKing.IsTBCClassic = IS_TBC_CLASSIC
QuestKing.IsWrathClassic = IS_WRATH_CLASSIC
QuestKing.IsCataclysmClassic = IS_CATACLYSM_CLASSIC
QuestKing.IsMistsClassic = IS_MISTS_CLASSIC
QuestKing.IsClassicFamily = IS_CLASSIC_FAMILY

local VALID_FONT_LAYERS = {
    BACKGROUND = true,
    BORDER = true,
    ARTWORK = true,
    OVERLAY = true,
    HIGHLIGHT = true,
}

function QuestKing.GetFontLayer()
    local options = GetOptions()
    local layer = options and options.fontLayer
    if type(layer) == "string" and VALID_FONT_LAYERS[layer] then
        return layer
    end

    return "OVERLAY"
end

function QuestKing.ApplyFontLayer(fontString)
    if not fontString or type(fontString.SetDrawLayer) ~= "function" then
        return false
    end

    fontString:SetDrawLayer(QuestKing.GetFontLayer())
    return true
end

-- Applies the documented three-state completed-objective policy consistently:
--   false    = never show completed objective rows
--   true     = show them only while their quest/scenario step is incomplete
--   "always" = show them even after the quest/scenario step is complete
function QuestKing.ShouldShowCompletedObjective(containerComplete)
    local options = GetOptions()
    local mode = options and options.showCompletedObjectives

    if mode == "always" then
        return true
    end

    if containerComplete then
        return false
    end

    return mode == true
end


--[[
    Retail / Midnight tooltip taint note

    QuestKing intentionally does not replace Blizzard tooltip, UIWidget, or
    embedded item-tooltip functions.

    Earlier builds wrapped UIWidgetTemplateTextWithStateMixin.Setup to catch a
    Blizzard map-tooltip failure. That stopped one TextWithState crash, but it
    also made Blizzard's own GameTooltip world-quest hover path execute with
    QuestKing taint. In current Retail builds, that taint can reach
    EmbeddedItemTooltip_UpdateSize and make Blizzard's own width/height math
    fail when GetWidth/GetHeight returns secret values.

    The safe fix is complete ownership isolation. On Mainline, QuestKing uses
    an addon-owned Frame and FontStrings rather than GameTooltipTemplate. This
    prevents QuestKing hover and cleanup work from entering Blizzard's shared
    GameTooltip, comparison-tooltip, embedded-tooltip, or UIWidget state.
    Classic-family clients retain GameTooltipTemplate because they require the
    legacy tooltip population methods and do not expose secret values.
]]
local function InstallTextWithStateWidgetGuard()
    return false
end

QuestKing.InstallTextWithStateWidgetGuard = InstallTextWithStateWidgetGuard


local function GetQuestIDForLogIndexCompat(questLogIndex)
    if type(questLogIndex) ~= "number" or questLogIndex <= 0 then
        return nil
    end

    if CQL and CQL.GetQuestIDForLogIndex then
        local ok, questID = pcall(CQL.GetQuestIDForLogIndex, questLogIndex)
        if ok and type(questID) == "number" and questID > 0 then
            return questID
        end
    end

    if CQL and CQL.GetInfo then
        local ok, info = pcall(CQL.GetInfo, questLogIndex)
        if ok and type(info) == "table" and type(info.questID) == "number" and info.questID > 0 then
            return info.questID
        end
    end

    if type(_G.GetQuestLogTitle) == "function" then
        local ok, _, _, _, _, _, _, _, questID = pcall(_G.GetQuestLogTitle, questLogIndex)
        if ok and type(questID) == "number" and questID > 0 then
            return questID
        end
    end

    return nil
end

local function GetQuestDifficultyLevelCompat(questID, questLogIndex)
    if type(questID) == "number" and CQL and CQL.GetQuestDifficultyLevel then
        local ok, level = pcall(CQL.GetQuestDifficultyLevel, questID)
        if ok and type(level) == "number" then
            return level
        end
    end

    if type(questLogIndex) == "number" and type(_G.GetQuestLogTitle) == "function" then
        local ok, _, level = pcall(_G.GetQuestLogTitle, questLogIndex)
        if ok and type(level) == "number" then
            return level
        end
    end

    if type(_G.UnitLevel) == "function" then
        local ok, level = pcall(_G.UnitLevel, "player")
        if ok and type(level) == "number" then
            return level
        end
    end

    return 0
end

local function SafeGetQuestInfoByIndex(questLogIndex)
    if type(questLogIndex) ~= "number" or questLogIndex <= 0 then
        return nil
    end

    if CQL and CQL.GetInfo then
        local ok, info = pcall(CQL.GetInfo, questLogIndex)
        if ok and type(info) == "table" then
            local questID = SafeNumber(info.questID, nil)
            local level = SafeNumber(info.level, nil)
            if level == nil then
                level = GetQuestDifficultyLevelCompat(questID, questLogIndex)
            end

            return {
                title = SafeString(info.title, _G.UNKNOWN or "<Unknown>"),
                level = SafeNumber(level, 0) or 0,
                suggestedGroup = SafeNumber(info.suggestedGroup, 0) or 0,
                frequency = SafeNumber(info.frequency, nil),
                questID = questID,
                isHeader = SafeBoolean(info.isHeader, false),
                isHidden = SafeBoolean(info.isHidden, false),
                isTask = SafeBoolean(info.isTask, false),
                campaignID = SafeNumber(info.campaignID, 0) or 0,
                isCampaign = info.isCampaign ~= nil
                    and SafeBoolean(info.isCampaign, false)
                    or nil,
                isOnMap = SafeBoolean(info.isOnMap, false),
                startEvent = SafeBoolean(info.startEvent, false),
                isStory = SafeBoolean(info.isStory, false),
                isDaily = SafeBoolean(info.isDaily, false),
                isScaling = SafeBoolean(info.isScaling, false),
                questClassification = SafeNumber(info.questClassification, nil),
            }
        end
    end

    if type(_G.GetQuestLogTitle) == "function" then
        local ok, title, level, suggestedGroup, isHeader, isCollapsed, isComplete, frequency, questID, startEvent =
            pcall(_G.GetQuestLogTitle, questLogIndex)
        if ok then
            return {
                title = SafeString(title, _G.UNKNOWN or "<Unknown>"),
                level = SafeNumber(level, 0) or 0,
                suggestedGroup = SafeNumber(suggestedGroup, 0) or 0,
                frequency = SafeNumber(frequency, nil),
                questID = SafeNumber(questID, nil),
                isHeader = SafeBoolean(isHeader, false),
                isCollapsed = SafeBoolean(isCollapsed, false),
                isComplete = isComplete,
                isHidden = false,
                isTask = false,
                campaignID = 0,
                isCampaign = nil,
                isOnMap = false,
                startEvent = SafeBoolean(startEvent, false),
                isStory = false,
                isDaily = false,
                isScaling = false,
                questClassification = nil,
            }
        end
    end

    return nil
end

local function SafeIsAutoComplete(questLogIndex, questID)
    local compatibility = QuestKing.Compatibility and QuestKing.Compatibility.Common
    if compatibility and type(compatibility.IsQuestAutoComplete) == "function" then
        return compatibility.IsQuestAutoComplete(questID, questLogIndex) and true or false
    end

    if type(questLogIndex) == "number" and CQL and CQL.GetInfo then
        local ok, info = pcall(CQL.GetInfo, questLogIndex)
        if ok and type(info) == "table" and info.isAutoComplete then
            return true
        end
    end

    if type(questLogIndex) == "number" and type(_G.GetQuestLogIsAutoComplete) == "function" then
        local ok, isAutoComplete = pcall(_G.GetQuestLogIsAutoComplete, questLogIndex)
        if ok then
            return isAutoComplete and true or false
        end
    end

    if type(questID) == "number" and CQL and CQL.IsAutoComplete then
        local ok, isAutoComplete = pcall(CQL.IsAutoComplete, questID)
        if ok then
            return isAutoComplete and true or false
        end
    end

    return false
end

local function SafeGetQuestTagInfo(questID)
    if type(questID) ~= "number" or questID <= 0 then
        return nil
    end

    if CQL and CQL.GetQuestTagInfo then
        local ok, info = pcall(CQL.GetQuestTagInfo, questID)
        if ok and type(info) == "table" then
            return {
                tagID = SafeNumber(info.tagID, 0) or 0,
                tagName = SafeString(info.tagName, nil),
                worldQuestType = SafeNumber(info.worldQuestType, nil),
                quality = SafeNumber(info.quality, nil),
                isElite = SafeBoolean(info.isElite, false),
                tradeskillLineID = SafeNumber(info.tradeskillLineID, nil),
                displayExpiration = SafeBoolean(info.displayExpiration, false),
            }
        end
    end

    if type(_G.GetQuestTagInfo) == "function" then
        local ok, tagID, tagName, worldQuestType, quality, isElite, tradeskillLineID, displayExpiration =
            pcall(_G.GetQuestTagInfo, questID)
        if ok and (tagID or tagName or worldQuestType or quality or isElite) then
            return {
                tagID = SafeNumber(tagID, 0) or 0,
                tagName = SafeString(tagName, nil),
                worldQuestType = SafeNumber(worldQuestType, nil),
                quality = SafeNumber(quality, nil),
                isElite = SafeBoolean(isElite, false),
                tradeskillLineID = SafeNumber(tradeskillLineID, nil),
                displayExpiration = SafeBoolean(displayExpiration, false),
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
    if type(questID) ~= "number" or questID <= 0 or type(_G.GetQuestFactionGroup) ~= "function" then
        return false
    end

    local ok, group = pcall(_G.GetQuestFactionGroup, questID)
    return ok and group ~= nil
end

local function IsEventLikeQuest(info)
    if type(info) ~= "table" then
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

local objectiveMatchType = 0

function QuestKing.MatchObjective(objectiveDesc)
    if type(objectiveDesc) ~= "string" or objectiveDesc == "" then
        return nil, nil, nil
    end

    if objectiveMatchType == 1 then
        return match(objectiveDesc, "^(%d+)%s*/%s*(%d+)%s+(.*)$")
    elseif objectiveMatchType == 2 then
        local quantName, quantCur, quantMax = match(objectiveDesc, "^(.*):%s+(%d+)%s*/%s*(%d+)")
        return quantCur, quantMax, quantName
    end

    local quantCur, quantMax, quantName = match(objectiveDesc, "^(%d+)%s*/%s*(%d+)%s+(.*)$")
    if quantName then
        objectiveMatchType = 1
        return quantCur, quantMax, quantName
    end

    quantName, quantCur, quantMax = match(objectiveDesc, "^(.*):%s+(%d+)%s*/%s*(%d+)")
    if quantName then
        objectiveMatchType = 2
        return quantCur, quantMax, quantName
    end

    return nil, nil, nil
end

function QuestKing.MatchObjectiveRep(objectiveDesc)
    if type(objectiveDesc) ~= "string" or objectiveDesc == "" then
        return nil, nil, nil
    end

    local quantCur, quantMax, quantName = match(objectiveDesc, "^(%S+)%s*/%s*(%S+)%s+(.*)$")
    if not quantName then
        quantName, quantCur, quantMax = match(objectiveDesc, "^(.*):%s+(%S+)%s*/%s*(%S+)")
    end

    return quantCur, quantMax, quantName
end

local BLIZZARD_TRACKER_FRAME_NAMES = {
    -- Retail / Midnight objective tracker roots and common child roots.
    "ObjectiveTrackerFrame",
    "ObjectiveTrackerBlocksFrame",
    "QuestObjectiveTracker",
    "AchievementObjectiveTracker",
    "BonusObjectiveTracker",
    "BonusObjectiveTrackerFrame",
    "ScenarioObjectiveTracker",
    "ScenarioBlocksFrame",
    "MonthlyActivitiesObjectiveTracker",
    "ProfessionsRecipeTracker",

    -- Wrath / Cataclysm / Mists Classic tracker roots.
    "WatchFrame",
    "AchievementWatchFrame",

    -- Classic Era / Burning Crusade Classic quest watch root.
    "QuestWatchFrame",
}

local BLIZZARD_TRACKER_REFRESH_FUNCTION_NAMES = {
    -- Retail / Midnight.
    "ObjectiveTracker_Update",
    "BonusObjectiveTracker_Update",
    "ScenarioObjectiveTracker_Update",
    "AchievementObjectiveTracker_Update",
    "QuestObjectiveTracker_Update",
    "MonthlyActivitiesObjectiveTracker_Update",

    -- Wrath / Cataclysm / Mists Classic.
    "WatchFrame_Update",
    "AchievementWatchFrame_Update",

    -- Classic Era / Burning Crusade Classic.
    "QuestWatch_Update",
}

local BLIZZARD_TRACKER_LEGACY_HARD_HIDE_NAMES = {
    QuestWatchFrame = true,
    WatchFrame = true,
    AchievementWatchFrame = true,
}

local trackerVisualHookedFrames = {}
local trackerVisualHookedFunctions = {}
local trackerVisualHookedObjects = {}

local function SafeEnableMouse(frame, enabled)
    if frame and frame.EnableMouse then
        pcall(frame.EnableMouse, frame, enabled and true or false)
    end
end

local function SafeSetAlpha(frame, alpha)
    if frame and frame.SetAlpha then
        pcall(frame.SetAlpha, frame, alpha)
    end
end

local function SafeSetIgnoreParentAlpha(frame, enabled)
    if frame and frame.SetIgnoreParentAlpha then
        pcall(frame.SetIgnoreParentAlpha, frame, enabled and true or false)
    end
end

local function SafeShow(frame)
    if frame and frame.Show then
        pcall(frame.Show, frame)
    end
end

local function SafeHide(frame)
    if frame and frame.Hide then
        pcall(frame.Hide, frame)
    end
end

local function SafeGetFrameName(frame)
    if frame and frame.GetName then
        local ok, name = pcall(frame.GetName, frame)
        if ok and type(name) == "string" then
            return name
        end
    end

    return nil
end

local function SafeGetGlobalFrame(name)
    if type(name) ~= "string" or name == "" then
        return nil
    end

    local frame = _G[name]
    if type(frame) == "table" then
        return frame
    end

    return nil
end

local function RegisterEventSafe(frame, eventName)
    if not frame or type(eventName) ~= "string" or eventName == "" or not frame.RegisterEvent then
        return false
    end

    local ok = pcall(frame.RegisterEvent, frame, eventName)
    return ok and true or false
end

local function HookMethodSafe(target, methodName, callback)
    if not target or type(methodName) ~= "string" or type(callback) ~= "function" or not hooksecurefunc then
        return false
    end

    if type(target[methodName]) ~= "function" then
        return false
    end

    local ok = pcall(hooksecurefunc, target, methodName, callback)
    return ok and true or false
end

local function HookGlobalSafe(functionName, callback)
    if type(functionName) ~= "string" or functionName == "" or type(callback) ~= "function" or not hooksecurefunc then
        return false
    end

    if type(_G[functionName]) ~= "function" then
        return false
    end

    local ok = pcall(hooksecurefunc, functionName, callback)
    return ok and true or false
end

local function ShouldHideBlizzardTracker()
    local options = GetOptions()
    return options and options.disableBlizzard == true or false
end

local function AddTrackerFrame(frames, seen, frame)
    if not frame or seen[frame] then
        return
    end

    seen[frame] = true
    frames[#frames + 1] = frame
end

local function AddTrackerFrameByName(frames, seen, frameName)
    AddTrackerFrame(frames, seen, SafeGetGlobalFrame(frameName))
end

local function AddTrackerObjectChild(frames, seen, object, childKey)
    if object and type(object) == "table" and type(childKey) == "string" then
        AddTrackerFrame(frames, seen, object[childKey])
    end
end

local function GetBlizzardTrackerRootFrames()
    local frames = {}
    local seen = {}

    for index = 1, #BLIZZARD_TRACKER_FRAME_NAMES do
        AddTrackerFrameByName(frames, seen, BLIZZARD_TRACKER_FRAME_NAMES[index])
    end

    local objectiveTracker = SafeGetGlobalFrame("ObjectiveTrackerFrame")
    AddTrackerObjectChild(frames, seen, objectiveTracker, "BlocksFrame")
    AddTrackerObjectChild(frames, seen, objectiveTracker, "ScrollContents")
    AddTrackerObjectChild(frames, seen, objectiveTracker, "HeaderMenu")
    AddTrackerObjectChild(frames, seen, objectiveTracker, "Header")
    AddTrackerObjectChild(frames, seen, objectiveTracker, "HeaderFrame")
    AddTrackerObjectChild(frames, seen, objectiveTracker, "Background")

    local watchFrame = SafeGetGlobalFrame("WatchFrame")
    AddTrackerObjectChild(frames, seen, watchFrame, "Lines")
    AddTrackerObjectChild(frames, seen, watchFrame, "Header")
    AddTrackerObjectChild(frames, seen, watchFrame, "CollapseExpandButton")

    local questWatchFrame = SafeGetGlobalFrame("QuestWatchFrame")
    AddTrackerObjectChild(frames, seen, questWatchFrame, "Lines")
    AddTrackerObjectChild(frames, seen, questWatchFrame, "Header")
    AddTrackerObjectChild(frames, seen, questWatchFrame, "CollapseExpandButton")

    return frames
end

local function IsLegacyHardHideTrackerFrame(frame)
    local name = SafeGetFrameName(frame)
    return name and BLIZZARD_TRACKER_LEGACY_HARD_HIDE_NAMES[name] == true or false
end

local function IsModernManagedTrackerFrame(frame)
    if not frame then
        return false
    end

    if frame.isManagedFrame or frame.isRightManagedFrame or frame.layoutParent then
        return true
    end

    local name = SafeGetFrameName(frame)
    if not name then
        return false
    end

    if name == "ObjectiveTrackerFrame" or name == "ObjectiveTrackerBlocksFrame" then
        return true
    end

    if string.find(name, "ObjectiveTracker", 1, true) then
        return true
    end

    if name == "MonthlyActivitiesObjectiveTracker" or name == "ProfessionsRecipeTracker" then
        return true
    end

    return false
end

local function ApplySuppressionToTrackerRoot(frame, hide)
    if not frame then
        return
    end

    local legacyHardHide = IsLegacyHardHideTrackerFrame(frame)
    local modernManaged = IsModernManagedTrackerFrame(frame)

    -- Retail / Midnight: keep suppression to one visual alpha write only.
    -- Do not call Show/Hide, EnableMouse, SetIgnoreParentAlpha, or any Blizzard
    -- tracker update hook path from QuestKing on Mainline. The world-map reward
    -- tooltip stack is too sensitive to addon-tainted Blizzard execution.
    if IS_MAINLINE then
        SafeSetAlpha(frame, hide and 0 or 1)
        return
    end

    -- Classic-family clients use older watch frames. They still need the
    -- stronger legacy hide path because alpha-only suppression is not reliable
    -- for QuestWatchFrame/WatchFrame refreshes.
    SafeSetIgnoreParentAlpha(frame, false)
    SafeSetAlpha(frame, hide and 0 or 1)

    if legacyHardHide then
        SafeEnableMouse(frame, not hide)

        if hide then
            SafeHide(frame)
        else
            SafeShow(frame)
        end
    else
        -- Non-managed child frames can safely have mouse disabled so invisible
        -- leftovers do not catch cursor interaction on Classic-family clients.
        SafeEnableMouse(frame, not hide)
    end
end

local function ApplyBlizzardTrackerVisualState()
    local hide = ShouldHideBlizzardTracker()
    local inCombat = type(_G.InCombatLockdown) == "function" and _G.InCombatLockdown()
    local trackerFrames = GetBlizzardTrackerRootFrames()

    for index = 1, #trackerFrames do
        local frame = trackerFrames[index]

        if inCombat and IsModernManagedTrackerFrame(frame) then
            -- Mainline-style managed frames are left alone during combat. The
            -- queued PLAYER_REGEN_ENABLED refresh below reapplies suppression.
        else
            ApplySuppressionToTrackerRoot(frame, hide)
        end
    end
end

local function RunQueuedBlizzardTrackerVisualRefresh()
    trackerVisualRefreshQueued = false
    ApplyBlizzardTrackerVisualState()
end

local function ScheduleBlizzardTrackerVisualRefresh(delay)
    if trackerVisualRefreshQueued then
        return
    end

    if not (C_Timer and C_Timer.After) then
        ApplyBlizzardTrackerVisualState()
        return
    end

    trackerVisualRefreshQueued = true
    C_Timer.After(delay or 0, RunQueuedBlizzardTrackerVisualRefresh)
end

local function RequestBlizzardTrackerVisualRefresh()
    ScheduleBlizzardTrackerVisualRefresh(0)
end

local function InstallTrackerFrameShowHook(frame)
    if not frame or trackerVisualHookedFrames[frame] then
        return false
    end

    if HookMethodSafe(frame, "Show", RequestBlizzardTrackerVisualRefresh) then
        trackerVisualHookedFrames[frame] = true
        return true
    end

    return false
end

local function InstallTrackerGlobalFunctionHook(functionName)
    if trackerVisualHookedFunctions[functionName] then
        return false
    end

    if HookGlobalSafe(functionName, RequestBlizzardTrackerVisualRefresh) then
        trackerVisualHookedFunctions[functionName] = true
        return true
    end

    return false
end

local function InstallTrackerObjectMethodHook(object, methodName, key)
    if trackerVisualHookedObjects[key] then
        return false
    end

    if HookMethodSafe(object, methodName, RequestBlizzardTrackerVisualRefresh) then
        trackerVisualHookedObjects[key] = true
        return true
    end

    return false
end

local function InstallTrackerVisualHooks()
    -- Mainline/Retail world-map reward tooltips are very sensitive to addon
    -- taint on Blizzard-owned execution paths. Do not hook Blizzard tracker
    -- Show/Update/Manager methods on Mainline; suppression is re-applied from
    -- QuestKing-owned events instead. Classic-family clients keep the legacy
    -- hooks because their watch frames are not the same protected managed UI.
    if IS_MAINLINE then
        return
    end

    local hookedAnything = false
    local trackerFrames = GetBlizzardTrackerRootFrames()

    for index = 1, #trackerFrames do
        if InstallTrackerFrameShowHook(trackerFrames[index]) then
            hookedAnything = true
        end
    end

    for index = 1, #BLIZZARD_TRACKER_REFRESH_FUNCTION_NAMES do
        if InstallTrackerGlobalFunctionHook(BLIZZARD_TRACKER_REFRESH_FUNCTION_NAMES[index]) then
            hookedAnything = true
        end
    end

    if InstallTrackerObjectMethodHook(_G.ObjectiveTrackerManager, "Update", "ObjectiveTrackerManager.Update") then
        hookedAnything = true
    end

    if InstallTrackerObjectMethodHook(_G.ObjectiveTrackerManager, "MarkDirty", "ObjectiveTrackerManager.MarkDirty") then
        hookedAnything = true
    end

    trackerVisualHooksInstalled = trackerVisualHooksInstalled or hookedAnything
end

local function OnTrackerVisualStateEvent(_, event, loadedAddonName)
    if event == "ADDON_LOADED"
        and loadedAddonName ~= addonName
        and loadedAddonName ~= "Blizzard_ObjectiveTracker"
        and loadedAddonName ~= "Blizzard_QuestWatch"
        and loadedAddonName ~= "Blizzard_AchievementUI" then
        return
    end

    InstallTrackerVisualHooks()
    RequestBlizzardTrackerVisualRefresh()
end

local function RegisterTrackerVisualStateEvents()
    if trackerVisualEventsRegistered then
        return
    end

    trackerVisualEventsRegistered = true

    trackerVisualStateFrame:SetScript("OnEvent", OnTrackerVisualStateEvent)

    RegisterEventSafe(trackerVisualStateFrame, "ADDON_LOADED")
    RegisterEventSafe(trackerVisualStateFrame, "PLAYER_LOGIN")
    RegisterEventSafe(trackerVisualStateFrame, "PLAYER_ENTERING_WORLD")
    RegisterEventSafe(trackerVisualStateFrame, "QUEST_LOG_UPDATE")
    RegisterEventSafe(trackerVisualStateFrame, "TRACKED_QUEST_LIST_CHANGED")
    RegisterEventSafe(trackerVisualStateFrame, "UPDATE_QUEST_WATCH")
    RegisterEventSafe(trackerVisualStateFrame, "ZONE_CHANGED")
    RegisterEventSafe(trackerVisualStateFrame, "ZONE_CHANGED_NEW_AREA")
    RegisterEventSafe(trackerVisualStateFrame, "DISPLAY_SIZE_CHANGED")
    RegisterEventSafe(trackerVisualStateFrame, "UI_SCALE_CHANGED")
    RegisterEventSafe(trackerVisualStateFrame, "EDIT_MODE_LAYOUTS_UPDATED")
    RegisterEventSafe(trackerVisualStateFrame, "PLAYER_REGEN_ENABLED")
end

function QuestKing:DisableBlizzard()
    if not ShouldHideBlizzardTracker() then
        return
    end

    RegisterTrackerVisualStateEvents()
    InstallTrackerVisualHooks()
    ScheduleBlizzardTrackerVisualRefresh(0)

    if not trackerVisualRecoveryScheduled and C_Timer and C_Timer.After then
        trackerVisualRecoveryScheduled = true
        C_Timer.After(0.5, OnTrackerVisualStateEvent)
        C_Timer.After(2, OnTrackerVisualStateEvent)
    end
end

function QuestKing:RefreshBlizzardTrackerSuppression()
    RegisterTrackerVisualStateEvents()
    InstallTrackerVisualHooks()
    ScheduleBlizzardTrackerVisualRefresh(0)
end

QuestKing.ApplyBlizzardTrackerVisualState = ApplyBlizzardTrackerVisualState
QuestKing.ScheduleBlizzardTrackerVisualRefresh = ScheduleBlizzardTrackerVisualRefresh
QuestKing.RequestBlizzardTrackerVisualRefresh = RequestBlizzardTrackerVisualRefresh

local function ColorGradient(progress, ...)
    if progress >= 1 then
        local r, g, b = select(select("#", ...) - 2, ...)
        return r, g, b
    elseif progress <= 0 then
        local r, g, b = ...
        return r, g, b
    end

    local num = select("#", ...) / 3
    local segment, relProgress = modf(progress * (num - 1))
    local r1, g1, b1, r2, g2, b2 = select((segment * 3) + 1, ...)

    return r1 + (r2 - r1) * relProgress,
           g1 + (g2 - g1) * relProgress,
           b1 + (b2 - b1) * relProgress
end

function QuestKing.GetObjectiveColor(progress)
    progress = SafeNumber(progress, 0) or 0

    local colors = GetOptionColors()
    local complete = colors.ObjectiveGradientComplete or fallbackColors.ObjectiveGradientComplete
    local g0 = colors.ObjectiveGradient0 or fallbackColors.ObjectiveGradient0
    local g50 = colors.ObjectiveGradient50 or fallbackColors.ObjectiveGradient50
    local g99 = colors.ObjectiveGradient99 or fallbackColors.ObjectiveGradient99

    if progress >= 1 then
        return complete[1], complete[2], complete[3]
    end

    return ColorGradient(
        progress,
        g0[1], g0[2], g0[3],
        g50[1], g50[2], g50[3],
        g99[1], g99[2], g99[3]
    )
end

function QuestKing.GetTimeStringFromSecondsShort(timeAmount)
    local seconds = SafeNumber(timeAmount, 0) or 0
    if seconds < 0 then
        seconds = 0
    end

    local hours = floor(seconds / 3600)
    local minutes = floor((seconds / 60) - (hours * 60))
    seconds = seconds - (hours * 3600) - (minutes * 60)

    if hours > 0 then
        return format("%d:%.2d:%.2d", hours, minutes, seconds)
    end

    return format("%d:%.2d", minutes, seconds)
end

local function HasMainlineTooltipFont(fontString)
    if not fontString or type(fontString.GetFont) ~= "function" then
        return false
    end

    local ok, fontFile, fontHeight = pcall(fontString.GetFont, fontString)
    return ok
        and type(fontFile) == "string"
        and fontFile ~= ""
        and IsSafeNumber(fontHeight)
        and fontHeight > 0
end

local function SetMainlineTooltipFontStringFont(fontString, isHeader)
    if not fontString then
        return false
    end

    local fontObject
    if isHeader then
        fontObject = _G.GameTooltipHeaderText or _G.GameFontNormal
    else
        fontObject = _G.GameTooltipText or _G.GameFontHighlightSmall
    end

    if fontObject and type(fontString.SetFontObject) == "function" then
        pcall(fontString.SetFontObject, fontString, fontObject)
        if HasMainlineTooltipFont(fontString) then
            return true
        end
    end

    local fallbackFont
    local fallbackSize
    if isHeader then
        fallbackFont = "Interface\\AddOns\\QuestKing\\fonts\\SourceSansPro-Semibold.ttf"
        fallbackSize = 13
    else
        fallbackFont = "Interface\\AddOns\\QuestKing\\fonts\\SourceSansPro-Regular.ttf"
        fallbackSize = 12
    end

    if type(fontString.SetFont) == "function" then
        pcall(fontString.SetFont, fontString, fallbackFont, fallbackSize)
    end

    return HasMainlineTooltipFont(fontString)
end

local function SetMainlineTooltipLineFont(line, isHeader)
    if not line or not line.left or not line.right then
        return false
    end

    local leftReady = SetMainlineTooltipFontStringFont(line.left, isHeader)
    local rightReady = SetMainlineTooltipFontStringFont(line.right, isHeader)
    return leftReady and rightReady
end

local function AcquireMainlineTooltipLine(tooltip, isHeader)
    local index = tooltip.lineCount + 1
    local line = tooltip.lines[index]

    if not line then
        line = {
            left = tooltip:CreateFontString(nil, "ARTWORK"),
            right = tooltip:CreateFontString(nil, "ARTWORK"),
            icon = tooltip:CreateTexture(nil, "ARTWORK"),
        }

        line.left:SetJustifyH("LEFT")
        line.left:SetJustifyV("TOP")
        line.right:SetJustifyH("RIGHT")
        line.right:SetJustifyV("TOP")
        line.icon:SetSize(MAINLINE_TOOLTIP_ICON_SIZE, MAINLINE_TOOLTIP_ICON_SIZE)
        line.icon:Hide()

        tooltip.lines[index] = line
    end

    if not SetMainlineTooltipLineFont(line, isHeader) then
        line.left:Hide()
        line.right:Hide()
        line.icon:Hide()
        return nil
    end

    tooltip.lineCount = index
    line.left:Show()
    line.right:Hide()
    line.icon:Hide()
    line.left:ClearAllPoints()
    line.right:ClearAllPoints()
    line.icon:ClearAllPoints()
    line.left:SetText("")
    line.right:SetText("")
    line.left:SetWidth(MAINLINE_TOOLTIP_WIDTH - (MAINLINE_TOOLTIP_PADDING * 2))
    line.right:SetWidth(0)
    line.hasRightText = false
    line.hasIcon = false
    line.wrapText = true
    line.isHeader = isHeader and true or false
    line.height = MAINLINE_TOOLTIP_MIN_LINE_HEIGHT

    return line
end

local function GetMainlineTooltipFontStringHeight(fontString)
    if not fontString or not fontString.GetStringHeight then
        return MAINLINE_TOOLTIP_MIN_LINE_HEIGHT
    end

    local ok, height = pcall(fontString.GetStringHeight, fontString)
    height = ok and SafeNumber(height, nil) or nil
    if height == nil or height < MAINLINE_TOOLTIP_MIN_LINE_HEIGHT then
        return MAINLINE_TOOLTIP_MIN_LINE_HEIGHT
    end

    return height
end

local function LayoutMainlineTooltip(tooltip)
    if not tooltip or not tooltip.isQuestKingTextTooltip then
        return
    end

    local contentHeight = 0
    local contentWidth = MAINLINE_TOOLTIP_WIDTH - (MAINLINE_TOOLTIP_PADDING * 2)

    for index = 1, tooltip.lineCount do
        local line = tooltip.lines[index]
        local leftOffset = line.hasIcon and (MAINLINE_TOOLTIP_ICON_SIZE + 4) or 0
        local lineTopOffset = MAINLINE_TOOLTIP_PADDING + contentHeight

        line.left:ClearAllPoints()
        line.right:ClearAllPoints()
        line.icon:ClearAllPoints()

        line.left:SetPoint(
            "TOPLEFT",
            tooltip,
            "TOPLEFT",
            MAINLINE_TOOLTIP_PADDING + leftOffset,
            -lineTopOffset
        )

        if line.hasRightText then
            line.left:SetWidth(190 - leftOffset)
            line.right:SetWidth(contentWidth - 198)
            line.right:SetPoint(
                "TOPRIGHT",
                tooltip,
                "TOPRIGHT",
                -MAINLINE_TOOLTIP_PADDING,
                -lineTopOffset
            )
        else
            line.left:SetWidth(contentWidth - leftOffset)
            line.right:SetWidth(0)
        end

        if line.hasIcon then
            line.icon:SetPoint("TOPLEFT", line.left, "TOPLEFT", -leftOffset, 0)
            line.icon:Show()
        else
            line.icon:Hide()
        end

        local lineHeight = GetMainlineTooltipFontStringHeight(line.left)
        if line.hasRightText then
            local rightHeight = GetMainlineTooltipFontStringHeight(line.right)
            if rightHeight > lineHeight then
                lineHeight = rightHeight
            end
        end
        if line.hasIcon and MAINLINE_TOOLTIP_ICON_SIZE > lineHeight then
            lineHeight = MAINLINE_TOOLTIP_ICON_SIZE
        end

        line.height = lineHeight
        contentHeight = contentHeight + lineHeight
        if index < tooltip.lineCount then
            contentHeight = contentHeight + MAINLINE_TOOLTIP_LINE_SPACING
        end
    end

    if tooltip.lineCount == 0 then
        contentHeight = MAINLINE_TOOLTIP_MIN_LINE_HEIGHT
    end

    tooltip:SetWidth(MAINLINE_TOOLTIP_WIDTH)
    tooltip:SetHeight(contentHeight + (MAINLINE_TOOLTIP_PADDING * 2))
end

local function ClearMainlineTooltipLines(tooltip)
    if not tooltip or not tooltip.lines then
        return
    end

    for index = 1, #tooltip.lines do
        local line = tooltip.lines[index]
        if SetMainlineTooltipLineFont(line, false) then
            line.left:SetText("")
            line.right:SetText("")
        end
        line.left:Hide()
        line.right:Hide()
        line.icon:SetTexture(nil)
        line.icon:Hide()
        line.hasRightText = false
        line.hasIcon = false
    end

    tooltip.lineCount = 0
    LayoutMainlineTooltip(tooltip)
end

local function AddMainlineTooltipLine(tooltip, text, r, g, b, wrapText, isHeader)
    text = SafeString(text, nil)
    if text == nil then
        return false
    end

    local line = AcquireMainlineTooltipLine(tooltip, isHeader)
    if not line then
        return false
    end

    line.wrapText = wrapText ~= false
    line.left:SetText(text)
    line.left:SetTextColor(
        SafeNumber(r, 1) or 1,
        SafeNumber(g, 1) or 1,
        SafeNumber(b, 1) or 1
    )
    line.left:SetWordWrap(line.wrapText)
    line.right:SetWordWrap(line.wrapText)
    LayoutMainlineTooltip(tooltip)
    return true
end

local function AddMainlineTooltipDoubleLine(
    tooltip,
    leftText,
    rightText,
    leftR,
    leftG,
    leftB,
    rightR,
    rightG,
    rightB,
    wrapText
)
    leftText = SafeString(leftText, nil)
    rightText = SafeString(rightText, nil)
    if leftText == nil and rightText == nil then
        return false
    end

    local line = AcquireMainlineTooltipLine(tooltip, false)
    if not line then
        return false
    end

    line.hasRightText = true
    line.wrapText = wrapText ~= false
    line.left:SetText(leftText or "")
    line.right:SetText(rightText or "")
    line.left:SetTextColor(
        SafeNumber(leftR, 1) or 1,
        SafeNumber(leftG, 1) or 1,
        SafeNumber(leftB, 1) or 1
    )
    line.right:SetTextColor(
        SafeNumber(rightR, 1) or 1,
        SafeNumber(rightG, 1) or 1,
        SafeNumber(rightB, 1) or 1
    )
    line.left:SetWordWrap(line.wrapText)
    line.right:SetWordWrap(line.wrapText)
    line.right:Show()
    LayoutMainlineTooltip(tooltip)
    return true
end

local function AddMainlineTooltipTexture(tooltip, texture)
    if texture == nil or IsSecretValue(texture) then
        return false
    end

    if type(texture) ~= "string" and type(texture) ~= "number" then
        return false
    end

    local line = tooltip.lines and tooltip.lines[tooltip.lineCount]
    if not line then
        return false
    end

    local ok = pcall(line.icon.SetTexture, line.icon, texture)
    if not ok then
        return false
    end

    line.hasIcon = true
    LayoutMainlineTooltip(tooltip)
    return true
end

local function AnchorMainlineTooltip(tooltip, owner, anchor)
    if not tooltip or not owner then
        return
    end

    anchor = SafeString(anchor, "ANCHOR_RIGHT") or "ANCHOR_RIGHT"
    tooltip:ClearAllPoints()

    if anchor == "ANCHOR_LEFT" then
        tooltip:SetPoint("RIGHT", owner, "LEFT", -8, 0)
    elseif anchor == "ANCHOR_TOP" then
        tooltip:SetPoint("BOTTOM", owner, "TOP", 0, 8)
    elseif anchor == "ANCHOR_BOTTOM" then
        tooltip:SetPoint("TOP", owner, "BOTTOM", 0, -8)
    elseif anchor == "ANCHOR_CURSOR" and type(_G.GetCursorPosition) == "function" then
        local ok, cursorX, cursorY = pcall(_G.GetCursorPosition)
        cursorX = ok and SafeNumber(cursorX, nil) or nil
        cursorY = ok and SafeNumber(cursorY, nil) or nil

        local parentScale = 1
        if UIParent and UIParent.GetEffectiveScale then
            local scaleOk, scale = pcall(UIParent.GetEffectiveScale, UIParent)
            parentScale = scaleOk and SafeNumber(scale, 1) or 1
        end
        if parentScale <= 0 then
            parentScale = 1
        end

        if cursorX ~= nil and cursorY ~= nil then
            tooltip:SetPoint(
                "BOTTOMLEFT",
                UIParent,
                "BOTTOMLEFT",
                (cursorX / parentScale) + 16,
                (cursorY / parentScale) - 8
            )
        else
            tooltip:SetPoint("LEFT", owner, "RIGHT", 8, 0)
        end
    else
        tooltip:SetPoint("LEFT", owner, "RIGHT", 8, 0)
    end
end

local function CreateMainlineTooltip()
    local tooltip = CreateFrame("Frame", nil, UIParent)
    tooltip.isQuestKingTextTooltip = true
    tooltip.lines = {}
    tooltip.lineCount = 0
    tooltip:SetFrameStrata("TOOLTIP")
    tooltip:SetClampedToScreen(true)
    tooltip:SetWidth(MAINLINE_TOOLTIP_WIDTH)

    tooltip.background = tooltip:CreateTexture(nil, "BACKGROUND")
    tooltip.background:SetAllPoints(tooltip)
    tooltip.background:SetColorTexture(0, 0, 0, 0.95)

    tooltip.borderTop = tooltip:CreateTexture(nil, "BORDER")
    tooltip.borderTop:SetPoint("TOPLEFT", tooltip, "TOPLEFT", 0, 0)
    tooltip.borderTop:SetPoint("TOPRIGHT", tooltip, "TOPRIGHT", 0, 0)
    tooltip.borderTop:SetHeight(1)
    tooltip.borderTop:SetColorTexture(0.35, 0.35, 0.35, 1)

    tooltip.borderBottom = tooltip:CreateTexture(nil, "BORDER")
    tooltip.borderBottom:SetPoint("BOTTOMLEFT", tooltip, "BOTTOMLEFT", 0, 0)
    tooltip.borderBottom:SetPoint("BOTTOMRIGHT", tooltip, "BOTTOMRIGHT", 0, 0)
    tooltip.borderBottom:SetHeight(1)
    tooltip.borderBottom:SetColorTexture(0.35, 0.35, 0.35, 1)

    tooltip.borderLeft = tooltip:CreateTexture(nil, "BORDER")
    tooltip.borderLeft:SetPoint("TOPLEFT", tooltip, "TOPLEFT", 0, 0)
    tooltip.borderLeft:SetPoint("BOTTOMLEFT", tooltip, "BOTTOMLEFT", 0, 0)
    tooltip.borderLeft:SetWidth(1)
    tooltip.borderLeft:SetColorTexture(0.35, 0.35, 0.35, 1)

    tooltip.borderRight = tooltip:CreateTexture(nil, "BORDER")
    tooltip.borderRight:SetPoint("TOPRIGHT", tooltip, "TOPRIGHT", 0, 0)
    tooltip.borderRight:SetPoint("BOTTOMRIGHT", tooltip, "BOTTOMRIGHT", 0, 0)
    tooltip.borderRight:SetWidth(1)
    tooltip.borderRight:SetColorTexture(0.35, 0.35, 0.35, 1)

    tooltip.ClearLines = ClearMainlineTooltipLines
    tooltip.AddLine = AddMainlineTooltipLine
    tooltip.AddDoubleLine = AddMainlineTooltipDoubleLine
    tooltip.AddTexture = AddMainlineTooltipTexture
    tooltip.SetText = function(self, text, r, g, b)
        ClearMainlineTooltipLines(self)
        return AddMainlineTooltipLine(self, text, r, g, b, true, true)
    end

    ClearMainlineTooltipLines(tooltip)
    tooltip:Hide()
    return tooltip
end

local function ApplyTooltipVisualStyle(tooltip)
    if not tooltip then
        return
    end

    if tooltip.isQuestKingTextTooltip then
        if tooltip.background then
            tooltip.background:SetColorTexture(0, 0, 0, 0.95)
            tooltip.background:Show()
        end
        return
    end

    if tooltip.NineSlice then
        if tooltip.NineSlice.Show then
            tooltip.NineSlice:Show()
        end

        if tooltip.NineSlice.SetAlpha then
            tooltip.NineSlice:SetAlpha(1)
        end

        local center = tooltip.NineSlice.Center
        if center then
            center:Show()
            center:SetVertexColor(0, 0, 0, 0.95)
        end

        local pieces = {
            "TopLeftCorner",
            "TopRightCorner",
            "BottomLeftCorner",
            "BottomRightCorner",
            "TopEdge",
            "BottomEdge",
            "LeftEdge",
            "RightEdge",
        }

        for index = 1, #pieces do
            local piece = tooltip.NineSlice[pieces[index]]
            if piece and piece.Show then
                piece:Show()
            end
        end

        return
    end

    if tooltip.SetBackdrop then
        tooltip:SetBackdrop(TOOLTIP_BACKDROP)
        if tooltip.SetBackdropColor then
            tooltip:SetBackdropColor(0, 0, 0, 0.95)
        end
        if tooltip.SetBackdropBorderColor then
            tooltip:SetBackdropBorderColor(0.35, 0.35, 0.35, 1)
        end
        return
    end

    if not tooltip.background then
        local background = tooltip:CreateTexture(nil, "BACKGROUND")
        background:SetAllPoints(tooltip)
        background:SetColorTexture(0, 0, 0, 0.95)
        tooltip.background = background
    else
        tooltip.background:SetColorTexture(0, 0, 0, 0.95)
        tooltip.background:Show()
    end
end

local function ClearTooltipTextRegions(tooltip)
    if not tooltip or not tooltip.GetName then
        return
    end

    local name = tooltip:GetName()
    if not name then
        return
    end

    for index = 1, 30 do
        local left = _G[name .. "TextLeft" .. index]
        local right = _G[name .. "TextRight" .. index]

        if left then
            left:SetText("")
        end

        if right then
            right:SetText("")
        end
    end
end

local function HideFrameSafe(frame)
    if frame and frame.Hide then
        pcall(frame.Hide, frame)
    end
end

local function ClearPrivateTooltipMoneyFrames(tooltip)
    if not tooltip or not tooltip.GetName then
        return
    end

    local name = tooltip:GetName()
    if type(name) ~= "string" or name == "" then
        return
    end

    local count = SafeNumber(tooltip.numMoneyFrames, 0) or 0
    local shown = SafeNumber(tooltip.shownMoneyFrames, 0) or 0

    if shown > count then
        count = shown
    end

    if count < 1 then
        count = 4
    end

    for index = 1, count do
        HideFrameSafe(_G[name .. "MoneyFrame" .. index])
    end

    tooltip.shownMoneyFrames = nil
    tooltip.hasMoney = nil
end

local function ClearPrivateTooltipItemState(tooltip)
    if not tooltip then
        return
    end

    HideFrameSafe(tooltip.ItemTooltip)

    if tooltip.ItemTooltip then
        HideFrameSafe(tooltip.ItemTooltip.Tooltip)
        HideFrameSafe(tooltip.ItemTooltip.FollowerTooltip)
    end

    local shoppingTooltips = tooltip.shoppingTooltips
    if type(shoppingTooltips) == "table" then
        for index = 1, #shoppingTooltips do
            HideFrameSafe(shoppingTooltips[index])
        end
    end

    tooltip.suppressAutomaticCompareItem = nil
end

local function ClearTooltipBlizzardState(tooltip)
    if not tooltip then
        return
    end

    -- Do not call Blizzard GameTooltip_Clear* or EmbeddedItemTooltip_* helpers
    -- from QuestKing code. Those helpers are designed for Blizzard's tooltip
    -- pipeline and can make current Retail/Midnight tooltip reward sizing run
    -- under QuestKing-tainted execution. QuestKing owns only QuestKingTooltip,
    -- so keep cleanup local and visual-only.
    ClearPrivateTooltipMoneyFrames(tooltip)
    ClearPrivateTooltipItemState(tooltip)

    if tooltip.ClearHandlerInfo then
        pcall(tooltip.ClearHandlerInfo, tooltip)
    end
end

local function ResetPrivateTooltipState(tooltip)
    if not tooltip then
        return
    end

    if tooltip.Hide then
        tooltip:Hide()
    end

    if tooltip.isQuestKingTextTooltip then
        ClearMainlineTooltipLines(tooltip)
        tooltip:ClearAllPoints()
        tooltip:SetScale(1)
        ApplyTooltipVisualStyle(tooltip)
        return
    end

    ClearTooltipBlizzardState(tooltip)

    if tooltip.ClearLines then
        tooltip:ClearLines()
    end

    ClearTooltipTextRegions(tooltip)

    if tooltip.SetOwner then
        pcall(tooltip.SetOwner, tooltip, UIParent, "ANCHOR_NONE")
    end

    if tooltip.SetScale then
        tooltip:SetScale(1)
    end

    ApplyTooltipVisualStyle(tooltip)
end

local function GetTooltipLineColor(color, defaultR, defaultG, defaultB)
    if color == nil or IsSecretValue(color) then
        return defaultR, defaultG, defaultB
    end

    local ok, r, g, b = pcall(function()
        if type(color.GetRGB) == "function" then
            return color:GetRGB()
        end

        return color.r, color.g, color.b
    end)

    if not ok then
        return defaultR, defaultG, defaultB
    end

    r = SafeNumber(r, defaultR)
    g = SafeNumber(g, defaultG)
    b = SafeNumber(b, defaultB)

    return r, g, b
end

local function AddPrivateTooltipDataLine(tooltip, lineData)
    if not tooltip or type(lineData) ~= "table" or IsSecretValue(lineData) then
        return false
    end

    local leftText = SafeString(lineData.leftText, nil)
    local rightText = SafeString(lineData.rightText, nil)
    local wrapText = SafeBoolean(lineData.wrapText, true)

    if leftText == nil and rightText == nil then
        local lineType = SafeNumber(lineData.type, nil)
        local blankLineType = Enum
            and Enum.TooltipDataLineType
            and Enum.TooltipDataLineType.Blank
            or nil

        if blankLineType == nil or lineType ~= blankLineType then
            return false
        end

        leftText = " "
    end

    leftText = leftText or ""

    local leftR, leftG, leftB = GetTooltipLineColor(
        lineData.leftColor,
        1,
        1,
        1
    )

    if rightText ~= nil and type(tooltip.AddDoubleLine) == "function" then
        local rightR, rightG, rightB = GetTooltipLineColor(
            lineData.rightColor,
            1,
            1,
            1
        )
        local ok, added = pcall(
            tooltip.AddDoubleLine,
            tooltip,
            leftText,
            rightText,
            leftR,
            leftG,
            leftB,
            rightR,
            rightG,
            rightB,
            wrapText
        )
        return ok and added == true
    end

    if type(tooltip.AddLine) ~= "function" then
        return false
    end

    local ok, added = pcall(
        tooltip.AddLine,
        tooltip,
        leftText,
        leftR,
        leftG,
        leftB,
        wrapText
    )
    return ok and added == true
end

local function PopulatePrivateTooltipFromData(tooltip, tooltipData)
    if not IS_MAINLINE
        or not tooltip
        or type(tooltipData) ~= "table"
        or IsSecretValue(tooltipData) then
        return false
    end

    local lines = tooltipData.lines
    if type(lines) ~= "table" or IsSecretValue(lines) then
        return false
    end

    local countOk, lineCount = pcall(function()
        return #lines
    end)
    lineCount = countOk and SafeNumber(lineCount, nil) or nil
    if lineCount == nil or lineCount < 1 then
        return false
    end

    local addedLine = false
    for index = 1, lineCount do
        local ok, added = pcall(function()
            return AddPrivateTooltipDataLine(tooltip, lines[index])
        end)
        if ok and added then
            addedLine = true
        end
    end

    return addedLine
end

local function GetMainlineTooltipData(getterName, ...)
    if not IS_MAINLINE then
        return nil
    end

    local tooltipInfo = _G.C_TooltipInfo
    local getter = tooltipInfo and tooltipInfo[getterName]
    if type(getter) ~= "function" then
        return nil
    end

    local ok, tooltipData = pcall(getter, ...)
    if not ok
        or type(tooltipData) ~= "table"
        or IsSecretValue(tooltipData) then
        return nil
    end

    return tooltipData
end

function QuestKing:PopulatePrivateTooltipFromHyperlink(tooltip, hyperlink)
    hyperlink = SafeString(hyperlink, nil)
    if hyperlink == nil then
        return false
    end

    return PopulatePrivateTooltipFromData(
        tooltip,
        GetMainlineTooltipData("GetHyperlink", hyperlink)
    )
end

function QuestKing:PopulatePrivateTooltipFromItemID(tooltip, itemID)
    itemID = SafeNumber(itemID, nil)
    if itemID == nil or itemID <= 0 then
        return false
    end

    return PopulatePrivateTooltipFromData(
        tooltip,
        GetMainlineTooltipData("GetItemByID", itemID)
    )
end

function QuestKing:PopulatePrivateTooltipFromQuestLogSpecialItem(tooltip, questLogIndex)
    questLogIndex = SafeNumber(questLogIndex, nil)
    if questLogIndex == nil or questLogIndex <= 0 then
        return false
    end

    return PopulatePrivateTooltipFromData(
        tooltip,
        GetMainlineTooltipData("GetQuestLogSpecialItem", questLogIndex)
    )
end

function QuestKing:GetTooltip()
    local tooltip = self.privateTooltip

    if IS_MAINLINE then
        if tooltip and tooltip.isQuestKingTextTooltip then
            ApplyTooltipVisualStyle(tooltip)
            return tooltip
        end

        if tooltip and tooltip.Hide then
            tooltip:Hide()
        end

        tooltip = CreateMainlineTooltip()
        ApplyTooltipVisualStyle(tooltip)
        self.privateTooltip = tooltip
        return tooltip
    end

    if tooltip and tooltip.IsObjectType and tooltip:IsObjectType("GameTooltip") then
        ApplyTooltipVisualStyle(tooltip)
        return tooltip
    end

    tooltip = CreateFrame("GameTooltip", "QuestKingTooltip", UIParent, "GameTooltipTemplate")
    tooltip:SetFrameStrata("TOOLTIP")
    tooltip:SetClampedToScreen(true)

    ApplyTooltipVisualStyle(tooltip)

    self.privateTooltip = tooltip
    return tooltip
end

function QuestKing:PrepareTooltip(owner, anchor)
    if not owner then
        return nil
    end

    local tooltip = self:GetTooltip()
    if not tooltip then
        return nil
    end

    ResetPrivateTooltipState(tooltip)

    local options = GetOptions()
    local tooltipAnchor = anchor or ((options and options.tooltipAnchor) or "ANCHOR_RIGHT")
    if tooltip.isQuestKingTextTooltip then
        AnchorMainlineTooltip(tooltip, owner, tooltipAnchor)
    else
        tooltip:SetOwner(owner, tooltipAnchor)
    end

    if tooltip.ClearLines then
        tooltip:ClearLines()
    end

    local scale = options and options.tooltipScale
    if type(scale) == "number" and scale > 0 and tooltip.SetScale then
        tooltip:SetScale(scale)
    elseif tooltip.SetScale then
        tooltip:SetScale(1)
    end

    ApplyTooltipVisualStyle(tooltip)

    return tooltip
end

function QuestKing:HideTooltip()
    local tooltip = self.privateTooltip
    if not tooltip then
        return
    end

    ResetPrivateTooltipState(tooltip)
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

function QuestKing.GetQuestTaggedTitle(questLogIndex, isBonus)
    local info = SafeGetQuestInfoByIndex(questLogIndex)
    if not info then
        if isBonus then
            return "[0] <Unknown>", 0
        end

        return "[0] <Unknown>"
    end

    local questTitle = SafeString(info.title, "<Unknown>") or "<Unknown>"
    local level = SafeNumber(info.level, 0) or 0
    local suggestedGroup = SafeNumber(info.suggestedGroup, 0) or 0
    local frequency = SafeNumber(info.frequency, nil)
    local questID = SafeNumber(info.questID, nil)

    local questTypeID = SafeGetQuestTypeTag(questID) or 0
    local typeTag = knownTypesTag[questTypeID]

    if typeTag == nil then
        typeTag = format("|cffff00ff(%s)|r", tostring(questTypeID))
    end

    local levelString
    if questTypeID == 1 and suggestedGroup > 1 then
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

    if SafeIsAutoComplete(questLogIndex, questID) and not isBonus then
        levelString = format("%sa", levelString)
    end

    if isBonus then
        questTitle = gsub(questTitle, "^Bonus Objective:%s*", "")
        return format("[%s] %s", levelString, questTitle), level
    end

    return format("[%s] %s", levelString, questTitle)
end

function QuestKing:GetQuestIDForLogIndex(questLogIndex)
    return GetQuestIDForLogIndexCompat(questLogIndex)
end
