-- core/autocomplete.lua
-- QuestKing2 = Reborn
--
-- Purpose:
--   Make a normal left-click on a QuestKing tracked quest row behave like the
--   Blizzard Objective Tracker for ready-to-complete / autocomplete quests.
--
-- Why this exists:
--   QuestKing replaces Blizzard's tracker. Blizzard's tracker checks whether a
--   quest is autocomplete + complete before opening normal quest details. If it
--   is ready, Blizzard calls ShowQuestComplete(questID) on Retail/Mainline.
--   Classic-family clients generally need ShowQuestComplete(questLogIndex).
--
--   ReadyForTurnIn alone is not enough: ordinary NPC turn-ins also report that
--   state. Field completion is routed through the shared compatibility contract.
--
-- Lua 5.1 compatible.

local addonName, addonTable = ...

local QuestKing = _G.QuestKing
if type(QuestKing) ~= "table" then
    if type(addonTable) == "table" then
        QuestKing = addonTable
    else
        QuestKing = {}
    end
    _G.QuestKing = QuestKing
end

local AutoComplete = QuestKing.AutoComplete
if type(AutoComplete) ~= "table" then
    AutoComplete = {}
    QuestKing.AutoComplete = AutoComplete
end

local CommonCompat = QuestKing.Compatibility and QuestKing.Compatibility.Common or {}

local frame = AutoComplete.EventFrame
if not frame then
    frame = CreateFrame("Frame", "QuestKing_AutoCompleteEventFrame")
    AutoComplete.EventFrame = frame
end

local hooksInstalled = false

local tonumber = tonumber
local tostring = tostring
local type = type
local pcall = pcall
local print = print

local function SafeCall(func, ...)
    if type(func) ~= "function" then
        return false
    end

    return pcall(func, ...)
end

local function RegisterEventSafe(eventName)
    if not eventName then
        return
    end

    SafeCall(frame.RegisterEvent, frame, eventName)
end

local function IsMainlineClient()
    return WOW_PROJECT_ID
        and WOW_PROJECT_MAINLINE
        and WOW_PROJECT_ID == WOW_PROJECT_MAINLINE
end

local function RequestRefresh(forceBuild)
    if type(QuestKing.RecordPerformanceMetric) == "function" then
        QuestKing:RecordPerformanceMetric("autoCompleteRequestCount", 1)
    end

    if type(QuestKing.RequestTrackerUpdate) == "function" then
        QuestKing:RequestTrackerUpdate(false, "autocomplete", false)
        return
    end

    if type(QuestKing.QueueTrackerUpdate) == "function" then
        QuestKing:QueueTrackerUpdate(false, false, "autocomplete")
        return
    end

    if type(QuestKing.UpdateTracker) == "function" then
        QuestKing:UpdateTracker(false, false, "autocomplete")
        return
    end

    if type(QuestKing.RefreshTracker) == "function" then
        QuestKing:RefreshTracker(forceBuild and true or false)
    end
end

local function QueueRefresh(forceBuild)
    RequestRefresh(forceBuild)
end

local function RecordQuestLogFallbackScan()
    if type(QuestKing.RecordPerformanceMetric) == "function" then
        QuestKing:RecordPerformanceMetric("autoCompleteScanCount", 1)
        QuestKing:RecordPerformanceMetric("questLogScanCount", 1)
    end
end

local function GetQuestLogIndexForQuestID(questID)
    questID = tonumber(questID)

    if not questID or questID <= 0 then
        return nil
    end

    if C_QuestLog and type(C_QuestLog.GetLogIndexForQuestID) == "function" then
        local ok, index = pcall(C_QuestLog.GetLogIndexForQuestID, questID)
        if ok and type(index) == "number" and index > 0 then
            return index
        end
    end

    if type(_G.GetQuestLogIndexByID) == "function" then
        local ok, index = pcall(_G.GetQuestLogIndexByID, questID)
        if ok and type(index) == "number" and index > 0 then
            return index
        end
    end

    if C_QuestLog
            and type(C_QuestLog.GetNumQuestLogEntries) == "function"
            and type(C_QuestLog.GetInfo) == "function" then
        local ok, numEntries = pcall(C_QuestLog.GetNumQuestLogEntries)
        if ok and type(numEntries) == "number" then
            RecordQuestLogFallbackScan()
            for index = 1, numEntries do
                local infoOk, info = pcall(C_QuestLog.GetInfo, index)
                if infoOk and type(info) == "table" and info.questID == questID then
                    return index
                end
            end
        end
    end

    if type(_G.GetNumQuestLogEntries) == "function" and type(_G.GetQuestLogTitle) == "function" then
        local numEntries = _G.GetNumQuestLogEntries() or 0
        RecordQuestLogFallbackScan()
        for index = 1, numEntries do
            local ok, title, level, suggestedGroup, isHeader, isCollapsed, isComplete, frequency, id =
                pcall(_G.GetQuestLogTitle, index)

            if ok and not isHeader and id == questID then
                return index
            end
        end
    end

    return nil
