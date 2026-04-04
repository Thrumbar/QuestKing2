local addonName, QuestKing = ...

local opt = (QuestKing and QuestKing.options) or {}

local Compat = {}
local setupAttempted = false

local function IsAddOnLoadedCompat(name)
    if C_AddOns and C_AddOns.IsAddOnLoaded then
        return C_AddOns.IsAddOnLoaded(name)
    end

    if IsAddOnLoaded then
        return IsAddOnLoaded(name)
    end

    return false
end

local function SetupPetTrackerCompatibility()
    if setupAttempted then
        return
    end

    setupAttempted = true

    -- Intentionally conservative:
    -- The previous implementation reparents and reanchors PetTracker's live
    -- objective frame into QuestKing's tracker. That pattern is a high-risk
    -- taint source on modern clients, especially around ObjectiveTracker and
    -- WorldMap interactions. Until a fully taint-safe integration is written,
    -- QuestKing leaves PetTracker's UI alone.
    if not opt.enablePetTrackerCompatibility then
        return
    end

    -- Reserved for a future taint-safe opt-in integration.
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
