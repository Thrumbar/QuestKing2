local addonName, QuestKing = ...

--

local EventsFrame = CreateFrame("Frame", "QuestKing_EventsFrame")
local Events = {}

local function handleEvent (self, event, ...)
	-- D("|cffaaccff" .. event, ...)

	local handler = Events[event]
	if (handler) then
		handler(self, event, ...)
	end
end

local function addonLoaded (self, event, name)
	if (name ~= addonName) then return end

	self:UnregisterEvent("ADDON_LOADED")

	for key, value in pairs(Events) do
		self:RegisterEvent(key)
	end

	self:SetScript("OnEvent", handleEvent)

	QuestKing:Init()
end

EventsFrame:SetScript("OnEvent", addonLoaded)
EventsFrame:RegisterEvent("ADDON_LOADED")

QuestKing.EventsFrame = EventsFrame
QuestKing.Events = Events
QuestKing.HandleEvent = handleEvent

----
---- Event handlers
----

local function UpdateTracker (self, event, ...)
	QuestKing:UpdateTracker()
end

-- looting quest starting items
Events.CHAT_MSG_LOOT = function (self, event, ...)
	QuestKing:ParseLoot(...)
end

-- money
Events.PLAYER_MONEY = function (self, event, ...)
	if (QuestKing.watchMoney) then
		QuestKing:UpdateTracker()
	end
end

-- quest/achievement updates
Events.QUEST_LOG_UPDATE = UpdateTracker
-- Events.ITEM_PUSH = UpdateTracker
Events.TRACKED_ACHIEVEMENT_LIST_CHANGED = UpdateTracker

-- achievements
-- can i ignore this/UpdateTracker entirely if achieveID isnt in trackedAchievementCache? (tContains)
-- if i do, tracking a quest with a timer that's already started may not show it (for a while...?)
Events.TRACKED_ACHIEVEMENT_UPDATE = function (self, event, ...)
	QuestKing:OnTrackedAchievementUpdate(...)
end

-- new quest/task
Events.QUEST_ACCEPTED = function (self, event, ...)
	local questLogIndex, questID = ...;
	if (IsQuestTask(questID)) then
		PlaySound("UI_Scenario_Stage_End");
	else
		if ((AUTO_QUEST_WATCH == "1") and (GetNumQuestWatches() < MAX_WATCHABLE_QUESTS)) then
			AddQuestWatch(questLogIndex)
			QuestKing:OnQuestAccepted(questID)
		end
	end
end

-- quest autocomplete
Events.QUEST_AUTOCOMPLETE = function (self, event, ...)
	local questId = ...
	if (AddAutoQuestPopUp(questId, "COMPLETE")) then
		PlaySound("UI_AutoQuestComplete")
	end
	QuestKing:UpdateTracker()
end

-- quest complete (for task)
Events.QUEST_TURNED_IN = function (self, event, ...)
	local questID = ...
	if (IsQuestTask(questID)) then
		QuestKing:OnTaskTurnedIn(...)
	end		
end

-- scenario
Events.SCENARIO_UPDATE = function (self, event, ...)
	QuestKing:OnScenarioUpdate(...)
end

-- scenario progress
Events.SCENARIO_CRITERIA_UPDATE = UpdateTracker

-- scenario critera complete (for bonus criteria)
Events.CRITERIA_COMPLETE = function (self, event, ...)
	QuestKing:OnCriteriaComplete(...)
end

-- scenario complete
Events.SCENARIO_COMPLETED = function (self, event, ...)
	QuestKing:OnScenarioCompleted(...)		
end

-- proving grounds
Events.PROVING_GROUNDS_SCORE_UPDATE = function (self, event, ...)
	local score = ...
	QuestKing.ProvingGroundsScoreUpdate(score)
end

-- world timers, POI...
Events.PLAYER_ENTERING_WORLD = function (self, event, ...)
	QuestKing:OnPlayerEnteringWorld()
	QuestKing:UpdateTracker()
end

-- more world timers
Events.WORLD_STATE_TIMER_START = UpdateTracker
Events.WORLD_STATE_TIMER_STOP = UpdateTracker

-- supertracked poi changed
Events.SUPER_TRACKED_QUEST_CHANGED = function (self, event, ...)
	QuestKing:OnSuperTrackedQuestChanged(...)
end

-- supertracked poi changed
Events.QUEST_POI_UPDATE = function (self, event, ...)
	-- new poi info received
	QuestKing:OnPOIUpdate()
end

-- level up
Events.PLAYER_LEVEL_UP = function (self, event, ...)
	QuestKing:OnPlayerLevelUp(...)
end
