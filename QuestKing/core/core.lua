local addonName, QuestKing = ...

local Tracker = QuestKing.Tracker or CreateFrame("Frame")
local WatchButton = QuestKing.WatchButton or {}

local _G = _G
local C_QuestLog = C_QuestLog
local C_ContentTracking = C_ContentTracking
local C_Scenario = C_Scenario
local C_Timer = C_Timer
local Enum = Enum

local format = string.format
local tonumber = tonumber
local tostring = tostring
local type = type
local pairs = pairs

local options = QuestKing.options or {}
local colors = (options and options.colors) or {
    TrackerTitlebarText = { 1, 1, 1 },
    TrackerTitlebarTextDimmed = { 0.7, 0.7, 0.7 },
}

local updateStateFrame = CreateFrame("Frame")

local initialized = false
local trackingHooksInstalled = false
local combatUpdateQueued = false
local pendingPlayerLevel = nil

local trackerUpdatePending = false
local trackerUpdatePendingForceBuild = false
local trackerUpdatePendingPostCombat = false
local trackerUpdateFlushQueued = false

local function IsInCombatLockdownSafe()
    return type(_G.InCombatLockdown) == "function" and _G.InCombatLockdown() or false
end

local function SafeCallMethod(target, method, ...)
    if type(target) ~= "table" then
        return false, nil
    end

    local fn = target[method]
    if type(fn) ~= "function" then
        return false, nil
    end

    local ok, result = pcall(fn, target, ...)
    if ok then
        return true, result
    end

    if _G.geterrorhandler then
        _G.geterrorhandler()(result)
    end

    return true, nil
end

local function SafeHookTableMethod(target, methodName, callback)
    if not hooksecurefunc or type(target) ~= "table" or type(methodName) ~= "string" or type(callback) ~= "function" then
        return false
    end

    local method = target[methodName]
    if type(method) ~= "function" then
        return false
    end

    local ok = pcall(hooksecurefunc, target, methodName, callback)
    return ok and true or false
end

local function SafeHookGlobal(functionName, callback)
    if not hooksecurefunc or type(functionName) ~= "string" or functionName == "" or type(callback) ~= "function" then
        return false
    end

    if type(_G[functionName]) ~= "function" then
        return false
    end

    local ok = pcall(hooksecurefunc, functionName, callback)
    return ok and true or false
end

local function GetTrackerModeButton()
    if Tracker and Tracker.modeButton and Tracker.modeButton.label then
        return Tracker.modeButton
    end

    return _G.QuestKing_TrackerModeButton
end

local function GetTrackerMinimizeButton()
    if Tracker and Tracker.minimizeButton and Tracker.minimizeButton.label then
        return Tracker.minimizeButton
    end

    return _G.QuestKing_TrackerMinimizeButton
end

local function SetModeButtonCombatColor(inCombat)
    local modeButton = GetTrackerModeButton()
    if not (modeButton and modeButton.label and modeButton.label.SetTextColor) then
        return
    end

    if inCombat then
        modeButton.label:SetTextColor(1, 0, 0)
        return
    end

    local normalColor = colors.TrackerTitlebarText or { 1, 1, 1 }
    modeButton.label:SetTextColor(normalColor[1] or 1, normalColor[2] or 1, normalColor[3] or 1)
end

local function MarkQuestFresh(questID)
    if type(questID) ~= "number" or questID <= 0 then
        return
    end

    QuestKing.newlyAddedQuests = QuestKing.newlyAddedQuests or {}
    QuestKing.newlyAddedQuests[questID] = true
end

