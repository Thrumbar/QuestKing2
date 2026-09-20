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
local strfind = string.find
local wipe = wipe

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
local trackerUpdatePendingQuestData = false
local trackerUpdatePendingAchievementData = false
local trackerUpdatePendingQuestEvent = false
local trackerUpdatePendingCombatQuestEvent = false
local trackerRenderRecoveryAttempted = false

local TRACKER_UPDATE_COALESCE_DELAY = 0.05

local VALID_DISPLAY_MODES = {
    combined = true,
    quests = true,
    achievements = true,
    raids = true,
}

local issecretvalue = _G.issecretvalue

local function IsSecretValue(value)
    if type(issecretvalue) == "function" then
        local ok, result = pcall(issecretvalue, value)
        if ok then
            return result and true or false
        end
    end

    return false
end

local function IsExpectedSecretValueError(errorValue)
    if IsSecretValue(errorValue) then
        return true
    end

    if type(errorValue) ~= "string" then
        return false
    end

    return strfind(errorValue, "secret ", 1, true) ~= nil
        or strfind(errorValue, "secret-", 1, true) ~= nil
        or strfind(errorValue, "secret value", 1, true) ~= nil
end

local function ReportErrorSafe(errorValue)
    if IsExpectedSecretValueError(errorValue) then
        return
    end

    if type(_G.geterrorhandler) ~= "function" then
        return
    end

    local ok, handler = pcall(_G.geterrorhandler)
    if ok and type(handler) == "function" then
        pcall(handler, errorValue)
    end
end

local function IsInCombatLockdownSafe()
    return type(_G.InCombatLockdown) == "function" and _G.InCombatLockdown() or false
end

local Performance = type(QuestKing.Performance) == "table" and QuestKing.Performance or {}
QuestKing.Performance = Performance
Performance.enabled = Performance.enabled == true

local function GetProfileTimeMilliseconds()
    if type(_G.debugprofilestop) == "function" then
        local ok, value = pcall(_G.debugprofilestop)
        if ok and type(value) == "number" then
            return value
        end
    end

    if type(_G.GetTimePreciseSec) == "function" then
        local ok, value = pcall(_G.GetTimePreciseSec)
        if ok and type(value) == "number" then
            return value * 1000
        end
    end

    if type(_G.GetTime) == "function" then
        local ok, value = pcall(_G.GetTime)
        if ok and type(value) == "number" then
            return value * 1000
        end
    end

    return nil
end

local function ResetPerformanceProfile()
    local enabled = Performance.enabled == true

    if type(wipe) == "function" then
        wipe(Performance)
    else
        for key in pairs(Performance) do
            Performance[key] = nil
        end
    end

    Performance.enabled = enabled
    Performance.startedAtMilliseconds = GetProfileTimeMilliseconds()
    Performance.refreshRequestCount = 0
    Performance.coalescedRequestCount = 0
    Performance.trackerRefreshCount = 0
    Performance.fullRebuildCount = 0
    Performance.cachedPopulationRefreshCount = 0
    Performance.questLogScanCount = 0
    Performance.objectiveScanCount = 0
    Performance.achievementListScanCount = 0
    Performance.achievementCriteriaScanCount = 0
    Performance.autoCompleteRequestCount = 0
    Performance.autoCompleteScanCount = 0
    Performance.bagScanCount = 0
    Performance.layoutPassCount = 0
    Performance.layoutAnchorUpdateCount = 0
    Performance.layoutMetricPassCount = 0
    Performance.rowAcquireCount = 0
    Performance.rowReleaseCount = 0
    Performance.questEventCount = 0
    Performance.questEventRefreshCount = 0
    Performance.combatQuestEventCount = 0
    Performance.combatQuestRefreshCount = 0
    Performance.totalRefreshMilliseconds = 0
    Performance.maxRefreshMilliseconds = 0
    Performance.lastRefreshMilliseconds = 0
    Performance.questEvents = {}
end

