local addonName, QuestKing = ...

if type(QuestKing) ~= "table" then
    return
end

local _G = _G
local CreateFrame = _G.CreateFrame

local floor = math.floor
local max = math.max
local min = math.min
local pcall = pcall
local tonumber = tonumber
local tostring = tostring
local type = type

local DEFAULT_WIDTH = 230
local DEFAULT_TITLE_HEIGHT = 18
local MIN_CONTENT_WIDTH = 120
local MAX_CONTENT_WIDTH = 500
local SECTION_GAP = 4
local HEADER_CONTENT_GAP = 4
local BAR_HEIGHT = 14
local LINE_HEIGHT = 15
local LINE_GAP = 4
local FIRST_LINE_GAP = 10
local QUEST_PROGRESS_BAR_LEFT_INSET = 16
local QUEST_PROGRESS_BAR_MIN_WIDTH = 80
local QUEST_PROGRESS_BAR_RIGHT_INSET = 20
local MAP_RETRY_DELAYS = { 0.1, 0.25, 0.5, 1, 2 }

local Adapter = QuestKing.PetTrackerAdapter or {}
QuestKing.PetTrackerAdapter = Adapter

local runtimeAddon = nil
local section = nil
local petTrackerFrame = nil
local signalHooked = false
local updateHookRegistered = false
local lifecycleEventsRegistered = false
local runtimeErrorReported = false
local layoutInProgress = false
local contentDirty = true
local worldReady = false
local layoutDeferred = false
local mapRetryAttempt = 0
local mapRetryGeneration = 0
local mapRetryQueued = false

local function ReportRuntimeError(message)
    if runtimeErrorReported then
        return
    end

    runtimeErrorReported = true

    if type(_G.geterrorhandler) == "function" then
        local ok, handler = pcall(_G.geterrorhandler)
        if ok and type(handler) == "function" then
            pcall(handler, "QuestKing PetTracker adapter: " .. tostring(message))
        end
    end
end

local function SafeCallMethod(target, methodName, ...)
    if type(target) ~= "table" then
        return false, nil
    end

    local method = target[methodName]
    if type(method) ~= "function" then
        return false, nil
    end

    local ok, result = pcall(method, target, ...)
    if not ok then
        ReportRuntimeError(result)
        return false, nil
    end

    return true, result
end

local function QueueTrackerRefresh()
    if type(QuestKing.RequestTrackerUpdate) == "function" then
        QuestKing:RequestTrackerUpdate(false, "pettracker", false)
    elseif type(QuestKing.QueueTrackerUpdate) == "function" then
        QuestKing:QueueTrackerUpdate(false, false, "pettracker")
    elseif type(QuestKing.UpdateTracker) == "function" then
        QuestKing:UpdateTracker(false, false, "pettracker")
    end
end

local function MarkContentDirty()
    contentDirty = true
end

local function ResetMapRetries()
    if mapRetryAttempt == 0 and not mapRetryQueued then
        return
    end

    mapRetryGeneration = mapRetryGeneration + 1
    mapRetryAttempt = 0
    mapRetryQueued = false
end

local function RunMapRetry(generation)
    if generation ~= mapRetryGeneration then
        return
    end

    mapRetryQueued = false
    MarkContentDirty()
    QueueTrackerRefresh()
end

local function QueueMapRetry()
    if mapRetryQueued then
        return
    end

    local nextAttempt = mapRetryAttempt + 1
    local delay = MAP_RETRY_DELAYS[nextAttempt]
    local timer = _G.C_Timer
    if not delay
        or type(timer) ~= "table"
        or type(timer.After) ~= "function" then
        return
    end

    mapRetryAttempt = nextAttempt
    mapRetryQueued = true

    local generation = mapRetryGeneration
    timer.After(delay, function()
        RunMapRetry(generation)
    end)
end

local function GetRuntimeAddon()
    local addon = _G.PetTracker
    if type(addon) ~= "table"
        or type(addon.sets) ~= "table"
        or type(addon.Tracker) ~= "table"
        or type(addon.Maps) ~= "table"
        or type(addon.Maps.GetCurrentProgress) ~= "function" then
        return nil
    end

    return addon
