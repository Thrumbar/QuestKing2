local addonName, QuestKing = ...

local _G = _G
local C_AddOns = C_AddOns
local C_ContentTracking = C_ContentTracking
local C_QuestLog = C_QuestLog
local C_SuperTrack = C_SuperTrack
local Enum = Enum

local type = type
local tonumber = tonumber
local pcall = pcall

local WOW_PROJECT_ID = _G.WOW_PROJECT_ID
local WOW_PROJECT_MAINLINE = _G.WOW_PROJECT_MAINLINE
local WOW_PROJECT_CLASSIC = _G.WOW_PROJECT_CLASSIC
local WOW_PROJECT_CATACLYSM_CLASSIC = _G.WOW_PROJECT_CATACLYSM_CLASSIC

local opt = (QuestKing and QuestKing.options) or {}

local Compatibility = QuestKing.Compatibility or {}
QuestKing.Compatibility = Compatibility

local Compat = Compatibility.Common or {}
Compatibility.Common = Compat

local AddOnCompat = Compatibility.AddOns or {}
Compatibility.AddOns = AddOnCompat

local PetTrackerCompat = Compatibility.PetTracker or {}
Compatibility.PetTracker = PetTrackerCompat

local loaderFrame = nil
local petTrackerWatcher = nil
local setupAttempted = false
local petTrackerLoaded = false
local petTrackerEnabled = false

local function SafeCall(func, ...)
    if type(func) ~= "function" then
        return false, nil, nil, nil, nil, nil
    end

    local ok, a, b, c, d, e = pcall(func, ...)
    if ok then
        return true, a, b, c, d, e
    end

    return false, nil, nil, nil, nil, nil
end

local function SafeNumber(value, fallback)
    if type(value) == "number" then
        return value
    end

    local converted = tonumber(value)
    if type(converted) == "number" then
        return converted
    end

    return fallback
end

local function GetProjectFlags()
    local isMainline = WOW_PROJECT_MAINLINE and WOW_PROJECT_ID == WOW_PROJECT_MAINLINE or false
    local isClassicEra = WOW_PROJECT_CLASSIC and WOW_PROJECT_ID == WOW_PROJECT_CLASSIC or false
    local isCataclysmClassic = WOW_PROJECT_CATACLYSM_CLASSIC and WOW_PROJECT_ID == WOW_PROJECT_CATACLYSM_CLASSIC or false

    return {
        projectID = WOW_PROJECT_ID,
        isMainline = isMainline,
        isClassicEra = isClassicEra,
        isCataclysmClassic = isCataclysmClassic,
        isClassicFamily = isClassicEra or isCataclysmClassic,
    }
end

function Compat.GetProjectFlags()
    return GetProjectFlags()
end

function Compat.IsMainline()
    return GetProjectFlags().isMainline
end

function Compat.IsClassicEra()
    return GetProjectFlags().isClassicEra
end

function Compat.IsCataclysmClassic()
    return GetProjectFlags().isCataclysmClassic
end

function Compat.IsClassicFamily()
    return GetProjectFlags().isClassicFamily
end

function AddOnCompat.IsAddOnLoaded(name)
    if C_AddOns and C_AddOns.IsAddOnLoaded then
        local ok, loadedOrLoading, loaded = SafeCall(C_AddOns.IsAddOnLoaded, name)
        if ok then
            if loaded ~= nil then
                return loaded and true or false, loadedOrLoading and true or false
            end

            return loadedOrLoading and true or false, loadedOrLoading and true or false
        end
    end

    if type(_G.IsAddOnLoaded) == "function" then
        local ok, loadedOrLoading, loaded = SafeCall(_G.IsAddOnLoaded, name)
        if ok then
            if loaded ~= nil then
                return loaded and true or false, loadedOrLoading and true or false
            end

            return loadedOrLoading and true or false, loadedOrLoading and true or false
        end
    end

    return false, false
end