end

local function GetQuestIDForQuestLogIndex(questLogIndex)
    questLogIndex = tonumber(questLogIndex)

    if not questLogIndex or questLogIndex <= 0 then
        return nil
    end

    if C_QuestLog and type(C_QuestLog.GetQuestIDForLogIndex) == "function" then
        local ok, questID = pcall(C_QuestLog.GetQuestIDForLogIndex, questLogIndex)
        if ok and type(questID) == "number" and questID > 0 then
            return questID
        end
    end

    if type(_G.GetQuestLogTitle) == "function" then
        local ok, title, level, suggestedGroup, isHeader, isCollapsed, isComplete, frequency, questID =
            pcall(_G.GetQuestLogTitle, questLogIndex)

        if ok and type(questID) == "number" and questID > 0 then
            return questID
        end
    end

    return nil
end

local function GetQuestTitle(questID, questLogIndex)
    questID = tonumber(questID)

    if questID and questID > 0 then
        if C_QuestLog and type(C_QuestLog.GetTitleForQuestID) == "function" then
            local ok, title = pcall(C_QuestLog.GetTitleForQuestID, questID)
            if ok and title and title ~= "" then
                return title
            end
        end
    end

    questLogIndex = tonumber(questLogIndex)
    if questLogIndex and questLogIndex > 0 then
        if C_QuestLog and type(C_QuestLog.GetInfo) == "function" then
            local ok, info = pcall(C_QuestLog.GetInfo, questLogIndex)
            if ok and type(info) == "table" and info.title and info.title ~= "" then
                return info.title
            end
        end

        if type(_G.GetQuestLogTitle) == "function" then
            local ok, title = pcall(_G.GetQuestLogTitle, questLogIndex)
            if ok and title and title ~= "" then
                return title
            end
        end
    end

    if questID then
        return "Quest " .. tostring(questID)
    end

    return "Quest"
end

local function GetQuestInfo(questLogIndex)
    questLogIndex = tonumber(questLogIndex)

    if not questLogIndex or questLogIndex <= 0 then
        return nil
    end

    if C_QuestLog and type(C_QuestLog.GetInfo) == "function" then
        local ok, info = pcall(C_QuestLog.GetInfo, questLogIndex)
        if ok and type(info) == "table" then
            return info
        end
    end

    if type(_G.GetQuestLogTitle) == "function" then
        local ok, title, level, suggestedGroup, isHeader, isCollapsed, isComplete, frequency, questID =
            pcall(_G.GetQuestLogTitle, questLogIndex)

        if ok then
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

local function IsQuestReadyForTurnIn(questID, questLogIndex)
    questID = tonumber(questID)

    if questID and questID > 0 then
        if C_QuestLog and type(C_QuestLog.ReadyForTurnIn) == "function" then
            local ok, ready = pcall(C_QuestLog.ReadyForTurnIn, questID)
            if ok and ready then
                return true
            end
        end

        if C_QuestLog and type(C_QuestLog.IsComplete) == "function" then
            local ok, complete = pcall(C_QuestLog.IsComplete, questID)
            if ok and complete then
                return true
            end
        end
    end

    if not questLogIndex and questID then
        questLogIndex = GetQuestLogIndexForQuestID(questID)
    end

    questLogIndex = tonumber(questLogIndex)
    if questLogIndex and questLogIndex > 0 then
        if type(_G.GetQuestLogIsComplete) == "function" then
            local ok, complete = pcall(_G.GetQuestLogIsComplete, questLogIndex)
            if ok and (complete == true or complete == 1) then
                return true
            end
        end

        local info = GetQuestInfo(questLogIndex)
        if type(info) == "table" and (info.isComplete == true or info.isComplete == 1) then
            return true
        end
    end

    return false
end

local function IsQuestAutoComplete(questID, questLogIndex)
    if type(CommonCompat.IsQuestAutoComplete) == "function" then
        return CommonCompat.IsQuestAutoComplete(questID, questLogIndex) and true or false
    end

    return false
end

