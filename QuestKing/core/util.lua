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


local TEXT_WITH_STATE_WIDGET_DEFAULT_WIDTH = 237
local TEXT_WITH_STATE_WIDGET_DEFAULT_HEIGHT = 16
local textWithStateWidgetGuardInstalled = false
local textWithStateWidgetGuardFrame = nil
local originalTextWithStateWidgetSetup = nil

local function SafeFrameMethod(frame, methodName, ...)
    if not frame or type(methodName) ~= "string" then
        return false, nil
    end

    local method = frame[methodName]
    if type(method) ~= "function" then
        return false, nil
    end

    local ok, result = pcall(method, frame, ...)
    if ok then
        return true, result
    end

    return false, nil
end

local function SafeFrameDimension(frame, methodName, fallback)
    local ok, value = SafeFrameMethod(frame, methodName)
    if ok and type(value) == "number" and not IsSecretValue(value) then
        return value
    end

    return fallback
end

local function GetDefaultUIWidgetFontType()
    return (Enum and Enum.UIWidgetFontType and Enum.UIWidgetFontType.Normal) or 0
end

local function GetDefaultUIWidgetTextSizeType()
    return (Enum and Enum.UIWidgetTextSizeType and Enum.UIWidgetTextSizeType.Standard14Pt) or 0
end

local function GetDefaultUIWidgetHAlignType()
    return (Enum and Enum.WidgetTextHorizontalAlignmentType and Enum.WidgetTextHorizontalAlignmentType.Left) or 0
end

local function EstimateTextWithStateWidgetHeight(textSizeType)
    local sizeEnum = Enum and Enum.UIWidgetTextSizeType
    if not sizeEnum then
        return TEXT_WITH_STATE_WIDGET_DEFAULT_HEIGHT
    end

    if textSizeType == sizeEnum.Small10Pt then
        return 12
    elseif textSizeType == sizeEnum.Small11Pt then
        return 13
    elseif textSizeType == sizeEnum.Small12Pt then
        return 14
    elseif textSizeType == sizeEnum.Medium16Pt then
        return 18
    elseif textSizeType == sizeEnum.Medium18Pt then
        return 20
    elseif textSizeType == sizeEnum.Large20Pt then
        return 22
    elseif textSizeType == sizeEnum.Large24Pt then
        return 26
    elseif textSizeType == sizeEnum.Huge27Pt then
        return 30
    end

    return TEXT_WITH_STATE_WIDGET_DEFAULT_HEIGHT
end

local function GetSafeUIWidgetScale(widgetScale)
    widgetScale = SafeNumber(widgetScale, nil)

    local scaleEnum = Enum and Enum.UIWidgetScale
    if not scaleEnum then
        return 1
    end

    if widgetScale == scaleEnum.Ninty then
        return 0.9
    elseif widgetScale == scaleEnum.Eighty then
        return 0.8
    elseif widgetScale == scaleEnum.Seventy then
        return 0.7
    elseif widgetScale == scaleEnum.Sixty then
        return 0.6
    elseif widgetScale == scaleEnum.Fifty then
        return 0.5
    elseif widgetScale == scaleEnum.OneHundredTen then
        return 1.1
    elseif widgetScale == scaleEnum.OneHundredTwenty then
        return 1.2
    elseif widgetScale == scaleEnum.OneHundredThirty then
        return 1.3
    elseif widgetScale == scaleEnum.OneHundredForty then
        return 1.4
    elseif widgetScale == scaleEnum.OneHundredFifty then
        return 1.5
    elseif widgetScale == scaleEnum.OneHundredSixty then
        return 1.6
    elseif widgetScale == scaleEnum.OneHundredSeventy then
        return 1.7
    elseif widgetScale == scaleEnum.OneHundredEighty then
        return 1.8
    elseif widgetScale == scaleEnum.OneHundredNinety then
        return 1.9
    elseif widgetScale == scaleEnum.TwoHundred then
        return 2
    end

    return 1
end

local function ClampWidgetPadding(value, textHeight)
    value = SafeNumber(value, 0) or 0

    if value < 0 then
        value = 0
    end

    local maximum = (textHeight or TEXT_WITH_STATE_WIDGET_DEFAULT_HEIGHT) - 1
    if maximum < 0 then
        maximum = 0
    end

    if value > maximum then
        value = maximum
    end

    return value
end

