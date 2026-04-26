local addonName, QuestKing = ...

local opt = QuestKing.options or {}
local opt_colors = (opt and opt.colors) or {}
local WatchButton = QuestKing.WatchButton

local C_Container = C_Container
local C_Item = C_Item
local C_QuestLog = C_QuestLog
local Enum = Enum

local find = string.find
local format = string.format
local gsub = string.gsub
local match = string.match
local pairs = pairs
local tonumber = tonumber
local type = type

local NUM_BAG_SLOTS_COMPAT = NUM_BAG_SLOTS or 4
local REAGENT_BAG_ID = Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag or nil
local LOOT_SELF_REGEX = LOOT_ITEM_SELF and gsub(LOOT_ITEM_SELF, "%%s", "(.+)") or nil

local DEFAULT_COLORS = {
    PopupOfferTitle = { 1.00, 0.96, 0.41 },
    PopupOfferDescription = { 1.00, 1.00, 1.00 },
    PopupOfferBackground = { 0.12, 0.24, 0.38, 0.70 },
    PopupCompleteTitle = { 0.30, 1.00, 0.60 },
    PopupCompleteDescription = { 1.00, 1.00, 1.00 },
    PopupCompleteBackground = { 0.09, 0.36, 0.29, 0.70 },
    PopupItemTitle = { 0.80, 0.90, 1.00 },
    PopupItemDescription = { 0.90, 0.90, 0.90 },
    PopupItemBackground = { 0.15, 0.15, 0.15, 0.60 },
}

local QUEST_START_ITEMS_CSV = [[
1307,1357,1972,2839,3082,3317,4056,4433,4613,4854,4881,4926,5099,5102,5103,5138,5179,5352,5791,5877,6172,6196
6497,6766,6775,6776,6916,8244,8524,8623,8704,8705,9326,9572,10454,10589,10590,10593,10621,11116,11668,12558
12564,12771,12842,13140,14646,14647,14648,14649,14650,14651,16303,16304,16305,16408,16782,17008,17115,17116
17409,18356,18357,18358,18359,18360,18361,18362,18363,18364,18422,18423,18565,18589,18628,18703,18706,18769
18770,18771,18969,18987,19002,19003,19016,19018,19228,19257,19267,19277,19423,19443,19452,19802,20310,20460
20461,20483,20644,20741,20742,20765,20798,20806,20807,20938,20939,20940,20941,20942,20943,20944,20945,20946
20947,20948,21165,21166,21167,21220,21221,21230,21245,21246,21247,21248,21249,21250,21251,21252,21253,21255
21256,21257,21258,21259,21260,21261,21262,21263,21264,21265,21378,21379,21380,21381,21382,21384,21385,21514
21749,21750,21751,21776,22597,22600,22601,22602,22603,22604,22605,22606,22607,22608,22609,22610,22611,22612
22613,22614,22615,22616,22617,22618,22620,22621,22622,22623,22624,22719,22723,22727,22888,22970,22972,22973
22974,22975,22977,23179,23180,23181,23182,23183,23184,23216,23228,23249,23338,23580,23678,23759,23777,23797
23837,23850,23870,23890,23892,23900,23904,23910,24132,24228,24330,24367,24407,24414,24483,24484,24504,24558
24559,25459,25705,25706,25752,25753,28113,28114,28552,28598,29233,29234,29235,29236,29476,29588,29590,29738
30431,30579,30756,31120,31239,31241,31345,31363,31384,31489,31707,31890,31891,31907,31914,32385,32386,32405
32523,32621,32726,33102,33121,33289,33314,33345,33347,33961,33962,33978,34028,34090,34091,34469,34777,34815
34984,35120,35567,35568,35569,35648,35723,35787,35855,36742,36744,36746,36756,36780,36855,36856,36940,36958
37163,37164,37432,37571,37599,37736,37737,37830,37833,38280,38281,38321,38567,38660,38673,39713,40666,41267
41556,42203,42772,43242,43297,43512,44148,44158,44259,44276,44294,44326,44569,44577,44725,44927,44979,45039
45506,45857,46004,46052,46053,46128,46318,46697,46875,46876,46877,46878,46879,46880,46881,46882,46883,46884
46955,47039,47246,48679,49010,49200,49203,49205,49219,49220,49641,49643,49644,49667,49676,49776,49932,50320
50379,50380,51315,52079,52197,52831,53053,53106,54345,54614,54639,55166,55167,55181,55186,55243,56474,56571
56812,57102,57118,57935,58117,58491,58898,59143,60816,60886,60956,61310,61322,61378,61505,62021,62044,62045
62046,62056,62138,62281,62282,62483,62768,62933,63090,63250,63276,63686,63700,64353,64450,65894,65895,65896
65897,69854,70928,70932,71635,71636,71637,71638,71715,71716,71951,71952,71953,73058,74034,77957,78912,79238
79323,79324,79325,79326,79341,79343,79812,80240,80241,80597,80827,82808,82870,83076,83767,83769,83770,83771
83772,83773,83774,83777,83779,83780,85477,85557,85558,85783,86404,86433,86434,86435,86436,86542,86544,86545
87871,87878,88538,88563,88715,89169,89170,89171,89172,89173,89174,89175,89176,89178,89179,89180,89181,89182
89183,89184,89185,89209,89317,89812,89813,89814,91819,91821,91822,91854,91855,91856,92441,94197,94198,94199
94721,95383,95384,95385,95386,95387,95388,95389,95390,97978,97979,97980,97981,97982,97983,97984,97985,97986
97987,97988,97990,102225,105891,108824,108951,109012,109095,109121,110225,111478,112378,112566,112692,113080
113103,113107,113109,113260,113444,113445,113446,113447,113448,113449,113453,113454,113456,113457,113458
113459,113460,113461,113586,113590,114018,114019,114020,114021,114022,114023,114024,114025,114026,114027
114029,114030,114031,114032,114033,114034,114035,114036,114037,114038,114142,114144,114146,114148,114150
114152,114154,114156,114158,114160,114162,114164,114166,114168,114170,114172,114174,114176,114178,114182
114184,114186,114188,114208,114209,114210,114211,114212,114213,114215,114216,114217,114218,114219,114220
114221,114222,114223,114224,114877,114965,114972,114973,114984,115008,115278,115281,115287,115343,115467
115507,115593,116068,116159,116160,116173,116438,119208,119310,119316,119317,119323,120206,120207,120208
120209,120210,120211,120277,120278,120279,120280,120281,120282,120283,120284,120285,122190,122399,122400
122401,122402,122403,122404,122405,122406,122407,122408,122409,122410,122411,122412,122413,122414,122415
122416,122417,122418,122419,122420,122421,122422,122423,122424,122572,122573
]]

