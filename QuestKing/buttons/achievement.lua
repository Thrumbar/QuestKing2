local addonName, QuestKing = ...

-- options
local opt = QuestKing.options
local opt_colors = opt.colors

-- import
local WatchButton = QuestKing.WatchButton

local GetTrackedAchievements = GetTrackedAchievements
local GetAchievementInfo = GetAchievementInfo
local GetAchievementNumCriteria = GetAchievementNumCriteria
local GetAchievementCriteriaInfo = GetAchievementCriteriaInfo

-- local functions
local setButtonToAchievement

-- local variables
local achievementTimers = {}
local achievementTimersMeta = {}

local mouseHandlerAchievement = {}

--

function QuestKing:OnTrackedAchievementUpdate (achievementID, criteriaID, timeElapsed, timeLimit)
	if timeElapsed and timeLimit then
		if timeElapsed >= timeLimit then
			achievementTimers[criteriaID] = nil
			achievementTimersMeta[achievementID] = nil
		else
			achievementTimers[criteriaID] = achievementTimers[criteriaID] or {}
			achievementTimers[criteriaID].startTime = GetTime() - timeElapsed
			achievementTimers[criteriaID].duration = timeLimit
			achievementTimersMeta[achievementID] = achievementTimers[criteriaID]
		end
	end
	QuestKing:UpdateTracker()
end

function QuestKing:UpdateTrackerAchievements()
	local trackedAchievements = { GetTrackedAchievements() }
	local numTrackedAchievements = #trackedAchievements

	-- header
	local showAchievements = true
	if (QuestKingDBPerChar.displayMode == "combined") then
		local headerName = "Achievements"
		if numTrackedAchievements > 0 then
			local button = WatchButton:GetKeyed("collapser", "Achievements")
			button._headerName = headerName

			if QuestKingDBPerChar.collapsedHeaders[headerName] then
				button.title:SetTextIcon("|TInterface\\AddOns\\QuestKing\\textures\\UI-SortArrow_sm_right:8:8:0:-1:0:0:0:0:0:0:1:1:1|t "..headerName)
				button.title:SetTextColor(opt_colors.AchievementHeaderCollapsed[1], opt_colors.AchievementHeaderCollapsed[2], opt_colors.AchievementHeaderCollapsed[3])
			else
				button.title:SetTextIcon("|TInterface\\AddOns\\QuestKing\\textures\\UI-SortArrow_sm_down:8:8:0:-1:0:0:0:0:0:0:1:1:1|t "..headerName)
				button.title:SetTextColor(opt_colors.AchievementHeader[1], opt_colors.AchievementHeader[2], opt_colors.AchievementHeader[3])
			end
		end

		if QuestKingDBPerChar.collapsedHeaders[headerName] then
			showAchievements = false
		end
	elseif (inScenario) and (QuestKingDBPerChar.displayMode == "achievements") then
		local achheader = WatchButton:GetKeyed("header", "Achievements")
		achheader.title:SetText("Achievements")
		achheader.title:SetTextColor(opt_colors.AchievementHeader[1], opt_colors.AchievementHeader[2], opt_colors.AchievementHeader[3])
	end

	-- achievements
	if showAchievements then
		for i = 1, numTrackedAchievements do
			local achievementID = trackedAchievements[i]

			local button = WatchButton:GetKeyed("achievement", achievementID)
			setButtonToAchievement(button, achievementID)
		end
	end
end