local function ResolveQuestIDFromIndexOrID(value)
    if type(value) ~= "number" or value <= 0 then
        return nil
    end

    if C_QuestLog and C_QuestLog.GetLogIndexForQuestID then
        local ok, questLogIndex = pcall(C_QuestLog.GetLogIndexForQuestID, value)
        if ok and type(questLogIndex) == "number" and questLogIndex > 0 then
            return value
        end
    end

    if C_QuestLog and C_QuestLog.GetQuestIDForLogIndex then
        local ok, questID = pcall(C_QuestLog.GetQuestIDForLogIndex, value)
        if ok and type(questID) == "number" and questID > 0 then
            return questID
        end
    end

    if C_QuestLog and C_QuestLog.GetInfo then
        local ok, info = pcall(C_QuestLog.GetInfo, value)
        if ok and type(info) == "table" and type(info.questID) == "number" and info.questID > 0 then
            return info.questID
        end
    end

    if type(_G.GetQuestLogTitle) == "function" then
        local ok, _, _, _, _, _, _, _, questID = pcall(_G.GetQuestLogTitle, value)
        if ok and type(questID) == "number" and questID > 0 then
            return questID
        end
    end

    return nil
end

local function GetTrackedAchievementCount()
    if QuestKing.SyncTrackedAchievementCacheFromAPIs then
        local _, cache = SafeCallMethod(QuestKing, "SyncTrackedAchievementCacheFromAPIs")
        local count = 0

        if type(cache) == "table" then
            for achievementID, tracked in pairs(cache) do
                if tracked and type(achievementID) == "number" then
                    count = count + 1
                end
            end
        end

        return count
    end

    if type(QuestKing.trackedAchievements) == "table" then
        local count = 0
        for achievementID, tracked in pairs(QuestKing.trackedAchievements) do
            if tracked and type(achievementID) == "number" then
                count = count + 1
            end
        end
        return count
    end

    return 0
end

local function GetMaxQuests()
    if C_QuestLog and C_QuestLog.GetMaxNumQuests then
        local ok, count = pcall(C_QuestLog.GetMaxNumQuests)
        if ok and type(count) == "number" and count > 0 then
            return count
        end
    end

    return _G.MAX_QUESTS or 25
end

local function GetNumQuestWatches()
    if C_QuestLog and C_QuestLog.GetNumQuestWatches then
        local ok, count = pcall(C_QuestLog.GetNumQuestWatches)
        if ok and type(count) == "number" then
            return count
        end
    end

    if type(_G.GetNumQuestWatches) == "function" then
        local ok, count = pcall(_G.GetNumQuestWatches)
        if ok and type(count) == "number" then
            return count
        end
    end

    return 0
end

local function GetQuestLogCounts()
    if C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo then
        local ok, totalEntries = pcall(C_QuestLog.GetNumQuestLogEntries)
        if ok and type(totalEntries) == "number" and totalEntries >= 0 then
            local totalQuests = 0

            for questLogIndex = 1, totalEntries do
                local okInfo, info = pcall(C_QuestLog.GetInfo, questLogIndex)
                if okInfo and type(info) == "table" and not info.isHeader and not info.isHidden then
                    totalQuests = totalQuests + 1
                end
            end

            return totalEntries, totalQuests
        end
    end

    if type(_G.GetNumQuestLogEntries) == "function" then
        local ok, lines, quests = pcall(_G.GetNumQuestLogEntries)
        if ok then
            return tonumber(lines) or 0, tonumber(quests) or 0
        end
    end

    return 0, 0
end

local function RefreshTrackedAchievementCacheOrUpdate()
    if QuestKing.QueueAchievementTrackerRefresh then
        SafeCallMethod(QuestKing, "QueueAchievementTrackerRefresh")
        return
    end

    SafeCallMethod(QuestKing, "QueueTrackerUpdate", true)
end

local function UpdateMinimizeButtonLabel(trackerCollapsed)
    local button = GetTrackerMinimizeButton()
    if not (button and button.label and button.label.SetText) then
        return
    end

    if trackerCollapsed == 2 then
        button.label:SetText("x")
    elseif trackerCollapsed == 1 then
        button.label:SetText("+")
    else
        button.label:SetText("-")
    end
end

