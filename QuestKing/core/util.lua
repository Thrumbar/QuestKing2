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
local WOW_PROJECT_CATACLYSM_CLASSIC = _G.WOW_PROJECT_CATACLYSM_CLASSIC

local IS_MAINLINE = WOW_PROJECT_MAINLINE and WOW_PROJECT_ID == WOW_PROJECT_MAINLINE or false
local IS_CLASSIC_ERA = WOW_PROJECT_CLASSIC and WOW_PROJECT_ID == WOW_PROJECT_CLASSIC or false
local IS_CATACLYSM_CLASSIC = WOW_PROJECT_CATACLYSM_CLASSIC and WOW_PROJECT_ID == WOW_PROJECT_CATACLYSM_CLASSIC or false
local IS_CLASSIC_FAMILY = IS_CLASSIC_ERA or IS_CATACLYSM_CLASSIC

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

local trackerVisualHooksInstalled = false
local trackerVisualEventsRegistered = false
local trackerVisualRefreshQueued = false
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
QuestKing.IsCataclysmClassic = IS_CATACLYSM_CLASSIC
QuestKing.IsClassicFamily = IS_CLASSIC_FAMILY


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

    The safe fix is isolation: QuestKing only sanitizes values it owns and only
    styles its own private tooltip. Blizzard's GameTooltip, map POI tooltips,
    widget setup, and embedded reward tooltip sizing are left to Blizzard code.
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
                isCampaign = SafeBoolean(info.isCampaign, false),
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
        local ok, title, level, suggestedGroup, _, isHeader, _, frequency, questID, startEvent =
            pcall(_G.GetQuestLogTitle, questLogIndex)
        if ok then
            return {
                title = SafeString(title, _G.UNKNOWN or "<Unknown>"),
                level = SafeNumber(level, 0) or 0,
                suggestedGroup = SafeNumber(suggestedGroup, 0) or 0,
                frequency = SafeNumber(frequency, nil),
                questID = SafeNumber(questID, nil),
                isHeader = SafeBoolean(isHeader, false),
                isHidden = false,
                isTask = false,
                campaignID = 0,
                isCampaign = false,
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
    if type(questID) == "number" and CQL and CQL.IsAutoComplete then
        local ok, isAutoComplete = pcall(CQL.IsAutoComplete, questID)
        if ok then
            return isAutoComplete and true or false
        end
    end

    if type(questLogIndex) == "number" and type(_G.GetQuestLogIsAutoComplete) == "function" then
        local ok, isAutoComplete = pcall(_G.GetQuestLogIsAutoComplete, questLogIndex)
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

local function OnTrackerVisualStateEvent()
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

    if C_Timer and C_Timer.After then
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

local function ApplyTooltipVisualStyle(tooltip)
    if not tooltip then
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

function QuestKing:GetTooltip()
    local tooltip = self.privateTooltip
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
    tooltip:SetOwner(owner, anchor or ((options and options.tooltipAnchor) or "ANCHOR_RIGHT"))

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