local function SetupTextWithStateWidgetBaseFallback(widget, widgetInfo, widgetContainer)
    SafeFrameMethod(widget, "SetScale", GetSafeUIWidgetScale(widgetInfo and widgetInfo.widgetScale))

    if widget.SetTooltip then
        SafeFrameMethod(widget, "SetTooltip", SafeString(widgetInfo and widgetInfo.tooltip, ""))
    end

    widget.disableTooltip = widgetContainer and widgetContainer.disableWidgetTooltips and true or false

    if widget.SetTooltipLocation then
        SafeFrameMethod(widget, "SetTooltipLocation", SafeNumber(widgetInfo and widgetInfo.tooltipLoc, 0) or 0)
    end

    if widget.UpdateMouseEnabled then
        SafeFrameMethod(widget, "UpdateMouseEnabled")
    end

    widget.widgetContainer = widgetContainer
    widget.orderIndex = SafeNumber(widgetInfo and widgetInfo.orderIndex, 0) or 0
    widget.layoutDirection = SafeNumber(widgetInfo and widgetInfo.layoutDirection, 0) or 0

    if widget.AnimIn then
        SafeFrameMethod(widget, "AnimIn")
    else
        SafeFrameMethod(widget, "Show")
    end
end

local function SetupTextWithStateWidgetTextFallback(widget, widgetInfo)
    local textRegion = widget and widget.Text
    if not textRegion then
        return
    end

    local widgetSizeSetting = SafeNumber(widgetInfo and widgetInfo.widgetSizeSetting, 0) or 0
    local fontType = SafeNumber(widgetInfo and widgetInfo.fontType, GetDefaultUIWidgetFontType()) or GetDefaultUIWidgetFontType()
    local textSizeType = SafeNumber(widgetInfo and widgetInfo.textSizeType, GetDefaultUIWidgetTextSizeType()) or GetDefaultUIWidgetTextSizeType()
    local enabledState = SafeNumber(widgetInfo and widgetInfo.enabledState, nil)
    local hAlign = SafeNumber(widgetInfo and widgetInfo.hAlign, GetDefaultUIWidgetHAlignType()) or GetDefaultUIWidgetHAlignType()
    local text = SafeString(widgetInfo and widgetInfo.text, "")

    if widgetSizeSetting > 0 then
        SafeFrameMethod(textRegion, "SetWidth", widgetSizeSetting)
    else
        SafeFrameMethod(textRegion, "SetWidth", 0)
    end

    if textRegion.Setup then
        local ok = pcall(textRegion.Setup, textRegion, text, fontType, textSizeType, enabledState, hAlign)
        if not ok then
            SafeFrameMethod(textRegion, "SetText", text)
        end
    else
        SafeFrameMethod(textRegion, "SetText", text)
    end

    if widget.fontColor and textRegion.SetTextColor and widget.fontColor.GetRGB then
        local ok, r, g, b = pcall(widget.fontColor.GetRGB, widget.fontColor)
        if ok then
            pcall(textRegion.SetTextColor, textRegion, r, g, b)
        end
    end

    local widgetWidth = widgetSizeSetting
    if widgetWidth <= 0 then
        widgetWidth = SafeFrameDimension(textRegion, "GetStringWidth", TEXT_WITH_STATE_WIDGET_DEFAULT_WIDTH)
        if not widgetWidth or widgetWidth <= 0 then
            widgetWidth = TEXT_WITH_STATE_WIDGET_DEFAULT_WIDTH
        end
    end

    SafeFrameMethod(widget, "SetWidth", widgetWidth)

    local estimatedHeight = EstimateTextWithStateWidgetHeight(textSizeType)
    local textHeight = SafeFrameDimension(textRegion, "GetStringHeight", estimatedHeight)
    if not textHeight or textHeight <= 0 then
        textHeight = estimatedHeight
    end

    local bottomPadding = ClampWidgetPadding(widgetInfo and widgetInfo.bottomPadding, textHeight)
    SafeFrameMethod(widget, "SetHeight", textHeight + bottomPadding)
end

local function SetupTextWithStateWidgetFallback(widget, widgetInfo, widgetContainer)
    if not widget or type(widgetInfo) ~= "table" then
        return
    end

    SetupTextWithStateWidgetBaseFallback(widget, widgetInfo, widgetContainer)
    SetupTextWithStateWidgetTextFallback(widget, widgetInfo)
end

local function QuestKingTextWithStateWidgetSetup(widget, widgetInfo, widgetContainer)
    if originalTextWithStateWidgetSetup then
        local ok = pcall(originalTextWithStateWidgetSetup, widget, widgetInfo, widgetContainer)
        if ok then
            return
        end
    end

    SetupTextWithStateWidgetFallback(widget, widgetInfo, widgetContainer)
end