local function UpdateModeButtonLabel(displayMode)
    local button = GetTrackerModeButton()
    if not (button and button.label and button.label.SetText) then
        return
    end

    if displayMode == "combined" then
        button.label:SetText("C")
    elseif displayMode == "achievements" then
        button.label:SetText("A")
    elseif displayMode == "raids" then
        button.label:SetText("R")
    else
        button.label:SetText("Q")
    end
end

local function GetScenarioTrackerState()
    local shouldShowScenarioTracker = false

    if QuestKing.ShouldShowScenarioTracker then
        local _, value = SafeCallMethod(QuestKing, "ShouldShowScenarioTracker")
        shouldShowScenarioTracker = value and true or false
    elseif C_Scenario and C_Scenario.IsInScenario then
        local ok, isInScenario = pcall(C_Scenario.IsInScenario)
        shouldShowScenarioTracker = ok and isInScenario and true or false
    end

    if not shouldShowScenarioTracker then
        return false, false
    end

    if type(_G.GetInstanceInfo) == "function" then
        local ok, _, instanceType = pcall(_G.GetInstanceInfo)
        if ok then
            return true, instanceType == "raid"
        end
    end

    return true, false
end

local function UpdateTrackerTitleText(displayMode, numAchievements, numWatches, totalQuests, maxQuests, numRaidBlocks)
    if not (Tracker and Tracker.titlebarText and Tracker.titlebarText.SetText and Tracker.titlebarText.SetTextColor) then
        return
    end

    local normalColor = colors.TrackerTitlebarText or { 1, 1, 1 }
    local dimmedColor = colors.TrackerTitlebarTextDimmed or { 0.7, 0.7, 0.7 }
    local isDimmed = false

    numAchievements = tonumber(numAchievements) or 0
    numWatches = tonumber(numWatches) or 0
    totalQuests = tonumber(totalQuests) or 0
    maxQuests = tonumber(maxQuests) or 0
    numRaidBlocks = tonumber(numRaidBlocks) or 0

    if displayMode == "combined" then
        if numAchievements > 0 then
            Tracker.titlebarText:SetText(format("%d/%d | %d", totalQuests, maxQuests, numAchievements))
        else
            Tracker.titlebarText:SetText(format("%d/%d", totalQuests, maxQuests))
        end

        isDimmed = (numWatches == 0 and numAchievements == 0 and numRaidBlocks == 0)
    elseif displayMode == "achievements" then
        Tracker.titlebarText:SetText(tostring(numAchievements))
        isDimmed = numAchievements == 0
    elseif displayMode == "raids" then
        Tracker.titlebarText:SetText(tostring(numRaidBlocks))
        isDimmed = numRaidBlocks == 0
    else
        Tracker.titlebarText:SetText(format("%d/%d", totalQuests, maxQuests))
        isDimmed = numWatches == 0
    end

    local color = isDimmed and dimmedColor or normalColor
    Tracker.titlebarText:SetTextColor(color[1] or 1, color[2] or 1, color[3] or 1)
end

local function LayoutRequestedButtons(postCombat)
    local requestOrder = WatchButton.requestOrder or {}
    local requestCount = WatchButton.requestCount or 0
    local lastShown = nil

    for index = 1, requestCount do
        local button = requestOrder[index]
        if button and button.ClearAllPoints and button.SetPoint and button.Render then
            button:ClearAllPoints()

            if not lastShown then
                if Tracker and Tracker.titlebar then
                    button:SetPoint("TOPLEFT", Tracker.titlebar, "BOTTOMLEFT", 0, -1)
                end
            elseif button.type == "header" or button.type == "collapser" then
                button:SetPoint("TOPLEFT", lastShown, "BOTTOMLEFT", 0, -4)
            elseif lastShown.type == "header" or lastShown.type == "collapser" then
                button:SetPoint("TOPLEFT", lastShown, "BOTTOMLEFT", 0, -3)
            else
                button:SetPoint("TOPLEFT", lastShown, "BOTTOMLEFT", 0, -2)
            end

            button:Render()
            lastShown = button
        end
    end

    if postCombat and WatchButton.freePool then
        for index = 1, #WatchButton.freePool do
            local button = WatchButton.freePool[index]
            if button and button.itemButton and button.RemoveItemButton then
                button:RemoveItemButton()
            end
        end
    end

    if WatchButton.FreeUnused then
        WatchButton:FreeUnused()
    end

    if Tracker and Tracker.Resize then
        Tracker:Resize(lastShown)
    end