end

local function IsSecretValue(value)
    if type(_G.issecretvalue) ~= "function" then
        return false
    end

    local ok, secret = pcall(_G.issecretvalue, value)
    return ok and secret == true
end

local function IsInCombatLockdownSafe()
    if type(_G.InCombatLockdown) ~= "function" then
        return false
    end

    local ok, inCombat = pcall(_G.InCombatLockdown)
    if not ok or IsSecretValue(inCombat) then
        return true
    end

    return inCombat and true or false
end

local function IsProtectedFrameSafe(frame)
    if not frame or type(frame.IsProtected) ~= "function" then
        return true
    end

    local ok, protected = pcall(frame.IsProtected, frame)
    if not ok or IsSecretValue(protected) then
        return true
    end

    return protected == true
end

local function ShouldDeferLayout()
    if not IsInCombatLockdownSafe() then
        return false
    end

    return IsProtectedFrameSafe(QuestKing.Tracker)
        or (section and IsProtectedFrameSafe(section))
        or (petTrackerFrame and IsProtectedFrameSafe(petTrackerFrame))
end

local function DeferLayoutUntilAfterCombat()
    layoutDeferred = true
    if type(QuestKing.StartCombatTimer) == "function" then
        QuestKing:StartCombatTimer()
    end
end

local function GetLastRequestedRow()
    local watchButton = QuestKing.WatchButton
    local requestOrder = type(watchButton) == "table" and watchButton.requestOrder or nil
    local requestCount = type(watchButton) == "table"
        and tonumber(watchButton.requestCount)
        or 0

    if type(requestOrder) ~= "table" then
        return nil
    end

    for index = requestCount, 1, -1 do
        local row = requestOrder[index]
        if row and type(row.IsShown) == "function" and row:IsShown() then
            return row
        end
    end

    return nil
end

local function GetContentHeight(lineCount)
    lineCount = max(0, floor(tonumber(lineCount) or 0))
    if lineCount == 0 then
        return BAR_HEIGHT
    end

    return BAR_HEIGHT
        + FIRST_LINE_GAP
        + (lineCount * LINE_HEIGHT)
        + ((lineCount - 1) * LINE_GAP)
end

local function GetQuestProgressBarWidth(buttonWidth)
    return max(
        QUEST_PROGRESS_BAR_MIN_WIDTH,
        buttonWidth
            - QUEST_PROGRESS_BAR_LEFT_INSET
            - QUEST_PROGRESS_BAR_RIGHT_INSET
    )
end

local function HideSection()
    Adapter.visible = false

    if not section then
        return
    end

    if type(section.IsShown) == "function"
        and section:IsShown()
        and type(section.Hide) == "function" then
        section:Hide()
    end
end

local function GetFontSettings()
    local options = QuestKing.options or {}
    local font = options.font or _G.STANDARD_TEXT_FONT or [[Fonts\FRIZQT__.TTF]]
    local fontSize = max(8, tonumber(options.fontSize) or 12)
    local fontStyle = options.fontStyle or "NONE"

    return font, fontSize, fontStyle
end

local function GetFontLayer()
    if QuestKing and type(QuestKing.GetFontLayer) == "function" then
        return QuestKing.GetFontLayer()
    end

    return "OVERLAY"
end

local function ApplyFontLayer(fontString)
    if QuestKing and type(QuestKing.ApplyFontLayer) == "function" then
        QuestKing.ApplyFontLayer(fontString)
    elseif fontString and type(fontString.SetDrawLayer) == "function" then
        fontString:SetDrawLayer(GetFontLayer())
    end
end

local function StyleHeader()
    if not section or not section.Header or not section.Header.Text then
        return
    end

    local options = QuestKing.options or {}
    local text = section.Header.Text
    local font, fontSize, fontStyle = GetFontSettings()
    local color = type(options.colors) == "table" and options.colors.SectionHeader or nil

    text:SetFont(font, fontSize, fontStyle)
    ApplyFontLayer(text)
    text:SetTextColor(
        type(color) == "table" and (color[1] or 1) or 1,
        type(color) == "table" and (color[2] or 0.82) or 0.82,
        type(color) == "table" and (color[3] or 0) or 0
    )
