local addonName, QuestKing = ...

local opt = QuestKing.options or {}
local Compat = QuestKing.Compatibility or {}

local _G = _G
local DEFAULT_CHAT_FRAME = _G.DEFAULT_CHAT_FRAME
local ReloadUI = _G.ReloadUI
local SlashCmdList = _G.SlashCmdList or {}

local format = string.format
local lower = string.lower
local tostring = tostring
local tonumber = tonumber
local tinsert = table.insert
local unpack = table.unpack or unpack
local type = type

local VALID_ORIGINS = {
    TOPRIGHT = true,
    TOPLEFT = true,
    BOTTOMRIGHT = true,
    BOTTOMLEFT = true,
}

local VALID_DISPLAY_MODES = {
    q = "quests",
    quest = "quests",
    quests = "quests",
    r = "raids",
    raid = "raids",
    raids = "raids",
    a = "achievements",
    achievement = "achievements",
    achievements = "achievements",
    c = "combined",
    combined = "combined",
    modeq = "quests",
    moder = "raids",
    modea = "achievements",
    modec = "combined",
}

local DISPLAY_MODE_LABELS = {
    quests = "Q",
    raids = "R",
    achievements = "A",
    combined = "C",
}

local function Print(msg, ...)
    if select("#", ...) > 0 then
        msg = format(msg, ...)
    end

    local prefix = "|cff99ccffQuestKing|cff6090ff:|r "
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage(prefix .. tostring(msg))
    elseif _G.print then
        _G.print("QuestKing: " .. tostring(msg))
    end
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

local function EnsureSavedVariables()
    _G.QuestKingDB = _G.QuestKingDB or {}
    _G.QuestKingDBPerChar = _G.QuestKingDBPerChar or {}

    local db = _G.QuestKingDB
    local perChar = _G.QuestKingDBPerChar

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

    perChar.collapsedHeaders = type(perChar.collapsedHeaders) == "table" and perChar.collapsedHeaders or {}
    perChar.collapsedQuests = type(perChar.collapsedQuests) == "table" and perChar.collapsedQuests or {}
    perChar.collapsedAchievements = type(perChar.collapsedAchievements) == "table" and perChar.collapsedAchievements or {}
    perChar.displayMode = VALID_DISPLAY_MODES[lower(tostring(perChar.displayMode or "combined"))] or "combined"
    perChar.trackerCollapsed = tonumber(perChar.trackerCollapsed) or 0
    perChar.trackerPositionPreset = tonumber(perChar.trackerPositionPreset) or 1

    return db, perChar
end

local function GetTracker()
    return QuestKing and QuestKing.Tracker or nil
end

local function QueueTrackerRefresh(forceBuild)
    if QuestKing and type(QuestKing.QueueTrackerUpdate) == "function" then
        QuestKing:QueueTrackerUpdate(forceBuild, false)
        return
    end

    if QuestKing and type(QuestKing.UpdateTracker) == "function" then
        QuestKing:UpdateTracker(forceBuild, false)
    end
end

local function RefreshTrackerPresentation(forceBuild)
    local tracker = GetTracker()
    if tracker then
        SafeCallMethod(tracker, "SetCustomAlpha")
        SafeCallMethod(tracker, "SetCustomScale")
        SafeCallMethod(tracker, "CheckDrag")
        SafeCallMethod(tracker, "RefreshLayoutMetrics")
    end

    QueueTrackerRefresh(forceBuild)
end

local function GetDisplayModeLabel(mode)
    return DISPLAY_MODE_LABELS[mode] or "Q"
end

local function SetModeButtonLabel(mode)
    local tracker = GetTracker()
    local button = (tracker and tracker.modeButton) or _G.QuestKing_TrackerModeButton
    if button and button.label and button.label.SetText then
        button.label:SetText(GetDisplayModeLabel(mode))
    end
end

