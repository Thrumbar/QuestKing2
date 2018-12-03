local addonName, QuestKing = ...

-- options
local opt = QuestKing.options
local opt_colors = opt.colors
local opt_itemAnchorSide = opt.itemAnchorSide
local opt_showCompletedObjectives = opt.showCompletedObjectives

-- import
local WatchButton = QuestKing.WatchButton
local getObjectiveColor = QuestKing.GetObjectiveColor
local getQuestTaggedTitle = QuestKing.GetQuestTaggedTitle
local matchObjective = QuestKing.MatchObjective
local matchObjectiveRep = QuestKing.MatchObjectiveRep

local pairs = pairs
local format = string.format
local GetQuestLogTitle = GetQuestLogTitle
local GetNumQuestLogEntries = GetNumQuestLogEntries
local GetSuperTrackedQuestID = GetSuperTrackedQuestID
local GetNumQuestLeaderBoards = GetNumQuestLeaderBoards
local GetQuestLogLeaderBoard = GetQuestLogLeaderBoard
local GetQuestLogRequiredMoney = GetQuestLogRequiredMoney
local GetQuestWatchInfo = GetQuestWatchInfo
local GetQuestWatchIndex = GetQuestWatchIndex
local GetQuestLogIsAutoComplete = GetQuestLogIsAutoComplete
local GetQuestDifficultyColor = GetQuestDifficultyColor
local GetQuestLogSpecialItemInfo = GetQuestLogSpecialItemInfo

-- local functions
local buildQuestSortTable
local setButtonToQuest

-- local variables
local headerList = {}
local questSortTable = {}

local prev_GetNumQuestLogEntries = 0
local prev_GetNumQuestWatches = 0

local mouseHandlerQuest = {}

--

function buildQuestSortTable ()
	for k,v in pairs(questSortTable) do
		wipe(questSortTable[k])
	end
	wipe(headerList)

	local numEntries = GetNumQuestLogEntries()
	local currentHeader = "(Unknown 0)"

	local numQuests = 0
	for i = 1, numEntries do
		local title, _, _, isHeader, isCollapsed, _, _, questID = GetQuestLogTitle(i)
		if (not title) or (title == "") then
			title = format("(Unknown %d)", i)
		end

		if (isHeader) then

			if not questSortTable[title] then
				questSortTable[title] = {}
			end

			if (title ~= currentHeader) then
				-- new header found
				-- note: quest "Safe Passage" in Frostfire Ridge is under a duplicate zone header
				currentHeader = title
				tinsert(headerList, title)
			end

		elseif (not isHeader) and (IsQuestWatched(i)) then
			if (not questSortTable[currentHeader]) then
				questSortTable[currentHeader] = {}
			end

			tinsert(questSortTable[currentHeader], i)
		end

		if (not isHeader) then
			numQuests = numQuests + 1
		end
	end

	-- totalQuestCount = numQuests
end

function QuestKing:CheckQuestSortTable (forceBuild)
	if (forceBuild) then
		buildQuestSortTable()
		prev_GetNumQuestLogEntries = GetNumQuestLogEntries()
		prev_GetNumQuestWatches = GetNumQuestWatches()
	else
		local numEntries = GetNumQuestLogEntries()
		local numWatches = GetNumQuestWatches()

		if (numEntries ~= prev_GetNumQuestLogEntries) or (numWatches ~= prev_GetNumQuestWatches) then
			buildQuestSortTable()
			prev_GetNumQuestLogEntries = numEntries
			prev_GetNumQuestWatches = numWatches
		end
	end
end

--

