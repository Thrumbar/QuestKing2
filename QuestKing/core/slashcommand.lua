local addonName, QuestKing = ...

-- options
local opt = QuestKing.options

-- local functions
local P, slashDispatch, slashParser

--

local Command = {}

Command["help"] = function (...)
	P("Valid commands: lock, origin, alpha, scale, reset, resetall.")
end

Command["reset"] = function (...)
	P("Resetting all collapsed headers/quests/achievements.")
	QuestKingDBPerChar.collapsedHeaders = {}
	QuestKingDBPerChar.collapsedQuests = {}
	QuestKingDBPerChar.collapsedAchievements = {}

	QuestKing:UpdateTracker()
end

Command["resetall"] = function (...)
	local confirm = ...
	if (confirm ~= "yes") then
		P("Are you sure? Doing this will reset all saved setting for this character. Type \"|cffaaffaa/qk resetall yes|r\" to confirm.")
		return
	end

	P("Resetting all saved variables.")
	QuestKingDB = {}
	QuestKingDBPerChar = {}

	ReloadUI()
end

Command["alpha"] = function (val)
	if (not val) then
		P("Please enter an alpha value between 0 and 1 (for example, 0.8) or \"clear\" to use options value.")
		return
	end

	if (val == "clear") then
		QuestKingDB.dbTrackerAlpha = nil
		QuestKing.Tracker:SetCustomAlpha()
	else
		val = tonumber(val)
		if (val < 0) then val = 0 end
		if (val > 1) then val = 1 end

		P("Setting alpha to %.2f.", val)
		QuestKing.Tracker:SetCustomAlpha(val)
	end

	QuestKing:UpdateTracker()
end

Command["scale"] = function (val)
	if (not val) then
		P("Please enter a scale value (for example, 1 for 100%% size, 1.2 for 120%%, etc.) or \"clear\" to use options value.")
		return
	end

	if (val == "clear") then
		QuestKingDB.dbTrackerScale = nil
		QuestKing.Tracker:SetCustomScale()
	else
		val = tonumber(val)
		if (val < 0) then val = 0.01 end

		P("Setting scale to %.2f.", val)
		QuestKing.Tracker:SetCustomScale(val)
	end
	
	QuestKing:UpdateTracker()
end

Command["lock"] = function ()
	local isLocked = QuestKing.Tracker:ToggleDrag()
	if (isLocked) then
		P("Tracker locked.")
	else
		P("Tracker unlocked.")
	end
end

Command["origin"] = function (origin)
	if (not origin) then
		P("No origin specified. Valid origins are: \"|cffaaffaaTOPRIGHT BOTTOMRIGHT BOTTOMLEFT TOPLEFT|r\"")
		P("Current settings are: dragLocked=|cffaaffaa%s|r dragOrigin=|cffaaffaa%s|r dragX=|cffaaffaa%s|r dragY=|cffaaffaa%s|r",
			tostring(QuestKingDB.dragLocked), QuestKingDB.dragOrigin, tostring(QuestKingDB.dragX), tostring(QuestKingDB.dragY))
		return
	end

	origin = string.upper(origin)

	if (origin == "TOPRIGHT") or (origin == "BOTTOMRIGHT") or (origin == "BOTTOMLEFT") or (origin == "TOPLEFT") then
		QuestKingDB.dragLocked = false
		QuestKingDB.dragOrigin = origin
		QuestKingDB.dragX = nil
		QuestKingDB.dragY = nil
		QuestKing.Tracker:InitDrag()
	else
		P("Invalid origin. Valid origins are: |cffaaffaaTOPRIGHT BOTTOMRIGHT BOTTOMLEFT TOPLEFT|r")
	end
end

--

function slashDispatch (first, ...)
	first = string.lower(first)
	if Command[first] then
		Command[first](...)
		return
	end

	P("Invalid command! Type \"|cffaaffaa/qk help|r\" for help.")
end

function slashParser (msg, editbox)
	local list = {}
	for token in string.gmatch(msg, "%S+") do
		tinsert(list, token)
	end

	if (#list == 0) then
		tinsert(list, "help")
	end

	slashDispatch(unpack(list))
end

SLASH_QUESTKING1, SLASH_QUESTKING2 = "/questking", "/qk"
SlashCmdList["QUESTKING"] = slashParser

--

function P (msg, ...)
	msg = string.format(msg, ...)
	DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff99ccffQuestKing|cff6090ff:|r %s", msg))
end