function setButtonToAchievement (button, achievementID)
	button.mouseHandler = mouseHandlerAchievement

	local id, achievementName, points, achievemntCompleted, _, _, _, achievementDesc, flags, image, rewardText, isGuildAch = GetAchievementInfo(achievementID)
	button.achievementID = achievementID

	local collapseCriteria = QuestKingDBPerChar.collapsedAchievements[achievementID]

	-- set title
	button.title:SetText(achievementName)
	if completed then
		button.title:SetTextColor(opt_colors.AchievementTitleComplete[1], opt_colors.AchievementTitleComplete[2], opt_colors.AchievementTitleComplete[3])
	else
		if isGuildAch then
			button.title:SetTextColor(opt_colors.AchievementTitleGuild[1], opt_colors.AchievementTitleGuild[2], opt_colors.AchievementTitleGuild[3])
		else
			button.title:SetTextColor(opt_colors.AchievementTitle[1], opt_colors.AchievementTitle[2], opt_colors.AchievementTitle[3])
		end
	end

	if collapseCriteria then
		button.title:SetAlpha(0.6)
	end

	-- criteria setup
	local numCriteria = GetAchievementNumCriteria(achievementID)
	local foundTimer = false
	local timeNow -- avoid multiple calls to GetTime()

	-- no criteria
	if (numCriteria == 0) then
		if (not collapseCriteria) then
			button:AddLine("  "..achievementDesc, nil, opt_colors.AchievementDescription[1], opt_colors.AchievementDescription[2], opt_colors.AchievementDescription[3]) -- no criteria exist, show desc line
		end
	end

	-- criteria loop
	for i = 1, numCriteria do
		local _
		local criteriaString, criteriaType, criteriaCompleted, quantity, totalQuantity, name, flags, assetID, quantityString, criteriaID, eligible, duration, elapsed = GetAchievementCriteriaInfo(achievementID, i)

		-- set string
		if (bit.band(flags, EVALUATION_TREE_FLAG_PROGRESS_BAR) == EVALUATION_TREE_FLAG_PROGRESS_BAR) then
			criteriaString = quantityString
		else
			if (criteriaType == CRITERIA_TYPE_ACHIEVEMENT and assetID) then -- meta achievement
				_, criteriaString = GetAchievementInfo(assetID)
			end
		end

		-- display criteria depending on timer state
		-- kinda wanna seperate this out, but display is dependent on timer logic (e.g. timeLeft > 0 forces display)

		--[[]
		local timerTable = achievementTimers[criteriaID]
		if (timerTable) then
			duration = timerTable.duration
			elapsed = GetTime() - timerTable.startTime
		end
		if ((timerTable) and (duration) and (elapsed) and (elapsed < duration)) then
		--]]
		if ((duration) and (elapsed) and (elapsed < duration)) then
			foundTimer = true

			-- timer is running, force showing criteria
			if criteriaCompleted then
				button:AddLine("  "..criteriaString, nil, opt_colors.AchievementCriteriaComplete[1], opt_colors.AchievementCriteriaComplete[2], opt_colors.AchievementCriteriaComplete[3]) -- timer running, force showing completed objective
			else
				button:AddLine("  "..criteriaString, nil, opt_colors.AchievementCriteria[1], opt_colors.AchievementCriteria[2], opt_colors.AchievementCriteria[3]) -- timer running, force showing normal objective
			end

			-- adding timer line
			local timerBar = button:AddTimerBar(duration, GetTime() - elapsed)
			timerBar:SetStatusBarColor(opt_colors.AchievementTimer[1], opt_colors.AchievementTimer[2], opt_colors.AchievementTimer[3])

		else
			-- no timer exists / timer expired

			local timerTable = achievementTimers[criteriaID]
			if (timerTable) then
				achievementTimers[criteriaID] = nil
				achievementTimersMeta[achievementID] = nil
			end

			if (not criteriaCompleted) and (not collapseCriteria) then
				button:AddLine("  "..criteriaString, nil, opt_colors.AchievementCriteria[1], opt_colors.AchievementCriteria[2], opt_colors.AchievementCriteria[3]) -- no timer, show normally unless completed/collapsed
			end
		end

	end

	-- show "meta" timer if there is a timer on this achievement, but no associated criteria are found in GetAchievementNumCriteria (Salt and Pepper?)
	-- multiple timers would be a problem (it sets/unsets with whichever criteria timer fires last), but it's better than nothing
	if ((foundTimer == false) and (achievementTimersMeta[achievementID])) then
		local timerTable = achievementTimersMeta[achievementID]
		local duration = timerTable.duration
		local elapsed = GetTime() - timerTable.startTime

		if ((duration) and (elapsed) and (elapsed < duration)) then
			foundTimer = true

			local timerBar = button:AddTimerBar(timerTable.duration, timerTable.startTime)
			timerBar:SetStatusBarColor(opt_colors.AchievementTimerMeta[1], opt_colors.AchievementTimerMeta[2], opt_colors.AchievementTimerMeta[3])
		end
	end

	-- D(achievementName, foundTimer)

	if (foundTimer == false) then
		button:SetBackdropColor(0, 0, 0, 0)
		button:SetScript("OnUpdate", nil)
	else
		button.title:SetTextColor(opt_colors.AchievementTimedTitle[1], opt_colors.AchievementTimedTitle[2], opt_colors.AchievementTimedTitle[3])
		button:SetBackdropColor(opt_colors.AchievementTimedBackground[1], opt_colors.AchievementTimedBackground[2], opt_colors.AchievementTimedBackground[3], opt_colors.AchievementTimedBackground[4])
	end

end

function mouseHandlerAchievement:TitleButtonOnEnter (motion)
	local button = self.parent

	local link = GetAchievementLink(button.achievementID)
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

function mouseHandlerAchievement:TitleButtonOnClick (mouse, down)
	local button = self.parent

	if (IsModifiedClick("CHATLINK") and ChatEdit_GetActiveWindow()) then
		local achievementLink = GetAchievementLink(button.achievementID)
		if (achievementLink) then
			ChatEdit_InsertLink(achievementLink)
			return
		end
	end

	if IsAltKeyDown() then
		if mouse == "RightButton" then
			RemoveTrackedAchievement(button.achievementID)
			QuestKing:UpdateTracker()
			return
		else
			if QuestKingDBPerChar.collapsedAchievements[button.achievementID] then
				QuestKingDBPerChar.collapsedAchievements[button.achievementID] = nil
			else
				QuestKingDBPerChar.collapsedAchievements[button.achievementID] = true
			end
			QuestKing:UpdateTracker()
			return
		end
	end

	if (not AchievementFrame) then AchievementFrame_LoadUI() end

	if (not AchievementFrame:IsShown()) then
		AchievementFrame_ToggleAchievementFrame()
		AchievementFrame_SelectAchievement(button.achievementID)
	else
		if (AchievementFrameAchievements.selection ~= button.achievementID) then
			AchievementFrame_SelectAchievement(button.achievementID)
		else
			AchievementFrame_ToggleAchievementFrame()
		end
	end
end