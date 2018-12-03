local addonName, QuestKing = ...

-- options
local opt = QuestKing.options
local opt_colors = opt.colors

-- import
local WatchButton = QuestKing.WatchButton

local pairs = pairs
local find = string.find
local tContains = tContains

-- local functions
local useContainerItemByID, findContainerItemByID
local setButtonToItemPopup, setButtonToPopup

-- local variables
local QUEST_START_ITEMS = nil
local LOOT_SELF_REGEX = gsub(LOOT_ITEM_SELF, "%%s", "(.+)")

local itemPopups = {}

local mouseHandlerPopup = {}

--

function useContainerItemByID (searchID)
	for i = 0, 4 do
		for j = 1, GetContainerNumSlots(i) do
			local id = GetContainerItemID(i, j)
			if (id == searchID) then
				UseContainerItem(i, j)
				return
			end
		end
	end
end

function findContainerItemByID (searchID)
	for i = 0, 4 do
		for j = 1, GetContainerNumSlots(i) do
			local id = GetContainerItemID(i, j)
			if (id == searchID) then
				return true
			end
		end
	end
	return false
end

function QuestKing:ParseLoot (msg)
	local _, _, link = find(msg, LOOT_SELF_REGEX)
	if link then
		local _, _, itemID, itemName = find(link, "item:(%d+):.*|h%[(.+)%]|h")
		itemID = tonumber(itemID)
		if itemID then
			-- if (tContains(QUEST_START_ITEMS, itemID)) and (not findContainerItemByID(itemID)) then
			-- ^ these generally seem to be unique, but if you somehow keep looting them, maybe repeated alerts are for the best...
			if (tContains(QUEST_START_ITEMS, itemID)) then
				itemPopups[itemID] = itemName
				PlaySound(SOUNDKIT.IG_QUEST_LOG_OPEN) -- PVPWarningHordeMono
				QuestKing:UpdateTracker()
			end
		end
	end
end

