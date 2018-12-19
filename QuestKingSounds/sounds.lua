local addonName, QuestKingSounds = ...
local opt = QuestKingSounds.options

-- options

local opt_playObjProgress = opt.playObjProgress
local opt_playObjComplete = opt.playObjComplete
local opt_playQuestComplete = opt.playQuestComplete
local opt_showQuestCompleteMessage = opt.showQuestCompleteMessage

-- import

local GetQuestLogTitle = GetQuestLogTitle
local GetNumQuestLeaderBoards = GetNumQuestLeaderBoards
local GetQuestLogLeaderBoard = GetQuestLogLeaderBoard
local GetQuestLogIndexByID = GetQuestLogIndexByID
local tremove = table.remove
local tinsert = table.insert

-- local variables

local fEvents = CreateFrame("Frame", "QuestKingSounds_Events")

local soundLevel = 0
local pendingUpdates = {}
local questCompleteObjectives = {}

--

local function setSoundLevel (level)
	if (level > soundLevel) then
		soundLevel = level
	end
end

local function playSoundAuto (sound)
	if (not sound) then return end
	local low = strlower(sound)

	if ((string.sub(low, -4) == ".wav") or (string.sub(low, -4) == ".mp3")  or (string.sub(low, -4) == ".ogg")) then
		PlaySoundFile(sound)
	else
		PlaySound(sound)
	end
end

local function playQuestSound ()
	if (soundLevel == 0) then
		return
	elseif (soundLevel == 1) then
		playSoundAuto(opt.soundObjProgress)
	elseif (soundLevel == 2) then
		playSoundAuto(opt.soundObjComplete)
	elseif (soundLevel == 3) then
		playSoundAuto(opt.soundQuestComplete)
	end
end

--

local function checkQuestCompletion (questIndex)
	local _, _, _, _, _, questIsComplete, _, questID = GetQuestLogTitle(questIndex)

	local numCompleteObjectives = 0
	local numObj = GetNumQuestLeaderBoards(questIndex) or 0

	for i = 1, numObj do
		local _, _, objIsComplete = GetQuestLogLeaderBoard(i, questIndex)
		if (objIsComplete) then
			numCompleteObjectives = numCompleteObjectives + 1
		end
	end

	return questID, questIsComplete, numCompleteObjectives
end

local function addPendingUpdate (questIndex)
	local questID, questIsComplete, numCompleteObjectives = checkQuestCompletion(questIndex)
	questCompleteObjectives[questID] = numCompleteObjectives
	tinsert(pendingUpdates, questID)
end

local function checkPendingUpdates ()
	if (#pendingUpdates < 1) then return end

	for i = #pendingUpdates, 1, -1 do
		local questID = tremove(pendingUpdates, i)
		local questIndex = GetQuestLogIndexByID(questID)
		if (questIndex) and (questIndex > 0) and (questCompleteObjectives[questID]) then -- check for table entry in case we get duplicate ids in the queue
			local questID, questIsComplete, numCompleteObjectives = checkQuestCompletion(questIndex)

			if (opt_showQuestCompleteMessage) and (questIsComplete) then
				local questTitle = GetQuestLogTitle(questIndex)
				UIErrorsFrame:AddMessage(format(opt.questCompleteMessageFormat, questTitle), opt.questCompleteMessageColor.r, opt.questCompleteMessageColor.g, opt.questCompleteMessageColor.b, 1, 5)
			end

			if (questIsComplete) and (opt_playQuestComplete) then
				setSoundLevel(3)
			elseif (numCompleteObjectives > questCompleteObjectives[questID]) and (opt_playObjComplete) then
				setSoundLevel(2)
			elseif (opt_playObjProgress) then
				setSoundLevel(1)
			end

			questCompleteObjectives[questID] = nil
		end
	end
end

--

local function handleEvent (self, event, ...)
	if (event == "QUEST_WATCH_UPDATE") then
		addPendingUpdate(...)

	elseif (event == "QUEST_LOG_UPDATE") then
		soundLevel = 0
		checkPendingUpdates()
		playQuestSound()
	end
end

fEvents:SetScript("OnEvent", function(self, event, name)
	if (name ~= addonName) then return end

	self:UnregisterEvent("ADDON_LOADED")

	self:SetScript("OnEvent", handleEvent)

	self:RegisterEvent("QUEST_LOG_UPDATE")
	self:RegisterEvent("QUEST_WATCH_UPDATE")
end)

fEvents:RegisterEvent("ADDON_LOADED")
