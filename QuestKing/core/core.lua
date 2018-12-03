local addonName, QuestKing = ...

-- options
local opt = QuestKing.options
local opt_colors = opt.colors

-- import
local WatchButton = QuestKing.WatchButton
local Tracker = QuestKing.Tracker

local format = string.format
local tonumber = tonumber
local tContains = tContains

-- local functions
local checkUpdates
local hookAddQuestWatch, hookRemoveQuestWatch, hookAddAutoQuestPopUp

-- local variables
local UpdateCheckFrame = CreateFrame("Frame", "QuestKing_UpdateCheckFrame")

local checkCombat = false
local checkPendingPlayerLevel = false

--

-- Events

function checkUpdates ()
	-- combat
	if (checkCombat) then
		if (not InCombatLockdown()) then
			checkCombat = false
			QuestKing_TrackerModeButton.label:SetTextColor(opt_colors.TrackerTitlebarText[1], opt_colors.TrackerTitlebarText[2], opt_colors.TrackerTitlebarText[3])
			QuestKing:UpdateTracker(false, true)

			-- ugly, but faster. if this does happen on the same frame we can skip the check below since we already updated once.
			if (checkPendingPlayerLevel) and (UnitLevel("player") >= checkPendingPlayerLevel) then
				checkPendingPlayerLevel = false
			end
		end
	end

	-- level up
	if (checkPendingPlayerLevel) and (UnitLevel("player") >= checkPendingPlayerLevel) then
		checkPendingPlayerLevel = false
		QuestKing:UpdateTracker()
	end

	-- stop updating if neither check is active
	if (not checkCombat) and (not checkPendingPlayerLevel) then
		UpdateCheckFrame:SetScript("OnUpdate", nil)
	end
end

function QuestKing:StartCombatTimer ()
	if (checkCombat == false) then
		checkCombat = true
		QuestKing_TrackerModeButton.label:SetTextColor(1, 0, 0)
		UpdateCheckFrame:SetScript("OnUpdate", checkUpdates)
	end
end

function QuestKing:OnPlayerLevelUp (newLevel)
	checkPendingPlayerLevel = tonumber(newLevel)
	UpdateCheckFrame:SetScript("OnUpdate", checkUpdates)
end


-- Hooks

function hookAddQuestWatch (questLogIndex, duration)
	--D("|cffaaffcchookQuestWatch")
	local _, _, _, _, _, _, _, questID = GetQuestLogTitle(questLogIndex)
	QuestKing.newlyAddedQuests[questID] = true
	QuestKing:UpdateTracker(true)
end

function hookRemoveQuestWatch (questLogIndex)
	--D("|cffaaffcchookQuestWatch")
	QuestKing:UpdateTracker(true)
end

function hookAddAutoQuestPopUp ()
	QuestKing:UpdateTracker()
end


-- Tracker Updating