function QuestKing:UpdateTrackerQuests()
	local headerName, questIndex
	for i = 1, #headerList do
		headerName = headerList[i]
		-- header
		if #questSortTable[headerName] > 0 then
			local button = WatchButton:GetKeyed("collapser", headerName)
			button._headerName = headerName

			--|TTexturePath:size1:size2:xoffset:yoffset:dimx:dimy:coordx1:coordx2:coordy1:coordy2:red:green:blue|t
			if QuestKingDBPerChar.collapsedHeaders[headerName] then
				button.title:SetTextIcon("|TInterface\\AddOns\\QuestKing\\textures\\UI-SortArrow_sm_right:8:8:0:-1:0:0:0:0:0:0:1:1:1|t "..headerName)
				button.title:SetTextColor(opt_colors.QuestHeaderCollapsed[1], opt_colors.QuestHeaderCollapsed[2], opt_colors.QuestHeaderCollapsed[3])
			else
				button.title:SetTextIcon("|TInterface\\AddOns\\QuestKing\\textures\\UI-SortArrow_sm_down:8:8:0:-1:0:0:0:0:0:0:1:1:1|t "..headerName)
				button.title:SetTextColor(opt_colors.QuestHeader[1], opt_colors.QuestHeader[2], opt_colors.QuestHeader[3])
			end
		end

		-- quests

		if not QuestKingDBPerChar.collapsedHeaders[headerName] then
			for j = 1, #questSortTable[headerName] do
				questIndex = questSortTable[headerName][j]
				local _,_,_,_,_,_,_, questID = GetQuestLogTitle(questIndex)
				local button = WatchButton:GetKeyed("quest", questID)
				setButtonToQuest(button, questIndex)
			end
		end
	end

end

