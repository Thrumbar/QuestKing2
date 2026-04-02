-- achievement.lua (QuestKing)
-- Renders tracked achievements in the custom watch window.
-- Midnight-safe tooltip handling:
--   - never stores addon state on GameTooltip
--   - never rescales Blizzard's shared GameTooltip
--   - only uses SetOwner / AddLine / Show

local addonName, QuestKing = ...

local opt = QuestKing.options
local opt_colors = opt.colors
local WatchButton = QuestKing.WatchButton
local GetObjectiveColor = QuestKing.GetObjectiveColor

local format = string.format
local sort = table.sort
local tinsert = table.insert
local tconcat = table.concat
local type = type
local pairs = pairs
local tostring = tostring
local GetTime = GetTime

local HAS_CONTENT_TRACKING = C_ContentTracking and Enum and Enum.ContentTrackingType
local HAS_C_ACHIEVEMENTINFO = C_AchievementInfo and C_AchievementInfo.GetAchievementInfo

local function EnsureTrackedAchievementCache()
    QuestKing.trackedAchievements = QuestKing.trackedAchievements or {}
    return QuestKing.trackedAchievements
end

local function Safe_GetTrackedAchievementIDs()
    local ids = {}
    local seen = {}

    local function AddID(id)
        if type(id) == "number" and not seen[id] then
            seen[id] = true
            tinsert(ids, id)
        end
    end

    if HAS_CONTENT_TRACKING then
        local ok, list

        if C_ContentTracking.GetTrackedIDsByType then
            ok, list = pcall(C_ContentTracking.GetTrackedIDsByType, Enum.ContentTrackingType.Achievement)
        elseif C_ContentTracking.GetTrackedIDs then
            ok, list = pcall(C_ContentTracking.GetTrackedIDs, Enum.ContentTrackingType.Achievement)
        end

        if ok and type(list) == "table" then
            for _, entry in pairs(list) do
                if type(entry) == "number" then
                    AddID(entry)
                elseif type(entry) == "table" then
                    AddID(entry.id or entry.achievementID or entry.contentID)
                end
            end
        end
    end

    if GetNumTrackedAchievements and GetTrackedAchievement then
        local num = GetNumTrackedAchievements() or 0
        for i = 1, num do
            AddID(GetTrackedAchievement(i))
        end
    end

    if GetNumTrackedAchievements and GetTrackedAchievementInfo then
        local num = GetNumTrackedAchievements() or 0
        for i = 1, num do
            AddID(select(1, GetTrackedAchievementInfo(i)))
        end
    end

    return ids
end

local function SyncTrackedAchievementCacheFromAPIs()
    local cache = {}
    local ids = Safe_GetTrackedAchievementIDs()

    for i = 1, #ids do
        local id = ids[i]
        if type(id) == "number" then
            cache[id] = true
        end
    end

    QuestKing.trackedAchievements = cache
    return cache
end

QuestKing.EnsureTrackedAchievementCache = EnsureTrackedAchievementCache
QuestKing.SyncTrackedAchievementCacheFromAPIs = SyncTrackedAchievementCacheFromAPIs

local function Safe_GetAchievementInfo(achievementID)
    if HAS_C_ACHIEVEMENTINFO then
        local info = C_AchievementInfo.GetAchievementInfo(achievementID)
        if info and type(info) == "table" then
            return info.name, info.points or 0, info.completed or false, info.month, info.day, info.year, info.description
        end
    end

    if GetAchievementInfo then
        local a1, a2, a3, a4, a5, a6, a7, a8 = GetAchievementInfo(achievementID)

        if type(a1) == "number" and type(a2) == "string" then
            return a2, a3 or 0, a4 or false, a5, a6, a7, a8
        end

        if type(a1) == "string" then
            return a1, a3 or 0, a4 or false, a5, a6, a7, a8
        end
    end

    return ("Achievement %d"):format(achievementID), 0, false, nil, nil, nil, ""
end