end

local function OpenPetTrackerMenu(header, mouseButton)
    if mouseButton ~= "RightButton" then
        return
    end

    local addon = runtimeAddon or GetRuntimeAddon()
    local menuUtil = _G.MenuUtil
    local createMenu = addon and addon.Tracker and addon.Tracker.CreateMenu
    if type(menuUtil) == "table"
        and type(menuUtil.CreateContextMenu) == "function"
        and type(createMenu) == "function" then
        local ok, err = pcall(menuUtil.CreateContextMenu, header, function(_, root)
            if type(root.SetTag) == "function" then
                root:SetTag("PETTRACKER_ZONE")
            end

            createMenu(root)
        end)

        if not ok then
            ReportRuntimeError(err)
        end
        return
    end

    if petTrackerFrame then
        SafeCallMethod(petTrackerFrame, "ToggleMenu")
    end
end

local function CreateSection()
    local tracker = QuestKing.Tracker
    if not tracker or type(CreateFrame) ~= "function" then
        return nil
    end

    local frame = CreateFrame("Frame", nil, tracker)
    frame:Hide()

    local header = CreateFrame("Button", nil, frame)
    header:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    header:RegisterForClicks("RightButtonUp")
    header:SetScript("OnClick", OpenPetTrackerMenu)
    header:SetHighlightTexture(
        [[Interface\QuestFrame\UI-QuestTitleHighlight]],
        "ADD"
    )

    local icon = header:CreateTexture(nil, "ARTWORK")
    icon:SetSize(16, 16)
    icon:SetPoint("LEFT", header, "LEFT", 2, 0)
    icon:SetTexture([[Interface\AddOns\PetTracker\art\compass]])

    local text = header:CreateFontString(nil, GetFontLayer())
    text:SetPoint("LEFT", icon, "RIGHT", 5, 0)
    text:SetPoint("RIGHT", header, "RIGHT", -4, 0)
    text:SetJustifyH("LEFT")
    text:SetJustifyV("MIDDLE")
    text:SetWordWrap(false)

    -- A FontString created without an inherited template has no usable font.
    -- Set the QuestKing font before assigning text; Retail 12.0.7/12.1 raises
    -- "FontString:SetText(): Font not set" when this order is reversed.
    local font, fontSize, fontStyle = GetFontSettings()
    text:SetFont(font, fontSize, fontStyle)
    ApplyFontLayer(text)
    text:SetText(_G.PETS or "Pets")

    header.Icon = icon
    header.Text = text
    frame.Header = header
    section = frame

    Adapter.Section = frame
    StyleHeader()

    return frame
end

local function InstallSignalHook(addon)
    if signalHooked
        or type(_G.hooksecurefunc) ~= "function"
        or type(addon) ~= "table"
        or type(addon.SendSignal) ~= "function" then
        return
    end

    local ok, err = pcall(
        _G.hooksecurefunc,
        addon,
        "SendSignal",
        function(_, signal)
            if signal == "OPTIONS_CHANGED" or signal == "COLLECTION_CHANGED" then
                MarkContentDirty()
                QueueTrackerRefresh()
            end
        end
    )

    if ok then
        signalHooked = true
    else
        ReportRuntimeError(err)
    end
end

local function CreatePetTrackerFrame(addon)
    if petTrackerFrame and runtimeAddon == addon then
        return petTrackerFrame, false
    end

    local parent = section or CreateSection()
    if not parent then
        return nil, false
    end

    local ok, frame = pcall(function()
        return addon.Tracker(parent)
    end)
    if not ok or type(frame) ~= "table" then
        ReportRuntimeError(frame or "PetTracker.Tracker did not create a frame.")
        return nil, false
    end

    if frame.Bar then
        -- PetTracker anchors its first species row to Bar and applies Bar.xOff.
        -- Counter the QuestKing bar inset so moving the bar does not move the
        -- PetTracker-owned species rows.
        frame.Bar.xOff = -QUEST_PROGRESS_BAR_LEFT_INSET
    end

    frame:ClearAllPoints()
    frame:SetPoint(
        "TOPLEFT",
        parent.Header,
        "BOTTOMLEFT",
        0,
        -HEADER_CONTENT_GAP
    )

    if type(frame.HookScript) == "function" then
        frame:HookScript("OnSizeChanged", function()
            if not layoutInProgress then
                QueueTrackerRefresh()
            end
        end)
    end

    runtimeAddon = addon
    petTrackerFrame = frame
    MarkContentDirty()

    Adapter.Frame = frame
    Adapter.Section = parent

    InstallSignalHook(addon)

    return frame, true
