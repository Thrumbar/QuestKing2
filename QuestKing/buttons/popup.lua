local addonName, QuestKing = ...

local opt = QuestKing.options
local opt_colors = opt.colors
local WatchButton = QuestKing.WatchButton

local pairs = pairs
local tonumber = tonumber
local type = type
local find = string.find
local gsub = string.gsub

local NUM_BAG_SLOTS_COMPAT = NUM_BAG_SLOTS or 4
local REAGENT_BAG_ID = Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag or nil

local LOOT_SELF_REGEX = gsub(LOOT_ITEM_SELF, "%%s", "(.+)")

local itemPopups = {}
local questStartItemSet = nil

local mouseHandlerPopup = {}

local function ResetPopupButtonState(button)
    if not button then
        return
    end

    button._popupType = nil
    button._itemID = nil
    button.questIndex = nil
    button.questLogIndex = nil
    button.questID = nil
end

local function PlaySoundCompat(soundKitID, legacyID)
    if not PlaySound then
        return
    end

    if SOUNDKIT and soundKitID then
        PlaySound(soundKitID)
        return
    end

    if legacyID then
        PlaySound(legacyID)
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
        return C_Container.GetContainerNumSlots(bagID) or 0
    end

    if GetContainerNumSlots then
        return GetContainerNumSlots(bagID) or 0
    end

    return 0
end

local function GetContainerItemIDCompat(bagID, slotID)
    if C_Container and C_Container.GetContainerItemID then
        return C_Container.GetContainerItemID(bagID, slotID)
    end

    if GetContainerItemID then
        return GetContainerItemID(bagID, slotID)
    end

    return nil
end

local function UseContainerItemCompat(bagID, slotID)
    if C_Container and C_Container.UseContainerItem then
        return C_Container.UseContainerItem(bagID, slotID)
    end

    if UseContainerItem then
        return UseContainerItem(bagID, slotID)
    end
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

local function UseContainerItemByID(searchID)
    if not searchID then
        return false
    end

    local used = false

    IteratePlayerBags(function(bagID)
        if used then
            return
        end

        local numSlots = GetContainerNumSlotsCompat(bagID)
        for slotID = 1, numSlots do
            local itemID = GetContainerItemIDCompat(bagID, slotID)
            if itemID == searchID then
                UseContainerItemCompat(bagID, slotID)
                used = true
                return
            end
        end
    end)

    return used
end

local function FindContainerItemByID(searchID)
    if not searchID then
        return false
    end

    local found = false

    IteratePlayerBags(function(bagID)
        if found then
            return
        end

        local numSlots = GetContainerNumSlotsCompat(bagID)
        for slotID = 1, numSlots do
            local itemID = GetContainerItemIDCompat(bagID, slotID)
            if itemID == searchID then
                found = true
                return
            end
        end
    end)

    return found
end

local function GetQuestLogIndexByIDCompat(questID)
    if not questID then
        return nil
    end

    if C_QuestLog and C_QuestLog.GetLogIndexForQuestID then
        local questLogIndex = C_QuestLog.GetLogIndexForQuestID(questID)
        if questLogIndex and questLogIndex > 0 then
            return questLogIndex
        end
    end

    if GetQuestLogIndexByID then
        local questLogIndex = GetQuestLogIndexByID(questID)
        if questLogIndex and questLogIndex > 0 then
            return questLogIndex
        end
    end

    return nil
end

local function RemoveAutoQuestPopUpCompat(questID)
    if RemoveAutoQuestPopUp and questID then
        RemoveAutoQuestPopUp(questID)
    end
end

local function IsTaskQuestCompat(questID)
    if not questID then
        return false
    end

    if C_QuestLog and C_QuestLog.IsQuestTask then
        return C_QuestLog.IsQuestTask(questID) and true or false
    end

    if C_TaskQuest and C_TaskQuest.IsActive then
        return C_TaskQuest.IsActive(questID) and true or false
    end

    if IsQuestTask then
        return IsQuestTask(questID) and true or false
    end

    return false
end