local itemPopups = QuestKing.itemPopups or {}
local questStartItemSet = nil
local mouseHandlerPopup = {}

QuestKing.itemPopups = itemPopups

local function GetColor(name)
    return opt_colors[name] or DEFAULT_COLORS[name] or { 1, 1, 1, 1 }
end

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

local function SafeString(value, fallback)
    if type(value) == "string" and value ~= "" then
        return value
    end
    return fallback
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

local function QueueTrackerRefresh(forceBuild)
    if type(QuestKing.QueueTrackerUpdate) == "function" then
        QuestKing:QueueTrackerUpdate(forceBuild, false)
    elseif type(QuestKing.UpdateTracker) == "function" then
        QuestKing:UpdateTracker(forceBuild, false)
    end
end

local function ResetPopupButtonState(button)
    if not button then
        return
    end

    button.mouseHandler = mouseHandlerPopup
    button._popupType = nil
    button._itemID = nil
    button._itemName = nil
    button._itemLink = nil
    button._itemTexture = nil
    button._popupKey = nil
    button.questIndex = nil
    button.questLogIndex = nil
    button.questID = nil
end

local function PlaySoundCompat(soundKitID, legacyID)
    if type(PlaySound) ~= "function" then
        return
    end

    if SOUNDKIT and soundKitID then
        pcall(PlaySound, soundKitID)
        return
    end

    if legacyID then
        pcall(PlaySound, legacyID)
    end
end

local function SetButtonBackdropColor(button, color)
    if not button or not color or not button.SetBackdropColor then
        return
    end

    button:SetBackdropColor(color[1] or 0, color[2] or 0, color[3] or 0, color[4] or 0)
end

local function GetContainerNumSlotsCompat(bagID)
    if C_Container and C_Container.GetContainerNumSlots then
        local ok, numSlots = SafeCall(C_Container.GetContainerNumSlots, bagID)
        if ok then
            return SafeNumber(numSlots, 0) or 0
        end
    end

    if type(GetContainerNumSlots) == "function" then
        local ok, numSlots = SafeCall(GetContainerNumSlots, bagID)
        if ok then
            return SafeNumber(numSlots, 0) or 0
        end
    end

    return 0
end

