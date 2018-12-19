local addonName, QuestKing = ...

-- options
local opt = QuestKing.options

-- local variables
local pendingQuestID
local activeSuperTrackedQuestID = 0

--

function QuestKing:OnQuestAccepted(questID)
	-- if (GetSuperTrackedQuestID() == 0) then
	-- FIXME: should we allow accepting a quest to set the arrow no matter what?
	-- elseif (QuestHasPOIInfo(questID)) then
	if (QuestHasPOIInfo(questID)) then
		pendingQuestID = nil

		QuestKing:TrackClosestQuest()
		QuestKing:UpdateTracker()
	else
		pendingQuestID = questID
	end
end

function QuestKing:OnPOIUpdate ()
	QuestPOIUpdateIcons()

	if (pendingQuestID) and (QuestHasPOIInfo(pendingQuestID)) then
		-- QuestKing:SetSuperTrackedQuestID(pendingQuestID)
		QuestKing:TrackClosestQuest()
		QuestKing:UpdateTracker()
	end

	pendingQuestID = nil
end

--

local supertrackUpdatePending = false

function QuestKing:PreCheckQuestTracking ()
	local trackedQuestID = GetSuperTrackedQuestID()

	if (trackedQuestID ~= 0) and (GetQuestLogIndexByID(trackedQuestID) == 0) then
		QuestKing:TrackClosestQuest()
	end
end

function QuestKing:OnQuestObjectivesCompleted (questID)
	supertrackUpdatePending = true
end

function QuestKing:PostCheckQuestTracking ()
	local trackedQuestID = GetSuperTrackedQuestID()

	if (supertrackUpdatePending) then
		supertrackUpdatePending = false

		if (GetSuperTrackedQuestID() ~= 0) then
			QuestKing:TrackClosestQuest()
			QuestKing:UpdateTracker()
		end
	end
end

--

function QuestKing:TrackClosestQuest ()
	local minDistSqr = math.huge
	local closestQuestID

	local numQuestWatches = GetNumQuestWatches()
	for i = 1, numQuestWatches do
		local questID, title, questLogIndex, _, _, isComplete, _, _, _, _, _, _, _, _, hasLocalPOI = GetQuestWatchInfo(i)

		if (questID) --[[and (not isComplete)]] and (QuestHasPOIInfo(questID)) then
			local distSqr, onContinent = GetDistanceSqToQuest(questLogIndex)
			if (onContinent) and (distSqr <= minDistSqr) then
				minDistSqr = distSqr
				closestQuestID = questID
			end
		end
	end

	-- If nothing with POI data is being tracked expand search to quest log
	if (not closestQuestID) then
		local numQuestLogEntries = GetNumQuestLogEntries()
		for questLogIndex = 1, numQuestLogEntries do
			local title, _, _, isHeader, _, isComplete, _, questID = GetQuestLogTitle(questLogIndex)

			if (not isHeader) --[[and (not isComplete)]] and (QuestHasPOIInfo(questID)) then
				local distSqr, onContinent = GetDistanceSqToQuest(questLogIndex)
				if (onContinent) and (distSqr <= minDistSqr) then
					minDistSqr = distSqr
					closestQuestID = questID
				end
			end
		end
	end

	-- Supertrack if we have a valid quest
	if (closestQuestID) then
		QuestKing:SetSuperTrackedQuestID(closestQuestID)
	else
		QuestKing:SetSuperTrackedQuestID(0)
	end
end

--

function QuestKing:SetSuperTrackedQuestID (questID)
	activeSuperTrackedQuestID = questID
	SetSuperTrackedQuestID(questID)
end

function QuestKing:OnSuperTrackedQuestChanged (...)
	local newID = ...
	if (newID ~= activeSuperTrackedQuestID) then
		activeSuperTrackedQuestID = questID
		QuestKing:UpdateTracker()
	end
end