local function CallQuestPopupAPICompat(func, questID, questLogIndex)
    if type(func) ~= "function" then
        return false
    end

    if questID then
        local ok = pcall(func, questID)
        if ok then
            return true
        end
    end

    if questLogIndex then
        local ok = pcall(func, questLogIndex)
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

    questStartItemSet = {
        [1307] = true, [1357] = true, [1972] = true, [2839] = true, [3082] = true, [3317] = true,
        [4056] = true, [4433] = true, [4613] = true, [4854] = true, [4881] = true, [4926] = true,
        [5099] = true, [5102] = true, [5103] = true, [5138] = true, [5179] = true, [5352] = true,
        [5791] = true, [5877] = true, [6172] = true, [6196] = true, [6497] = true, [6766] = true,
        [6775] = true, [6776] = true, [6916] = true, [8244] = true, [8524] = true, [8623] = true,
        [8704] = true, [8705] = true, [9326] = true, [9572] = true, [10454] = true, [10589] = true,
        [10590] = true, [10593] = true, [10621] = true, [11116] = true, [11668] = true, [12558] = true,
        [12564] = true, [12771] = true, [12842] = true, [13140] = true, [14646] = true, [14647] = true,
        [14648] = true, [14649] = true, [14650] = true, [14651] = true, [16303] = true, [16304] = true,
        [16305] = true, [16408] = true, [16782] = true, [17008] = true, [17115] = true, [17116] = true,
        [17409] = true, [18356] = true, [18357] = true, [18358] = true, [18359] = true, [18360] = true,
        [18361] = true, [18362] = true, [18363] = true, [18364] = true, [18422] = true, [18423] = true,
        [18565] = true, [18589] = true, [18628] = true, [18703] = true, [18706] = true, [18769] = true,
        [18770] = true, [18771] = true, [18969] = true, [18987] = true, [19002] = true, [19003] = true,
        [19016] = true, [19018] = true, [19228] = true, [19257] = true, [19267] = true, [19277] = true,
        [19423] = true, [19443] = true, [19452] = true, [19802] = true, [20310] = true, [20460] = true,
        [20461] = true, [20483] = true, [20644] = true, [20741] = true, [20742] = true, [20765] = true,
        [20798] = true, [20806] = true, [20807] = true, [20938] = true, [20939] = true, [20940] = true,
        [20941] = true, [20942] = true, [20943] = true, [20944] = true, [20945] = true, [20946] = true,
        [20947] = true, [20948] = true, [21165] = true, [21166] = true, [21167] = true, [21220] = true,
        [21221] = true, [21230] = true, [21245] = true, [21246] = true, [21247] = true, [21248] = true,
        [21249] = true, [21250] = true, [21251] = true, [21252] = true, [21253] = true, [21255] = true,
        [21256] = true, [21257] = true, [21258] = true, [21259] = true, [21260] = true, [21261] = true,
        [21262] = true, [21263] = true, [21264] = true, [21265] = true, [21378] = true, [21379] = true,
        [21380] = true, [21381] = true, [21382] = true, [21384] = true, [21385] = true, [21514] = true,
        [21749] = true, [21750] = true, [21751] = true, [21776] = true, [22597] = true, [22600] = true,
        [22601] = true, [22602] = true, [22603] = true, [22604] = true, [22605] = true, [22606] = true,
        [22607] = true, [22608] = true, [22609] = true, [22610] = true, [22611] = true, [22612] = true,
        [22613] = true, [22614] = true, [22615] = true, [22616] = true, [22617] = true, [22618] = true,
        [22620] = true, [22621] = true, [22622] = true, [22623] = true, [22624] = true, [22719] = true,
        [22723] = true, [22727] = true, [22888] = true, [22970] = true, [22972] = true, [22973] = true,
        [22974] = true, [22975] = true, [22977] = true, [23179] = true, [23180] = true, [23181] = true,
        [23182] = true, [23183] = true, [23184] = true, [23216] = true, [23228] = true, [23249] = true,
        [23338] = true, [23580] = true, [23678] = true, [23759] = true, [23777] = true, [23797] = true,
        [23837] = true, [23850] = true, [23870] = true, [23890] = true, [23892] = true, [23900] = true,
        [23904] = true, [23910] = true, [24132] = true, [24228] = true, [24330] = true, [24367] = true,
        [24407] = true, [24414] = true, [24483] = true, [24484] = true, [24504] = true, [24558] = true,
        [24559] = true, [25459] = true, [25705] = true, [25706] = true, [25752] = true, [25753] = true,
        [28113] = true, [28114] = true, [28552] = true, [28598] = true, [29233] = true, [29234] = true,
        [29235] = true, [29236] = true, [29476] = true, [29588] = true, [29590] = true, [29738] = true,
        [30431] = true, [30579] = true, [30756] = true, [31120] = true, [31239] = true, [31241] = true,
        [31345] = true, [31363] = true, [31384] = true, [31489] = true, [31707] = true, [31890] = true,
        [31891] = true, [31907] = true, [31914] = true, [32385] = true, [32386] = true, [32405] = true,
        [32523] = true, [32621] = true, [32726] = true, [33102] = true, [33121] = true, [33289] = true,
        [33314] = true, [33345] = true, [33347] = true, [33961] = true, [33962] = true, [33978] = true,
        [34028] = true, [34090] = true, [34091] = true, [34469] = true, [34777] = true, [34815] = true,
        [34984] = true, [35120] = true, [35567] = true, [35568] = true, [35569] = true, [35648] = true,
        [35723] = true, [35787] = true, [35855] = true, [36742] = true, [36744] = true, [36746] = true,
        [36756] = true, [36780] = true, [36855] = true, [36856] = true, [36940] = true, [36958] = true,
        [37163] = true, [37164] = true, [37432] = true, [37571] = true, [37599] = true, [37736] = true,
        [37737] = true, [37830] = true, [37833] = true, [38280] = true, [38281] = true, [38321] = true,
        [38567] = true, [38660] = true, [38673] = true, [39713] = true, [40666] = true, [41267] = true,
        [41556] = true, [42203] = true, [42772] = true, [43242] = true, [43297] = true, [43512] = true,
        [44148] = true, [44158] = true, [44259] = true, [44276] = true, [44294] = true, [44326] = true,
        [44569] = true, [44577] = true, [44725] = true, [44927] = true, [44979] = true, [45039] = true,
        [45506] = true, [45857] = true, [46004] = true, [46052] = true, [46053] = true, [46128] = true,
        [46318] = true, [46697] = true, [46875] = true, [46876] = true, [46877] = true, [46878] = true,
        [46879] = true, [46880] = true, [46881] = true, [46882] = true, [46883] = true, [46884] = true,
        [46955] = true, [47039] = true, [47246] = true, [48679] = true, [49010] = true, [49200] = true,
        [49203] = true, [49205] = true, [49219] = true, [49220] = true, [49641] = true, [49643] = true,
        [49644] = true, [49667] = true, [49676] = true, [49776] = true, [49932] = true, [50320] = true,
        [50379] = true, [50380] = true, [51315] = true, [52079] = true, [52197] = true, [52831] = true,
        [53053] = true, [53106] = true, [54345] = true, [54614] = true, [54639] = true, [55166] = true,
        [55167] = true, [55181] = true, [55186] = true, [55243] = true, [56474] = true, [56571] = true,
        [56812] = true, [57102] = true, [57118] = true, [57935] = true, [58117] = true, [58491] = true,
        [58898] = true, [59143] = true, [60816] = true, [60886] = true, [60956] = true, [61310] = true,
        [61322] = true, [61378] = true, [61505] = true, [62021] = true, [62044] = true, [62045] = true,
        [62046] = true, [62056] = true, [62138] = true, [62281] = true, [62282] = true, [62483] = true,
        [62768] = true, [62933] = true, [63090] = true, [63250] = true, [63276] = true, [63686] = true,
        [63700] = true, [64353] = true, [64450] = true, [65894] = true, [65895] = true, [65896] = true,
        [65897] = true, [69854] = true, [70928] = true, [70932] = true, [71635] = true, [71636] = true,
        [71637] = true, [71638] = true, [71715] = true, [71716] = true, [71951] = true, [71952] = true,
        [71953] = true, [73058] = true, [74034] = true, [77957] = true, [78912] = true, [79238] = true,
        [79323] = true, [79324] = true, [79325] = true, [79326] = true, [79341] = true, [79343] = true,
        [79812] = true, [80240] = true, [80241] = true, [80597] = true, [80827] = true, [82808] = true,
        [82870] = true, [83076] = true, [83767] = true, [83769] = true, [83770] = true, [83771] = true,
        [83772] = true, [83773] = true, [83774] = true, [83777] = true, [83779] = true, [83780] = true,
        [85477] = true, [85557] = true, [85558] = true, [85783] = true, [86404] = true, [86433] = true,
        [86434] = true, [86435] = true, [86436] = true, [86542] = true, [86544] = true, [86545] = true,
        [87871] = true, [87878] = true, [88538] = true, [88563] = true, [88715] = true, [89169] = true,
        [89170] = true, [89171] = true, [89172] = true, [89173] = true, [89174] = true, [89175] = true,
        [89176] = true, [89178] = true, [89179] = true, [89180] = true, [89181] = true, [89182] = true,
        [89183] = true, [89184] = true, [89185] = true, [89209] = true, [89317] = true, [89812] = true,
        [89813] = true, [89814] = true, [91819] = true, [91821] = true, [91822] = true, [91854] = true,
        [91855] = true, [91856] = true, [92441] = true, [94197] = true, [94198] = true, [94199] = true,
        [94721] = true, [95383] = true, [95384] = true, [95385] = true, [95386] = true, [95387] = true,
        [95388] = true, [95389] = true, [95390] = true, [97978] = true, [97979] = true, [97980] = true,
        [97981] = true, [97982] = true, [97983] = true, [97984] = true, [97985] = true, [97986] = true,
        [97987] = true, [97988] = true, [97990] = true, [102225] = true, [105891] = true, [108824] = true,
        [108951] = true, [109012] = true, [109095] = true, [109121] = true, [110225] = true, [111478] = true,
        [112378] = true, [112566] = true, [112692] = true, [113080] = true, [113103] = true, [113107] = true,
        [113109] = true, [113260] = true, [113444] = true, [113445] = true, [113446] = true, [113447] = true,
        [113448] = true, [113449] = true, [113453] = true, [113454] = true, [113456] = true, [113457] = true,
        [113458] = true, [113459] = true, [113460] = true, [113461] = true, [113586] = true, [113590] = true,
        [114018] = true, [114019] = true, [114020] = true, [114021] = true, [114022] = true, [114023] = true,
        [114024] = true, [114025] = true, [114026] = true, [114027] = true, [114029] = true, [114030] = true,
        [114031] = true, [114032] = true, [114033] = true, [114034] = true, [114035] = true, [114036] = true,
        [114037] = true, [114038] = true, [114142] = true, [114144] = true, [114146] = true, [114148] = true,
        [114150] = true, [114152] = true, [114154] = true, [114156] = true, [114158] = true, [114160] = true,
        [114162] = true, [114164] = true, [114166] = true, [114168] = true, [114170] = true, [114172] = true,
        [114174] = true, [114176] = true, [114178] = true, [114182] = true, [114184] = true, [114186] = true,
        [114188] = true, [114208] = true, [114209] = true, [114210] = true, [114211] = true, [114212] = true,
        [114213] = true, [114215] = true, [114216] = true, [114217] = true, [114218] = true, [114219] = true,
        [114220] = true, [114221] = true, [114222] = true, [114223] = true, [114224] = true, [114877] = true,
        [114965] = true, [114972] = true, [114973] = true, [114984] = true, [115008] = true, [115278] = true,
        [115281] = true, [115287] = true, [115343] = true, [115467] = true, [115507] = true, [115593] = true,
        [116068] = true, [116159] = true, [116160] = true, [116173] = true, [116438] = true, [119208] = true,
        [119310] = true, [119316] = true, [119317] = true, [119323] = true, [120206] = true, [120207] = true,
        [120208] = true, [120209] = true, [120210] = true, [120211] = true, [120277] = true, [120278] = true,
        [120279] = true, [120280] = true, [120281] = true, [120282] = true, [120283] = true, [120284] = true,
        [120285] = true, [122190] = true, [122399] = true, [122400] = true, [122401] = true, [122402] = true,
        [122403] = true, [122404] = true, [122405] = true, [122406] = true, [122407] = true, [122408] = true,
        [122409] = true, [122410] = true, [122411] = true, [122412] = true, [122413] = true, [122414] = true,
        [122415] = true, [122416] = true, [122417] = true, [122418] = true, [122419] = true, [122420] = true,
        [122421] = true, [122422] = true, [122423] = true, [122424] = true, [122572] = true, [122573] = true,
    }

    return questStartItemSet
