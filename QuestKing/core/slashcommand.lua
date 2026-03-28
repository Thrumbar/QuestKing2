local addonName, QuestKing = ...

local opt = QuestKing.options or {}
local Tracker = QuestKing.Tracker

local format = string.format
local lower = string.lower
local tinsert = table.insert
local unpack = unpack or table.unpack

local VALID_ORIGINS = {
    TOPRIGHT = true,
    BOTTOMRIGHT = true,
    BOTTOMLEFT = true,
    TOPLEFT = true,
}

local function Print(msg, ...)
    if select("#", ...) > 0 then
        msg = format(msg, ...)
    end

    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage(format("|cff99ccffQuestKing|cff6090ff:|r %s", msg))
    end
end

local function EnsureSavedVariables()
    QuestKingDB = QuestKingDB or {}
    QuestKingDBPerChar = QuestKingDBPerChar or {}

    QuestKingDBPerChar.collapsedHeaders = QuestKingDBPerChar.collapsedHeaders or {}
    QuestKingDBPerChar.collapsedQuests = QuestKingDBPerChar.collapsedQuests or {}
    QuestKingDBPerChar.collapsedAchievements = QuestKingDBPerChar.collapsedAchievements or {}
    QuestKingDBPerChar.displayMode = QuestKingDBPerChar.displayMode or "combined"
    QuestKingDBPerChar.trackerCollapsed = QuestKingDBPerChar.trackerCollapsed or 0
    QuestKingDBPerChar.trackerPositionPreset = QuestKingDBPerChar.trackerPositionPreset or 1

    if QuestKingDB.dragLocked == nil then
        QuestKingDB.dragLocked = false
    end

    QuestKingDB.dragOrigin = QuestKingDB.dragOrigin or "TOPRIGHT"
end

local function UpdateTracker(forceBuild)
    if QuestKing and QuestKing.UpdateTracker then
        QuestKing:UpdateTracker(forceBuild)
    end
end

local function GetTrackerSafe()
    return QuestKing and QuestKing.Tracker or Tracker
end

local function PrintHelp()
    Print("Valid commands:")
    Print("  help - show this help")
    Print("  lock - toggle tracker dragging")
    Print("  origin <TOPRIGHT|BOTTOMRIGHT|BOTTOMLEFT|TOPLEFT> - reset drag origin")
    Print("  alpha <0-1|clear> - set tracker alpha override")
    Print("  scale <value|clear> - set tracker scale override")
    Print("  reset - clear collapsed headers, quests, and achievements")
    Print("  resetall yes - reset all saved variables for this character and reload")
end

local Command = {}

Command.help = function()
    PrintHelp()
end

Command.reset = function()
    EnsureSavedVariables()

    QuestKingDBPerChar.collapsedHeaders = {}
    QuestKingDBPerChar.collapsedQuests = {}
    QuestKingDBPerChar.collapsedAchievements = {}

    Print("Reset collapsed headers, quests, and achievements.")
    UpdateTracker(true)
end

Command.resetall = function(confirm)
    if lower(tostring(confirm or "")) ~= "yes" then
        Print("This resets all saved settings for this character.")
        Print("Type \"|cffaaffaa/qk resetall yes|r\" to confirm.")
        return
    end

    Print("Resetting all saved variables and reloading UI.")
    QuestKingDB = {}
    QuestKingDBPerChar = {}

    if ReloadUI then
        ReloadUI()
    end
end

Command.alpha = function(value)
    EnsureSavedVariables()

    local tracker = GetTrackerSafe()
    if not tracker or not tracker.SetCustomAlpha then
        Print("Tracker alpha control is not available.")
        return
    end

    if not value or value == "" then
        Print("Enter an alpha value between 0 and 1, or \"clear\" to use the option default.")
        return
    end

    if lower(value) == "clear" then
        QuestKingDB.dbTrackerAlpha = nil
        tracker:SetCustomAlpha()
        Print("Cleared alpha override.")
        UpdateTracker()
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
    UpdateTracker()
end

Command.scale = function(value)
    EnsureSavedVariables()

    local tracker = GetTrackerSafe()
    if not tracker or not tracker.SetCustomScale then
        Print("Tracker scale control is not available.")
        return
    end

    if not value or value == "" then
        Print("Enter a scale value, or \"clear\" to use the option default.")
        Print("Example: |cffaaffaa/qk scale 1.15|r")
        return
    end

    if lower(value) == "clear" then
        QuestKingDB.dbTrackerScale = nil
        tracker:SetCustomScale()
        Print("Cleared scale override.")
        UpdateTracker()
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
    UpdateTracker()
end

Command.lock = function()
    EnsureSavedVariables()

    local tracker = GetTrackerSafe()
    if not tracker or not tracker.ToggleDrag then
        Print("Tracker drag control is not available.")
        return
    end

    local isLocked = tracker:ToggleDrag()
    if isLocked then
        Print("Tracker locked.")
    else
        Print("Tracker unlocked.")
    end
end

Command.origin = function(origin)
    EnsureSavedVariables()

    local tracker = GetTrackerSafe()
    if not tracker or not tracker.InitDrag then
        Print("Tracker drag origin control is not available.")
        return
    end

    if not origin or origin == "" then
        Print("No origin specified. Valid origins are: |cffaaffaaTOPRIGHT BOTTOMRIGHT BOTTOMLEFT TOPLEFT|r")
        Print(
            "Current settings: dragLocked=|cffaaffaa%s|r dragOrigin=|cffaaffaa%s|r dragX=|cffaaffaa%s|r dragY=|cffaaffaa%s|r",
            tostring(QuestKingDB.dragLocked),
            tostring(QuestKingDB.dragOrigin),
            tostring(QuestKingDB.dragX),
            tostring(QuestKingDB.dragY)
        )
        return
    end

    origin = string.upper(origin)
    if not VALID_ORIGINS[origin] then
        Print("Invalid origin. Valid origins are: |cffaaffaaTOPRIGHT BOTTOMRIGHT BOTTOMLEFT TOPLEFT|r")
        return
    end

    QuestKingDB.dragLocked = false
    QuestKingDB.dragOrigin = origin
    QuestKingDB.dragX = nil
    QuestKingDB.dragY = nil

    tracker:InitDrag()
    Print("Tracker origin set to %s.", origin)
    UpdateTracker()
end

local function Dispatch(first, ...)
    first = lower(tostring(first or "help"))

    local fn = Command[first]
    if fn then
        fn(...)
        return
    end

    Print("Invalid command. Type \"|cffaaffaa/qk help|r\" for help.")
end

local function ParseSlash(msg)
    local args = {}

    for token in string.gmatch(msg or "", "%S+") do
        tinsert(args, token)
    end

    if #args == 0 then
        args[1] = "help"
    end

    Dispatch(unpack(args))
end

SLASH_QUESTKING1 = "/questking"
SLASH_QUESTKING2 = "/qk"
SlashCmdList.QUESTKING = ParseSlash

QuestKing.Print = Print