function QuestKing:InitLoot()
	if (opt.enableItemPopups) then
		QUEST_START_ITEMS = {1307,1357,1972,2839,3082,3317,4056,4433,4613,4854,4881,4926,5099,5102,5103,5138,5179,5352,5791,5877,6172,6196,6497,6766,6775,6776,6916,8244,8524,8623,8704,8705,9326,9572,10454,10589,10590,10593,10621,11116,11668,12558,12564,12771,12842,13140,14646,14647,14648,14649,14650,14651,16303,16304,16305,16408,16782,17008,17115,17116,17409,18356,18357,18358,18359,18360,18361,18362,18363,18364,18422,18423,18565,18589,18628,18703,18706,18769,18770,18771,18969,18987,19002,19003,19016,19018,19228,19257,19267,19277,19423,19443,19452,19802,20310,20460,20461,20483,20644,20741,20742,20765,20798,20806,20807,20938,20939,20940,20941,20942,20943,20944,20945,20946,20947,20948,21165,21166,21167,21220,21221,21230,21245,21246,21247,21248,21249,21250,21251,21252,21253,21255,21256,21257,21258,21259,21260,21261,21262,21263,21264,21265,21378,21379,21380,21381,21382,21384,21385,21514,21749,21750,21751,21776,22597,22600,22601,22602,22603,22604,22605,22606,22607,22608,22609,22610,22611,22612,22613,22614,22615,22616,22617,22618,22620,22621,22622,22623,22624,22719,22723,22727,22888,22970,22972,22973,22974,22975,22977,23179,23180,23181,23182,23183,23184,23216,23228,23249,23338,23580,23678,23759,23777,23797,23837,23850,23870,23890,23892,23900,23904,23910,24132,24228,24330,24367,24407,24414,24483,24484,24504,24558,24559,25459,25705,25706,25752,25753,28113,28114,28552,28598,29233,29234,29235,29236,29476,29588,29590,29738,30431,30579,30756,31120,31239,31241,31345,31363,31384,31489,31707,31890,31891,31907,31914,32385,32386,32405,32523,32621,32726,33102,33121,33289,33314,33345,33347,33961,33962,33978,34028,34090,34091,34469,34777,34815,34984,35120,35567,35568,35569,35648,35723,35787,35855,36742,36744,36746,36756,36780,36855,36856,36940,36958,37163,37164,37432,37571,37599,37736,37737,37830,37833,38280,38281,38321,38567,38660,38673,39713,40666,41267,41556,42203,42772,43242,43297,43512,44148,44158,44259,44276,44294,44326,44569,44577,44725,44927,44979,45039,45506,45857,46004,46052,46053,46128,46318,46697,46875,46876,46877,46878,46879,46880,46881,46882,46883,46884,46955,47039,47246,48679,49010,49200,49203,49205,49219,49220,49641,49643,49644,49667,49676,49776,49932,50320,50379,50380,51315,52079,52197,52831,53053,53106,54345,54614,54639,55166,55167,55181,55186,55243,56474,56571,56812,57102,57118,57935,58117,58491,58898,59143,60816,60886,60956,61310,61322,61378,61505,62021,62044,62045,62046,62056,62138,62281,62282,62483,62768,62933,63090,63250,63276,63686,63700,64353,64450,65894,65895,65896,65897,69854,70928,70932,71635,71636,71637,71638,71715,71716,71951,71952,71953,73058,74034,77957,78912,79238,79323,79324,79325,79326,79341,79343,79812,80240,80241,80597,80827,82808,82870,83076,83767,83769,83770,83771,83772,83773,83774,83777,83779,83780,85477,85557,85558,85783,86404,86433,86434,86435,86436,86542,86544,86545,87871,87878,88538,88563,88715,89169,89170,89171,89172,89173,89174,89175,89176,89178,89179,89180,89181,89182,89183,89184,89185,89209,89317,89812,89813,89814,91819,91821,91822,91854,91855,91856,92441,94197,94198,94199,94721,95383,95384,95385,95386,95387,95388,95389,95390,97978,97979,97980,97981,97982,97983,97984,97985,97986,97987,97988,97990,102225,105891,108824,108951,109012,109095,109121,110225,111478,112378,112566,112692,113080,113103,113107,113109,113260,113444,113445,113446,113447,113448,113449,113453,113454,113456,113457,113458,113459,113460,113461,113586,113590,114018,114019,114020,114021,114022,114023,114024,114025,114026,114027,114029,114030,114031,114032,114033,114034,114035,114036,114037,114038,114142,114144,114146,114148,114150,114152,114154,114156,114158,114160,114162,114164,114166,114168,114170,114172,114174,114176,114178,114182,114184,114186,114188,114208,114209,114210,114211,114212,114213,114215,114216,114217,114218,114219,114220,114221,114222,114223,114224,114877,114965,114972,114973,114984,115008,115278,115281,115287,115343,115467,115507,115593,116068,116159,116160,116173,116438,119208,119310,119316,119317,119323,120206,120207,120208,120209,120210,120211,120277,120278,120279,120280,120281,120282,120283,120284,120285,122190,122399,122400,122401,122402,122403,122404,122405,122406,122407,122408,122409,122410,122411,122412,122413,122414,122415,122416,122417,122418,122419,122420,122421,122422,122423,122424,122572,122573}
	else
		QuestKing.EventsFrame:UnregisterEvent("CHAT_MSG_LOOT")
	end
end

--

function QuestKing:UpdateTrackerPopups()
	for itemID, itemName in pairs(itemPopups) do
		local button = WatchButton:GetKeyed("popup", itemID)
		setButtonToItemPopup(button, itemID, itemName)
	end

	local numPopups = GetNumAutoQuestPopUps()
	for i = 1, numPopups do
		local popID, popType = GetAutoQuestPopUp(i)

		local button = WatchButton:GetKeyed("popup", popID)
		setButtonToPopup(button, popID, popType)
	end
end

