local addonName, QuestKing = ...

if type(QuestKing) ~= "table" then
    return
end

local _G = _G
local CreateFrame = _G.CreateFrame

if _G.WOW_PROJECT_ID ~= nil
    and _G.WOW_PROJECT_MAINLINE ~= nil
    and _G.WOW_PROJECT_ID ~= _G.WOW_PROJECT_MAINLINE then
    return
end

local pcall = pcall
local type = type

local ANCHOR_GAP = 5

local Adapter = QuestKing.WorldQuestTrackerAdapter or {}
QuestKing.WorldQuestTrackerAdapter = Adapter

local hookedAddon = nil
local anchorHost = nil
local lifecycleEventsRegistered = false
local layoutDeferred = false
local restoreInProgress = false
local runtimeErrorReported = false

local function ReportRuntimeError(message)
    if runtimeErrorReported then
        return
    end

    runtimeErrorReported = true

    if type(_G.geterrorhandler) == "function" then
        local ok, handler = pcall(_G.geterrorhandler)
        if ok and type(handler) == "function" then
            pcall(
                handler,
                "QuestKing WorldQuestTracker adapter: " .. tostring(message)
            )
        end
    end
end

local function GetRuntime()
    local addon = _G.WorldQuestTrackerAddon
    local panel = _G.WorldQuestTrackerScreenPanel

    if type(addon) ~= "table"
        or type(addon.RefreshTrackerAnchor) ~= "function"
        or not panel
        or type(panel.ClearAllPoints) ~= "function"
        or type(panel.SetPoint) ~= "function" then
        return nil, nil, nil
    end

    local db = addon.db
    local profile = type(db) == "table" and db.profile or nil
    if type(profile) ~= "table" then
        return nil, nil, nil
    end

    return addon, panel, profile
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
        return false
    end

    local ok, protected = pcall(frame.IsProtected, frame)
    if not ok or IsSecretValue(protected) then
        return true
    end

    return protected == true
end

local function IsAnchoringRestrictedSafe(frame)
    if not frame or type(frame.IsAnchoringRestricted) ~= "function" then
        return false
    end

    local ok, restricted = pcall(frame.IsAnchoringRestricted, frame)
    if not ok or IsSecretValue(restricted) then
        return true
    end

    return restricted == true
end

local function ShouldDeferLayout(panel, tracker, host)
    if IsAnchoringRestrictedSafe(panel)
        or IsAnchoringRestrictedSafe(tracker)
        or IsAnchoringRestrictedSafe(host) then
        return true
    end

    if not IsInCombatLockdownSafe() then
        return false
    end

    return IsProtectedFrameSafe(panel)
        or IsProtectedFrameSafe(tracker)
        or IsProtectedFrameSafe(host)
end

local function IsFrameShown(frame)
    if not frame or type(frame.IsShown) ~= "function" then
        return false
    end

    local ok, shown = pcall(frame.IsShown, frame)
    return ok and shown == true
end

local function GetAnchorHost()
    if anchorHost then
        return anchorHost
    end

    local tracker = QuestKing.Tracker
    if not tracker or type(CreateFrame) ~= "function" then
        return nil
    end

    local frame = CreateFrame("Frame", nil, tracker)
    frame:SetSize(1, 1)
    frame:SetPoint("TOPRIGHT", tracker, "BOTTOMRIGHT", 0, 0)
    if type(frame.EnableMouse) == "function" then
        frame:EnableMouse(false)
    end
    if type(tracker.HookScript) == "function" then
        tracker:HookScript("OnShow", function()
            if type(Adapter.Refresh) == "function" then
                Adapter:Refresh()
            end
        end)
        tracker:HookScript("OnHide", function()
            if type(Adapter.Refresh) == "function" then
                Adapter:Refresh()
            end
        end)
    end

    anchorHost = frame
    Adapter.AnchorHost = frame
    return frame
end

local function IsAnchoredToQuestKing(panel, host)
    if type(panel.GetPoint) ~= "function" then
        return false
    end

    local ok, point, relativeTo, relativePoint, xOffset, yOffset =
        pcall(panel.GetPoint, panel, 1)
    if not ok then
        return false
    end

    return point == "TOPRIGHT"
        and relativeTo == host
        and relativePoint == "TOPRIGHT"
        and xOffset == 0
        and yOffset == -ANCHOR_GAP