function AddOnCompat.IsAddOnLoadOnDemand(name)
    if C_AddOns and C_AddOns.IsAddOnLoadOnDemand then
        local ok, loadOnDemand = SafeCall(C_AddOns.IsAddOnLoadOnDemand, name)
        if ok then
            return loadOnDemand and true or false
        end
    end

    if type(_G.IsAddOnLoadOnDemand) == "function" then
        local ok, loadOnDemand = SafeCall(_G.IsAddOnLoadOnDemand, name)
        if ok then
            return loadOnDemand and true or false
        end
    end

    return false
end

function AddOnCompat.IsAddOnLoadable(name)
    if C_AddOns and C_AddOns.IsAddOnLoadable then
        local ok, loadable, reason = SafeCall(C_AddOns.IsAddOnLoadable, name)
        if ok then
            return loadable and true or false, reason
        end
    end

    local loaded = AddOnCompat.IsAddOnLoaded(name)
    if loaded then
        return true, nil
    end

    if AddOnCompat.IsAddOnLoadOnDemand(name) then
        return true, nil
    end

    return false, nil
end

function AddOnCompat.LoadAddOn(name)
    if C_AddOns and C_AddOns.LoadAddOn then
        local ok, loaded, reason = SafeCall(C_AddOns.LoadAddOn, name)
        if ok then
            return loaded and true or false, reason
        end
    end

    if type(_G.LoadAddOn) == "function" then
        local ok, loaded, reason = SafeCall(_G.LoadAddOn, name)
        if ok then
            return loaded and true or false, reason
        end
    end

    return false, nil
end

function Compat.GetQuestLogIndexByQuestID(questID)
    questID = SafeNumber(questID, nil)
    if not questID or questID <= 0 then
        return nil
    end

    if C_QuestLog and C_QuestLog.GetLogIndexForQuestID then
        local ok, index = SafeCall(C_QuestLog.GetLogIndexForQuestID, questID)
        if ok and type(index) == "number" and index > 0 then
            return index
        end
    end

    if type(_G.GetQuestLogIndexByID) == "function" then
        local ok, index = SafeCall(_G.GetQuestLogIndexByID, questID)
        if ok and type(index) == "number" and index > 0 then
            return index
        end
    end

    return nil
end

function Compat.GetQuestIDByLogIndex(questLogIndex)
    questLogIndex = SafeNumber(questLogIndex, nil)
    if not questLogIndex or questLogIndex <= 0 then
        return nil
    end

    if C_QuestLog and C_QuestLog.GetQuestIDForLogIndex then
        local ok, questID = SafeCall(C_QuestLog.GetQuestIDForLogIndex, questLogIndex)
        if ok and type(questID) == "number" and questID > 0 then
            return questID
        end
    end

    if C_QuestLog and C_QuestLog.GetInfo then
        local ok, info = SafeCall(C_QuestLog.GetInfo, questLogIndex)
        if ok and type(info) == "table" and type(info.questID) == "number" and info.questID > 0 then
            return info.questID
        end
    end

    if type(_G.GetQuestLogTitle) == "function" then
        local ok, _, _, _, _, _, _, _, questID = SafeCall(_G.GetQuestLogTitle, questLogIndex)
        if ok and type(questID) == "number" and questID > 0 then
            return questID
        end
    end

    return nil
end

function Compat.GetQuestInfo(questLogIndex)
    questLogIndex = SafeNumber(questLogIndex, nil)
    if not questLogIndex or questLogIndex <= 0 then
        return nil
    end

    if C_QuestLog and C_QuestLog.GetInfo then
        local ok, info = SafeCall(C_QuestLog.GetInfo, questLogIndex)
        if ok and type(info) == "table" then
            return info
        end
    end

    if type(_G.GetQuestLogTitle) == "function" then
        local ok, title, level, suggestedGroup, _, isHeader, _, frequency, questID, startEvent = SafeCall(_G.GetQuestLogTitle, questLogIndex)
        if ok and title then
            return {
                title = title,
                level = level,
                suggestedGroup = suggestedGroup,
                isHeader = isHeader and true or false,
                frequency = frequency,
                questID = questID,
                startEvent = startEvent and true or false,
            }
        end
    end

    return nil
end

