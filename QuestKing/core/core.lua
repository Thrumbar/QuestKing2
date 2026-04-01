local addonName, QuestKing = ...

local opt = QuestKing.options or {}
local opt_colors = (opt and opt.colors) or {
    TrackerTitlebarText = { 1, 1, 1 },
    TrackerTitlebarTextDimmed = { 0.7, 0.7, 0.7 },
}

local WatchButton = QuestKing.WatchButton or {}
local Tracker = QuestKing.Tracker or CreateFrame("Frame")

local format = string.format
local pairs = pairs
local type = type
local tostring = tostring
local tonumber = tonumber
local unpack = table.unpack or unpack

local UpdateCheckFrame = CreateFrame("Frame", "QuestKing_UpdateCheckFrame")

local checkCombat = false
local checkPendingPlayerLevel = false
local initialized = false
local trackingHooksInstalled = false

local function SafeCall(obj, method, ...)
    local fn = obj and obj[method]
    if type(fn) ~= "function" then
        return nil
    end

    local ok, result = pcall(fn, obj, ...)
    if ok then
        return result
    end

    return nil
end

local function SafeGetTrackedAchievementCount()
    if QuestKing.SyncTrackedAchievementCacheFromAPIs then
        local cache = QuestKing:SyncTrackedAchievementCacheFromAPIs()
        local count = 0

        if type(cache) == "table" then
            for id, tracked in pairs(cache) do
                if tracked and type(id) == "number" then
                    count = count + 1
                end
            end
        end

        return count
    end

    if type(QuestKing.trackedAchievements) == "table" then
        local count = 0
        for id, tracked in pairs(QuestKing.trackedAchievements) do
            if tracked and type(id) == "number" then
                count = count + 1
            end
        end
        return count
    end

    return 0
end

local function SafeGetMaxQuests()
    if C_QuestLog and C_QuestLog.GetMaxNumQuests then
        local count = C_QuestLog.GetMaxNumQuests()
        if type(count) == "number" and count > 0 then
            return count
        end
    end

    return MAX_QUESTS or 25
end

local function SafeGetNumQuestWatches()
    if C_QuestLog and C_QuestLog.GetNumQuestWatches then
        return C_QuestLog.GetNumQuestWatches() or 0
    end

    if GetNumQuestWatches then
        return GetNumQuestWatches() or 0
    end

    return 0
end

local function SafeGetQuestLogCounts()
    if C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo then
        local totalEntries = C_QuestLog.GetNumQuestLogEntries() or 0
        local totalQuests = 0

        for questLogIndex = 1, totalEntries do
            local info = C_QuestLog.GetInfo(questLogIndex)
            if info and not info.isHeader and not info.isHidden then
                totalQuests = totalQuests + 1
            end
        end

        return totalEntries, totalQuests
    end

    if GetNumQuestLogEntries then
        local lines, quests = GetNumQuestLogEntries()
        return lines or 0, quests or 0
    end

    return 0, 0
end

local function ResolveQuestIDFromIndexOrID(value)
    if type(value) ~= "number" then
        return nil
    end

    if C_QuestLog and C_QuestLog.GetLogIndexForQuestID then
        local index = C_QuestLog.GetLogIndexForQuestID(value)
        if index and index > 0 then
            return value
        end
    end

    if C_QuestLog and C_QuestLog.GetInfo then
        local info = C_QuestLog.GetInfo(value)
        if info and info.questID then
            return info.questID
        end
    end

    if GetQuestLogTitle then
        local _, _, _, _, _, _, _, questID = GetQuestLogTitle(value)
        return questID
    end

    return nil
end

local function SetModeButtonCombatColor(inCombat)
    if not (QuestKing_TrackerModeButton and QuestKing_TrackerModeButton.label) then
        return
    end

    if inCombat then
        QuestKing_TrackerModeButton.label:SetTextColor(1, 0, 0)
    else
        QuestKing_TrackerModeButton.label:SetTextColor(
            opt_colors.TrackerTitlebarText[1],
            opt_colors.TrackerTitlebarText[2],
            opt_colors.TrackerTitlebarText[3]
        )
    end
end

local function QueueUpdateChecker()
    UpdateCheckFrame:SetScript("OnUpdate", function()
        if checkCombat then
            if not InCombatLockdown() then
                checkCombat = false
                SetModeButtonCombatColor(false)
                QuestKing:UpdateTracker(false, true)

                if checkPendingPlayerLevel and UnitLevel("player") >= checkPendingPlayerLevel then
                    checkPendingPlayerLevel = false
                end
            end
        end

        if checkPendingPlayerLevel and UnitLevel("player") >= checkPendingPlayerLevel then
            checkPendingPlayerLevel = false
            QuestKing:UpdateTracker()
        end

        if (not checkCombat) and (not checkPendingPlayerLevel) then
            UpdateCheckFrame:SetScript("OnUpdate", nil)
        end
    end)