end

local function IsTrackerExpanded()
    local perCharacter = _G.QuestKingDBPerChar or {}
    return (tonumber(perCharacter.trackerCollapsed) or 0) == 0
end

local function ShouldShow(frame, addon)
    if not IsTrackerExpanded()
        or not addon.sets.zoneTracker then
        return false
    end

    local bar = frame.Bar
    if not bar or type(bar.IsMaximized) ~= "function" then
        return false
    end

    local ok, maximized = pcall(bar.IsMaximized, bar)
    return ok and not maximized
end

local function AnchorSection(tracker)
    section:ClearAllPoints()

    local lastRow = GetLastRequestedRow()
    if lastRow then
        section:SetPoint("TOPLEFT", lastRow, "BOTTOMLEFT", 0, -SECTION_GAP)
    else
        section:SetPoint("TOPLEFT", tracker.titlebar, "BOTTOMLEFT", 0, -1)
    end
end

local function ApplyLineLayout(frame, contentWidth)
    if type(frame.Lines) ~= "table" then
        return 0
    end

    local font, fontSize, fontStyle = GetFontSettings()

    for index = 1, #frame.Lines do
        local line = frame.Lines[index]
        if line and type(line.SetWidth) == "function" then
            line:SetWidth(contentWidth)
        end

        if line
            and line.Text
            and type(line.Text.SetFont) == "function" then
            line.Text:SetFont(font, fontSize, fontStyle)
            ApplyFontLayer(line.Text)
        end
    end

    return #frame.Lines
end

local function ApplySectionLayout(frame, tracker)
    local options = QuestKing.options or {}
    local width = max(
        MIN_CONTENT_WIDTH,
        tonumber(options.buttonWidth) or DEFAULT_WIDTH
    )
    width = min(MAX_CONTENT_WIDTH, width)

    local titleHeight = max(
        16,
        tonumber(options.titleHeight) or DEFAULT_TITLE_HEIGHT
    )
    local contentWidth = width - 4
    local barWidth = GetQuestProgressBarWidth(width)

    layoutInProgress = true
    local ok, err = pcall(function()
        section:SetWidth(width)
        section.Header:SetSize(width, titleHeight)
        StyleHeader()
        AnchorSection(tracker)

        frame:SetWidth(contentWidth)
        local bar = frame.Bar
        if bar
            and type(bar.ClearAllPoints) == "function"
            and type(bar.SetPoint) == "function"
            and type(bar.SetWidth) == "function" then
            bar.xOff = -QUEST_PROGRESS_BAR_LEFT_INSET
            bar:ClearAllPoints()
            bar:SetPoint(
                "TOPLEFT",
                frame,
                "TOPLEFT",
                QUEST_PROGRESS_BAR_LEFT_INSET,
                0
            )
            bar:SetWidth(barWidth)
        end

        local lineCount = ApplyLineLayout(frame, contentWidth)
        local contentHeight = GetContentHeight(lineCount)

        if type(frame.GetHeight) == "function" then
            local heightOk, nativeHeight = pcall(frame.GetHeight, frame)
            if heightOk
                and type(nativeHeight) == "number"
                and nativeHeight > contentHeight then
                contentHeight = nativeHeight
            end
        end

        section:SetHeight(
            titleHeight + HEADER_CONTENT_GAP + contentHeight
        )
    end)
    layoutInProgress = false

    if not ok then
        ReportRuntimeError(err)
        return false
    end

    return true
end

function Adapter:IsAvailable()
    return GetRuntimeAddon() ~= nil
end

function Adapter:IsVisible()
    return self.visible == true
end