function Compat.IsQuestWatched(questID, questLogIndex)
    questID = SafeNumber(questID, nil)
    if questID and questID > 0 and C_QuestLog and C_QuestLog.IsQuestWatched then
        local ok, watched = SafeCall(C_QuestLog.IsQuestWatched, questID)
        if ok then
            return watched and true or false
        end
    end

    questLogIndex = SafeNumber(questLogIndex, nil) or Compat.GetQuestLogIndexByQuestID(questID)
    if questLogIndex and type(_G.IsQuestWatched) == "function" then
        local ok, watched = SafeCall(_G.IsQuestWatched, questLogIndex)
        if ok then
            return watched and true or false
        end
    end

    return false
end

function Compat.AddQuestWatch(questID, questLogIndex)
    questID = SafeNumber(questID, nil)
    if questID and questID > 0 and C_QuestLog and C_QuestLog.AddQuestWatch then
        local ok = SafeCall(C_QuestLog.AddQuestWatch, questID)
        return ok and true or false
    end

    questLogIndex = SafeNumber(questLogIndex, nil) or Compat.GetQuestLogIndexByQuestID(questID)
    if questLogIndex and type(_G.AddQuestWatch) == "function" then
        local ok = SafeCall(_G.AddQuestWatch, questLogIndex)
        return ok and true or false
    end

    return false
end

function Compat.RemoveQuestWatch(questID, questLogIndex)
    questID = SafeNumber(questID, nil)
    if questID and questID > 0 and C_QuestLog and C_QuestLog.RemoveQuestWatch then
        local ok = SafeCall(C_QuestLog.RemoveQuestWatch, questID)
        return ok and true or false
    end

    questLogIndex = SafeNumber(questLogIndex, nil) or Compat.GetQuestLogIndexByQuestID(questID)
    if questLogIndex and type(_G.RemoveQuestWatch) == "function" then
        local ok = SafeCall(_G.RemoveQuestWatch, questLogIndex)
        return ok and true or false
    end

    return false
end

function Compat.GetQuestIDForWatchIndex(watchIndex)
    watchIndex = SafeNumber(watchIndex, nil)
    if not watchIndex or watchIndex <= 0 then
        return nil
    end

    if C_QuestLog and C_QuestLog.GetQuestIDForQuestWatchIndex then
        local ok, questID = SafeCall(C_QuestLog.GetQuestIDForQuestWatchIndex, watchIndex)
        if ok and type(questID) == "number" and questID > 0 then
            return questID
        end
    end

    if type(_G.GetQuestIndexForWatch) == "function" then
        local ok, questLogIndex = SafeCall(_G.GetQuestIndexForWatch, watchIndex)
        if ok and type(questLogIndex) == "number" and questLogIndex > 0 then
            return Compat.GetQuestIDByLogIndex(questLogIndex)
        end
    end

    return nil
end

function Compat.GetSuperTrackedQuestID()
    if C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID then
        local ok, questID = SafeCall(C_SuperTrack.GetSuperTrackedQuestID)
        if ok and type(questID) == "number" then
            return questID
        end
    end

    if type(_G.GetSuperTrackedQuestID) == "function" then
        local ok, questID = SafeCall(_G.GetSuperTrackedQuestID)
        if ok and type(questID) == "number" then
            return questID
        end
    end

    return 0
end

function Compat.SetSuperTrackedQuestID(questID)
    questID = SafeNumber(questID, 0) or 0

    if C_SuperTrack and C_SuperTrack.SetSuperTrackedQuestID then
        local ok = SafeCall(C_SuperTrack.SetSuperTrackedQuestID, questID)
        return ok and true or false
    end

    if type(_G.SetSuperTrackedQuestID) == "function" then
        local ok = SafeCall(_G.SetSuperTrackedQuestID, questID)
        return ok and true or false
    end

    return false
end

