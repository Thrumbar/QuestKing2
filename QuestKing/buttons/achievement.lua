local addonName, QuestKing = ...

local WatchButton = QuestKing.WatchButton
local opt = QuestKing.options or {}
local opt_colors = opt.colors or {}

local C_AchievementInfo = C_AchievementInfo
local C_ContentTracking = C_ContentTracking
local C_Timer = C_Timer
local Enum = Enum

local format = string.format
local pairs = pairs
local sort = table.sort
local tinsert = table.insert
local tostring = tostring
local type = type
local GetTime = GetTime

local NORMAL_FONT_COLOR = NORMAL_FONT_COLOR or { r = 1, g = 0.82, b = 0 }
local WHITE_COLOR = { r = 1, g = 1, b = 1 }
local RED_COLOR = { r = 1, g = 0.2, b = 0.2 }

local SECTION_HEADER_COLOR = opt_colors.SectionHeader or { 1.0, 0.82, 0.0 }
local TITLE_COLOR = opt_colors.ScenarioStageTitle or { 1.0, 0.82, 0.0 }
local COMPLETE_TITLE_COLOR = opt_colors.ObjectiveComplete or { 0.2, 1.0, 0.2 }
local COMPLETE_OBJECTIVE_COLOR = opt_colors.ObjectiveGradientComplete or { 0.6, 1.0, 0.6 }
local TIMER_COLOR = opt_colors.ScenarioTimer or { 0.8, 0.25, 0.25 }
local ALERT_GLOW_COLOR = opt_colors.ObjectiveAlertGlow or { 1.0, 0.5, 0.2 }

local GetObjectiveColor = QuestKing.GetObjectiveColor or function()
    return 1, 1, 1
end

local GetTimeStringFromSecondsShort = QuestKing.GetTimeStringFromSecondsShort or function(seconds)
    seconds = tonumber(seconds) or 0
    if seconds < 0 then
        seconds = 0
    end
    return tostring(seconds)
end

local CONTENT_TRACKING_TYPE_ACHIEVEMENT =
    Enum
    and Enum.ContentTrackingType
    and Enum.ContentTrackingType.Achievement

local CONTENT_TRACKING_STOP_MANUAL =
    Enum
    and Enum.ContentTrackingStopType
    and Enum.ContentTrackingStopType.Manual

local function SafeCall(func, ...)
    if type(func) ~= "function" then
        return false, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil
    end

    local ok, a, b, c, d, e, f, g, h, i, j, k, l, m, n = pcall(func, ...)
    if ok then
        return true, a, b, c, d, e, f, g, h, i, j, k, l, m, n
    end

    return false, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil
end

local function SafeNumber(value, fallback)
    if type(value) == "number" then
        return value
    end

    local numberValue = tonumber(value)
    if type(numberValue) == "number" then
        return numberValue
    end

    return fallback
end

local function SafeString(value, fallback)
    if type(value) == "string" and value ~= "" then
        return value
    end

    return fallback
end

local function SafeBoolean(value, fallback)
    if value == nil then
        return fallback
    end

    return value and true or false
end

local function Clamp01(value)
    value = SafeNumber(value, 0) or 0

    if value < 0 then
        return 0
    end

    if value > 1 then
        return 1
    end

    return value
end

local function QueueTrackerRefresh(forceBuild)
    if type(QuestKing.QueueTrackerUpdate) == "function" then
        QuestKing:QueueTrackerUpdate(forceBuild, false)
    elseif type(QuestKing.UpdateTracker) == "function" then
        QuestKing:UpdateTracker(forceBuild, false)
    end
end

local function EnsureTrackedAchievementCache()
    QuestKing.trackedAchievements = type(QuestKing.trackedAchievements) == "table" and QuestKing.trackedAchievements or {}
    return QuestKing.trackedAchievements
end

local function HasModernContentTracking()
    return C_ContentTracking
        and CONTENT_TRACKING_TYPE_ACHIEVEMENT ~= nil
        and type(C_ContentTracking.GetTrackedIDs) == "function"
end