local function ApplyDisplayMode(mode)
    local _, perChar = EnsureSavedVariables()

    if not mode or mode == "" then
        return false
    end

    mode = VALID_DISPLAY_MODES[lower(tostring(mode))]
    if not mode then
        return false
    end

    perChar.displayMode = mode
    SetModeButtonLabel(mode)
    RefreshTrackerPresentation(true)
    return mode
end

local function GetStatusStrings()
    local db, perChar = EnsureSavedVariables()
    local tracker = GetTracker()

    local alpha = db.dbTrackerAlpha
    if alpha == nil then
        alpha = tonumber(opt.trackerAlpha) or 1
    end

    local scale = db.dbTrackerScale
    if scale == nil then
        scale = tonumber(opt.trackerScale) or 1
    end

    local trackerVisible = tracker and tracker.IsShown and tracker:IsShown() and "shown" or "hidden"
    local origin = tostring(db.dragOrigin or "TOPRIGHT")
    local x = db.dragX ~= nil and tostring(db.dragX) or "default"
    local y = db.dragY ~= nil and tostring(db.dragY) or "default"

    return {
        format("mode=%s (%s)", perChar.displayMode, GetDisplayModeLabel(perChar.displayMode)),
        format("collapsed=%s", tostring(perChar.trackerCollapsed)),
        format("dragLocked=%s", tostring(db.dragLocked)),
        format("origin=%s x=%s y=%s", origin, x, y),
        format("alpha=%.2f scale=%.2f", alpha, scale),
        format("preset=%s tracker=%s", tostring(perChar.trackerPositionPreset), trackerVisible),
    }
end

local function PrintHelp()
    Print("Valid commands:")
    Print("  help - show this help")
    Print("  status - show current tracker settings")
    Print("  q / r / a / c - switch tracker mode")
    Print("  mode <q|r|a|c> - switch tracker mode directly")
    Print("  lock - lock tracker dragging")
    Print("  unlock - unlock tracker dragging")
    Print("  origin <TOPRIGHT|TOPLEFT|BOTTOMRIGHT|BOTTOMLEFT> - reset drag origin")
    Print("  preset [index|next] - move tracker to a saved preset position")
    Print("  alpha <0-1|clear> - set tracker alpha override")
    Print("  scale <value|clear> - set tracker scale override")
    Print("  refresh - force a tracker rebuild")
    Print("  reset - clear collapsed headers, quests, and achievements")
    Print("  resetall yes - reset all saved variables for this character and reload")
end

local Command = {}

Command.help = function()
    PrintHelp()
end

Command.status = function()
    local lines = GetStatusStrings()
    for index = 1, #lines do
        Print(lines[index])
    end
end

Command.mode = function(mode)
    local applied = ApplyDisplayMode(mode)
    if not applied then
        Print("Invalid mode. Use |cffaaffaaq|r, |cffaaffaar|r, |cffaaffaaa|r, or |cffaaffaac|r.")
        return
    end

    Print("Tracker mode set to %s (%s).", applied, GetDisplayModeLabel(applied))
end

Command.q = function()
    Command.mode("quests")
end
Command.quest = Command.q
Command.quests = Command.q

Command.r = function()
    Command.mode("raids")
end
Command.raid = Command.r
Command.raids = Command.r

Command.a = function()
    Command.mode("achievements")
end
Command.achievement = Command.a
Command.achievements = Command.a

Command.c = function()
    Command.mode("combined")
end
Command.combined = Command.c

Command.refresh = function()
    RefreshTrackerPresentation(true)
    Print("Tracker refreshed.")
end

Command.reset = function()
    local _, perChar = EnsureSavedVariables()
    perChar.collapsedHeaders = {}
    perChar.collapsedQuests = {}
    perChar.collapsedAchievements = {}

    Print("Reset collapsed headers, quests, and achievements.")
    RefreshTrackerPresentation(true)
end