local function TryInstallTextWithStateWidgetGuard()
    if textWithStateWidgetGuardInstalled or not IS_MAINLINE then
        return textWithStateWidgetGuardInstalled
    end

    local mixin = _G.UIWidgetTemplateTextWithStateMixin
    if type(mixin) ~= "table" or type(mixin.Setup) ~= "function" then
        return false
    end

    if mixin._QuestKingTextWithStateWidgetGuard then
        textWithStateWidgetGuardInstalled = true
        return true
    end

    originalTextWithStateWidgetSetup = mixin.Setup
    mixin.Setup = QuestKingTextWithStateWidgetSetup
    mixin._QuestKingTextWithStateWidgetGuard = true
    textWithStateWidgetGuardInstalled = true
    return true
end

local function InstallTextWithStateWidgetGuard()
    if not IS_MAINLINE or TryInstallTextWithStateWidgetGuard() then
        return
    end

    if textWithStateWidgetGuardFrame then
        return
    end

    textWithStateWidgetGuardFrame = CreateFrame("Frame")

    if textWithStateWidgetGuardFrame.RegisterEvent then
        pcall(textWithStateWidgetGuardFrame.RegisterEvent, textWithStateWidgetGuardFrame, "ADDON_LOADED")
        pcall(textWithStateWidgetGuardFrame.RegisterEvent, textWithStateWidgetGuardFrame, "PLAYER_LOGIN")
    end

    textWithStateWidgetGuardFrame:SetScript("OnEvent", function(frame, eventName, loadedAddonName)
        if eventName == "PLAYER_LOGIN" or loadedAddonName == "Blizzard_UIWidgets" then
            if TryInstallTextWithStateWidgetGuard() and frame.UnregisterAllEvents then
                frame:UnregisterAllEvents()
            end
        end
    end)

    if _G.C_Timer and _G.C_Timer.After then
        _G.C_Timer.After(0, TryInstallTextWithStateWidgetGuard)
        _G.C_Timer.After(1, TryInstallTextWithStateWidgetGuard)
    end
end

QuestKing.InstallTextWithStateWidgetGuard = InstallTextWithStateWidgetGuard
InstallTextWithStateWidgetGuard()


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

local function RegisterEventSafe(frame, eventName)
    if not frame or type(eventName) ~= "string" or eventName == "" then
        return false
    end

    local ok = pcall(frame.RegisterEvent, frame, eventName)
    return ok and true or false
end

local function HookMethodSafe(target, methodName, callback)
    if not target or type(methodName) ~= "string" or type(callback) ~= "function" or not hooksecurefunc then
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

local function CanSafelySuppressBlizzardTracker()
    -- Classic-family clients still tolerate direct visual suppression of the
    -- legacy tracker much better than Mainline.
    return IS_CLASSIC_FAMILY
end

local function ShouldHideBlizzardTracker()
    local options = GetOptions()
    return options and options.disableBlizzard and true or false
end

local function ShouldUseRetailTrackerCloak()
    return IS_MAINLINE and ShouldHideBlizzardTracker()
end

local function GetBlizzardTrackerRootFrames()
    return {
        _G.ObjectiveTrackerFrame,
        _G.ObjectiveTrackerFrame and _G.ObjectiveTrackerFrame.BlocksFrame or nil,
        _G.ObjectiveTrackerBlocksFrame,
        _G.ScenarioBlocksFrame,
        _G.WatchFrame,
    }
end

local function ApplySuppressionToTrackerRoot(frame, hide)
    if not frame then
        return
    end

    SafeSetIgnoreParentAlpha(frame, false)
    SafeSetAlpha(frame, hide and 0 or 1)
    SafeEnableMouse(frame, not hide)
end

local function ApplyRetailTrackerCloak(frame, hide)
    if not frame then
        return
    end

    -- Do not toggle mouse propagation/click handling on Mainline managed frames.
    -- Just visually cloak the tracker root and its known art/text containers.
    SafeSetIgnoreParentAlpha(frame, false)
    SafeSetAlpha(frame, hide and 0 or 1)

    if frame.BlocksFrame then
        SafeSetIgnoreParentAlpha(frame.BlocksFrame, false)
        SafeSetAlpha(frame.BlocksFrame, hide and 0 or 1)
    end

    if frame.HeaderMenu then
        SafeSetIgnoreParentAlpha(frame.HeaderMenu, false)
        SafeSetAlpha(frame.HeaderMenu, hide and 0 or 1)
    end

    if frame.Background then
        SafeSetIgnoreParentAlpha(frame.Background, false)
        SafeSetAlpha(frame.Background, hide and 0 or 1)
    end
end

local function ApplyBlizzardTrackerVisualState()
    local hide = ShouldHideBlizzardTracker()

    if ShouldUseRetailTrackerCloak() then
        if type(_G.InCombatLockdown) == "function" and _G.InCombatLockdown() then
            return
        end

        ApplyRetailTrackerCloak(_G.ObjectiveTrackerFrame, hide)
        return
    end

    local trackerFrames = GetBlizzardTrackerRootFrames()

    for index = 1, #trackerFrames do
        ApplySuppressionToTrackerRoot(trackerFrames[index], hide)
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