function setButtonToItemPopup (button, itemID, itemName)
	button.mouseHandler = mouseHandlerPopup

	button._popupType = "ITEM"
	button._itemID = itemID

	button.title:SetText(itemName)
	button.title:SetTextColor(opt_colors.PopupItemTitle[1], opt_colors.PopupItemTitle[2], opt_colors.PopupItemTitle[3])
	button:AddLine("  Item Begins a Quest", nil, opt_colors.PopupItemDescription[1], opt_colors.PopupItemDescription[2], opt_colors.PopupItemDescription[3])
	button:SetBackdropColor(opt_colors.PopupItemBackground[1], opt_colors.PopupItemBackground[2], opt_colors.PopupItemBackground[3], opt_colors.PopupItemBackground[4])
	button:SetIcon("QuestIcon-Exclamation")

	button.titleButton:EnableMouse(false)
	button:EnableMouse(true)
end

function setButtonToPopup (button, questID, popType)
	button.mouseHandler = mouseHandlerPopup

	local questIndex = GetQuestLogIndexByID(questID)
	local taggedTitle
	--enter the nexus?
	--D(button, questID, popType, questIndex)
	if (questIndex == 0) or (questIndex == nil) then
		--D("NQ")
		taggedTitle = "New Quest!"
	else
		--D("TI")
		taggedTitle = QuestKing.GetQuestTaggedTitle(questIndex)
	end

	button._popupType = popType
	button.questIndex = questIndex
	button.questID = questID

	button.title:SetText(taggedTitle)

	if popType == "COMPLETE" then
		button.title:SetTextColor(opt_colors.PopupCompleteTitle[1], opt_colors.PopupCompleteTitle[2], opt_colors.PopupCompleteTitle[3])
		button:AddLine("  Quest Completed", nil, opt_colors.PopupCompleteDescription[1], opt_colors.PopupCompleteDescription[2], opt_colors.PopupCompleteDescription[3])
		button:SetBackdropColor(opt_colors.PopupCompleteBackground[1], opt_colors.PopupCompleteBackground[2], opt_colors.PopupCompleteBackground[3], opt_colors.PopupCompleteBackground[4])
		button:SetIcon("QuestIcon-QuestionMark")
	else
		button.title:SetTextColor(opt_colors.PopupOfferTitle[1], opt_colors.PopupOfferTitle[2], opt_colors.PopupOfferTitle[3])
		button:AddLine("  Quest Received", nil, opt_colors.PopupOfferDescription[1], opt_colors.PopupOfferDescription[2], opt_colors.PopupOfferDescription[3])
		button:SetBackdropColor(opt_colors.PopupOfferBackground[1], opt_colors.PopupOfferBackground[2], opt_colors.PopupOfferBackground[3], opt_colors.PopupOfferBackground[4])
		button:SetIcon("QuestIcon-Exclamation")
	end
	button.titleButton:EnableMouse(false)
	button:EnableMouse(true)
end

function mouseHandlerPopup:ButtonOnClick (mouse, down)
	if self._popupType == "ITEM" then
		if mouse == "RightButton" then
			itemPopups[self._itemID] = nil
			QuestKing:UpdateTracker()
		else
			--if InCombatLockdown() then return end
			useContainerItemByID(self._itemID)
			itemPopups[self._itemID] = nil
			QuestKing:UpdateTracker()
		end
	elseif mouse == "RightButton" then
		RemoveAutoQuestPopUp(self.questID)
		QuestKing:UpdateTracker()
	else
		if self._popupType == "OFFER" then
			-- QuestObjectiveTracker_OpenQuestMap(nil, self.questIndex)
			ShowQuestOffer(self.questIndex)
			RemoveAutoQuestPopUp(self.questID)
			QuestKing:UpdateTracker()
		elseif self._popupType == "COMPLETE" then
			ShowQuestComplete(self.questIndex)
			RemoveAutoQuestPopUp(self.questID)
			QuestKing:UpdateTracker()
		end
	end
end