local function Safe_GetAchievementNumCriteria(achievementID)
    if GetAchievementNumCriteria then
        return GetAchievementNumCriteria(achievementID)
    end

    if C_AchievementInfo and C_AchievementInfo.GetAchievementNumCriteria then
        return C_AchievementInfo.GetAchievementNumCriteria(achievementID)
    end

    return 0
end

local function Safe_GetAchievementCriteriaInfo(achievementID, index)
    if C_AchievementInfo and C_AchievementInfo.GetCriteriaInfo then
        local c = C_AchievementInfo.GetCriteriaInfo(achievementID, index)
        if c then
            return c.description or "",
                c.criteriaType or 0,
                c.completed or false,
                c.quantity or 0,
                c.requiredQuantity or c.maxQuantity or 0,
                c.flags,
                c.assetID,
                c.quantityString,
                c.criteriaID,
                c.isEligible,
                c.duration,
                c.elapsed
        end
    end

    if GetAchievementCriteriaInfo then
        return GetAchievementCriteriaInfo(achievementID, index)
    end

    return "", 0, false, 0, 0
end

local function Safe_IsTracked(achievementID)
    if HAS_CONTENT_TRACKING and C_ContentTracking.IsTrackingID then
        local ok, tracked = pcall(C_ContentTracking.IsTrackingID, achievementID, Enum.ContentTrackingType.Achievement)
        if ok then
            return tracked and true or false
        end
    end

    if IsTrackedAchievement then
        return IsTrackedAchievement(achievementID)
    end

    local cache = EnsureTrackedAchievementCache()
    return cache[achievementID] and true or false
end

local function Safe_RefreshAchievementUIs()
    if AchievementFrameAchievements_ForceUpdate then
        pcall(AchievementFrameAchievements_ForceUpdate)
    end

    if WatchFrame_Update then
        pcall(WatchFrame_Update)
    end
end

local function BuildTrackedAchievementSignature()
    local ids = Safe_GetTrackedAchievementIDs()
    if not ids or #ids == 0 then
        return ""
    end

    sort(ids)

    local parts = {}
    for i = 1, #ids do
        parts[i] = tostring(ids[i])
    end

    return tconcat(parts, ",")
end

function QuestKing:QueueAchievementTrackerRefresh()
    QuestKing._achievementRefreshToken = (QuestKing._achievementRefreshToken or 0) + 1

    local token = QuestKing._achievementRefreshToken
    local attempts = 0

    local function RefreshStep()
        if token ~= QuestKing._achievementRefreshToken then
            return
        end

        local oldSignature = QuestKing._lastTrackedAchievementSignature or ""
        local newSignature = BuildTrackedAchievementSignature()

        if QuestKing.SyncTrackedAchievementCacheFromAPIs then
            QuestKing:SyncTrackedAchievementCacheFromAPIs()
        end

        Safe_RefreshAchievementUIs()

        if newSignature ~= oldSignature or attempts >= 5 then
            QuestKing._lastTrackedAchievementSignature = newSignature

            if QuestKing.UpdateTracker then
                QuestKing:UpdateTracker(true)
            end
            return
        end

        attempts = attempts + 1

        if C_Timer and C_Timer.After then
            C_Timer.After(0.05, RefreshStep)
        else
            if QuestKing.UpdateTracker then
                QuestKing:UpdateTracker(true)
            end
        end
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(0, RefreshStep)
    else
        RefreshStep()
    end
end

local function Safe_ToggleTracked(achievementID)
    if HAS_CONTENT_TRACKING and C_ContentTracking then
        local isTracked = Safe_IsTracked(achievementID)

        if isTracked then
            if C_ContentTracking.StopTracking then
                C_ContentTracking.StopTracking(Enum.ContentTrackingType.Achievement, achievementID)
            end
        else
            if C_ContentTracking.StartTracking then
                C_ContentTracking.StartTracking(Enum.ContentTrackingType.Achievement, achievementID)
            end
        end

        Safe_RefreshAchievementUIs()

        if QuestKing.QueueAchievementTrackerRefresh then
            QuestKing:QueueAchievementTrackerRefresh()
        end

        return
    end

    if IsTrackedAchievement and AddTrackedAchievement and RemoveTrackedAchievement then
        if IsTrackedAchievement(achievementID) then
            RemoveTrackedAchievement(achievementID)
        else
            AddTrackedAchievement(achievementID)
        end

        Safe_RefreshAchievementUIs()

        if QuestKing.QueueAchievementTrackerRefresh then
            QuestKing:QueueAchievementTrackerRefresh()
        end
    end