local function GetContainerItemIDCompat(bagID, slotID)
    if C_Container and C_Container.GetContainerItemID then
        local ok, itemID = SafeCall(C_Container.GetContainerItemID, bagID, slotID)
        if ok then
            return SafeNumber(itemID, nil)
        end
    end

    if type(GetContainerItemID) == "function" then
        local ok, itemID = SafeCall(GetContainerItemID, bagID, slotID)
        if ok then
            return SafeNumber(itemID, nil)
        end
    end

    return nil
end

local function UseContainerItemCompat(bagID, slotID)
    if C_Container and C_Container.UseContainerItem then
        local ok = SafeCall(C_Container.UseContainerItem, bagID, slotID)
        return ok and true or false
    end

    if type(UseContainerItem) == "function" then
        local ok = SafeCall(UseContainerItem, bagID, slotID)
        return ok and true or false
    end

    return false
end

local function IteratePlayerBags(callback)
    if type(callback) ~= "function" then
        return
    end

    for bagID = 0, NUM_BAG_SLOTS_COMPAT do
        callback(bagID)
    end

    if REAGENT_BAG_ID ~= nil then
        callback(REAGENT_BAG_ID)
    end
end

local function FindContainerPositionByID(searchID)
    if type(searchID) ~= "number" or searchID <= 0 then
        return nil, nil
    end

    local foundBagID, foundSlotID = nil, nil

    IteratePlayerBags(function(bagID)
        if foundBagID then
            return
        end

        local numSlots = GetContainerNumSlotsCompat(bagID)
        for slotID = 1, numSlots do
            local itemID = GetContainerItemIDCompat(bagID, slotID)
            if itemID == searchID then
                foundBagID = bagID
                foundSlotID = slotID
                return
            end
        end
    end)

    return foundBagID, foundSlotID
end

local function FindContainerItemByID(searchID)
    local bagID = FindContainerPositionByID(searchID)
    return bagID ~= nil
end

local function UseContainerItemByID(searchID)
    local bagID, slotID = FindContainerPositionByID(searchID)
    if not bagID or not slotID then
        return false
    end

    return UseContainerItemCompat(bagID, slotID)
end

local function GetQuestLogIndexByIDCompat(questID)
    if type(questID) ~= "number" or questID <= 0 then
        return nil
    end

    if C_QuestLog and C_QuestLog.GetLogIndexForQuestID then
        local ok, questLogIndex = SafeCall(C_QuestLog.GetLogIndexForQuestID, questID)
        if ok and type(questLogIndex) == "number" and questLogIndex > 0 then
            return questLogIndex
        end
    end

    if type(GetQuestLogIndexByID) == "function" then
        local ok, questLogIndex = SafeCall(GetQuestLogIndexByID, questID)
        if ok and type(questLogIndex) == "number" and questLogIndex > 0 then
            return questLogIndex
        end
    end

    return nil
end

local function RemoveAutoQuestPopUpCompat(questID)
    if type(RemoveAutoQuestPopUp) == "function" and type(questID) == "number" and questID > 0 then
        SafeCall(RemoveAutoQuestPopUp, questID)
    end
end

local function IsTaskQuestCompat(questID)
    if type(questID) ~= "number" or questID <= 0 then
        return false
    end

    if C_QuestLog and C_QuestLog.IsQuestTask then
        local ok, isTask = SafeCall(C_QuestLog.IsQuestTask, questID)
        if ok then
            return isTask and true or false
        end
    end

    if C_TaskQuest and C_TaskQuest.IsActive then
        local ok, isTask = SafeCall(C_TaskQuest.IsActive, questID)
        if ok then
            return isTask and true or false
        end
    end

    if type(IsQuestTask) == "function" then
        local ok, isTask = SafeCall(IsQuestTask, questID)
        if ok then
            return isTask and true or false
        end
    end

    return false
end

local function CallQuestPopupAPICompat(func, questID, questLogIndex)
    if type(func) ~= "function" then
        return false
    end

    if type(questID) == "number" and questID > 0 then
        local ok = SafeCall(func, questID)
        if ok then
            return true
        end
    end

    if type(questLogIndex) == "number" and questLogIndex > 0 then
        local ok = SafeCall(func, questLogIndex)
        if ok then
            return true
        end
    end

    return false
end

local function GetPopupOfferLineText()
    return QUEST_WATCH_POPUP_CLICK_TO_VIEW
        or QUEST_WATCH_POPUP_QUEST_DISCOVERED
        or QUEST_WATCH_QUEST_READY
        or "Click to view"
end