end

function QuestKing:StartCombatTimer()
    if checkCombat then
        return
    end

    checkCombat = true
    SetModeButtonCombatColor(true)
    QueueUpdateChecker()
end

function QuestKing:OnPlayerLevelUp(newLevel)
    checkPendingPlayerLevel = tonumber(newLevel)
    QueueUpdateChecker()
end

local function MarkQuestFresh(questID)
    if type(questID) ~= "number" then
        return
    end

    QuestKing.newlyAddedQuests = QuestKing.newlyAddedQuests or {}
    QuestKing.newlyAddedQuests[questID] = true
end

local function hookAddQuestWatch_Legacy(questLogIndex)
    local questID = ResolveQuestIDFromIndexOrID(questLogIndex)
    if questID then
        MarkQuestFresh(questID)
    end

    QuestKing:UpdateTracker(true)
end

local function hookAddQuestWatch_Retail(questID)
    if questID then
        MarkQuestFresh(questID)
    end

    QuestKing:UpdateTracker(true)
end

local function hookRemoveQuestWatch_Legacy()
    QuestKing:UpdateTracker(true)
end

local function hookRemoveQuestWatch_Retail()
    QuestKing:UpdateTracker(true)
end

local function RefreshTrackedAchievementCacheOrUpdate()
    if QuestKing.QueueAchievementTrackerRefresh then
        QuestKing:QueueAchievementTrackerRefresh()
    else
        QuestKing:UpdateTracker(true)
    end
end

local function hookAddTrackedAchievement_Legacy(achievementID)
    if type(achievementID) == "number" then
        QuestKing.trackedAchievements = QuestKing.trackedAchievements or {}
        QuestKing.trackedAchievements[achievementID] = true
    elseif QuestKing.SyncTrackedAchievementCacheFromAPIs then
        QuestKing:SyncTrackedAchievementCacheFromAPIs()
    end

    RefreshTrackedAchievementCacheOrUpdate()
end

local function hookRemoveTrackedAchievement_Legacy(achievementID)
    if type(achievementID) == "number" and QuestKing.trackedAchievements then
        QuestKing.trackedAchievements[achievementID] = nil
    elseif QuestKing.SyncTrackedAchievementCacheFromAPIs then
        QuestKing:SyncTrackedAchievementCacheFromAPIs()
    end

    RefreshTrackedAchievementCacheOrUpdate()
end

local function hookStartTracking_ContentTracking(contentType, id)
    if not (Enum and Enum.ContentTrackingType) then
        return
    end

    if contentType ~= Enum.ContentTrackingType.Achievement then
        return
    end

    if type(id) == "number" then
        QuestKing.trackedAchievements = QuestKing.trackedAchievements or {}
        QuestKing.trackedAchievements[id] = true
    elseif QuestKing.SyncTrackedAchievementCacheFromAPIs then
        QuestKing:SyncTrackedAchievementCacheFromAPIs()
    end

    RefreshTrackedAchievementCacheOrUpdate()
end

local function hookStopTracking_ContentTracking(contentType, id)
    if not (Enum and Enum.ContentTrackingType) then
        return
    end

    if contentType ~= Enum.ContentTrackingType.Achievement then
        return
    end

    if type(id) == "number" and QuestKing.trackedAchievements then
        QuestKing.trackedAchievements[id] = nil
    elseif QuestKing.SyncTrackedAchievementCacheFromAPIs then
        QuestKing:SyncTrackedAchievementCacheFromAPIs()
    end

    RefreshTrackedAchievementCacheOrUpdate()
end

local function hookAddAutoQuestPopUp()
    QuestKing:UpdateTracker()
end

local function UpdateMinimizeButtonLabel(trackerCollapsed)
    if not (QuestKing_TrackerMinimizeButton and QuestKing_TrackerMinimizeButton.label) then
        return
    end

    if trackerCollapsed == 2 then
        QuestKing_TrackerMinimizeButton.label:SetText("x")
    elseif trackerCollapsed == 1 then
        QuestKing_TrackerMinimizeButton.label:SetText("+")
    else
        QuestKing_TrackerMinimizeButton.label:SetText("-")
    end
end