local function OnTrackerVisualStateEvent()
    RequestBlizzardTrackerVisualRefresh()
end

local function RegisterTrackerVisualStateEvents()
    if trackerVisualEventsRegistered then
        return
    end

    trackerVisualEventsRegistered = true

    trackerVisualStateFrame:SetScript("OnEvent", OnTrackerVisualStateEvent)

    RegisterEventSafe(trackerVisualStateFrame, "PLAYER_ENTERING_WORLD")
    RegisterEventSafe(trackerVisualStateFrame, "DISPLAY_SIZE_CHANGED")
    RegisterEventSafe(trackerVisualStateFrame, "UI_SCALE_CHANGED")
    RegisterEventSafe(trackerVisualStateFrame, "EDIT_MODE_LAYOUTS_UPDATED")
    RegisterEventSafe(trackerVisualStateFrame, "PLAYER_REGEN_ENABLED")
end

local function InstallTrackerVisualHooks()
    if trackerVisualHooksInstalled then
        return
    end

    if ShouldUseRetailTrackerCloak() then
        trackerVisualHooksInstalled = true
        return
    end

    local hookedAnything = false

    if HookMethodSafe(_G.ObjectiveTrackerFrame, "Show", RequestBlizzardTrackerVisualRefresh) then
        hookedAnything = true
    end

    if _G.WatchFrame and _G.WatchFrame ~= _G.ObjectiveTrackerFrame then
        if HookMethodSafe(_G.WatchFrame, "Show", RequestBlizzardTrackerVisualRefresh) then
            hookedAnything = true
        end
    end

    if HookGlobalSafe("ObjectiveTracker_Update", RequestBlizzardTrackerVisualRefresh) then
        hookedAnything = true
    end

    if HookGlobalSafe("BonusObjectiveTracker_Update", RequestBlizzardTrackerVisualRefresh) then
        hookedAnything = true
    end

    if HookGlobalSafe("ScenarioObjectiveTracker_Update", RequestBlizzardTrackerVisualRefresh) then
        hookedAnything = true
    end

    if HookGlobalSafe("WatchFrame_Update", RequestBlizzardTrackerVisualRefresh) then
        hookedAnything = true
    end

    if _G.ObjectiveTrackerManager and _G.ObjectiveTrackerManager.Update then
        if HookMethodSafe(_G.ObjectiveTrackerManager, "Update", RequestBlizzardTrackerVisualRefresh) then
            hookedAnything = true
        end
    end

    trackerVisualHooksInstalled = hookedAnything
end

function QuestKing:DisableBlizzard()
    if not ShouldHideBlizzardTracker() then
        return
    end

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

local function ClearTooltipBlizzardState(tooltip)
    if not tooltip then
        return
    end

    if type(_G.SharedTooltip_ClearInsertedFrames) == "function" then
        pcall(_G.SharedTooltip_ClearInsertedFrames, tooltip)
    end

    if type(_G.GameTooltip_ClearMoney) == "function" then
        pcall(_G.GameTooltip_ClearMoney, tooltip)
    end

    if type(_G.GameTooltip_ClearStatusBars) == "function" then
        pcall(_G.GameTooltip_ClearStatusBars, tooltip)
    end

    if type(_G.GameTooltip_ClearStatusBarWatch) == "function" then
        pcall(_G.GameTooltip_ClearStatusBarWatch, tooltip)
    end

    if type(_G.GameTooltip_ClearProgressBars) == "function" then
        pcall(_G.GameTooltip_ClearProgressBars, tooltip)
    end

    if type(_G.GameTooltip_ClearWidgetSet) == "function" then
        pcall(_G.GameTooltip_ClearWidgetSet, tooltip)
    end

    if _G.TooltipComparisonManager and _G.TooltipComparisonManager.Clear then
        pcall(_G.TooltipComparisonManager.Clear, _G.TooltipComparisonManager, tooltip)
    end

    if tooltip.ItemTooltip then
        if type(_G.EmbeddedItemTooltip_Hide) == "function" then
            pcall(_G.EmbeddedItemTooltip_Hide, tooltip.ItemTooltip)
        elseif tooltip.ItemTooltip.Hide then
            tooltip.ItemTooltip:Hide()
        end
    end

    if tooltip.ClearHandlerInfo then
        pcall(tooltip.ClearHandlerInfo, tooltip)
    end

    if tooltip.ClearPadding then
        pcall(tooltip.ClearPadding, tooltip)
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