end

local function ShouldAttach(profile)
    local options = QuestKing.options or {}
    local tracker = QuestKing.Tracker

    return options.attachWorldQuestTracker ~= false
        and profile.use_tracker == true
        and profile.tracker_attach_to_questlog == true
        and tracker ~= nil
        and IsFrameShown(tracker)
end

local function RestoreNativeAnchor(addon, panel, tracker, host)
    if restoreInProgress then
        return
    end

    if not IsAnchoredToQuestKing(panel, host) then
        Adapter.attached = false
        return
    end

    if ShouldDeferLayout(panel, tracker, host) then
        layoutDeferred = true
        if type(QuestKing.StartCombatTimer) == "function" then
            QuestKing:StartCombatTimer()
        end
        return
    end

    restoreInProgress = true
    Adapter.attached = false

    local ok, err = pcall(addon.RefreshTrackerAnchor)

    restoreInProgress = false
    if not ok then
        ReportRuntimeError(err)
    end
end

local function ApplyAnchor()
    if restoreInProgress then
        return
    end

    local addon, panel, profile = GetRuntime()
    local tracker = QuestKing.Tracker
    local host = GetAnchorHost()
    if not addon or not panel or not tracker or not host then
        Adapter.attached = false
        return
    end

    if not ShouldAttach(profile) then
        RestoreNativeAnchor(addon, panel, tracker, host)
        return
    end

    if ShouldDeferLayout(panel, tracker, host) then
        layoutDeferred = true
        if type(QuestKing.StartCombatTimer) == "function" then
            QuestKing:StartCombatTimer()
        end
        return
    end

    layoutDeferred = false

    if IsAnchoredToQuestKing(panel, host) then
        Adapter.attached = true
        return
    end

    local ok, err = pcall(function()
        panel:ClearAllPoints()
        panel:SetPoint(
            "TOPRIGHT",
            host,
            "TOPRIGHT",
            0,
            -ANCHOR_GAP
        )
    end)

    if not ok then
        Adapter.attached = false
        ReportRuntimeError(err)
        return
    end

    Adapter.attached = true
end

local function InstallAnchorHook()
    local addon = GetRuntime()
    if not addon or hookedAddon == addon then
        return addon ~= nil
    end

    if type(_G.hooksecurefunc) ~= "function" then
        return false
    end

    local ok, err = pcall(
        _G.hooksecurefunc,
        addon,
        "RefreshTrackerAnchor",
        function()
            ApplyAnchor()
        end
    )

    if not ok then
        ReportRuntimeError(err)
        return false
    end

    hookedAddon = addon
    return true
end

function Adapter:IsAvailable()
    return GetRuntime() ~= nil
end

function Adapter:IsAttached()
    local _, panel = GetRuntime()
    local host = GetAnchorHost()
    return panel ~= nil
        and host ~= nil
        and IsAnchoredToQuestKing(panel, host)
end

function Adapter:Refresh()
    InstallAnchorHook()
    ApplyAnchor()
end

local function RegisterLifecycleEvents()
    if lifecycleEventsRegistered or type(CreateFrame) ~= "function" then
        return
    end

    local frame = CreateFrame("Frame")
    frame:RegisterEvent("ADDON_LOADED")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:RegisterEvent("PLAYER_REGEN_ENABLED")
    frame:SetScript("OnEvent", function(eventFrame, event, loadedAddonName)
        if event == "ADDON_LOADED"
            and loadedAddonName ~= "WorldQuestTracker" then
            return
        end

        if event == "ADDON_LOADED" then
            eventFrame:UnregisterEvent("ADDON_LOADED")
        elseif event == "PLAYER_REGEN_ENABLED" and not layoutDeferred then
            return
        end

        layoutDeferred = false
        InstallAnchorHook()
        ApplyAnchor()
    end)

    if GetRuntime() then
        frame:UnregisterEvent("ADDON_LOADED")
    end

    lifecycleEventsRegistered = true
    Adapter.LoaderFrame = frame
end

RegisterLifecycleEvents()
GetAnchorHost()
InstallAnchorHook()
ApplyAnchor()