function Compat.GetTrackedAchievementIDs()
    local trackedIDs = {}
    local seen = {}

    local function AddID(id)
        if type(id) == "number" and id > 0 and not seen[id] then
            seen[id] = true
            trackedIDs[#trackedIDs + 1] = id
        end
    end

    if C_ContentTracking and Enum and Enum.ContentTrackingType and Enum.ContentTrackingType.Achievement and C_ContentTracking.GetTrackedIDs then
        local ok, ids = SafeCall(C_ContentTracking.GetTrackedIDs, Enum.ContentTrackingType.Achievement)
        if ok and type(ids) == "table" then
            for index = 1, #ids do
                AddID(ids[index])
            end
        end
    end

    if type(_G.GetNumTrackedAchievements) == "function" and type(_G.GetTrackedAchievement) == "function" then
        local ok, count = SafeCall(_G.GetNumTrackedAchievements)
        count = ok and (SafeNumber(count, 0) or 0) or 0

        for index = 1, count do
            local okID, achievementID = SafeCall(_G.GetTrackedAchievement, index)
            if okID then
                AddID(achievementID)
            end
        end
    end

    return trackedIDs
end

function PetTrackerCompat.IsLoaded()
    return petTrackerLoaded and true or false
end

function PetTrackerCompat.IsEnabled()
    return petTrackerEnabled and true or false
end

function PetTrackerCompat.SetupPetTrackerCompatibility()
    if setupAttempted then
        return petTrackerEnabled
    end

    setupAttempted = true
    petTrackerLoaded = AddOnCompat.IsAddOnLoaded("PetTracker")

    if not petTrackerLoaded then
        petTrackerEnabled = false
        return false
    end

    if not opt.enablePetTrackerCompatibility then
        petTrackerEnabled = false
        return false
    end

    -- Intentionally conservative.
    -- QuestKing does not reparent or restack PetTracker frames here because
    -- that approach is a taint risk on modern ObjectiveTracker/Edit Mode clients.
    -- This compatibility layer only records state and offers a future-safe hook point.
    petTrackerEnabled = true

    if QuestKing and type(QuestKing.RequestBlizzardTrackerVisualRefresh) == "function" then
        QuestKing:RequestBlizzardTrackerVisualRefresh()
    end

    return true
end

local function TrySetupPetTrackerCompatibility()
    PetTrackerCompat.SetupPetTrackerCompatibility()
end

if AddOnCompat.IsAddOnLoaded("PetTracker") then
    petTrackerLoaded = true
    TrySetupPetTrackerCompatibility()
else
    loaderFrame = CreateFrame("Frame")
    loaderFrame:RegisterEvent("ADDON_LOADED")
    loaderFrame:RegisterEvent("PLAYER_LOGIN")
    loaderFrame:SetScript("OnEvent", function(_, event, arg1)
        if event == "ADDON_LOADED" and arg1 == "PetTracker" then
            petTrackerLoaded = true
            TrySetupPetTrackerCompatibility()
        elseif event == "PLAYER_LOGIN" then
            petTrackerLoaded = AddOnCompat.IsAddOnLoaded("PetTracker")
            if petTrackerLoaded then
                TrySetupPetTrackerCompatibility()
            end
        end
    end)
end

petTrackerWatcher = loaderFrame
PetTrackerCompat.LoaderFrame = petTrackerWatcher

QuestKing.IsMainline = Compat.IsMainline
QuestKing.IsClassicEra = Compat.IsClassicEra
QuestKing.IsCataclysmClassic = Compat.IsCataclysmClassic
QuestKing.IsClassicFamily = Compat.IsClassicFamily

QuestKing.GetQuestLogIndexByQuestIDCompat = Compat.GetQuestLogIndexByQuestID
QuestKing.GetQuestIDByLogIndexCompat = Compat.GetQuestIDByLogIndex
QuestKing.IsQuestWatchedCompat = Compat.IsQuestWatched
QuestKing.AddQuestWatchCompat = Compat.AddQuestWatch
QuestKing.RemoveQuestWatchCompat = Compat.RemoveQuestWatch
QuestKing.GetQuestIDForWatchIndexCompat = Compat.GetQuestIDForWatchIndex
QuestKing.GetSuperTrackedQuestIDCompat = Compat.GetSuperTrackedQuestID
QuestKing.SetSuperTrackedQuestIDCompat = Compat.SetSuperTrackedQuestID