function Adapter:Refresh()
    MarkContentDirty()
    if worldReady and GetRuntimeAddon() then
        QueueTrackerRefresh()
    end
end

function Adapter:OpenMenu()
    if section and section.Header then
        OpenPetTrackerMenu(section.Header, "RightButton")
        return true
    end

    return false
end

function Adapter:Layout()
    local tracker = QuestKing.Tracker
    if not tracker or not tracker.titlebar then
        HideSection()
        return
    end

    if ShouldDeferLayout() then
        DeferLayoutUntilAfterCombat()
        return
    end
    layoutDeferred = false

    local addon = GetRuntimeAddon()
    if not addon or not worldReady or not IsTrackerExpanded() then
        HideSection()
        return
    end

    InstallSignalHook(addon)
    if not addon.sets.zoneTracker then
        HideSection()
        return
    end

    local mapAPI = _G.C_Map
    if type(mapAPI) == "table"
        and type(mapAPI.GetBestMapForUnit) == "function" then
        local mapOk, mapID = pcall(mapAPI.GetBestMapForUnit, "player")
        if not mapOk or type(mapID) ~= "number" or mapID <= 0 then
            MarkContentDirty()
            QueueMapRetry()
            HideSection()
            return
        end
    end
    ResetMapRetries()

    local parent = section or CreateSection()
    if not parent then
        HideSection()
        return
    end

    -- PetTracker constructs and sizes its rows against the current visible
    -- layout root. Anchor and expose the QuestKing-owned root before creating
    -- the independent PetTracker frame so its first update has valid geometry.
    AnchorSection(tracker)

    local creatingFrame = petTrackerFrame == nil or runtimeAddon ~= addon
    if creatingFrame then
        parent:Show()
    end

    local frame, created = CreatePetTrackerFrame(addon)
    if not frame then
        HideSection()
        return
    end

    if created or contentDirty then
        layoutInProgress = true
        local updated = SafeCallMethod(frame, "Update")
        layoutInProgress = false

        if not updated then
            HideSection()
            return
        end

        contentDirty = false
    end

    if not ShouldShow(frame, addon) then
        HideSection()
        return
    end

    layoutInProgress = true
    parent:Show()
    frame:Show()
    layoutInProgress = false

    if not ApplySectionLayout(frame, tracker) then
        HideSection()
        return
    end

    Adapter.visible = true

    if type(tracker.Resize) == "function" then
        tracker:Resize(section)
    end
end

local function RegisterUpdateHook()
    if updateHookRegistered then
        return
    end

    QuestKing.updateHooks = type(QuestKing.updateHooks) == "table"
        and QuestKing.updateHooks
        or {}

    table.insert(QuestKing.updateHooks, function()
        local ok, err = pcall(Adapter.Layout, Adapter)
        if not ok then
            ReportRuntimeError(err)
            HideSection()
        end
    end)

    updateHookRegistered = true
end

local function RegisterLifecycleEvents()
    if lifecycleEventsRegistered or type(CreateFrame) ~= "function" then
        return
    end

    local frame = CreateFrame("Frame")
    frame:RegisterEvent("ADDON_LOADED")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    frame:RegisterEvent("PLAYER_REGEN_ENABLED")
    frame:SetScript("OnEvent", function(eventFrame, event, loadedAddonName)
        if event == "PLAYER_ENTERING_WORLD" then
            worldReady = true
        end

        if event == "ADDON_LOADED" and loadedAddonName ~= "PetTracker" then
            return
        end
        if event == "ADDON_LOADED" then
            eventFrame:UnregisterEvent("ADDON_LOADED")
        end

        if event == "PLAYER_REGEN_ENABLED" then
            if not layoutDeferred then
                return
            end
            layoutDeferred = false
        else
            ResetMapRetries()
            MarkContentDirty()
        end

        if worldReady and GetRuntimeAddon() then
            QueueTrackerRefresh()
        end
    end)

    if GetRuntimeAddon() then
        frame:UnregisterEvent("ADDON_LOADED")
    end

    lifecycleEventsRegistered = true
    Adapter.LoaderFrame = frame
end

RegisterUpdateHook()
RegisterLifecycleEvents()