local function GetPopupCompleteLineText(questID)
    if IsTaskQuestCompat(questID) then
        return QUEST_WATCH_POPUP_CLICK_TO_COMPLETE_TASK
            or QUEST_WATCH_POPUP_CLICK_TO_COMPLETE
            or QUEST_WATCH_QUEST_READY
            or "Click to complete"
    end

    return QUEST_WATCH_POPUP_CLICK_TO_COMPLETE
        or QUEST_WATCH_QUEST_READY
        or "Click to complete"
end

local function BuildQuestStartItemSet()
    if questStartItemSet then
        return questStartItemSet
    end

    questStartItemSet = {}
    for itemID in QUEST_START_ITEMS_CSV:gmatch("%d+") do
        questStartItemSet[tonumber(itemID)] = true
    end

    return questStartItemSet
end

local function GetItemInfoCompat(itemID)
    if type(itemID) ~= "number" or itemID <= 0 then
        return nil, nil, nil
    end

    if C_Item and C_Item.GetItemNameByID and C_Item.GetItemIconByID then
        local okName, itemName = SafeCall(C_Item.GetItemNameByID, itemID)
        local okIcon, texture = SafeCall(C_Item.GetItemIconByID, itemID)
        if okName and itemName then
            return itemName, itemName and ("item:" .. itemID) or nil, okIcon and texture or nil
        end
    end

    if type(GetItemInfo) == "function" then
        local ok, itemName, itemLink, _, _, _, _, _, _, texture = SafeCall(GetItemInfo, itemID)
        if ok and itemName then
            return itemName, itemLink, texture
        end
    end

    if type(GetItemInfoInstant) == "function" then
        local ok, _, _, _, _, _, _, _, _, texture = SafeCall(GetItemInfoInstant, itemID)
        if ok then
            return nil, nil, texture
        end
    end

    return nil, nil, nil
end

local function GetQuestPopupTitle(questID, questLogIndex)
    if type(questLogIndex) == "number" and questLogIndex > 0 and type(QuestKing.GetQuestTaggedTitle) == "function" then
        local ok, taggedTitle = SafeCall(QuestKing.GetQuestTaggedTitle, questLogIndex)
        if ok and taggedTitle and taggedTitle ~= "" then
            return taggedTitle
        end
    end

    if C_QuestLog and C_QuestLog.GetTitleForQuestID and type(questID) == "number" and questID > 0 then
        local ok, title = SafeCall(C_QuestLog.GetTitleForQuestID, questID)
        if ok and title and title ~= "" then
            return title
        end
    end

    return NEW_QUEST_AVAILABLE or "New Quest!"
end

local function SetPopupVisuals(button, titleColorName, backgroundColorName, iconType)
    local titleColor = GetColor(titleColorName)
    local backgroundColor = GetColor(backgroundColorName)

    button.title:SetTextColor(titleColor[1] or 1, titleColor[2] or 1, titleColor[3] or 1)
    SetButtonBackdropColor(button, backgroundColor)
    button:SetIcon(iconType)
    button.titleButton:EnableMouse(false)
    button:EnableMouse(true)
end

local function SetButtonToItemPopup(button, itemID, popupInfo)
    ResetPopupButtonState(button)

    popupInfo = type(popupInfo) == "table" and popupInfo or {}

    local itemName = popupInfo.name
    local itemLink = popupInfo.link
    local itemTexture = popupInfo.texture

    if not itemName or not itemLink or not itemTexture then
        local resolvedName, resolvedLink, resolvedTexture = GetItemInfoCompat(itemID)
        itemName = itemName or resolvedName
        itemLink = itemLink or resolvedLink
        itemTexture = itemTexture or resolvedTexture
    end

    button._popupType = "ITEM"
    button._popupKey = "item:" .. tostring(itemID)
    button._itemID = itemID
    button._itemName = itemName
    button._itemLink = itemLink
    button._itemTexture = itemTexture

    button.title:SetText(itemName or ITEM or "Item")
    button:AddLine(
        "  " .. (ITEM_STARTS_QUEST or "Item Begins a Quest"),
        nil,
        (GetColor("PopupItemDescription"))[1],
        (GetColor("PopupItemDescription"))[2],
        (GetColor("PopupItemDescription"))[3]
    )

    SetPopupVisuals(button, "PopupItemTitle", "PopupItemBackground", "QuestIcon-Exclamation")
end