local function GetTrackedAchievementIDs()
    local ids = {}
    local seen = {}

    local function AddID(id)
        if type(id) == "number" and id > 0 and not seen[id] then
            seen[id] = true
            ids[#ids + 1] = id
        end
    end

    if HasModernContentTracking() then
        local ok, trackedIDs = SafeCall(C_ContentTracking.GetTrackedIDs, CONTENT_TRACKING_TYPE_ACHIEVEMENT)
        if ok and type(trackedIDs) == "table" then
            for index = 1, #trackedIDs do
                AddID(trackedIDs[index])
            end
        end
    end

    if type(GetNumTrackedAchievements) == "function" and type(GetTrackedAchievement) == "function" then
        local okCount, count = SafeCall(GetNumTrackedAchievements)
        count = okCount and (SafeNumber(count, 0) or 0) or 0

        for index = 1, count do
            local okID, achievementID = SafeCall(GetTrackedAchievement, index)
            if okID then
                AddID(achievementID)
            end
        end
    end

    if type(GetNumTrackedAchievements) == "function" and type(GetTrackedAchievementInfo) == "function" then
        local okCount, count = SafeCall(GetNumTrackedAchievements)
        count = okCount and (SafeNumber(count, 0) or 0) or 0

        for index = 1, count do
            local okInfo, a1, a2 = SafeCall(GetTrackedAchievementInfo, index)
            if okInfo then
                if type(a1) == "number" then
                    AddID(a1)
                elseif type(a2) == "number" then
                    AddID(a2)
                end
            end
        end
    end

    return ids
end

local function BuildTrackedAchievementSignature()
    local ids = GetTrackedAchievementIDs()

    if #ids == 0 then
        return ""
    end

    sort(ids)

    for index = 1, #ids do
        ids[index] = tostring(ids[index])
    end

    return table.concat(ids, ",")
end

function QuestKing:SyncTrackedAchievementCacheFromAPIs()
    local cache = {}
    local ids = GetTrackedAchievementIDs()

    for index = 1, #ids do
        cache[ids[index]] = true
    end

    self.trackedAchievements = cache
    return cache
end

QuestKing.EnsureTrackedAchievementCache = EnsureTrackedAchievementCache

local function RefreshAchievementUIState()
    if type(AchievementFrameAchievements_ForceUpdate) == "function" then
        SafeCall(AchievementFrameAchievements_ForceUpdate)
    end

    if type(WatchFrame_Update) == "function" then
        SafeCall(WatchFrame_Update)
    end
end

function QuestKing:QueueAchievementTrackerRefresh()
    self._achievementRefreshToken = (self._achievementRefreshToken or 0) + 1

    local token = self._achievementRefreshToken
    local attempts = 0

    local function RefreshStep()
        if token ~= QuestKing._achievementRefreshToken then
            return
        end

        local oldSignature = QuestKing._lastTrackedAchievementSignature or ""

        if type(QuestKing.SyncTrackedAchievementCacheFromAPIs) == "function" then
            QuestKing:SyncTrackedAchievementCacheFromAPIs()
        end

        local newSignature = BuildTrackedAchievementSignature()
        RefreshAchievementUIState()

        if newSignature ~= oldSignature or attempts >= 4 then
            QuestKing._lastTrackedAchievementSignature = newSignature
            QueueTrackerRefresh(true)
            return
        end

        attempts = attempts + 1

        if C_Timer and C_Timer.After then
            C_Timer.After(0.05, RefreshStep)
        else
            QueueTrackerRefresh(true)
        end
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(0, RefreshStep)
    else
        RefreshStep()
    end
end

local function IsAchievementTracked(achievementID)
    if type(achievementID) ~= "number" or achievementID <= 0 then
        return false
    end

    if C_ContentTracking and CONTENT_TRACKING_TYPE_ACHIEVEMENT ~= nil then
        if type(C_ContentTracking.IsTracking) == "function" then
            local ok, tracked = SafeCall(C_ContentTracking.IsTracking, CONTENT_TRACKING_TYPE_ACHIEVEMENT, achievementID)
            if ok then
                return tracked and true or false
            end
        end

        if type(C_ContentTracking.IsTrackingID) == "function" then
            local ok, tracked = SafeCall(C_ContentTracking.IsTrackingID, achievementID, CONTENT_TRACKING_TYPE_ACHIEVEMENT)
            if ok then
                return tracked and true or false
            end
        end
    end

    if type(IsTrackedAchievement) == "function" then
        local ok, tracked = SafeCall(IsTrackedAchievement, achievementID)
        if ok then
            return tracked and true or false
        end
    end

    local cache = EnsureTrackedAchievementCache()
    return cache[achievementID] and true or false
end

local function ToggleAchievementTracked(achievementID)
    if type(achievementID) ~= "number" or achievementID <= 0 then
        return
    end

    if C_ContentTracking and CONTENT_TRACKING_TYPE_ACHIEVEMENT ~= nil then
        local currentlyTracked = IsAchievementTracked(achievementID)

        if currentlyTracked then
            if type(C_ContentTracking.StopTracking) == "function" then
                if CONTENT_TRACKING_STOP_MANUAL ~= nil then
                    SafeCall(C_ContentTracking.StopTracking, CONTENT_TRACKING_TYPE_ACHIEVEMENT, achievementID, CONTENT_TRACKING_STOP_MANUAL)
                else
                    SafeCall(C_ContentTracking.StopTracking, CONTENT_TRACKING_TYPE_ACHIEVEMENT, achievementID)
                end
            end
        else
            if type(C_ContentTracking.StartTracking) == "function" then
                SafeCall(C_ContentTracking.StartTracking, CONTENT_TRACKING_TYPE_ACHIEVEMENT, achievementID)
            end
        end

        RefreshAchievementUIState()
        if type(QuestKing.QueueAchievementTrackerRefresh) == "function" then
            QuestKing:QueueAchievementTrackerRefresh()
        end
        return
    end

    if type(IsTrackedAchievement) == "function"
        and type(AddTrackedAchievement) == "function"
        and type(RemoveTrackedAchievement) == "function" then
        local okTracked, tracked = SafeCall(IsTrackedAchievement, achievementID)
        if okTracked and tracked then
            SafeCall(RemoveTrackedAchievement, achievementID)
        else
            SafeCall(AddTrackedAchievement, achievementID)
        end

        RefreshAchievementUIState()
        if type(QuestKing.QueueAchievementTrackerRefresh) == "function" then
            QuestKing:QueueAchievementTrackerRefresh()
        end
    end
end

local function GetAchievementInfoCompat(achievementID)
    if C_AchievementInfo and type(C_AchievementInfo.GetAchievementInfo) == "function" then
        local ok, info = SafeCall(C_AchievementInfo.GetAchievementInfo, achievementID)
        if ok and type(info) == "table" then
            return {
                id = SafeNumber(info.id, achievementID) or achievementID,
                name = SafeString(info.name, ("Achievement %d"):format(achievementID)),
                points = SafeNumber(info.points, 0) or 0,
                completed = SafeBoolean(info.completed, false),
                month = SafeNumber(info.month, nil),
                day = SafeNumber(info.day, nil),
                year = SafeNumber(info.year, nil),
                description = SafeString(info.description, ""),
                rewardText = SafeString(info.rewardText, nil),
                isStatistic = SafeBoolean(info.isStatistic, false),
                wasEarnedByMe = SafeBoolean(info.wasEarnedByMe, false),
                earnedBy = SafeString(info.earnedBy, nil),
                icon = SafeNumber(info.icon, nil),
            }
        end
    end

    if type(GetAchievementInfo) == "function" then
        local ok, a1, a2, a3, a4, a5, a6, a7, a8, _, a10, a11, _, a13, a14, a15 = SafeCall(GetAchievementInfo, achievementID)
        if ok then
            if type(a1) == "number" and type(a2) == "string" then
                return {
                    id = a1,
                    name = SafeString(a2, ("Achievement %d"):format(achievementID)),
                    points = SafeNumber(a3, 0) or 0,
                    completed = SafeBoolean(a4, false),
                    month = SafeNumber(a5, nil),
                    day = SafeNumber(a6, nil),
                    year = SafeNumber(a7, nil),
                    description = SafeString(a8, ""),
                    icon = SafeNumber(a10, nil),
                    rewardText = SafeString(a11, nil),
                    wasEarnedByMe = SafeBoolean(a13, false),
                    earnedBy = SafeString(a14, nil),
                    isStatistic = SafeBoolean(a15, false),
                }
            elseif type(a1) == "string" then
                return {
                    id = achievementID,
                    name = SafeString(a1, ("Achievement %d"):format(achievementID)),
                    points = SafeNumber(a2, 0) or 0,
                    completed = SafeBoolean(a3, false),
                    month = SafeNumber(a4, nil),
                    day = SafeNumber(a5, nil),
                    year = SafeNumber(a6, nil),
                    description = SafeString(a7, ""),
                    icon = SafeNumber(a10, nil),
                    rewardText = SafeString(a11, nil),
                    wasEarnedByMe = SafeBoolean(a13, false),
                    earnedBy = SafeString(a14, nil),
                    isStatistic = SafeBoolean(a15, false),
                }
            end
        end
    end

    return {
        id = achievementID,
        name = ("Achievement %d"):format(achievementID),
        points = 0,
        completed = false,
        description = "",
    }
end

local function GetAchievementNumCriteriaCompat(achievementID)
    if type(GetAchievementNumCriteria) == "function" then
        local ok, count = SafeCall(GetAchievementNumCriteria, achievementID)
        if ok then
            return SafeNumber(count, 0) or 0
        end
    end

    if C_AchievementInfo and type(C_AchievementInfo.GetAchievementNumCriteria) == "function" then
        local ok, count = SafeCall(C_AchievementInfo.GetAchievementNumCriteria, achievementID)
        if ok then
            return SafeNumber(count, 0) or 0
        end
    end

    return 0
end

local function GetAchievementCriteriaInfoCompat(achievementID, criteriaIndex)
    if C_AchievementInfo and type(C_AchievementInfo.GetCriteriaInfo) == "function" then
        local ok, info = SafeCall(C_AchievementInfo.GetCriteriaInfo, achievementID, criteriaIndex)
        if ok and type(info) == "table" then
            return {
                description = SafeString(info.description, ""),
                criteriaType = SafeNumber(info.criteriaType, 0) or 0,
                completed = SafeBoolean(info.completed, false),
                quantity = SafeNumber(info.quantity, 0) or 0,
                reqQuantity = SafeNumber(info.requiredQuantity, SafeNumber(info.maxQuantity, 0) or 0) or 0,
                flags = info.flags,
                assetID = info.assetID,
                quantityString = SafeString(info.quantityString, nil),
                criteriaID = SafeNumber(info.criteriaID, nil),
                eligible = info.isEligible,
                duration = SafeNumber(info.duration, nil),
                elapsed = SafeNumber(info.elapsed, nil),
            }
        end
    end

    if type(GetAchievementCriteriaInfo) == "function" then
        local ok, description, criteriaType, completed, quantity, reqQuantity, _, flags, assetID, quantityString, criteriaID, eligible, duration, elapsed =
            SafeCall(GetAchievementCriteriaInfo, achievementID, criteriaIndex)
        if ok then
            return {
                description = SafeString(description, ""),
                criteriaType = SafeNumber(criteriaType, 0) or 0,
                completed = SafeBoolean(completed, false),
                quantity = SafeNumber(quantity, 0) or 0,
                reqQuantity = SafeNumber(reqQuantity, 0) or 0,
                flags = flags,
                assetID = assetID,
                quantityString = SafeString(quantityString, nil),
                criteriaID = SafeNumber(criteriaID, nil),
                eligible = eligible,
                duration = SafeNumber(duration, nil),
                elapsed = SafeNumber(elapsed, nil),
            }
        end
    end

    return {
        description = "",
        criteriaType = 0,
        completed = false,
        quantity = 0,
        reqQuantity = 0,
    }
end

local function ShouldShowCompletedObjective()
    local value = opt.showCompletedObjectives
    return value == true or value == "always"
end

local function AddTooltipLine(tooltip, text, r, g, b)
    if tooltip and text and text ~= "" then
        tooltip:AddLine(text, r or 1, g or 1, b or 1, true)
    end
end

local function BuildCriteriaDisplay(criteria)
    local text = SafeString(criteria.description, nil) or SafeString(criteria.quantityString, nil) or "Objective"
    local quantity = SafeNumber(criteria.quantity, 0) or 0
    local reqQuantity = SafeNumber(criteria.reqQuantity, 0) or 0

    if reqQuantity > 0 then
        return text, quantity, reqQuantity, Clamp01(quantity / reqQuantity)
    end

    return text, nil, nil, criteria.completed and 1 or 0
end

local function AddAchievementTooltipObjectives(tooltip, achievementID)
    local count = GetAchievementNumCriteriaCompat(achievementID)
    if count <= 0 then
        return 0
    end

    AddTooltipLine(tooltip, QUEST_TOOLTIP_REQUIREMENTS or "Objectives", NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)

    local added = 0

    for index = 1, count do
        local criteria = GetAchievementCriteriaInfoCompat(achievementID, index)
        local text, quantity, reqQuantity, progress = BuildCriteriaDisplay(criteria)

        if criteria.completed then
            if ShouldShowCompletedObjective() then
                if quantity and reqQuantity then
                    AddTooltipLine(
                        tooltip,
                        format("- %s: %s/%s", text, tostring(quantity), tostring(reqQuantity)),
                        COMPLETE_OBJECTIVE_COLOR[1],
                        COMPLETE_OBJECTIVE_COLOR[2],
                        COMPLETE_OBJECTIVE_COLOR[3]
                    )
                else
                    AddTooltipLine(
                        tooltip,
                        "- " .. text,
                        COMPLETE_OBJECTIVE_COLOR[1],
                        COMPLETE_OBJECTIVE_COLOR[2],
                        COMPLETE_OBJECTIVE_COLOR[3]
                    )
                end
                added = added + 1
            end
        else
            local r, g, b = GetObjectiveColor(progress)

            if criteria.eligible == false then
                r, g, b = RED_COLOR.r, RED_COLOR.g, RED_COLOR.b
            end

            if quantity and reqQuantity then
                AddTooltipLine(
                    tooltip,
                    format("- %s: %s/%s", text, tostring(quantity), tostring(reqQuantity)),
                    r,
                    g,
                    b
                )
            else
                AddTooltipLine(
                    tooltip,
                    "- " .. text,
                    r,
                    g,
                    b
                )
            end
            added = added + 1

            if criteria.duration and criteria.elapsed and criteria.elapsed < criteria.duration then
                local remaining = criteria.duration - criteria.elapsed
                if remaining < 0 then
                    remaining = 0
                end

                AddTooltipLine(
                    tooltip,
                    "  Time Left: " .. GetTimeStringFromSecondsShort(remaining),
                    TIMER_COLOR[1],
                    TIMER_COLOR[2],
                    TIMER_COLOR[3]
                )
            end
        end
    end

    return added
end

local function AddHeader()
    local header = WatchButton:GetKeyed("header", "Achievements")
    header.title:SetText(TRACKER_HEADER_ACHIEVEMENTS or "Achievements")
    header.title:SetTextColor(SECTION_HEADER_COLOR[1], SECTION_HEADER_COLOR[2], SECTION_HEADER_COLOR[3])
    header.titleButton:EnableMouse(false)
    return header
end

local mouseHandlerAchievement = {}

function mouseHandlerAchievement:TitleButtonOnClick(mouseButton)
    local button = self.parent
    local achievementID = button and button.achievementID

    if type(achievementID) ~= "number" then
        return
    end

    if type(IsModifiedClick) == "function"
        and IsModifiedClick("CHATLINK")
        and type(ChatEdit_GetActiveWindow) == "function"
        and ChatEdit_GetActiveWindow()
        and type(GetAchievementLink) == "function" then
        local okLink, link = SafeCall(GetAchievementLink, achievementID)
        if okLink and link then
            ChatEdit_InsertLink(link)
            return
        end
    end

    if mouseButton == "RightButton" then
        ToggleAchievementTracked(achievementID)
        return
    end

    if not AchievementFrame and type(UIParentLoadAddOn) == "function" then
        SafeCall(UIParentLoadAddOn, "Blizzard_AchievementUI")
    end

    if AchievementFrame then
        if type(ShowUIPanel) == "function" then
            SafeCall(ShowUIPanel, AchievementFrame)
        else
            AchievementFrame:Show()
        end

        if type(AchievementFrame_SelectAchievement) == "function" then
            SafeCall(AchievementFrame_SelectAchievement, achievementID)
        elseif type(AchievementFrameAchievements_SelectAchievement) == "function" then
            SafeCall(AchievementFrameAchievements_SelectAchievement, achievementID)
        end
    end
end

function mouseHandlerAchievement:TitleButtonOnEnter()
    local button = self.parent
    local achievementID = button and button.achievementID

    if type(achievementID) ~= "number" then
        return
    end

    local info = GetAchievementInfoCompat(achievementID)

    local tooltip = QuestKing.PrepareTooltip and QuestKing:PrepareTooltip(self, opt.tooltipAnchor or "ANCHOR_RIGHT")
    if not tooltip then
        return
    end

    tooltip:SetText(info.name or "Achievement", 1, 0.82, 0)

    if info.points and info.points > 0 then
        if type(ACHIEVEMENT_TOOLTIP_POINTS) == "string" then
            AddTooltipLine(tooltip, format(ACHIEVEMENT_TOOLTIP_POINTS, info.points), WHITE_COLOR.r, WHITE_COLOR.g, WHITE_COLOR.b)
        else
            AddTooltipLine(tooltip, format("%d points", info.points), WHITE_COLOR.r, WHITE_COLOR.g, WHITE_COLOR.b)
        end
    end

    if info.description and info.description ~= "" then
        AddTooltipLine(tooltip, " ")
        AddTooltipLine(tooltip, info.description, WHITE_COLOR.r, WHITE_COLOR.g, WHITE_COLOR.b)
    end

    if info.rewardText and info.rewardText ~= "" then
        AddTooltipLine(tooltip, " ")
        AddTooltipLine(tooltip, REWARDS or "Rewards", NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
        AddTooltipLine(tooltip, info.rewardText, WHITE_COLOR.r, WHITE_COLOR.g, WHITE_COLOR.b)
    end

    local criteriaCount = GetAchievementNumCriteriaCompat(achievementID)
    local addedObjectives = 0

    if criteriaCount > 0 then
        AddTooltipLine(tooltip, " ")
        addedObjectives = AddAchievementTooltipObjectives(tooltip, achievementID)
    end

    if info.completed then
        AddTooltipLine(tooltip, " ")
        AddTooltipLine(tooltip, ACHIEVEMENT_COMPLETED or "Completed", COMPLETE_TITLE_COLOR[1], COMPLETE_TITLE_COLOR[2], COMPLETE_TITLE_COLOR[3])

        if info.month and info.day and info.year then
            if type(GUILD_NEWS_FORMAT_TIME) == "string" then
                AddTooltipLine(tooltip, format(GUILD_NEWS_FORMAT_TIME, info.month, info.day, info.year), 0.8, 0.8, 0.8)
            else
                AddTooltipLine(tooltip, format("%02d/%02d/%02d", info.month, info.day, info.year), 0.8, 0.8, 0.8)
            end
        end
    elseif criteriaCount > 0 and addedObjectives == 0 then
        AddTooltipLine(tooltip, " ")
        AddTooltipLine(tooltip, COMPLETE or "Complete", COMPLETE_OBJECTIVE_COLOR[1], COMPLETE_OBJECTIVE_COLOR[2], COMPLETE_OBJECTIVE_COLOR[3])
    end

    if IsAchievementTracked(achievementID) then
        AddTooltipLine(tooltip, " ")
        AddTooltipLine(tooltip, "Right-click to stop tracking", 0.7, 0.7, 0.7)
    else
        AddTooltipLine(tooltip, " ")
        AddTooltipLine(tooltip, "Right-click to track", 0.7, 0.7, 0.7)
    end

    tooltip:Show()
end

function mouseHandlerAchievement:TitleButtonOnLeave()
    if QuestKing.HideTooltip then
        QuestKing:HideTooltip()
    end
end

local function AddCriteriaLine(button, criteria)
    local text, quantity, reqQuantity, progress = BuildCriteriaDisplay(criteria)

    if criteria.completed then
        if not ShouldShowCompletedObjective() then
            return nil
        end

        local line = button:AddLine(
            format("  %s", text),
            quantity and reqQuantity and format(": %s/%s", tostring(quantity), tostring(reqQuantity)) or nil,
            COMPLETE_OBJECTIVE_COLOR[1],
            COMPLETE_OBJECTIVE_COLOR[2],
            COMPLETE_OBJECTIVE_COLOR[3]
        )

        if line and line.SetAlpha then
            line:SetAlpha(0.65)
            if line.right then
                line.right:SetAlpha(0.65)
            end
        end

        return line
    end

    local r, g, b = GetObjectiveColor(progress)

    if criteria.eligible == false then
        r, g, b = RED_COLOR.r, RED_COLOR.g, RED_COLOR.b
    end

    local rightText = nil
    if quantity and reqQuantity then
        rightText = format(": %s/%s", tostring(quantity), tostring(reqQuantity))
    end

    local line = button:AddLine(format("  %s", text), rightText, r, g, b)

    if line and quantity then
        local lastQuantity = SafeNumber(line._lastQuant, nil)
        if lastQuantity and quantity > lastQuantity and type(line.Flash) == "function" then
            line:Flash()
        end
        line._lastQuant = quantity
    end

    if criteria.duration and criteria.elapsed and criteria.elapsed < criteria.duration and type(button.AddTimerBar) == "function" then
        local timerBar = button:AddTimerBar(criteria.duration, GetTime() - criteria.elapsed)
        if timerBar and type(timerBar.SetStatusBarColor) == "function" then
            timerBar:SetStatusBarColor(TIMER_COLOR[1], TIMER_COLOR[2], TIMER_COLOR[3])
        end
    end

    return line
end

local function SetButtonToAchievement(button, achievementID)
    local info = GetAchievementInfoCompat(achievementID)

    button.mouseHandler = mouseHandlerAchievement
    button.achievementID = achievementID

    if info.completed then
        button.title:SetFormattedTextIcon("|TInterface\\RAIDFRAME\\ReadyCheck-Ready:0:0:1:1|t %s", info.name)
        button.title:SetTextColor(COMPLETE_TITLE_COLOR[1], COMPLETE_TITLE_COLOR[2], COMPLETE_TITLE_COLOR[3])
    else
        button.title:SetText(info.name)
        button.title:SetTextColor(TITLE_COLOR[1], TITLE_COLOR[2], TITLE_COLOR[3])
    end

    local count = GetAchievementNumCriteriaCompat(achievementID)
    for index = 1, count do
        AddCriteriaLine(button, GetAchievementCriteriaInfoCompat(achievementID, index))
    end

    if button.fresh and type(button.lines) == "table" then
        for index = 1, #button.lines do
            local line = button.lines[index]
            if line then
                if type(line.Glow) == "function" then
                    line:Glow(ALERT_GLOW_COLOR[1], ALERT_GLOW_COLOR[2], ALERT_GLOW_COLOR[3])
                elseif type(line.Pulse) == "function" then
                    line:Pulse()
                end
            end
        end
    end
end

function QuestKing:UpdateTrackerAchievements()
    local cache = self.SyncTrackedAchievementCacheFromAPIs and self:SyncTrackedAchievementCacheFromAPIs() or EnsureTrackedAchievementCache()
    local ids = {}

    for achievementID, tracked in pairs(cache) do
        if tracked and type(achievementID) == "number" then
            ids[#ids + 1] = achievementID
        end
    end

    if #ids == 0 then
        return
    end

    sort(ids, function(a, b)
        local infoA = GetAchievementInfoCompat(a)
        local infoB = GetAchievementInfoCompat(b)

        if infoA.completed ~= infoB.completed then
            return not infoA.completed
        end

        local nameA = SafeString(infoA.name, tostring(a))
        local nameB = SafeString(infoB.name, tostring(b))

        if nameA ~= nameB then
            return nameA < nameB
        end

        return a < b
    end)

    local header = AddHeader()

    for index = 1, #ids do
        local achievementID = ids[index]
        local button = WatchButton:GetKeyed("achievement", achievementID)
        button._previousHeader = header
        SetButtonToAchievement(button, achievementID)
    end
end

function QuestKing:OnTrackedAchievementListChanged()
    self:QueueAchievementTrackerRefresh()
end

function QuestKing:OnTrackedAchievementUpdate()
    self:QueueAchievementTrackerRefresh()
end

function QuestKing:OnAchievementCriteriaUpdate()
    self:QueueAchievementTrackerRefresh()
end

function QuestKing:OnAchievementEarned()
    self:QueueAchievementTrackerRefresh()
end