function QuestKing:UpdateTracker (forceBuild, postCombat)
	--D("!QuestKing:UpdateTracker")

	QuestKing:CheckQuestSortTable(forceBuild)
	QuestKing.watchMoney = false

	QuestKing:PreCheckQuestTracking()

	WatchButton:StartOrder()

	-- titlebar
	local trackerCollapsed = QuestKingDBPerChar.trackerCollapsed
	if (trackerCollapsed == 2) then
		QuestKing_TrackerMinimizeButton.label:SetText("x")
	elseif (trackerCollapsed == 1) then
		QuestKing_TrackerMinimizeButton.label:SetText("+")
	else
		QuestKing_TrackerMinimizeButton.label:SetText("-")
	end

	if (QuestKingDBPerChar.trackerCollapsed <= 1) then
		QuestKing:UpdateTrackerPopups()

		-- challenge timers
		QuestKing:UpdateTrackerChallengeTimers()

		-- scenarios
		local inScenario = C_Scenario.IsInScenario()
		if inScenario then
			QuestKing:UpdateTrackerScenarios()
		end

		-- bonus objectives
		QuestKing:UpdateTrackerBonusObjectives()
	end
	
	local displayMode = QuestKingDBPerChar.displayMode

	if (trackerCollapsed == 0) then
		if (displayMode == "combined") or (displayMode == "achievements") then
			QuestKing:UpdateTrackerAchievements()
		end

		if (displayMode == "combined") or (displayMode == "quests") then
			QuestKing:UpdateTrackerQuests()
		end
	end

	local numAch = GetNumTrackedAchievements()
	local numWatches = GetNumQuestWatches()
	local totalLogLines, totalQuestCount = GetNumQuestLogEntries()

	if displayMode == "combined" then
		QuestKing_TrackerModeButton.label:SetText("C")
		if numAch > 0 then
			Tracker.titlebarText:SetText(format("%d/%d | %d", totalQuestCount, MAX_QUESTS, numAch))
		else
			Tracker.titlebarText:SetText(format("%d/%d", totalQuestCount, MAX_QUESTS))
		end
		if (numWatches == 0) and (numAch == 0) then
			Tracker.titlebarText:SetTextColor(opt_colors.TrackerTitlebarTextDimmed[1], opt_colors.TrackerTitlebarTextDimmed[2], opt_colors.TrackerTitlebarTextDimmed[3])
		else
			Tracker.titlebarText:SetTextColor(opt_colors.TrackerTitlebarText[1], opt_colors.TrackerTitlebarText[2], opt_colors.TrackerTitlebarText[3])
		end

	elseif displayMode == "achievements" then
		QuestKing_TrackerModeButton.label:SetText("A")
		Tracker.titlebarText:SetText(numAch)
		if (numAch == 0) then
			Tracker.titlebarText:SetTextColor(opt_colors.TrackerTitlebarTextDimmed[1], opt_colors.TrackerTitlebarTextDimmed[2], opt_colors.TrackerTitlebarTextDimmed[3])
		else
			Tracker.titlebarText:SetTextColor(opt_colors.TrackerTitlebarText[1], opt_colors.TrackerTitlebarText[2], opt_colors.TrackerTitlebarText[3])
		end

	else
		QuestKing_TrackerModeButton.label:SetText("Q")
		Tracker.titlebarText:SetText(format("%d/%d", totalQuestCount, MAX_QUESTS))
		if (numWatches == 0) then
			Tracker.titlebarText:SetTextColor(opt_colors.TrackerTitlebarTextDimmed[1], opt_colors.TrackerTitlebarTextDimmed[2], opt_colors.TrackerTitlebarTextDimmed[3])
		else
			Tracker.titlebarText:SetTextColor(opt_colors.TrackerTitlebarText[1], opt_colors.TrackerTitlebarText[2], opt_colors.TrackerTitlebarText[3])
		end		
	end


	-- LAYOUT
	local requestOrder = WatchButton.requestOrder
	local requestCount = WatchButton.requestCount
	local lastShown = nil
	for i = 1, requestCount do
		-- loop over watch buttons
		local button = requestOrder[i]
		button:ClearAllPoints()
		
		-- layout shown buttons
		if (lastShown == nil) then
			button:SetPoint("TOPLEFT", Tracker.titlebar, "BOTTOMLEFT", 0, -1)
		else
			if (button.type == "header") or (button.type == "collapser") then
				button:SetPoint("TOPLEFT", lastShown, "BOTTOMLEFT", 0, -4)
			elseif (lastShown.type == "header") or (lastShown.type == "collapser") then
				button:SetPoint("TOPLEFT", lastShown, "BOTTOMLEFT", 0, -3)
			else
				button:SetPoint("TOPLEFT", lastShown, "BOTTOMLEFT", 0, -2)
			end
		end
		button:Render()

		lastShown = button
	end

	if (postCombat) then -- we already check for combat in timer func, no need here
		local freePool = WatchButton.freePool
		for i = 1, #freePool do
			local button = freePool[i]
			if (button.itemButton) then
				button:RemoveItemButton()
			end
		end
	end

	WatchButton:FreeUnused()
	
	Tracker:Resize(lastShown)

	QuestKing:PostCheckQuestTracking()

	local hooks = QuestKing.updateHooks
	if (#hooks) then
		for i = 1, #hooks do
			hooks[i]()
		end
	end
end


-- Init

function QuestKing:Init()
	if (not QuestKingDB) then
		QuestKingDB = {}
	end
	if (not QuestKingDBPerChar) then
		QuestKingDBPerChar = {}
	end

	QuestKingDBPerChar.version = QuestKingDBPerChar.version or 2

	QuestKingDBPerChar.collapsedHeaders = QuestKingDBPerChar.collapsedHeaders or {}
	QuestKingDBPerChar.collapsedQuests = QuestKingDBPerChar.collapsedQuests or {}
	QuestKingDBPerChar.collapsedAchievements = QuestKingDBPerChar.collapsedAchievements or {}
	QuestKingDBPerChar.trackerCollapsed = QuestKingDBPerChar.trackerCollapsed or 0
	
	QuestKingDBPerChar.displayMode = QuestKingDBPerChar.displayMode or "combined"
	QuestKingDBPerChar.trackerPositionPreset = QuestKingDBPerChar.trackerPositionPreset or 1

	QuestKingDB.dbTrackerAlpha = QuestKingDB.dbTrackerAlpha or nil
	QuestKingDB.dbTrackerScale = QuestKingDB.dbTrackerScale or nil

	QuestKingDB.dragLocked = QuestKingDB.dragLocked or false
	QuestKingDB.dragOrigin = QuestKingDB.dragOrigin or "TOPRIGHT"
	QuestKingDB.dragX = QuestKingDB.dragX or nil
	QuestKingDB.dragY = QuestKingDB.dragY or nil

	QuestKing:InitLoot()

	if (opt.disableBlizzard) then
		QuestKing:DisableBlizzard()
	end
	
	hooksecurefunc("AddQuestWatch", hookAddQuestWatch)
	hooksecurefunc("RemoveQuestWatch", hookRemoveQuestWatch)
	hooksecurefunc("AddAutoQuestPopUp", hookAddAutoQuestPopUp)

	Tracker:Init()
	QuestKing:UpdateTracker()
end