end

local function SetButtonToItemPopup(button, itemID, itemName)
    ResetPopupButtonState(button)

    button.mouseHandler = mouseHandlerPopup
    button._popupType = "ITEM"
    button._itemID = itemID

    button.title:SetText(itemName or ITEM or "Item")
    button.title:SetTextColor(opt_colors.PopupItemTitle[1], opt_colors.PopupItemTitle[2], opt_colors.PopupItemTitle[3])
    button:AddLine("  Item Begins a Quest", nil, opt_colors.PopupItemDescription[1], opt_colors.PopupItemDescription[2], opt_colors.PopupItemDescription[3])
    SetButtonBackdropColor(button, opt_colors.PopupItemBackground)
    button:SetIcon("QuestIcon-Exclamation")

    button.titleButton:EnableMouse(false)
    button:EnableMouse(true)
end

local function SetButtonToPopup(button, questID, popupType)
    local questLogIndex = GetQuestLogIndexByIDCompat(questID)
    local taggedTitle

    ResetPopupButtonState(button)

    button.mouseHandler = mouseHandlerPopup
    button._popupType = popupType
    button.questIndex = questLogIndex
    button.questLogIndex = questLogIndex
    button.questID = questID

    if questLogIndex then
        taggedTitle = QuestKing.GetQuestTaggedTitle(questLogIndex)
    elseif C_QuestLog and C_QuestLog.GetTitleForQuestID then
        taggedTitle = C_QuestLog.GetTitleForQuestID(questID)
    end

    if not taggedTitle or taggedTitle == "" then
        taggedTitle = NEW_QUEST_AVAILABLE or "New Quest!"
    end

    button.title:SetText(taggedTitle)

    if popupType == "COMPLETE" then
        button.title:SetTextColor(opt_colors.PopupCompleteTitle[1], opt_colors.PopupCompleteTitle[2], opt_colors.PopupCompleteTitle[3])
        button:AddLine(
            ("  %s"):format(GetPopupCompleteLineText(questID)),
            nil,
            opt_colors.PopupCompleteDescription[1],
            opt_colors.PopupCompleteDescription[2],
            opt_colors.PopupCompleteDescription[3]
        )
        SetButtonBackdropColor(button, opt_colors.PopupCompleteBackground)
        button:SetIcon("QuestIcon-QuestionMark")
    else
        button.title:SetTextColor(opt_colors.PopupOfferTitle[1], opt_colors.PopupOfferTitle[2], opt_colors.PopupOfferTitle[3])
        button:AddLine(
            ("  %s"):format(GetPopupOfferLineText()),
            nil,
            opt_colors.PopupOfferDescription[1],
            opt_colors.PopupOfferDescription[2],
            opt_colors.PopupOfferDescription[3]
        )
        SetButtonBackdropColor(button, opt_colors.PopupOfferBackground)
        button:SetIcon("QuestIcon-Exclamation")
    end

    button.titleButton:EnableMouse(false)
    button:EnableMouse(true)