end

local function addHeader()
    local header = WatchButton:GetKeyed("header", "Achievements")
    header.title:SetText(TRACKER_HEADER_ACHIEVEMENTS or "Achievements")
    header.title:SetTextColor(
        opt_colors.SectionHeader[1],
        opt_colors.SectionHeader[2],
        opt_colors.SectionHeader[3]
    )
    return header
end

local mouseHandlerAchievement = {}

function mouseHandlerAchievement:TitleButtonOnClick(mouse)
    local button = self.parent
    local achievementID = button.achievementID

    if IsModifiedClick and IsModifiedClick("CHATLINK") and ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow() and GetAchievementLink then
        local link = GetAchievementLink(achievementID)
        if link then
            ChatEdit_InsertLink(link)
            return
        end
    end

    if mouse == "RightButton" then
        Safe_ToggleTracked(achievementID)
        return
    end

    if not AchievementFrame and UIParentLoadAddOn then
        UIParentLoadAddOn("Blizzard_AchievementUI")
    end

    if AchievementFrame then
        ShowUIPanel(AchievementFrame)

        if AchievementFrame_SelectAchievement then
            AchievementFrame_SelectAchievement(achievementID)
        elseif AchievementFrameAchievements_SelectAchievement then
            AchievementFrameAchievements_SelectAchievement(achievementID)
        end
    end
end

function mouseHandlerAchievement:TitleButtonOnEnter()
    local button = self.parent
    local achievementID = button.achievementID
    local name, points, completed, month, day, year, desc = Safe_GetAchievementInfo(achievementID)

    local tooltip = QuestKing.PrepareTooltip and QuestKing:PrepareTooltip(self, opt.tooltipAnchor or "ANCHOR_RIGHT")
    if not tooltip then
        return
    end

    tooltip:SetText(name or "Achievement", 1, 0.914, 0.682, 1)

    if points and points > 0 then
        local pointsText
        if type(ACHIEVEMENT_TOOLTIP_POINTS) == "string" then
            pointsText = format(ACHIEVEMENT_TOOLTIP_POINTS, points)
        else
            pointsText = ("%d points"):format(points)
        end
        tooltip:AddLine(pointsText, 1, 1, 1, 1)
    end

    tooltip:AddLine(" ")

    if desc and desc ~= "" then
        tooltip:AddLine(desc, 1, 1, 1, 1)
    end

    if completed then
        tooltip:AddLine(" ")
        tooltip:AddLine(ACHIEVEMENT_COMPLETED or "Completed", 0.2, 0.9, 0.2, 1)

        if month and day and year and type(GUILD_NEWS_FORMAT_TIME) == "string" then
            tooltip:AddLine(format(GUILD_NEWS_FORMAT_TIME, month, day, year), 0.8, 0.8, 0.8, 1)
        end
    end

    tooltip:Show()
end

local function ShouldShowCompletedAchievementObjective()
    local value = opt.showCompletedObjectives
    return value == true or value == "always"
end