function setButtonToQuest (button, questIndex)
	button.mouseHandler = mouseHandlerQuest

	local questTitle, level, suggestedGroup, isHeader, isCollapsed, isComplete, frequency, questID, startEvent, displayQuestID, isOnMap, hasLocalPOI, isTask, isStory = GetQuestLogTitle(questIndex)

	button.questIndex = questIndex
	button.questID = questID

	local collapseObjectives = QuestKingDBPerChar.collapsedQuests[questID]

	-- set title
	local taggedTitle = getQuestTaggedTitle(questIndex)

	if (GetSuperTrackedQuestID() == questID) then
		taggedTitle = taggedTitle .. " |TInterface\\Scenarios\\ScenarioIcon-Combat:10:10:-1:0|t"
	end

	if (isComplete == -1) then
		button.title:SetFormattedTextIcon("|TInterface\\RAIDFRAME\\ReadyCheck-NotReady:0:0:1:0|t %s", taggedTitle)
	else
		button.title:SetTextIcon(taggedTitle)
	end

	-- add objectives
	local numObj = GetNumQuestLeaderBoards(questIndex) or 0
	local completedObj = 0
	local displayedObj = 0

	for i = 1, numObj do
		local objectiveDesc, objectiveType, objectiveIsDone = GetQuestLogLeaderBoard(i, questIndex)

		if (objectiveIsDone) then
			completedObj = completedObj + 1
		end

		local displayObjective = true
		if (collapseObjectives) then
			-- hide for collapsed quest
			displayObjective = false
		elseif (isComplete == 1) and (opt_showCompletedObjectives ~= "always") then
			-- hide for complete quest (unless show type is "always")
			displayObjective = false
		elseif (objectiveIsDone) and (opt_showCompletedObjectives == false) then
			-- hide for completed objectives if showCompletedObjectives is false
			displayObjective = false
		elseif (objectiveDesc == nil) then
			-- hide invalid objectives
			displayObjective = false
		end

		-- types:
		-- event, reputation, item, log(Direbrew's Dire Brew), monster, object?, spell(Frost Nova)
		if (displayObjective) then
			local quantCur, quantMax, quantName = matchObjective(objectiveDesc)

			if (objectiveType == "reputation") then
				quantCur, quantMax, quantName = matchObjectiveRep(objectiveDesc)

				local r, g, b = getObjectiveColor(objectiveIsDone and 1 or 0)
				local line
				if (not quantName) then
					line = button:AddLine(format("  %s", objectiveDesc), nil, r, g, b)
				else
					line = button:AddLine(format("  %s", quantName), format(": %s / %s", quantCur, quantMax), r, g, b)
				end

				objectiveIsDone = not not objectiveIsDone
				if ((line._lastQuant == false) and (objectiveIsDone == true)) then
					line:Flash()
				end
				line._lastQuant = objectiveIsDone

				displayedObj = displayedObj + 1

			elseif (not quantName) or (objectiveType == "spell") then
				if ((displayObjective) or (not objectiveIsDone)) then
					local r, g, b = getObjectiveColor(objectiveIsDone and 1 or 0)
					local line = button:AddLine(format("  %s", objectiveDesc), nil, r, g, b)

					---- FIXME: test this!
					objectiveIsDone = not not objectiveIsDone
					if ((line._lastQuant == false) and (objectiveIsDone == true)) then
						line:Flash()
					end
					line._lastQuant = objectiveIsDone

					displayedObj = displayedObj + 1
				end

			else
				if ((displayObjective) or (not objectiveIsDone)) then
					local r, g, b = getObjectiveColor(quantCur / quantMax)
					local line = button:AddLine(format("  %s", quantName), format(": %s/%s", quantCur, quantMax), r, g, b)

					local lastQuant = line._lastQuant
					if ((lastQuant) and (quantCur > lastQuant)) then
						line:Flash()
					end
					line._lastQuant = quantCur

					displayedObj = displayedObj + 1
				end
			end
		end

	end

	-- money
	local requiredMoney = GetQuestLogRequiredMoney(questIndex)
	if (requiredMoney > 0) then
		QuestKing.watchMoney = true
		local playerMoney = GetMoney()

		-- not sure about this, but the default watch frame does it
		-- (fake completion for gold-requiring connectors when gold req is met and no event begins)
		if (numObj == 0 and playerMoney >= requiredMoney and not startEvent) then
			isComplete = 1
		end

		numObj = numObj + 1 -- (questking only) ensure all gold-requiring quests aren't marked as connectors

		if (not collapseObjectives) then -- hide entirely if objectives are collapsed
			if playerMoney >= requiredMoney then
				-- show met gold amounts only for incomplete quests
				if (isComplete ~= 1) and (opt_showCompletedObjectives) then
					local r, g, b = getObjectiveColor(1)
					button:AddLine("  Requires: "..GetMoneyString(requiredMoney), nil, r, g, b)
				end
			else
				-- always show unmet gold amount
				local r, g, b = getObjectiveColor(0)
				button:AddLine("  Requires: "..GetMoneyString(requiredMoney), nil, r, g, b)
			end
		end
	end

	local _, _, _, _, _, _, _, _, failureTime, timeElapsed = GetQuestWatchInfo(GetQuestWatchIndex(questIndex))

	-- timer
	if (failureTime) then
		if (timeElapsed) then
			local timerBar = button:AddTimerBar(failureTime, GetTime() - timeElapsed)
			timerBar:SetStatusBarColor(opt_colors.QuestTimer[1], opt_colors.QuestTimer[2], opt_colors.QuestTimer[3])
		end
	end

	-- set title colour
	if (isComplete == -1) then
		-- failed
		button.title:SetTextColor(opt_colors.ObjectiveFailed[1], opt_colors.ObjectiveFailed[2], opt_colors.ObjectiveFailed[3])
	elseif (isComplete == 1) then
		if GetQuestLogIsAutoComplete(questIndex) then
			-- autocomplete
			button.title:SetTextColor(opt_colors.QuestCompleteAuto[1], opt_colors.QuestCompleteAuto[2], opt_colors.QuestCompleteAuto[3])
		elseif (numObj == 0) then
			-- connector quest [type c] (complete, 0/0 objectives)
			button.title:SetTextColor(opt_colors.QuestConnector[1], opt_colors.QuestConnector[2], opt_colors.QuestConnector[3])
		else
			-- completed quest (complete, n/n objectives)
			button.title:SetTextColor(opt_colors.ObjectiveComplete[1], opt_colors.ObjectiveComplete[2], opt_colors.ObjectiveComplete[3])
		end
	else
		if numObj == 0 then
			-- connector quest [type i] (incomplete, 0/0 objectives)
			button.title:SetTextColor(opt_colors.QuestConnector[1], opt_colors.QuestConnector[2], opt_colors.QuestConnector[3])
		elseif numObj == completedObj then
			-- unknown state (incomplete, n/n objectives where n>0)
			button.title:SetTextColor(1, 0, 1)
		else
			-- incomplete quest (incomplete, n/m objectives where m>n)
			local color = GetQuestDifficultyColor(level)
			button.title:SetTextColor(color.r, color.g, color.b)
		end
	end

	if collapseObjectives then
		button.title:SetAlpha(0.6)
	end

	-- add item button
	local link, item, charges, showItemWhenComplete = GetQuestLogSpecialItemInfo(questIndex)
	local itemButton
	if opt_itemAnchorSide and item and ((isComplete ~= 1) or (showItemWhenComplete)) then
		if InCombatLockdown() then
			QuestKing:StartCombatTimer()
		else
			itemButton = button:SetItemButton(questIndex, link, item, charges, displayedObj)
		end

	else
		if (button.itemButton) then
			if InCombatLockdown() then
				QuestKing:StartCombatTimer()
			else
				button:RemoveItemButton()
			end
		end
	end

	if (button.fresh) then
		if (QuestKing.newlyAddedQuests[questID]) then
			button:Pulse(0.9, 0.6, 0.2)
			QuestKing.newlyAddedQuests[questID] = nil
		end
	end

	-- quests enter a state of unknown completion (isComplete == nil) when zoning between instances.
	-- since they also has no objectives in this state, we completely ignore completion changes for quests with no objectives
	if (numObj > 0) then
		if (isComplete == 1) and (button._questCompleted == false) then
			button:Pulse(0.2, 0.6, 0.9)
			QuestKing:OnQuestObjectivesCompleted(questID)
		end
		button._questCompleted = not not (isComplete == 1)
	end

	-- animate sequenced quests
	if ((not button.fresh) and IsQuestSequenced(questID)) then
		local lastNumObj = button._lastNumObj

		if ((lastNumObj) and (lastNumObj > 0) and (numObj > lastNumObj)) then
			-- do animations [FIXME: test this]
			PlaySound(SOUNDKIT.IG_QUEST_LIST_OPEN)
			local lines = button.lines
			for i = 1, #lines do
				if (i > lastNumObj) then
					local line = lines[i]
					line:Glow(opt_colors.ObjectiveChangedGlow[1], opt_colors.ObjectiveChangedGlow[2], opt_colors.ObjectiveChangedGlow[3])
				end
			end
		end
		button._lastNumObj = numObj
	end

end


---- Mouse handlers

function mouseHandlerQuest:TitleButtonOnEnter (motion)
	local button = self.parent

	local link = GetQuestLink(button.questIndex)
	if link then
		GameTooltip:SetOwner(self, opt.tooltipAnchor)

		if opt.tooltipScale then
			if not GameTooltip.__QuestKingPreviousScale then
				GameTooltip.__QuestKingPreviousScale = GameTooltip:GetScale()
			end
			GameTooltip:SetScale(opt.tooltipScale)
		end

		GameTooltip:SetHyperlink(link)
		GameTooltip:Show()
	end
end

function mouseHandlerQuest:TitleButtonOnClick (mouse, down)
	local button = self.parent

	if (IsModifiedClick("CHATLINK") and ChatEdit_GetActiveWindow()) then
		local questLink = GetQuestLink(button.questIndex)
		if (questLink) then
			ChatEdit_InsertLink(questLink)
			return
		end
	end

	if (IsShiftKeyDown()) and (ClassicQuestLog) then
		SelectQuestLogEntry(button.questIndex)
		if ClassicQuestLog:IsVisible() then
			ClassicQuestLog:OnShow()
		else
			ClassicQuestLog:SetShown(true)
		end
		return
	end

	if IsAltKeyDown() then
		if mouse == "RightButton" then
			RemoveQuestWatch(button.questIndex)
			QuestKing:UpdateTracker()
			return
		else
			if QuestKingDBPerChar.collapsedQuests[button.questID] then
				QuestKingDBPerChar.collapsedQuests[button.questID] = nil
			else
				QuestKingDBPerChar.collapsedQuests[button.questID] = true
			end
			QuestKing:UpdateTracker()
			return
		end
	end

	if mouse == "RightButton" then
		-- WORLDMAP_SETTINGS.selectedQuestId = button.questID
		if (GetSuperTrackedQuestID() == button.questID) then
			QuestKing:SetSuperTrackedQuestID(0)
			QuestKing:UpdateTracker()
		else
			QuestKing:SetSuperTrackedQuestID(button.questID)
			QuestKing:UpdateTracker()
		end
		-- QuestPOIUpdateIcons()
		-- if WorldMapFrame:IsShown() then
		-- 	HideUIPanel(WorldMapFrame)
		-- 	ShowUIPanel(WorldMapFrame)
		-- end
	else
		-- if (QuestLogFrame:IsShown()) and (QuestLogFrame.selectedIndex == button.questIndex) then
		-- 	HideUIPanel(QuestLogFrame)
		-- else
		-- 	QuestLog_OpenToQuest(button.questIndex)
		-- 	ShowUIPanel(QuestLogFrame)
		-- end
		QuestObjectiveTracker_OpenQuestMap(nil, button.questIndex)
	end

end