end

local function RunTrackerUpdate(forceBuild, postCombat)
    if not postCombat and IsInCombatLockdownSafe() then
        QuestKing:StartCombatTimer()
        return
    end

    SafeCallMethod(QuestKing, "CheckQuestSortTable", forceBuild)
    QuestKing.watchMoney = false

    SafeCallMethod(QuestKing, "PreCheckQuestTracking")

    if WatchButton.StartOrder then
        WatchButton:StartOrder()
    end

    local trackerDB = _G.QuestKingDBPerChar or {}
    local trackerCollapsed = trackerDB.trackerCollapsed or 0
    local displayMode = trackerDB.displayMode or "combined"

    UpdateMinimizeButtonLabel(trackerCollapsed)

    local hasScenarioTracker, isRaidScenario = GetScenarioTrackerState()
    local numRaidBlocks = isRaidScenario and 1 or 0

    if trackerCollapsed <= 1 then
        SafeCallMethod(QuestKing, "UpdateTrackerPopups")
        SafeCallMethod(QuestKing, "UpdateTrackerChallengeTimers")

        local showScenarioBlock = false
        local showBonusObjectives = false

        if displayMode == "combined" then
            showScenarioBlock = hasScenarioTracker
            showBonusObjectives = true
        elseif displayMode == "quests" then
            showScenarioBlock = hasScenarioTracker and (not isRaidScenario)
            showBonusObjectives = true
        elseif displayMode == "raids" then
            showScenarioBlock = hasScenarioTracker and isRaidScenario
            showBonusObjectives = false
        elseif displayMode == "achievements" then
            showScenarioBlock = false
            showBonusObjectives = false
        else
            showScenarioBlock = hasScenarioTracker
            showBonusObjectives = true
        end

        if showScenarioBlock then
            SafeCallMethod(QuestKing, "UpdateTrackerScenarios")
        end

        if showBonusObjectives then
            SafeCallMethod(QuestKing, "UpdateTrackerBonusObjectives")
        end
    end

    if trackerCollapsed == 0 then
        if displayMode == "combined" or displayMode == "achievements" then
            SafeCallMethod(QuestKing, "UpdateTrackerAchievements")
        end

        if displayMode == "combined" or displayMode == "quests" then
            SafeCallMethod(QuestKing, "UpdateTrackerQuests")
        end
    end

    local numAchievements = GetTrackedAchievementCount()
    local numWatches = GetNumQuestWatches()
    local _, totalQuests = GetQuestLogCounts()
    local maxQuests = GetMaxQuests()

    UpdateModeButtonLabel(displayMode)
    UpdateTrackerTitleText(displayMode, numAchievements, numWatches, totalQuests, maxQuests, numRaidBlocks)

    LayoutRequestedButtons(postCombat)

    SafeCallMethod(QuestKing, "PostCheckQuestTracking")

    local hooks = QuestKing.updateHooks or {}
    for index = 1, #hooks do
        local fn = hooks[index]
        if type(fn) == "function" then
            pcall(fn)
        end
    end

    if QuestKing.RequestBlizzardTrackerVisualRefresh then
        SafeCallMethod(QuestKing, "RequestBlizzardTrackerVisualRefresh")
    end
end

local function FlushQueuedTrackerUpdate()
    trackerUpdateFlushQueued = false

    if not trackerUpdatePending then
        return
    end

    local forceBuild = trackerUpdatePendingForceBuild
    local postCombat = trackerUpdatePendingPostCombat

    trackerUpdatePending = false
    trackerUpdatePendingForceBuild = false
    trackerUpdatePendingPostCombat = false

    RunTrackerUpdate(forceBuild, postCombat)