if Performance.refreshRequestCount == nil then
    ResetPerformanceProfile()
end

function QuestKing:RecordPerformanceMetric(metric, amount)
    if not Performance.enabled or type(metric) ~= "string" then
        return
    end

    amount = tonumber(amount) or 1
    Performance[metric] = (tonumber(Performance[metric]) or 0) + amount
end

function QuestKing:RecordPerformanceQuestEvent(eventName)
    if not Performance.enabled then
        return
    end

    self:RecordPerformanceMetric("questEventCount", 1)

    if type(eventName) == "string" then
        local eventCounts = Performance.questEvents
        if type(eventCounts) ~= "table" then
            eventCounts = {}
            Performance.questEvents = eventCounts
        end
        eventCounts[eventName] = (tonumber(eventCounts[eventName]) or 0) + 1
    end

    if IsInCombatLockdownSafe() then
        self:RecordPerformanceMetric("combatQuestEventCount", 1)
    end
end

function QuestKing:SetPerformanceProfilingEnabled(enabled)
    Performance.enabled = enabled and true or false
    if Performance.enabled then
        ResetPerformanceProfile()
        Performance.enabled = true
    end

    return Performance.enabled
end

function QuestKing:ResetPerformanceProfile()
    ResetPerformanceProfile()
    return Performance
end

function QuestKing:GetPerformanceProfile()
    return Performance
end

local function IsProtectedFrameSafe(frame)
    if not frame or type(frame.IsProtected) ~= "function" then
        return true
    end

    local ok, protected = pcall(frame.IsProtected, frame)
    return not ok or protected == true
end

local function IsAnchoringRestrictedSafe(frame)
    if not frame or type(frame.IsAnchoringRestricted) ~= "function" then
        return false
    end

    local ok, restricted = pcall(frame.IsAnchoringRestricted, frame)
    return not ok or restricted == true
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

    ReportErrorSafe(result)

    return false, nil
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
    local cache = QuestKing.trackedAchievements
    if type(cache) ~= "table" and QuestKing.SyncTrackedAchievementCacheFromAPIs then
        local _, refreshedCache = SafeCallMethod(QuestKing, "SyncTrackedAchievementCacheFromAPIs")
        cache = refreshedCache
    end

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

local function GetMaxQuests()
    -- C_QuestLog.GetMaxNumQuests can return Blizzard's broad internal quest cap
    -- on modern clients. That value includes hidden/system/world quest buckets and
    -- is not the player's normal accepted quest-log capacity.
    if C_QuestLog and C_QuestLog.GetMaxNumQuestsCanAccept then
        local ok, count = pcall(C_QuestLog.GetMaxNumQuestsCanAccept)
        if ok and type(count) == "number" and count > 0 then
            return count
        end
    end

    -- Older clients may only expose GetMaxNumQuests. Keep it as a fallback, but
    -- reject modern internal-cap values such as 175 so the title does not lie.
    if C_QuestLog and C_QuestLog.GetMaxNumQuests then
        local ok, count = pcall(C_QuestLog.GetMaxNumQuests)
        if ok and type(count) == "number" and count > 0 and count <= 50 then
            return count
        end
    end

    return _G.MAX_QUESTLOG_QUESTS or _G.MAX_QUESTS or 25
end

local function GetAcceptedQuestCount()
    if C_QuestLog and C_QuestLog.GetNumQuestLogEntries then
        local ok, _, numQuests = pcall(C_QuestLog.GetNumQuestLogEntries)
        if ok and type(numQuests) == "number" and numQuests >= 0 then
            return numQuests
        end
    end

    if type(_G.GetNumQuestLogEntries) == "function" then
        local ok, _, numQuests = pcall(_G.GetNumQuestLogEntries)
        if ok and type(numQuests) == "number" and numQuests >= 0 then
            return numQuests
        end
    end

    return 0
end