local function HasAutoQuestPopUp(questID)
    questID = tonumber(questID)

    if not questID or questID <= 0 then
        return false, nil
    end

    if type(CommonCompat.GetAutoQuestPopupType) == "function" then
        local popupType = CommonCompat.GetAutoQuestPopupType(questID)
        return popupType ~= nil, popupType
    end

    if type(_G.GetNumAutoQuestPopUps) ~= "function" or type(_G.GetAutoQuestPopUp) ~= "function" then
        return false, nil
    end

    local okCount, count = pcall(_G.GetNumAutoQuestPopUps)
    if not okCount or type(count) ~= "number" or count <= 0 then
        return false, nil
    end

    for index = 1, count do
        local ok, popupQuestID, popupType = pcall(_G.GetAutoQuestPopUp, index)
        if ok and popupQuestID == questID then
            return true, popupType
        end
    end

    return false, nil
end

local function GetSpecialQuestItemInfo(questLogIndex)
    questLogIndex = tonumber(questLogIndex)

    if not questLogIndex or questLogIndex <= 0 then
        return nil
    end

    if type(_G.GetQuestLogSpecialItemInfo) ~= "function" then
        return nil
    end

    local ok, itemLink, itemTexture, charges, showWhenComplete = pcall(_G.GetQuestLogSpecialItemInfo, questLogIndex)
    if not ok or (not itemLink and not itemTexture) then
        return nil
    end

    return {
        link = itemLink,
        texture = itemTexture,
        charges = charges,
        showWhenComplete = showWhenComplete and true or false,
    }
end

local function SelectQuest(questID, questLogIndex)
    questID = tonumber(questID)
    questLogIndex = tonumber(questLogIndex)

    if questID and questID > 0 and C_QuestLog and type(C_QuestLog.SetSelectedQuest) == "function" then
        SafeCall(C_QuestLog.SetSelectedQuest, questID)
    end

    if questLogIndex and questLogIndex > 0 and type(_G.SelectQuestLogEntry) == "function" then
        SafeCall(_G.SelectQuestLogEntry, questLogIndex)
    end
end

local function RemoveAutoQuestPopUp(questID)
    questID = tonumber(questID)

    if questID and questID > 0 and type(_G.RemoveAutoQuestPopUp) == "function" then
        SafeCall(_G.RemoveAutoQuestPopUp, questID)
    end
end

local function TryShowQuestComplete(questID, questLogIndex)
    questID = tonumber(questID)

    if not questID or questID <= 0 then
        return false
    end

    if not questLogIndex then
        questLogIndex = GetQuestLogIndexForQuestID(questID)
    end

    if type(CommonCompat.ShowQuestComplete) == "function" then
        return CommonCompat.ShowQuestComplete(questID, questLogIndex) and true or false
    end

    if type(_G.ShowQuestComplete) ~= "function" then
        return false
    end

    SelectQuest(questID, questLogIndex)

    -- Retail/Mainline/Midnight uses questID. Classic-family clients use
    -- questLogIndex. Calling questID first on Classic can open details instead
    -- of the completion panel, so branch instead of guessing.
    if IsMainlineClient() then
        local ok = SafeCall(_G.ShowQuestComplete, questID)
        if ok then
            return true
        end

        if questLogIndex and questLogIndex > 0 then
            ok = SafeCall(_G.ShowQuestComplete, questLogIndex)
            return ok and true or false
        end

        return false
    end

    if questLogIndex and questLogIndex > 0 then
        local ok = SafeCall(_G.ShowQuestComplete, questLogIndex)
        if ok then
            return true
        end
    end

    local ok = SafeCall(_G.ShowQuestComplete, questID)
    return ok and true or false
end

local function OpenQuestFromTracker(questID, questLogIndex)
    questID = tonumber(questID)

    if not questID or questID <= 0 then
        return false
    end

    if not questLogIndex then
        questLogIndex = GetQuestLogIndexForQuestID(questID)
    end

    local hasPopup, popupType = HasAutoQuestPopUp(questID)
    local canCompleteRemotely = type(CommonCompat.CanCompleteQuestRemotely) == "function"
        and CommonCompat.CanCompleteQuestRemotely(questID, questLogIndex)
        or false

    if canCompleteRemotely then
        if TryShowQuestComplete(questID, questLogIndex) then
            if hasPopup and popupType == "COMPLETE" then
                RemoveAutoQuestPopUp(questID)
            end

            QueueRefresh(true)
            return true
        end
    end

    return false
end

QuestKing.OpenQuestFromTracker = OpenQuestFromTracker
QuestKing.ShowQuestCompleteSafe = OpenQuestFromTracker
AutoComplete.OpenQuestFromTracker = OpenQuestFromTracker