end

function QuestKing:QueueTrackerUpdate(forceBuild, postCombat)
    if forceBuild then
        trackerUpdatePendingForceBuild = true
    end

    if postCombat then
        trackerUpdatePendingPostCombat = true
    end

    trackerUpdatePending = true

    if trackerUpdateFlushQueued then
        return
    end

    if C_Timer and C_Timer.After then
        trackerUpdateFlushQueued = true
        C_Timer.After(0, FlushQueuedTrackerUpdate)
    else
        FlushQueuedTrackerUpdate()
    end
end

function QuestKing:UpdateTracker(forceBuild, postCombat)
    self:QueueTrackerUpdate(forceBuild, postCombat)
end

local function EnsureSavedVariables()
    _G.QuestKingDB = _G.QuestKingDB or {}
    _G.QuestKingDBPerChar = _G.QuestKingDBPerChar or {}

    local db = _G.QuestKingDB
    local perChar = _G.QuestKingDBPerChar

    perChar.version = tonumber(perChar.version) or 2
    perChar.collapsedHeaders = type(perChar.collapsedHeaders) == "table" and perChar.collapsedHeaders or {}
    perChar.collapsedQuests = type(perChar.collapsedQuests) == "table" and perChar.collapsedQuests or {}
    perChar.collapsedAchievements = type(perChar.collapsedAchievements) == "table" and perChar.collapsedAchievements or {}
    perChar.trackerCollapsed = tonumber(perChar.trackerCollapsed) or 0
    perChar.displayMode = type(perChar.displayMode) == "string" and perChar.displayMode or "combined"
    perChar.trackerPositionPreset = tonumber(perChar.trackerPositionPreset) or 1

    db.dragLocked = db.dragLocked == true
    db.dragOrigin = type(db.dragOrigin) == "string" and db.dragOrigin or "TOPRIGHT"
    db.dragRelativePoint = type(db.dragRelativePoint) == "string" and db.dragRelativePoint or db.dragOrigin
    db.dragX = tonumber(db.dragX)
    db.dragY = tonumber(db.dragY)

    if db.dbTrackerAlpha ~= nil then
        db.dbTrackerAlpha = tonumber(db.dbTrackerAlpha)
    end

    if db.dbTrackerScale ~= nil then
        db.dbTrackerScale = tonumber(db.dbTrackerScale)
    end
end

local function QueueUpdateChecker()
    updateStateFrame:SetScript("OnUpdate", function()
        if combatUpdateQueued and not IsInCombatLockdownSafe() then
            combatUpdateQueued = false
            SetModeButtonCombatColor(false)
            QuestKing:QueueTrackerUpdate(false, true)

            if pendingPlayerLevel and type(_G.UnitLevel) == "function" and _G.UnitLevel("player") >= pendingPlayerLevel then
                pendingPlayerLevel = nil
            end
        end

        if pendingPlayerLevel and type(_G.UnitLevel) == "function" and _G.UnitLevel("player") >= pendingPlayerLevel then
            pendingPlayerLevel = nil
            QuestKing:QueueTrackerUpdate(true)
        end

        if not combatUpdateQueued and not pendingPlayerLevel then
            updateStateFrame:SetScript("OnUpdate", nil)
        end
    end)
end

function QuestKing:StartCombatTimer()
    if combatUpdateQueued then
        return
    end

    combatUpdateQueued = true
    SetModeButtonCombatColor(true)
    QueueUpdateChecker()
end

function QuestKing:OnPlayerLevelUp(newLevel)
    pendingPlayerLevel = tonumber(newLevel)
    QueueUpdateChecker()
end

local function OnQuestWatchAdded(questIndexOrID)
    local questID = ResolveQuestIDFromIndexOrID(questIndexOrID)
    if questID then
        MarkQuestFresh(questID)
    end

    QuestKing:QueueTrackerUpdate(true)