end

function QuestKing:ParseLoot(msg)
    if not opt.enableItemPopups or not msg then
        return
    end

    local _, _, link = find(msg, LOOT_SELF_REGEX)
    if not link then
        return
    end

    local _, _, itemID, itemName = find(link, "item:(%d+):.*|h%[(.+)%]|h")
    itemID = tonumber(itemID)

    if not itemID then
        return
    end

    if BuildQuestStartItemSet()[itemID] then
        itemPopups[itemID] = itemName
        PlaySoundCompat(SOUNDKIT and SOUNDKIT.PVP_WARNING_HORDE, 9375)
        self:UpdateTracker()
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
    for itemID, itemName in pairs(itemPopups) do
        local button = WatchButton:GetKeyed("popup", itemID)
        SetButtonToItemPopup(button, itemID, itemName)
    end

    if not GetNumAutoQuestPopUps or not GetAutoQuestPopUp then
        return
    end

    local numPopups = GetNumAutoQuestPopUps() or 0
    for i = 1, numPopups do
        local questID, popupType = GetAutoQuestPopUp(i)
        if questID and popupType then
            local button = WatchButton:GetKeyed("popup", questID)
            SetButtonToPopup(button, questID, popupType)
        end
    end
end

function mouseHandlerPopup:ButtonOnClick(mouse)
    local popupType = self._popupType

    if popupType == "ITEM" then
        local itemID = self._itemID
        if not itemID then
            return
        end

        if mouse == "RightButton" then
            itemPopups[itemID] = nil
            QuestKing:UpdateTracker()
            return
        end

        UseContainerItemByID(itemID)
        itemPopups[itemID] = nil
        QuestKing:UpdateTracker()
        return
    end

    local questID = self.questID
    if not questID then
        return
    end

    if mouse == "RightButton" then
        RemoveAutoQuestPopUpCompat(questID)
        QuestKing:UpdateTracker()
        return
    end

    if popupType == "OFFER" then
        CallQuestPopupAPICompat(ShowQuestOffer, questID, self.questIndex)
        RemoveAutoQuestPopUpCompat(questID)
        QuestKing:UpdateTracker()
    elseif popupType == "COMPLETE" then
        CallQuestPopupAPICompat(ShowQuestComplete, questID, self.questIndex)
        RemoveAutoQuestPopUpCompat(questID)
        QuestKing:UpdateTracker()
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