local function InstallClickHooks()
    if hooksInstalled then
        return
    end

    -- Normal quest rows route directly through buttons/quest.lua. Replacing the
    -- shared WatchButton prototype would also intercept OFFER popups, bonus
    -- objectives, and modified-click quest links.
    hooksInstalled = true
end

AutoComplete.InstallClickHooks = InstallClickHooks

function AutoComplete:DebugQuest(questID)
    questID = tonumber(questID)

    if not questID or questID <= 0 then
        print("|cffffd100QuestKing AutoComplete:|r usage: /qkauto quest <questID>")
        return
    end

    local questLogIndex = GetQuestLogIndexForQuestID(questID)
    local ready = IsQuestReadyForTurnIn(questID, questLogIndex)
    local auto = IsQuestAutoComplete(questID, questLogIndex)
    local hasPopup, popupType = HasAutoQuestPopUp(questID)
    local specialItem = GetSpecialQuestItemInfo(questLogIndex)

    print("|cffffd100QuestKing AutoComplete:|r", GetQuestTitle(questID, questLogIndex))
    print(" questID=", tostring(questID), " index=", tostring(questLogIndex or 0))
    print(" ready=", tostring(ready), " auto=", tostring(auto), " popup=", tostring(hasPopup), tostring(popupType or ""))
    print(" specialItem=", tostring(specialItem ~= nil), specialItem and tostring(specialItem.link or specialItem.texture or "") or "")
end

function AutoComplete:DebugClickedHooks()
    local WatchButton = QuestKing.WatchButton
    print("|cffffd100QuestKing AutoComplete:|r click hooks installed=", tostring(hooksInstalled))
    print(" WatchButton=", tostring(type(WatchButton)))
    print(" OpenQuestFromTracker=", tostring(type(QuestKing.OpenQuestFromTracker)))
end

SLASH_QUESTKINGAUTOCOMPLETE1 = "/qkauto"
SlashCmdList.QUESTKINGAUTOCOMPLETE = function(message)
    message = message or ""
    local command, value = message:match("^(%S*)%s*(.-)$")
    command = command or ""
    value = value or ""

    if command == "quest" then
        AutoComplete:DebugQuest(tonumber(value))
        return
    end

    if command == "complete" then
        local questID = tonumber(value)
        if questID and questID > 0 then
            if not OpenQuestFromTracker(questID) then
                print("|cffffd100QuestKing AutoComplete:|r could not open completion for quest " .. tostring(questID))
            end
        else
            print("|cffffd100QuestKing AutoComplete:|r usage: /qkauto complete <questID>")
        end
        return
    end

    if command == "hooks" then
        AutoComplete:DebugClickedHooks()
        return
    end

    InstallClickHooks()
    QueueRefresh(true)
    print("|cffffd100QuestKing AutoComplete commands:|r")
    print("/qkauto hooks - verify QuestKing click hooks are installed")
    print("/qkauto quest <questID> - print ready/auto/popup/special-item state")
    print("/qkauto complete <questID> - force-open the native completion dialog")
end

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local loadedAddonName = ...
        if loadedAddonName ~= addonName then
            return
        end

        self:UnregisterEvent("ADDON_LOADED")
        InstallClickHooks()
        return
    end

    QueueRefresh(false)
end)

RegisterEventSafe("ADDON_LOADED")
RegisterEventSafe("QUEST_ITEM_UPDATE")

if type(hooksecurefunc) == "function" then
    -- OFFER popups are inserted directly from QUEST_DETAIL on Mainline and do
    -- not emit QUEST_AUTOCOMPLETE. Hook the mutation itself so both OFFER and
    -- COMPLETE paths reach the coalesced tracker coordinator.
    if type(_G.AddAutoQuestPopUp) == "function" and not AutoComplete.AddAutoQuestPopUpHooked then
        AutoComplete.AddAutoQuestPopUpHooked = true
        hooksecurefunc("AddAutoQuestPopUp", function()
            QueueRefresh(false)
        end)
    end

    if type(_G.RemoveAutoQuestPopUp) == "function" and not AutoComplete.RemoveAutoQuestPopUpHooked then
        AutoComplete.RemoveAutoQuestPopUpHooked = true
        hooksecurefunc("RemoveAutoQuestPopUp", function()
            QueueRefresh(true)
        end)
    end

    if type(_G.UseQuestLogSpecialItem) == "function" and not AutoComplete.UseQuestLogSpecialItemHooked then
        AutoComplete.UseQuestLogSpecialItemHooked = true
        hooksecurefunc("UseQuestLogSpecialItem", function()
            QueueRefresh(true)
        end)
    end
end

InstallClickHooks()