local function SetButtonToQuestPopup(button, questID, popupType)
    local questLogIndex = GetQuestLogIndexByIDCompat(questID)

    ResetPopupButtonState(button)

    button._popupType = popupType
    button._popupKey = "quest:" .. tostring(questID) .. ":" .. tostring(popupType)
    button.questIndex = questLogIndex
    button.questLogIndex = questLogIndex
    button.questID = questID

    button.title:SetText(GetQuestPopupTitle(questID, questLogIndex))

    if popupType == "COMPLETE" then
        local descriptionColor = GetColor("PopupCompleteDescription")
        button:AddLine(
            "  " .. GetPopupCompleteLineText(questID),
            nil,
            descriptionColor[1],
            descriptionColor[2],
            descriptionColor[3]
        )
        SetPopupVisuals(button, "PopupCompleteTitle", "PopupCompleteBackground", "QuestIcon-QuestionMark")
    else
        local descriptionColor = GetColor("PopupOfferDescription")
        button:AddLine(
            "  " .. GetPopupOfferLineText(),
            nil,
            descriptionColor[1],
            descriptionColor[2],
            descriptionColor[3]
        )
        SetPopupVisuals(button, "PopupOfferTitle", "PopupOfferBackground", "QuestIcon-Exclamation")
    end
end

local function CleanupStaleItemPopups()
    for itemID in pairs(itemPopups) do
        if not FindContainerItemByID(itemID) then
            itemPopups[itemID] = nil
        end
    end
end

local function OpenItemPopupTooltip(owner, itemID, popupInfo)
    if not owner or type(itemID) ~= "number" or itemID <= 0 or not QuestKing.PrepareTooltip then
        return
    end

    local tooltip = QuestKing:PrepareTooltip(owner, opt.tooltipAnchor or "ANCHOR_RIGHT")
    if not tooltip then
        return
    end

    local itemLink = popupInfo and popupInfo.link or nil

    if tooltip.SetHyperlink and itemLink then
        local ok = SafeCall(tooltip.SetHyperlink, tooltip, itemLink)
        if ok then
            tooltip:AddLine(" ")
            tooltip:AddLine("Left-click to use the item", 0.7, 0.7, 0.7)
            tooltip:AddLine("Right-click to dismiss", 0.7, 0.7, 0.7)
            tooltip:Show()
            return
        end
    end

    if tooltip.SetItemByID then
        local ok = SafeCall(tooltip.SetItemByID, tooltip, itemID)
        if ok then
            tooltip:AddLine(" ")
            tooltip:AddLine("Left-click to use the item", 0.7, 0.7, 0.7)
            tooltip:AddLine("Right-click to dismiss", 0.7, 0.7, 0.7)
            tooltip:Show()
            return
        end
    end

    local itemName = popupInfo and popupInfo.name or nil
    tooltip:SetText(itemName or ITEM or "Item", 1, 0.82, 0)
    tooltip:AddLine(ITEM_STARTS_QUEST or "Item Begins a Quest", 1, 1, 1, true)
    tooltip:AddLine(" ")
    tooltip:AddLine("Left-click to use the item", 0.7, 0.7, 0.7)
    tooltip:AddLine("Right-click to dismiss", 0.7, 0.7, 0.7)
    tooltip:Show()
end

local function OpenQuestPopupTooltip(owner, questID, popupType, questLogIndex)
    if not owner or type(questID) ~= "number" or questID <= 0 or not QuestKing.PrepareTooltip then
        return
    end

    local tooltip = QuestKing:PrepareTooltip(owner, opt.tooltipAnchor or "ANCHOR_RIGHT")
    if not tooltip then
        return
    end

    tooltip:SetText(GetQuestPopupTitle(questID, questLogIndex), 1, 0.82, 0)

    if popupType == "COMPLETE" then
        tooltip:AddLine(GetPopupCompleteLineText(questID), 1, 1, 1, true)
    else
        tooltip:AddLine(GetPopupOfferLineText(), 1, 1, 1, true)
    end

    tooltip:AddLine(" ")
    tooltip:AddLine("Left-click to open the popup", 0.7, 0.7, 0.7)
    tooltip:AddLine("Right-click to dismiss", 0.7, 0.7, 0.7)
    tooltip:Show()
end

