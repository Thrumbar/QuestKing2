local addonName, QuestKing = ...

local opt = (QuestKing and QuestKing.options) or {}

local Compat = {}
local setupComplete = false
local updateHookInstalled = false

local hookedObjectiveFrames = setmetatable({}, { __mode = "k" })
local compatibilityHeaders = setmetatable({}, { __mode = "k" })

local function IsAddOnLoadedCompat(name)
    if C_AddOns and C_AddOns.IsAddOnLoaded then
        return C_AddOns.IsAddOnLoaded(name)
    end

    if IsAddOnLoaded then
        return IsAddOnLoaded(name)
    end

    return false
end

local function SafeCall(fn, ...)
    if type(fn) ~= "function" then
        return nil
    end

    local ok, result = pcall(fn, ...)
    if ok then
        return result
    end

    return nil
end

local function GetTrackerCollapsedState()
    return (QuestKingDBPerChar and QuestKingDBPerChar.trackerCollapsed) or 0
end

local function GetPetTrackerHiddenOption()
    local petTracker = _G.PetTracker
    local sets = petTracker and petTracker.Sets
    return sets and sets.HideTracker and true or false
end

local function GetPetTrackerObjectivesFrame()
    local petTracker = _G.PetTracker
    return petTracker and petTracker.Objectives or nil
end

local function ShouldShowObjectivesFrame()
    if GetTrackerCollapsedState() > 0 then
        return false
    end

    if GetPetTrackerHiddenOption() then
        return false
    end

    return true
end

local function TogglePetTrackerOptions()
    local objectives = GetPetTrackerObjectivesFrame()
    if objectives and objectives.ToggleOptions then
        SafeCall(objectives.ToggleOptions, objectives)
    end
end

local function CreateCompatibilityHeader(parentFrame)
    if not (QuestKing and QuestKing.WatchButton and QuestKing.WatchButton.Create) then
        return nil
    end

    local header = QuestKing.WatchButton:Create()
    compatibilityHeaders[header] = true

    header:SetParent(parentFrame)
    header.mouseHandler = header.mouseHandler or {}
    header.mouseHandler.TitleButtonOnClick = function()
        TogglePetTrackerOptions()
    end

    if header.titleButton then
        header.titleButton:EnableMouse(true)
        header.titleButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    end

    return header
end

local function EnsureHeader(frame)
    if not frame then
        return nil
    end

    if not frame.Header or not compatibilityHeaders[frame.Header] then
        frame.Header = CreateCompatibilityHeader(frame)
    end

    local header = frame.Header
    if not header then
        return nil
    end

    local label = (_G.PetTracker and _G.PetTracker.Locals and _G.PetTracker.Locals.BattlePets) or "Battle Pets"

    header:SetParent(frame)
    header:ClearAllPoints()
    header:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    header:SetWidth((opt and opt.buttonWidth) or 230)

    if header.title then
        header.title:SetText(label)
        header.title:SetTextColor(0.50, 0.65, 0.85, 1)
    end

    if header.level then
        header.level:Hide()
        header.level:SetText("")
    end

    if header.completed then
        header.completed:Hide()
    end

    header.currentLine = 0
    if header.Render then
        header:Render()
    else
        header:Show()
    end

    return header
end

local function AnchorObjectiveList(frame)
    local header = EnsureHeader(frame)
    if not header then
        return
    end

    if frame.Anchor then
        frame.Anchor:ClearAllPoints()
        frame.Anchor:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -8)
        frame.Anchor:SetWidth((opt and opt.buttonWidth) or 230)
    end

    if frame.SetParent and QuestKing and QuestKing.Tracker then
        frame:SetParent(QuestKing.Tracker)
    end

    if frame.ClearAllPoints and frame.SetPoint and QuestKing and QuestKing.Tracker then
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", QuestKing.Tracker, "BOTTOMLEFT", 0, -5)
    end

    if frame.SetWidth then
        frame:SetWidth((opt and opt.buttonWidth) or 230)
    end

    frame.maxEntries = 1000
end

local function UpdateObjectivesVisibility(frame)
    if not frame or not frame.Show or not frame.Hide then
        return
    end

    if ShouldShowObjectivesFrame() then
        frame:Show()
    else
        frame:Hide()
    end
end

local function RefreshObjectivesFrame(frame)
    if not frame then
        return
    end

    EnsureHeader(frame)
    AnchorObjectiveList(frame)
    UpdateObjectivesVisibility(frame)
end

local function AddQuestKingUpdateHook(frame)
    if updateHookInstalled then
        return
    end

    if not (QuestKing and QuestKing.updateHooks) then
        return
    end

    updateHookInstalled = true
    table.insert(QuestKing.updateHooks, function()
        local objectives = frame or GetPetTrackerObjectivesFrame()
        if objectives then
            RefreshObjectivesFrame(objectives)
        end
    end)
end

local function HookPetTrackerObjectives(frame)
    if not frame or hookedObjectiveFrames[frame] then
        return
    end

    hookedObjectiveFrames[frame] = true

    if hooksecurefunc and type(frame.Startup) == "function" then
        SafeCall(hooksecurefunc, frame, "Startup", function(self)
            RefreshObjectivesFrame(self)
        end)
    end

    if hooksecurefunc and type(frame.TrackingChanged) == "function" then
        SafeCall(hooksecurefunc, frame, "TrackingChanged", function(self)
            RefreshObjectivesFrame(self)
        end)
    end

    RefreshObjectivesFrame(frame)
    AddQuestKingUpdateHook(frame)
end

local function SetupPetTrackerCompatibility()
    if setupComplete then
        local existingFrame = GetPetTrackerObjectivesFrame()
        if existingFrame then
            RefreshObjectivesFrame(existingFrame)
        end
        return
    end

    local frame = GetPetTrackerObjectivesFrame()
    if not frame then
        return
    end

    setupComplete = true
    HookPetTrackerObjectives(frame)
end

Compat.SetupPetTrackerCompatibility = SetupPetTrackerCompatibility
QuestKing.Compatibility = QuestKing.Compatibility or {}
QuestKing.Compatibility.PetTracker = Compat

if IsAddOnLoadedCompat("PetTracker") then
    SetupPetTrackerCompatibility()
else
    local loader = CreateFrame("Frame")
    loader:RegisterEvent("ADDON_LOADED")
    loader:RegisterEvent("PLAYER_LOGIN")
    loader:SetScript("OnEvent", function(_, event, arg1)
        if event == "ADDON_LOADED" and arg1 == "PetTracker" then
            SetupPetTrackerCompatibility()
        elseif event == "PLAYER_LOGIN" and IsAddOnLoadedCompat("PetTracker") then
            SetupPetTrackerCompatibility()
        end
    end)
end