local function RefreshTrackedAchievementCacheOrUpdate()
    if QuestKing.QueueAchievementTrackerRefresh then
        SafeCallMethod(QuestKing, "QueueAchievementTrackerRefresh", true)
        return
    end

    SafeCallMethod(QuestKing, "QueueTrackerUpdate", false, false, "achievement")
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

local function UpdateTrackerTitleText(displayMode, numAchievements, acceptedQuests, maxQuests, numRaidBlocks, hasTrackerContent)
    if not (Tracker and Tracker.titlebarText and Tracker.titlebarText.SetText and Tracker.titlebarText.SetTextColor) then
        return
    end

    local normalColor = colors.TrackerTitlebarText or { 1, 1, 1 }
    local dimmedColor = colors.TrackerTitlebarTextDimmed or { 0.7, 0.7, 0.7 }
    local isDimmed = false

    numAchievements = tonumber(numAchievements) or 0
    acceptedQuests = tonumber(acceptedQuests) or 0
    maxQuests = tonumber(maxQuests) or 0
    numRaidBlocks = tonumber(numRaidBlocks) or 0

    if displayMode == "combined" then
        if numAchievements > 0 then
            Tracker.titlebarText:SetText(format("%d/%d | %d", acceptedQuests, maxQuests, numAchievements))
        else
            Tracker.titlebarText:SetText(format("%d/%d", acceptedQuests, maxQuests))
        end

        isDimmed = (not hasTrackerContent and numAchievements == 0 and numRaidBlocks == 0)
    elseif displayMode == "achievements" then
        Tracker.titlebarText:SetText(tostring(numAchievements))
        isDimmed = numAchievements == 0
    elseif displayMode == "raids" then
        Tracker.titlebarText:SetText(tostring(numRaidBlocks))
        isDimmed = numRaidBlocks == 0
    else
        Tracker.titlebarText:SetText(format("%d/%d", acceptedQuests, maxQuests))
        isDimmed = not hasTrackerContent
    end

    local color = isDimmed and dimmedColor or normalColor
    Tracker.titlebarText:SetTextColor(color[1] or 1, color[2] or 1, color[3] or 1)
end

local function LayoutRequestedButtons(postCombat)
    local requestOrder = WatchButton.requestOrder or {}
    local requestCount = WatchButton.requestCount or 0
    local lastShown = nil
    local layoutGeneration = tonumber(Tracker and Tracker._layoutGeneration) or 0

    local inCombat = IsInCombatLockdownSafe()
    QuestKing:RecordPerformanceMetric("layoutPassCount", 1)

    for index = 1, requestCount do
        local button = requestOrder[index]
        if button and button.ClearAllPoints and button.SetPoint and button.Render then
            local protected = inCombat and IsProtectedFrameSafe(button)
            local deferExternalAnchor = inCombat and (
                protected
                or button.itemButton ~= nil
                or IsAnchoringRestrictedSafe(button)
            )

            if deferExternalAnchor then
                -- Moving an item row would also move its separately parented
                -- secure button through the relative anchor. Keep the row's
                -- external anchor stable until combat ends.
                if QuestKing.StartCombatTimer then
                    QuestKing:StartCombatTimer()
                end
            else
                local previousButton = lastShown or false
                local anchorKind

                if not lastShown then
                    anchorKind = "first"
                elseif button.type == "header" or button.type == "collapser" then
                    anchorKind = "section"
                elseif lastShown.type == "header" or lastShown.type == "collapser" then
                    anchorKind = "after-section"
                else
                    anchorKind = "normal"
                end

                if postCombat
                    or button._layoutPreviousButton ~= previousButton
                    or button._layoutAnchorKind ~= anchorKind
                    or button._layoutGeneration ~= layoutGeneration then
                    button:ClearAllPoints()

                    if anchorKind == "first" then
                        if Tracker and Tracker.titlebar then
                            button:SetPoint("TOPLEFT", Tracker.titlebar, "BOTTOMLEFT", 0, -1)
                        end
                    elseif anchorKind == "section" then
                        button:SetPoint("TOPLEFT", lastShown, "BOTTOMLEFT", 0, -4)
                    elseif anchorKind == "after-section" then
                        button:SetPoint("TOPLEFT", lastShown, "BOTTOMLEFT", 0, -3)
                    else
                        button:SetPoint("TOPLEFT", lastShown, "BOTTOMLEFT", 0, -2)
                    end

                    button._layoutPreviousButton = previousButton
                    button._layoutAnchorKind = anchorKind
                    button._layoutGeneration = layoutGeneration
                    QuestKing:RecordPerformanceMetric("layoutAnchorUpdateCount", 1)
                end
            end

            -- Item rows remain ordinary, unprotected pooled rows. Their text,
            -- line geometry, and progress bars can update while the secure
            -- button's own anchor and the row's external anchor stay deferred.
            if not protected then
                button:Render()
            end

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
    if WatchButton.CommitOrder then
        WatchButton:CommitOrder()
    end

    if Tracker and Tracker.Resize then
        Tracker:Resize(lastShown)
    end