end

local function OnQuestWatchRemoved()
    QuestKing:QueueTrackerUpdate(true)
end

local function OnContentTrackingStarted(contentType, contentID)
    if not (Enum and Enum.ContentTrackingType and contentType == Enum.ContentTrackingType.Achievement) then
        return
    end

    if type(contentID) == "number" then
        QuestKing.trackedAchievements = QuestKing.trackedAchievements or {}
        QuestKing.trackedAchievements[contentID] = true
    else
        SafeCallMethod(QuestKing, "SyncTrackedAchievementCacheFromAPIs")
    end

    RefreshTrackedAchievementCacheOrUpdate()
end

local function OnContentTrackingStopped(contentType, contentID)
    if not (Enum and Enum.ContentTrackingType and contentType == Enum.ContentTrackingType.Achievement) then
        return
    end

    if type(contentID) == "number" and QuestKing.trackedAchievements then
        QuestKing.trackedAchievements[contentID] = nil
    else
        SafeCallMethod(QuestKing, "SyncTrackedAchievementCacheFromAPIs")
    end

    RefreshTrackedAchievementCacheOrUpdate()
end

local function OnTrackedAchievementAdded(achievementID)
    if type(achievementID) == "number" then
        QuestKing.trackedAchievements = QuestKing.trackedAchievements or {}
        QuestKing.trackedAchievements[achievementID] = true
    else
        SafeCallMethod(QuestKing, "SyncTrackedAchievementCacheFromAPIs")
    end

    RefreshTrackedAchievementCacheOrUpdate()
end

local function OnTrackedAchievementRemoved(achievementID)
    if type(achievementID) == "number" and QuestKing.trackedAchievements then
        QuestKing.trackedAchievements[achievementID] = nil
    else
        SafeCallMethod(QuestKing, "SyncTrackedAchievementCacheFromAPIs")
    end

    RefreshTrackedAchievementCacheOrUpdate()
end

local function HookTrackingFunctions()
    if trackingHooksInstalled then
        return
    end

    trackingHooksInstalled = true

    SafeHookTableMethod(C_QuestLog, "AddQuestWatch", OnQuestWatchAdded)
    SafeHookTableMethod(C_QuestLog, "RemoveQuestWatch", OnQuestWatchRemoved)

    SafeHookGlobal("AddQuestWatch", OnQuestWatchAdded)
    SafeHookGlobal("RemoveQuestWatch", OnQuestWatchRemoved)

    SafeHookGlobal("AddAutoQuestPopUp", function()
        QuestKing:QueueTrackerUpdate(true)
    end)

    SafeHookGlobal("AddTrackedAchievement", OnTrackedAchievementAdded)
    SafeHookGlobal("RemoveTrackedAchievement", OnTrackedAchievementRemoved)

    SafeHookTableMethod(C_ContentTracking, "StartTracking", OnContentTrackingStarted)
    SafeHookTableMethod(C_ContentTracking, "StopTracking", OnContentTrackingStopped)
end

function QuestKing:Init()
    if initialized then
        self:QueueTrackerUpdate(true)
        return
    end

    EnsureSavedVariables()

    self.updateHooks = type(self.updateHooks) == "table" and self.updateHooks or {}
    self.newlyAddedQuests = type(self.newlyAddedQuests) == "table" and self.newlyAddedQuests or {}
    self.trackedAchievements = type(self.trackedAchievements) == "table" and self.trackedAchievements or {}

    SafeCallMethod(self, "InitLoot")

    if options.disableBlizzard then
        SafeCallMethod(self, "DisableBlizzard")
    end

    HookTrackingFunctions()

    if Tracker and Tracker.Init then
        Tracker:Init()
    end

    SafeCallMethod(self, "SyncTrackedAchievementCacheFromAPIs")

    initialized = true
    self:QueueTrackerUpdate(true)
end