local function UpdateModeButtonLabel(displayMode)
    if not (QuestKing_TrackerModeButton and QuestKing_TrackerModeButton.label) then
        return
    end

    if displayMode == "combined" then
        QuestKing_TrackerModeButton.label:SetText("C")
    elseif displayMode == "achievements" then
        QuestKing_TrackerModeButton.label:SetText("A")
    else
        QuestKing_TrackerModeButton.label:SetText("Q")
    end
end

local function UpdateTrackerTitleText(displayMode, numAchievements, numWatches, totalQuests, maxQuests)
    if not (Tracker and Tracker.titlebarText) then
        return
    end

    if displayMode == "combined" then
        if numAchievements > 0 then
            Tracker.titlebarText:SetText(format("%d/%d | %d", totalQuests, maxQuests, numAchievements))
        else
            Tracker.titlebarText:SetText(format("%d/%d", totalQuests, maxQuests))
        end

        if numWatches == 0 and numAchievements == 0 then
            Tracker.titlebarText:SetTextColor(
                opt_colors.TrackerTitlebarTextDimmed[1],
                opt_colors.TrackerTitlebarTextDimmed[2],
                opt_colors.TrackerTitlebarTextDimmed[3]
            )
        else
            Tracker.titlebarText:SetTextColor(
                opt_colors.TrackerTitlebarText[1],
                opt_colors.TrackerTitlebarText[2],
                opt_colors.TrackerTitlebarText[3]
            )
        end
    elseif displayMode == "achievements" then
        Tracker.titlebarText:SetText(tostring(numAchievements))

        if numAchievements == 0 then
            Tracker.titlebarText:SetTextColor(
                opt_colors.TrackerTitlebarTextDimmed[1],
                opt_colors.TrackerTitlebarTextDimmed[2],
                opt_colors.TrackerTitlebarTextDimmed[3]
            )
        else
            Tracker.titlebarText:SetTextColor(
                opt_colors.TrackerTitlebarText[1],
                opt_colors.TrackerTitlebarText[2],
                opt_colors.TrackerTitlebarText[3]
            )
        end
    else
        Tracker.titlebarText:SetText(format("%d/%d", totalQuests, maxQuests))

        if numWatches == 0 then
            Tracker.titlebarText:SetTextColor(
                opt_colors.TrackerTitlebarTextDimmed[1],
                opt_colors.TrackerTitlebarTextDimmed[2],
                opt_colors.TrackerTitlebarTextDimmed[3]
            )
        else
            Tracker.titlebarText:SetTextColor(
                opt_colors.TrackerTitlebarText[1],
                opt_colors.TrackerTitlebarText[2],
                opt_colors.TrackerTitlebarText[3]
            )
        end
    end
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
            else
                if button.type == "header" or button.type == "collapser" then
                    button:SetPoint("TOPLEFT", lastShown, "BOTTOMLEFT", 0, -4)
                elseif lastShown.type == "header" or lastShown.type == "collapser" then
                    button:SetPoint("TOPLEFT", lastShown, "BOTTOMLEFT", 0, -3)
                else
                    button:SetPoint("TOPLEFT", lastShown, "BOTTOMLEFT", 0, -2)
                end
            end

            button:Render()
            lastShown = button
        end
    end

    if postCombat and WatchButton.freePool then
        for i = 1, #WatchButton.freePool do
            local button = WatchButton.freePool[i]
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

function QuestKing:UpdateTracker(forceBuild, postCombat)
    SafeCall(self, "CheckQuestSortTable", forceBuild)
    self.watchMoney = false

    SafeCall(self, "PreCheckQuestTracking")

    if WatchButton.StartOrder then
        WatchButton:StartOrder()
    end

    local trackerCollapsed = (QuestKingDBPerChar and QuestKingDBPerChar.trackerCollapsed) or 0
    local displayMode = (QuestKingDBPerChar and QuestKingDBPerChar.displayMode) or "combined"

    UpdateMinimizeButtonLabel(trackerCollapsed)

    if trackerCollapsed <= 1 then
        SafeCall(self, "UpdateTrackerPopups")
        SafeCall(self, "UpdateTrackerChallengeTimers")

        if C_Scenario and C_Scenario.IsInScenario and C_Scenario.IsInScenario() then
            SafeCall(self, "UpdateTrackerScenarios")
        end

        SafeCall(self, "UpdateTrackerBonusObjectives")
    end

    if trackerCollapsed == 0 then
        if displayMode == "combined" or displayMode == "achievements" then
            SafeCall(self, "UpdateTrackerAchievements")
        end

        if displayMode == "combined" or displayMode == "quests" then
            SafeCall(self, "UpdateTrackerQuests")
        end
    end

    local numAchievements = SafeGetTrackedAchievementCount()
    local numWatches = SafeGetNumQuestWatches()
    local _, totalQuests = SafeGetQuestLogCounts()
    local maxQuests = SafeGetMaxQuests()

    UpdateModeButtonLabel(displayMode)
    UpdateTrackerTitleText(displayMode, numAchievements, numWatches, totalQuests, maxQuests)

    LayoutRequestedButtons(postCombat)

    SafeCall(self, "PostCheckQuestTracking")

    local hooks = self.updateHooks or {}
    for i = 1, #hooks do
        local fn = hooks[i]
        if type(fn) == "function" then
            pcall(fn)
        end
    end