end

local function RunTrackerUpdate(
    forceBuild,
    postCombat,
    refreshQuestData,
    refreshAchievementData,
    isQuestEventRefresh,
    isCombatQuestEventRefresh
)
    local profileStart = Performance.enabled and GetProfileTimeMilliseconds() or nil
    QuestKing:RecordPerformanceMetric("trackerRefreshCount", 1)
    if isQuestEventRefresh then
        QuestKing:RecordPerformanceMetric("questEventRefreshCount", 1)
    end
    if isCombatQuestEventRefresh then
        QuestKing:RecordPerformanceMetric("combatQuestRefreshCount", 1)
    end

    -- Ordinary quest/scenario data and FontString updates are safe during combat.
    -- Protected item-button mutations and tracker resizing defer themselves in
    -- ui/itembutton.lua, ui/watchbutton.lua, and ui/tracker.lua.
    SafeCallMethod(QuestKing, "PreCheckQuestFocus")

    if WatchButton.StartOrder then
        WatchButton:StartOrder()
    end

    local trackerDB = _G.QuestKingDBPerChar or {}
    local trackerCollapsed = trackerDB.trackerCollapsed or 0
    local displayMode = trackerDB.displayMode or "combined"
    local questRows = nil
    local questRenderFailed = false

    if forceBuild then
        QuestKing._questSortTableReady = false
        QuestKing._questSortDisplayDataReady = false
    elseif refreshQuestData then
        QuestKing._questSortDisplayDataReady = false
    end

    if refreshAchievementData then
        QuestKing._achievementDisplayDataReady = false
    end

    if refreshQuestData then
        SafeCallMethod(QuestKing, "InvalidateQuestPopupState")
    end

    if displayMode == "combined" or displayMode == "quests" then
        local shouldRefreshQuestRows = trackerCollapsed == 0
            and (refreshQuestData or QuestKing._questSortDisplayDataReady ~= true)
        local ok, rows = SafeCallMethod(
            QuestKing,
            "BuildQuestSortTable",
            forceBuild,
            shouldRefreshQuestRows
        )
        if ok and type(rows) == "table" then
            questRows = rows
        else
            questRenderFailed = true
        end
    end

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
            SafeCallMethod(QuestKing, "UpdateTrackerScenarios", true)
        end

        if showBonusObjectives then
            SafeCallMethod(QuestKing, "UpdateTrackerBonusObjectives")
        end
    end

    if trackerCollapsed == 0 then
        if displayMode == "combined" or displayMode == "achievements" then
            SafeCallMethod(QuestKing, "UpdateTrackerAchievements", refreshAchievementData)
        end

        if (displayMode == "combined" or displayMode == "quests")
            and not questRenderFailed then
            local ok = SafeCallMethod(QuestKing, "UpdateTrackerQuests", questRows)
            if not ok then
                questRenderFailed = true
            end
        end
    end

    if questRenderFailed then
        -- StartOrder marks the previous generation unused before any renderer
        -- runs. A transient data/API failure must not commit that partial
        -- generation, free every healthy row, and shrink the tracker to its
        -- title height. Restore the last completed order and retry once.
        if WatchButton.AbortOrder then
            WatchButton:AbortOrder()
        end

        if not trackerRenderRecoveryAttempted then
            trackerRenderRecoveryAttempted = true
            QuestKing:QueueTrackerUpdate(true, false, "displaydata")
        end
        return
    end
    trackerRenderRecoveryAttempted = false

    local numAchievements = GetTrackedAchievementCount()
    local acceptedQuests = 0
    local maxQuests = 0
    if displayMode == "combined" or displayMode == "quests" then
        acceptedQuests = GetAcceptedQuestCount()
        maxQuests = GetMaxQuests()
    end
    local hasTrackerContent = QuestKing.trackerQuestHasContent == true
        or (tonumber(WatchButton.requestCount) or 0) > 0

    UpdateModeButtonLabel(displayMode)
    UpdateTrackerTitleText(
        displayMode,
        numAchievements,
        acceptedQuests,
        maxQuests,
        numRaidBlocks,
        hasTrackerContent
    )

    LayoutRequestedButtons(postCombat)

    SafeCallMethod(QuestKing, "PostCheckQuestFocus")

    local hooks = QuestKing.updateHooks or {}
    for index = 1, #hooks do
        local fn = hooks[index]
        if type(fn) == "function" then
            pcall(fn)
        end
    end

    if profileStart then
        local profileEnd = GetProfileTimeMilliseconds()
        if profileEnd then
            local duration = profileEnd - profileStart
            if duration < 0 then
                duration = 0
            end

            Performance.lastRefreshMilliseconds = duration
            Performance.totalRefreshMilliseconds =
                (tonumber(Performance.totalRefreshMilliseconds) or 0) + duration
            if duration > (tonumber(Performance.maxRefreshMilliseconds) or 0) then
                Performance.maxRefreshMilliseconds = duration
            end
        end
    end
