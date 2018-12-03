local addonName, QuestKing = ...

---- Global variables ----

_G.QuestKing = QuestKing

---- Addon-wide variables ----

QuestKing.newlyAddedQuests = {}
QuestKing.watchMoney = false

QuestKing.itemButtonAlpha = 1
QuestKing.itemButtonScale = QuestKing.options.itemButtonScale

QuestKing.updateHooks = {}

-- import

local opt = QuestKing.options
local opt_colors = opt.colors

local select = select
local modf = math.modf
local floor = math.floor
local format = string.format

local tostring = tostring
local GetQuestLogTitle = GetQuestLogTitle
local GetQuestTagInfo = GetQuestTagInfo
local GetQuestLogIsAutoComplete = GetQuestLogIsAutoComplete
local GetQuestLogQuestType = GetQuestLogQuestType
local gsub = string.gsub

--

local match = string.match
local matchType = 0

function QuestKing.MatchObjective (objectiveDesc)
	if (matchType == 1) then
		return match(objectiveDesc, "^(%d+)%s*/%s*(%d+)%s+(.*)$") -- quantCur, quantMax, quantName

	elseif (matchType == 2) then
		local quantName, quantCur, quantMax = match(objectiveDesc, "^(.*):%s+(%d+)%s*/%s*(%d+)")
		-- D("$$$", quantName, quantCur, quantMax, objectiveDesc)
		return quantCur, quantMax, quantName

	else
		local quantCur, quantMax, quantName = match(objectiveDesc, "^(%d+)%s*/%s*(%d+)%s+(.*)$")
		if (quantName) then
			matchType = 1
			return quantCur, quantMax, quantName
		else
			quantName, quantCur, quantMax = match(objectiveDesc, "^(.*):%s+(%d+)%s*/%s*(%d+)")
			if (quantName) then
				matchType = 2
				return quantCur, quantMax, quantName
			end
		end
	end
end

function QuestKing.MatchObjectiveRep (objectiveDesc)
	local quantCur, quantMax, quantName = match(objectiveDesc, "^(%S+)%s*/%s*(%S+)%s+(.*)$")
	if (not quantName) then
		quantName, quantCur, quantMax = match(objectiveDesc, "^(.*):%s+(%S+)%s*/%s*(%S+)")
	end

	return quantCur, quantMax, quantName
end

--

function QuestKing:DisableBlizzard ()
	ObjectiveTrackerBlocksFrame:UnregisterAllEvents()
	ScenarioBlocksFrame:UnregisterAllEvents()

	ObjectiveTrackerFrame:UnregisterAllEvents()
	ObjectiveTrackerFrame:Hide()

	hooksecurefunc(ObjectiveTrackerFrame, "Show", function ()
		ObjectiveTrackerFrame:Hide()
	end)
end

--

local function colorGradient (perc, ...)
	if perc >= 1 then
		local r, g, b = select(select('#', ...) - 2, ...)
		return r, g, b
	elseif perc <= 0 then
		local r, g, b = ...
		return r, g, b
	end

	local num = select('#', ...) / 3

	local segment, relperc = modf(perc*(num-1))
	local r1, g1, b1, r2, g2, b2 = select((segment*3)+1, ...)

	return r1 + (r2-r1)*relperc, g1 + (g2-g1)*relperc, b1 + (b2-b1)*relperc
end

function QuestKing.GetObjectiveColor (progress)
	local r, g, b
	if (progress >= 1) then
		r, g, b = opt_colors.ObjectiveGradientComplete[1], opt_colors.ObjectiveGradientComplete[2], opt_colors.ObjectiveGradientComplete[3]
	else
		r, g, b = colorGradient(progress,
			opt_colors.ObjectiveGradient0[1], opt_colors.ObjectiveGradient0[2], opt_colors.ObjectiveGradient0[3],
			opt_colors.ObjectiveGradient50[1], opt_colors.ObjectiveGradient50[2], opt_colors.ObjectiveGradient50[3],
			opt_colors.ObjectiveGradient99[1], opt_colors.ObjectiveGradient99[2], opt_colors.ObjectiveGradient99[3])
	end
	return r, g, b
end

-- simplified and shortened version of Blizzard equivalent GetTimeStringFromSeconds
function QuestKing.GetTimeStringFromSecondsShort (timeAmount)
	local seconds = timeAmount

	local hours = floor(seconds / 3600)
	local minutes = floor((seconds / 60) - (hours * 60))
	seconds = seconds - hours * 3600 - minutes * 60

	if hours > 0 then
		return format("%d:%.2d:%.2d", hours, minutes, seconds)
	else
		return format("%d:%.2d", minutes, seconds)
	end
end

--

local knownTypesTag = {
	[0] = "",     -- Normal
	[1] = "G",    -- Group
	[21] = "C",	  -- Class
	[41] = "P",   -- PVP
	[62] = "R",   -- Raid
	[81] = "D",   -- Dungeon
	[82] = "V",   -- World Event (?)
	[83] = "L",   -- Legendary
	[84] = "E",   -- Escort (?)
	[85] = "H",   -- Heroic
	[88] = "R10", -- 10 Player (?)
	[89] = "R25", -- 25 Player (?)
	[98] = "S",   -- Scenario
	[102] = "A",  -- Account
	-- Y = Daily
	-- W = Weekly
	-- F = Faction (Alliance/Horde)
	-- e = Starts event
	-- a = Autocomplete
}

function QuestKing.GetQuestTaggedTitle (questIndex, isBonus)
	local questTitle, level, suggestedGroup, _, _, _, frequency, questID, startEvent = GetQuestLogTitle(questIndex)
	local questType = GetQuestLogQuestType(questIndex)
	-- local questTagID, questTag = GetQuestTagInfo(questID)

	local levelString
	local typeTag = knownTypesTag[questType]

	if (typeTag == nil) then
		typeTag = format("|cffff00ff(%d)|r", questType) -- Alert user to unknown tags
	end

	-- Add primary tags

	if (questType == 1) and (suggestedGroup) and (suggestedGroup > 1) then
		-- Group
		levelString = format("%d%s%d", level, typeTag, suggestedGroup)

	elseif (questType == 102) then
		-- Account
		local factionGroup = GetQuestFactionGroup(questID)
		if (factionGroup) then
			levelString = format("%d%s", level, "F")
		else
			levelString = format("%d%s", level, typeTag)
		end		

	elseif (questType > 0) then
		-- Other types
		levelString = format("%d%s", level, typeTag)

	else
		-- Normal
		levelString = tostring(level)
	end

	-- Extra tags

	if (frequency == LE_QUEST_FREQUENCY_DAILY) then
		levelString = format("%sY", levelString)
	elseif (frequency == LE_QUEST_FREQUENCY_WEEKLY) then
		levelString = format("%sW", levelString)
	end

	if (startEvent) then
		levelString = format("%se", levelString)
	end

	if (GetQuestLogIsAutoComplete(questIndex)) and (not isBonus) then
		levelString = format("%sa", levelString)
	end	

	-- Return

	if (isBonus) then
		questTitle = gsub(questTitle, "Bonus Objective: ", "")
		return format("[%s] %s", levelString, questTitle), level
	else
		return format("[%s] %s", levelString, questTitle)
	end
end