end

local function EnsureSavedVariables()
    QuestKingDB = QuestKingDB or {}
    QuestKingDBPerChar = QuestKingDBPerChar or {}

    QuestKingDBPerChar.version = QuestKingDBPerChar.version or 2
    QuestKingDBPerChar.collapsedHeaders = QuestKingDBPerChar.collapsedHeaders or {}
    QuestKingDBPerChar.collapsedQuests = QuestKingDBPerChar.collapsedQuests or {}
    QuestKingDBPerChar.collapsedAchievements = QuestKingDBPerChar.collapsedAchievements or {}
    QuestKingDBPerChar.trackerCollapsed = QuestKingDBPerChar.trackerCollapsed or 0
    QuestKingDBPerChar.displayMode = QuestKingDBPerChar.displayMode or "combined"
    QuestKingDBPerChar.trackerPositionPreset = QuestKingDBPerChar.trackerPositionPreset or 1

    if QuestKingDB.dbTrackerAlpha == nil then
        QuestKingDB.dbTrackerAlpha = nil
    end

    if QuestKingDB.dbTrackerScale == nil then
        QuestKingDB.dbTrackerScale = nil
    end

    QuestKingDB.dragLocked = QuestKingDB.dragLocked == true
    QuestKingDB.dragOrigin = QuestKingDB.dragOrigin or "TOPRIGHT"
    QuestKingDB.dragRelativePoint = QuestKingDB.dragRelativePoint or QuestKingDB.dragOrigin
    QuestKingDB.dragX = tonumber(QuestKingDB.dragX)
    QuestKingDB.dragY = tonumber(QuestKingDB.dragY)
end

local function HookTrackingFunctions()
    if trackingHooksInstalled then
        return
    end

    trackingHooksInstalled = true

    if not hooksecurefunc then
        return
    end

    if C_QuestLog and C_QuestLog.AddQuestWatch then
        hooksecurefunc(C_QuestLog, "AddQuestWatch", hookAddQuestWatch_Retail)
    end

    if C_QuestLog and C_QuestLog.RemoveQuestWatch then
        hooksecurefunc(C_QuestLog, "RemoveQuestWatch", hookRemoveQuestWatch_Retail)
    end

    if AddQuestWatch then
        hooksecurefunc("AddQuestWatch", hookAddQuestWatch_Legacy)
    end

    if RemoveQuestWatch then
        hooksecurefunc("RemoveQuestWatch", hookRemoveQuestWatch_Legacy)
    end

    if AddAutoQuestPopUp then
        hooksecurefunc("AddAutoQuestPopUp", hookAddAutoQuestPopUp)
    end

    if AddTrackedAchievement then
        hooksecurefunc("AddTrackedAchievement", hookAddTrackedAchievement_Legacy)
    end

    if RemoveTrackedAchievement then
        hooksecurefunc("RemoveTrackedAchievement", hookRemoveTrackedAchievement_Legacy)
    end

    if C_ContentTracking and C_ContentTracking.StartTracking then
        hooksecurefunc(C_ContentTracking, "StartTracking", hookStartTracking_ContentTracking)
    end

    if C_ContentTracking and C_ContentTracking.StopTracking then
        hooksecurefunc(C_ContentTracking, "StopTracking", hookStopTracking_ContentTracking)
    end
end

function QuestKing:Init()
    if initialized then
        self:UpdateTracker()
        return
    end

    EnsureSavedVariables()

    self.updateHooks = self.updateHooks or {}
    self.newlyAddedQuests = self.newlyAddedQuests or {}
    self.trackedAchievements = self.trackedAchievements or {}

    SafeCall(self, "InitLoot")

    if opt.disableBlizzard then
        SafeCall(self, "DisableBlizzard")
    end

    HookTrackingFunctions()

    if Tracker and Tracker.Init then
        Tracker:Init()
    end

    if self.SyncTrackedAchievementCacheFromAPIs then
        self:SyncTrackedAchievementCacheFromAPIs()
    end

    initialized = true
    self:UpdateTracker()
end