end

local function FlushQueuedTrackerUpdate()
    trackerUpdateFlushQueued = false

    if not trackerUpdatePending then
        return
    end

    local forceBuild = trackerUpdatePendingForceBuild
    local postCombat = trackerUpdatePendingPostCombat
    local refreshQuestData = trackerUpdatePendingQuestData
    local refreshAchievementData = trackerUpdatePendingAchievementData
    local isQuestEventRefresh = trackerUpdatePendingQuestEvent
    local isCombatQuestEventRefresh = trackerUpdatePendingCombatQuestEvent

    trackerUpdatePending = false
    trackerUpdatePendingForceBuild = false
    trackerUpdatePendingPostCombat = false
    trackerUpdatePendingQuestData = false
    trackerUpdatePendingAchievementData = false
    trackerUpdatePendingQuestEvent = false
    trackerUpdatePendingCombatQuestEvent = false

    RunTrackerUpdate(
        forceBuild,
        postCombat,
        refreshQuestData,
        refreshAchievementData,
        isQuestEventRefresh,
        isCombatQuestEventRefresh
    )
end

function QuestKing:QueueTrackerUpdate(forceBuild, postCombat, reason)
    self:RecordPerformanceMetric("refreshRequestCount", 1)

    if trackerUpdatePending or trackerUpdateFlushQueued then
        self:RecordPerformanceMetric("coalescedRequestCount", 1)
    end

    if forceBuild then
        trackerUpdatePendingForceBuild = true
        trackerUpdatePendingQuestData = true
    end

    if postCombat then
        trackerUpdatePendingPostCombat = true
    end

    if reason == nil then
        trackerUpdatePendingQuestData = true
        trackerUpdatePendingAchievementData = true
    elseif reason == "displaydata" then
        trackerUpdatePendingQuestData = true
        trackerUpdatePendingAchievementData = true
    elseif reason == "quest"
        or reason == "questevent"
        or reason == "world"
        or reason == "item"
        or reason == "autocomplete" then
        trackerUpdatePendingQuestData = true
    elseif reason == "init" then
        trackerUpdatePendingQuestData = true
        trackerUpdatePendingAchievementData = true
    elseif reason == "achievement" then
        trackerUpdatePendingAchievementData = true
    end

    if reason == "questevent" then
        trackerUpdatePendingQuestEvent = true
        if IsInCombatLockdownSafe() then
            trackerUpdatePendingCombatQuestEvent = true
        end
    end

    trackerUpdatePending = true

    if trackerUpdateFlushQueued then
        return
    end

    if C_Timer and C_Timer.After then
        trackerUpdateFlushQueued = true
        C_Timer.After(TRACKER_UPDATE_COALESCE_DELAY, FlushQueuedTrackerUpdate)
    else
        FlushQueuedTrackerUpdate()
    end