function QuestKing:ParseLoot(msg)
    if not opt.enableItemPopups or type(msg) ~= "string" or msg == "" then
        return
    end

    local itemID = SafeNumber(msg:match("|Hitem:(%d+)"), nil)
    local itemName = SafeString(msg:match("|h%[(.-)%]|h"), nil)

    if not itemID and LOOT_SELF_REGEX then
        local _, _, link = find(msg, LOOT_SELF_REGEX)
        if link then
            itemID = SafeNumber(link:match("item:(%d+)"), nil)
            itemName = itemName or SafeString(link:match("|h%[(.-)%]|h"), nil)
        end
    end

    if not itemID then
        return
    end

    if BuildQuestStartItemSet()[itemID] then
        local resolvedName, itemLink, itemTexture = GetItemInfoCompat(itemID)
        itemPopups[itemID] = {
            name = itemName or resolvedName,
            link = itemLink,
            texture = itemTexture,
        }
        PlaySoundCompat(SOUNDKIT and SOUNDKIT.PVP_WARNING_HORDE, 9375)
        QueueTrackerRefresh(true)
    end
end

function QuestKing:InitLoot()
    if opt.enableItemPopups then
        BuildQuestStartItemSet()
        return
    end

    if self.EventsFrame then
        self.EventsFrame:UnregisterEvent("CHAT_MSG_LOOT")
    end
end

function QuestKing:UpdateTrackerPopups()
    CleanupStaleItemPopups()

    for itemID, popupInfo in pairs(itemPopups) do
        local button = WatchButton:GetKeyed("popup", "item:" .. tostring(itemID))
        SetButtonToItemPopup(button, itemID, popupInfo)
    end

    if type(GetNumAutoQuestPopUps) ~= "function" or type(GetAutoQuestPopUp) ~= "function" then
        return
    end

    local okCount, numPopups = SafeCall(GetNumAutoQuestPopUps)
    numPopups = okCount and (SafeNumber(numPopups, 0) or 0) or 0

    for index = 1, numPopups do
        local okPopup, questID, popupType = SafeCall(GetAutoQuestPopUp, index)
        questID = okPopup and (SafeNumber(questID, nil)) or nil
        popupType = okPopup and SafeString(popupType, nil) or nil

        if questID and popupType then
            local button = WatchButton:GetKeyed("popup", "quest:" .. tostring(questID) .. ":" .. popupType)
            SetButtonToQuestPopup(button, questID, popupType)
        end
    end
end

function mouseHandlerPopup:ButtonOnClick(mouse)
    local button = self
    local popupType = button and button._popupType

    if popupType == "ITEM" then
        local itemID = button._itemID
        if not itemID then
            return
        end

        if mouse == "RightButton" then
            itemPopups[itemID] = nil
            QueueTrackerRefresh(true)
            return
        end

        if UseContainerItemByID(itemID) then
            itemPopups[itemID] = nil
            QueueTrackerRefresh(true)
        elseif not FindContainerItemByID(itemID) then
            itemPopups[itemID] = nil
            QueueTrackerRefresh(true)
        end
        return
    end

    local questID = button and button.questID
    local questLogIndex = button and (button.questLogIndex or button.questIndex)
    if not questID then
        return
    end

    if mouse == "RightButton" then
        RemoveAutoQuestPopUpCompat(questID)
        QueueTrackerRefresh(true)
        return
    end

    if popupType == "OFFER" then
        CallQuestPopupAPICompat(ShowQuestOffer, questID, questLogIndex)
        RemoveAutoQuestPopUpCompat(questID)
        QueueTrackerRefresh(true)
    elseif popupType == "COMPLETE" then
        CallQuestPopupAPICompat(ShowQuestComplete, questID, questLogIndex)
        RemoveAutoQuestPopUpCompat(questID)
        QueueTrackerRefresh(true)
    end
end

function mouseHandlerPopup:TitleButtonOnEnter()
    local button = self.parent or self
    if not button then
        return
    end

    if button._popupType == "ITEM" then
        OpenItemPopupTooltip(self, button._itemID, itemPopups[button._itemID])
    else
        OpenQuestPopupTooltip(self, button.questID, button._popupType, button.questLogIndex or button.questIndex)
    end
end

function mouseHandlerPopup:TitleButtonOnLeave()
    if QuestKing.HideTooltip then
        QuestKing:HideTooltip()
    end
end

function QuestKing:HasTrackedPopupItem(itemID)
    return itemPopups[itemID] ~= nil
end

function QuestKing:RemoveTrackedPopupItem(itemID)
    itemPopups[itemID] = nil
end

function QuestKing:FindTrackedPopupItemInBags(itemID)
    return FindContainerItemByID(itemID)
end

function QuestKing:IsQuestStartItemID(itemID)
    itemID = SafeNumber(itemID, nil)
    return itemID and BuildQuestStartItemSet()[itemID] and true or false
end