local function setButtonToAchievement(button, achievementID)
    button.mouseHandler = mouseHandlerAchievement
    button.achievementID = achievementID

    local name, points, completed = Safe_GetAchievementInfo(achievementID)
    name = name or ("Achievement %d"):format(achievementID)

    if completed then
        button.title:SetFormattedTextIcon("|TInterface\\RAIDFRAME\\ReadyCheck-Ready:0:0:1:1|t %s", name)
        button.title:SetTextColor(
            opt_colors.ObjectiveComplete[1],
            opt_colors.ObjectiveComplete[2],
            opt_colors.ObjectiveComplete[3]
        )
    else
        button.title:SetText(name)
        button.title:SetTextColor(
            opt_colors.ScenarioStageTitle[1],
            opt_colors.ScenarioStageTitle[2],
            opt_colors.ScenarioStageTitle[3]
        )
    end

    local numCriteria = Safe_GetAchievementNumCriteria(achievementID) or 0
    if numCriteria > 0 then
        for i = 1, numCriteria do
            local desc, cType, cDone, qty, req, flags, assetID, qtyString, criteriaID, eligible, duration, elapsed =
                Safe_GetAchievementCriteriaInfo(achievementID, i)

            if (not desc or desc == "") and qtyString then
                desc = qtyString
            elseif not desc or desc == "" then
                desc = "Objective"
            end

            if cDone then
                if ShouldShowCompletedAchievementObjective() then
                    button:AddLine(
                        format("  %s", desc),
                        nil,
                        opt_colors.ObjectiveGradientComplete[1],
                        opt_colors.ObjectiveGradientComplete[2],
                        opt_colors.ObjectiveGradientComplete[3]
                    )
                end
            else
                local rightText

                if req and req > 0 then
                    local fraction = 0

                    if qty and req and req > 0 then
                        fraction = qty / req
                        if fraction < 0 then
                            fraction = 0
                        elseif fraction > 1 then
                            fraction = 1
                        end
                    end

                    rightText = format(": %s/%s", tostring(qty or 0), tostring(req))

                    local r, g, b = GetObjectiveColor(fraction)
                    local line = button:AddLine(format("  %s", desc), rightText, r, g, b)

                    local last = line._lastQuant or 0
                    if (qty or 0) > last and type(line.Flash) == "function" then
                        line:Flash()
                    end
                    line._lastQuant = qty or 0
                else
                    local r, g, b = GetObjectiveColor(0)
                    button:AddLine(format("  %s", desc), nil, r, g, b)
                end

                if duration and elapsed and elapsed < duration and type(button.AddTimerBar) == "function" then
                    local timerBar = button:AddTimerBar(duration, GetTime() - elapsed)
                    if timerBar and type(timerBar.SetStatusBarColor) == "function" then
                        timerBar:SetStatusBarColor(
                            opt_colors.ScenarioTimer[1],
                            opt_colors.ScenarioTimer[2],
                            opt_colors.ScenarioTimer[3]
                        )
                    end
                end
            end
        end
    end

    if button.fresh then
        local lines = button.lines
        for i = 1, #lines do
            local line = lines[i]
            if line then
                if type(line.Glow) == "function" then
                    line:Glow(
                        opt_colors.ObjectiveAlertGlow[1],
                        opt_colors.ObjectiveAlertGlow[2],
                        opt_colors.ObjectiveAlertGlow[3]
                    )
                elseif type(line.Pulse) == "function" then
                    line:Pulse()
                end
            end
        end
    end
end

function QuestKing:UpdateTrackerAchievements()
    local cache
    if QuestKing.SyncTrackedAchievementCacheFromAPIs then
        cache = QuestKing:SyncTrackedAchievementCacheFromAPIs()
    else
        cache = EnsureTrackedAchievementCache()
    end

    local ids = {}

    for id, tracked in pairs(cache) do
        if tracked and type(id) == "number" then
            ids[#ids + 1] = id
        end
    end

    if #ids == 0 then
        return
    end

    sort(ids)

    local header = addHeader()

    for i = 1, #ids do
        local achievementID = ids[i]
        local button = WatchButton:GetKeyed("achievement", achievementID)
        button._previousHeader = header
        setButtonToAchievement(button, achievementID)
    end
end

function QuestKing:OnTrackedAchievementListChanged(...)
    QuestKing:QueueAchievementTrackerRefresh()
end

function QuestKing:OnTrackedAchievementUpdate(...)
    QuestKing:QueueAchievementTrackerRefresh()
end

function QuestKing:OnAchievementCriteriaUpdate(...)
    QuestKing:QueueAchievementTrackerRefresh()
end

function QuestKing:OnAchievementEarned(...)
    QuestKing:QueueAchievementTrackerRefresh()
end