end

function QuestKing:RequestTrackerUpdate(forceBuild, reason, postCombat)
    self:QueueTrackerUpdate(forceBuild, postCombat, reason)
end

function QuestKing:UpdateTracker(forceBuild, postCombat, reason)
    self:QueueTrackerUpdate(forceBuild, postCombat, reason)
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
    perChar.untrackedCampaignRequirements = type(perChar.untrackedCampaignRequirements) == "table"
        and perChar.untrackedCampaignRequirements
        or {}
    local trackerCollapsed = tonumber(perChar.trackerCollapsed)
    if trackerCollapsed ~= 0 and trackerCollapsed ~= 1 and trackerCollapsed ~= 2 then
        trackerCollapsed = 0
    end
    perChar.trackerCollapsed = trackerCollapsed

    local displayMode = type(perChar.displayMode) == "string" and perChar.displayMode or "combined"
    perChar.displayMode = VALID_DISPLAY_MODES[displayMode] and displayMode or "combined"
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
        if pendingPlayerLevel and type(_G.UnitLevel) == "function" and _G.UnitLevel("player") >= pendingPlayerLevel then
            pendingPlayerLevel = nil
            QuestKing:QueueTrackerUpdate(true, false, "quest")
        end

        if not pendingPlayerLevel then
            updateStateFrame:SetScript("OnUpdate", nil)
        end
    end)
end

function QuestKing:ReconcileAfterCombat()
    if IsInCombatLockdownSafe() then
        return false
    end

    local hadCombatUpdate = combatUpdateQueued
    combatUpdateQueued = false
    if hadCombatUpdate then
        SetModeButtonCombatColor(false)
    end

    local _, presentationApplied = SafeCallMethod(Tracker, "ApplyDeferredProtectedPresentation")

    if pendingPlayerLevel and type(_G.UnitLevel) == "function" and _G.UnitLevel("player") >= pendingPlayerLevel then
        pendingPlayerLevel = nil
    end

    if hadCombatUpdate then
        self:QueueTrackerUpdate(false, true, "presentation")
    end

    return hadCombatUpdate or presentationApplied == true
end

function QuestKing:StartCombatTimer()
    if combatUpdateQueued then
        return
    end

    if not IsInCombatLockdownSafe() then
        self:QueueTrackerUpdate(false, true, "presentation")
        return
    end

    combatUpdateQueued = true
    SetModeButtonCombatColor(true)
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

    QuestKing:QueueTrackerUpdate(true, false, "quest")
end

local function OnQuestWatchRemoved()
    QuestKing:QueueTrackerUpdate(true, false, "quest")
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

    SafeHookGlobal("AddTrackedAchievement", OnTrackedAchievementAdded)
    SafeHookGlobal("RemoveTrackedAchievement", OnTrackedAchievementRemoved)

    SafeHookTableMethod(C_ContentTracking, "StartTracking", OnContentTrackingStarted)
    SafeHookTableMethod(C_ContentTracking, "StopTracking", OnContentTrackingStopped)
end

function QuestKing:Init()
    if initialized then
        self:QueueTrackerUpdate(true, false, "init")
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
    self:QueueTrackerUpdate(true, false, "init")
end