Command.resetall = function(confirm)
    if lower(tostring(confirm or "")) ~= "yes" then
        Print("This resets all saved settings for this character.")
        Print("Type \"|cffaaffaa/qk resetall yes|r\" to confirm.")
        return
    end

    Print("Resetting all saved variables and reloading UI.")
    _G.QuestKingDB = {}
    _G.QuestKingDBPerChar = {}

    if type(ReloadUI) == "function" then
        ReloadUI()
    end
end

Command.alpha = function(value)
    local db = EnsureSavedVariables()
    local tracker = GetTracker()

    if not tracker or type(tracker.SetCustomAlpha) ~= "function" then
        Print("Tracker alpha control is not available.")
        return
    end

    if not opt.dbAllowTrackerAlpha then
        Print("Tracker alpha overrides are disabled in options.")
        return
    end

    if not value or value == "" then
        Print("Enter an alpha value between 0 and 1, or \"clear\" to use the option default.")
        return
    end

    if lower(tostring(value)) == "clear" then
        db.dbTrackerAlpha = nil
        tracker:SetCustomAlpha()
        Print("Cleared alpha override.")
        RefreshTrackerPresentation()
        return
    end

    local alpha = tonumber(value)
    if not alpha then
        Print("Invalid alpha value. Example: |cffaaffaa/qk alpha 0.85|r")
        return
    end

    if alpha < 0 then
        alpha = 0
    elseif alpha > 1 then
        alpha = 1
    end

    tracker:SetCustomAlpha(alpha)
    Print("Tracker alpha set to %.2f.", alpha)
    RefreshTrackerPresentation()
end

Command.scale = function(value)
    local db = EnsureSavedVariables()
    local tracker = GetTracker()

    if not tracker or type(tracker.SetCustomScale) ~= "function" then
        Print("Tracker scale control is not available.")
        return
    end

    if not opt.dbAllowTrackerScale then
        Print("Tracker scale overrides are disabled in options.")
        return
    end

    if not value or value == "" then
        Print("Enter a scale value, or \"clear\" to use the option default.")
        Print("Example: |cffaaffaa/qk scale 1.15|r")
        return
    end

    if lower(tostring(value)) == "clear" then
        db.dbTrackerScale = nil
        tracker:SetCustomScale()
        Print("Cleared scale override.")
        RefreshTrackerPresentation()
        return
    end

    local scale = tonumber(value)
    if not scale then
        Print("Invalid scale value. Example: |cffaaffaa/qk scale 1.15|r")
        return
    end

    if scale <= 0 then
        scale = 0.01
    end

    tracker:SetCustomScale(scale)
    Print("Tracker scale set to %.2f.", scale)
    RefreshTrackerPresentation()
end

local function SetDragLockedState(locked)
    local db = EnsureSavedVariables()
    local tracker = GetTracker()

    if not opt.allowDrag then
        Print("Tracker dragging is disabled in options.")
        return
    end

    if not tracker or type(tracker.CheckDrag) ~= "function" then
        Print("Tracker drag control is not available.")
        return
    end

    db.dragLocked = locked and true or false
    tracker:CheckDrag()

    if db.dragLocked then
        Print("Tracker locked.")
    else
        Print("Tracker unlocked.")
    end
end

Command.lock = function()
    SetDragLockedState(true)
end

Command.unlock = function()
    SetDragLockedState(false)
end

Command.origin = function(origin)
    local db = EnsureSavedVariables()
    local tracker = GetTracker()

    if not opt.allowDrag then
        Print("Tracker dragging is disabled in options.")
        return
    end

    if not tracker or type(tracker.InitDrag) ~= "function" then
        Print("Tracker drag origin control is not available.")
        return
    end

    if not origin or origin == "" then
        Print("No origin specified. Valid origins are: |cffaaffaaTOPRIGHT TOPLEFT BOTTOMRIGHT BOTTOMLEFT|r")
        Print(
            "Current settings: dragLocked=|cffaaffaa%s|r dragOrigin=|cffaaffaa%s|r dragX=|cffaaffaa%s|r dragY=|cffaaffaa%s|r",
            tostring(db.dragLocked),
            tostring(db.dragOrigin),
            tostring(db.dragX),
            tostring(db.dragY)
        )
        return
    end

    origin = string.upper(tostring(origin))
    if not VALID_ORIGINS[origin] then
        Print("Invalid origin. Valid origins are: |cffaaffaaTOPRIGHT TOPLEFT BOTTOMRIGHT BOTTOMLEFT|r")
        return
    end

    db.dragLocked = false
    db.dragOrigin = origin
    db.dragRelativePoint = origin
    db.dragX = nil
    db.dragY = nil

    tracker:InitDrag()
    Print("Tracker origin set to %s.", origin)
    RefreshTrackerPresentation()
end

Command.preset = function(value)
    local _, perChar = EnsureSavedVariables()
    local tracker = GetTracker()
    local presets = opt.positionPresets
    local presetCount = type(presets) == "table" and #presets or 0

    if presetCount <= 0 then
        Print("No tracker presets are defined in options.")
        return
    end

    if not tracker then
        Print("Tracker is not available yet.")
        return
    end

    if not value or value == "" or lower(tostring(value)) == "next" then
        if type(tracker.CyclePresetPosition) == "function" then
            tracker:CyclePresetPosition()
        else
            local current = tonumber(perChar.trackerPositionPreset) or 1
            perChar.trackerPositionPreset = (current % presetCount) + 1
            if type(tracker.SetPresetPosition) == "function" then
                tracker:SetPresetPosition()
            end
        end

        Print("Tracker preset set to %d.", tonumber(perChar.trackerPositionPreset) or 1)
        RefreshTrackerPresentation()
        return
    end

    local newIndex = tonumber(value)
    if not newIndex or newIndex < 1 or newIndex > presetCount then
        Print("Invalid preset. Use a value from 1 to %d, or \"next\".", presetCount)
        return
    end

    perChar.trackerPositionPreset = newIndex
    if type(tracker.SetPresetPosition) == "function" then
        tracker:SetPresetPosition()
    end

    if type(tracker.CheckDrag) == "function" then
        tracker:CheckDrag()
    end

    Print("Tracker preset set to %d.", newIndex)
    RefreshTrackerPresentation()
end

local function Dispatch(first, ...)
    first = lower(tostring(first or "help"))

    local fn = Command[first]
    if fn then
        fn(...)
        return
    end

    local aliasMode = VALID_DISPLAY_MODES[first]
    if aliasMode then
        Command.mode(aliasMode)
        return
    end

    Print("Invalid command. Type \"|cffaaffaa/qk help|r\" for help.")
end

local function ParseSlashArguments(message)
    local args = {}
    local token = ""
    local inQuotes = false
    local quoteChar = nil

    local i = 1
    local len = message and #message or 0

    while i <= len do
        local ch = message:sub(i, i)

        if inQuotes then
            if ch == quoteChar then
                inQuotes = false
                quoteChar = nil
            else
                token = token .. ch
            end
        else
            if ch == '"' or ch == "'" then
                inQuotes = true
                quoteChar = ch
            elseif ch:match("%s") then
                if token ~= "" then
                    args[#args + 1] = token
                    token = ""
                end
            else
                token = token .. ch
            end
        end

        i = i + 1
    end

    if token ~= "" then
        args[#args + 1] = token
    end

    if #args == 0 then
        args[1] = "help"
    end

    return args
end

local function ParseSlash(message)
    local args = ParseSlashArguments(message or "")
    Dispatch(unpack(args))
end

SLASH_QUESTKING1 = "/questking"
SLASH_QUESTKING2 = "/qk"
SlashCmdList.QUESTKING = ParseSlash

QuestKing.ParseSlash = ParseSlash
QuestKing.PrintSlashHelp = PrintHelp
