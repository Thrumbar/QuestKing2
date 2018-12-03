local addonName, QuestKing = ...

local opt = {}
QuestKing.options = opt

--------------------------------------------------------------------
--------------------------------------------------------------------
---- This file lists all the default options for QuestKing.
---- 
---- Instead of editing the options here directly, please consider
---- adding overrides for the default settings instead. You can do
---- this in options_override.lua
--------------------------------------------------------------------
--------------------------------------------------------------------

---- Default options

opt.disableBlizzard = true   -- disable Blizzard's default objective tracker

---- Font

opt.font = [[Interface\AddOns\QuestKing\fonts\SourceSansPro-Semibold.ttf]]
opt.fontChallengeTimer = [[Interface\AddOns\QuestKing\fonts\SourceSansPro-Bold.ttf]]

opt.fontSize = 11
opt.fontStyle = ""            -- can do OUTLINE etc here
opt.fontLayer = "BACKGROUND"

---- Size

opt.buttonWidth = 200  -- width of the entire tracker
opt.lineHeight = 12    -- height of individual text lines
opt.titleHeight = 13   -- height of the title line

opt.trackerScale = 1              -- scale for the whole tracker
opt.dbAllowTrackerScale = true    -- allow scale value to be read from the db instead of the options file

---- Appearance

opt.trackerAlpha = 0.9           -- default alpha value (transparency) of the tracker
opt.dbAllowTrackerAlpha = true   -- allow alpha value to be read from the db instead of the options file

opt.enableItemPopups = true           -- show a special popup when looting an item that starts a quest
opt.showCompletedObjectives = true    -- false = hide complete objectives, true = show complete objectives, "always" = show completed objectives even for complete quests
opt.hideSupersedingObjectives = true  -- hide superseding objectives, such as garrison invasion scores that had a lower prerequisite score

opt.itemButtonScale = 0.9        -- size of item buttons relative to 2x line size
opt.itemAnchorSide = "left"      -- "left" or "right" to choose side for item buttons, nil (no quotes) to disable item buttons
opt.rewardAnchorSide = "left"    -- "left" or "right" to choose side for reward animations

opt.tooltipAnchor = "ANCHOR_LEFT"  -- which anchor type to use when anchoring tooltips to buttons
opt.tooltipScale = 0.9             -- asbolute tooltip scale for quest tooltip, set to nil to disable all tooltip scaling changes

opt.hideToggleButtonBorder = false    -- hide the border around the Q/A/C/+/- buttons

---- Position

opt.allowDrag = true   -- set true to enable a lockable/draggable tracker. if false, the follow preset table is used instead.

-- list of positions that the tracker can be in. first is the default, other ones are cycled through by right-clicking the minimize button
opt.positionPresets = {
	{ "TOPRIGHT", "UIParent", "TOPRIGHT", -2, -154 },
	{ "TOPRIGHT", "UIParent", "TOPRIGHT", -159, -16 },
}

---- Background/Backdrop

opt.enableAdvancedBackground = true    -- enable an advanced tracker background with border support
opt.advancedBackgroundTable = {
	bgFile = [[Interface\ChatFrame\ChatFrameBackground]],
	edgeFile = [[Interface\Tooltips\UI-Tooltip-Border]],
	edgeSize = 12,
	insets = { left = 3, right = 3, top = 3, bottom = 3 },
	_backdropColor = { 0, 0, 0, 1 }, -- red, green, blue, alpha
	_borderColor = { 0.5, 0.5, 0.5, 1 }, -- red, green, blue, alpha
	_alpha = 0,
	_alphaStep = 0.25,
	_anchorPoints = { topLeftX = -5, topLeftY = 5, bottomRightX = 5, bottomRightY = -5 },
	_hideWhenEmpty = true,
}

opt.enableBackdrop = false    -- enable an simple tracker backdrop with no border support
opt.backdropTable = {
	bgFile = [[Interface\ChatFrame\ChatFrameBackground]],
	insets = { left = -2, right = -2, top = opt.titleHeight + 1, bottom = -2 },
	_backdropColor = { 0, 0, 0, 0 }, -- red, green, blue, alpha
	_alphaStep = 0.25, -- using mousewheel on the minimize button increments/decrements alpha by this value (not saved between reloads)
}

---- Colours

opt.colors = {
	-- titlebar
	["TrackerTitlebarText"] = { 1, 0.82, 0 },
	["TrackerTitlebarTextDimmed"] = { 0.6, 0.6, 0.6 },
	
	-- popups
	["PopupCompleteTitle"] = { 0.5, 0.5, 1 },
	["PopupCompleteDescription"] = { 0.7, 0.7, 1 },
	["PopupCompleteBackground"] = { 0.7, 0.7, 1, 0.5 }, -- has alpha
	
	["PopupOfferTitle"] = { 1, 0.9, 0.4 },
	["PopupOfferDescription"] = { 1, 0.9, 0.75 },
	["PopupOfferBackground"] = { 1, 0.9, 0.65, 0.5 }, -- has alpha
	
	["PopupItemTitle"] = { 0.35, 1, 0.35 },
	["PopupItemDescription"] = { 0.7, 1, 0.7 },
	["PopupItemBackground"] = { 0.4, 1, 0.4, 0.5 },	 -- has alpha
	
	-- headers
	["QuestHeader"] = { 1, 1, 1 },
	["QuestHeaderCollapsed"] = { 1, 1, 1 },
	["AchievementHeader"] = { 1, 1, 1 },
	["AchievementHeaderCollapsed"] = { 1, 1, 1 },
	["SectionHeader"] = { 1, 0.8, 0.6 },

	-- general objectives
	["ObjectiveComplete"] = { 0.3, 0.8, 1 },
	["ObjectiveFailed"] = { 0.55, 0.55, 0.55 },

	-- objective gradients
	["ObjectiveGradient0"]  = { 0.91, 0.19, 0.41 },
	["ObjectiveGradient50"] = { 0.81, 0.77, 0.41 },
	["ObjectiveGradient99"] = { 0.29, 0.87, 0.56 },
	["ObjectiveGradientComplete"] = { 0.75, 0.60, 0.79 },	
	
	-- scenario-specific
	["ScenarioStageTitle"] = { 0, 1, 0.5 },
	["ScenarioTimer"] = { 0, 0.33, 0.61 },

	-- quest-specific
	["QuestCompleteAuto"] = { 0.5, 0.5, 1 },
	["QuestConnector"] = { 0.75, 0.95, 0.75 },
	["QuestTimer"] = { 0.6, 0.1, 0.2 },
	
	-- achievement-specific
	["AchievementTitle"] = { 0.85, 0.71, 0.1 },
	["AchievementTitleGuild"] = { 0.95, 0.51, 0.1 },
	["AchievementTitleComplete"] = { 0, 1, 1 }, -- normally never shown as completed achievements are automatically untracked
	
	["AchievementDescription"] = { 0.7, 0.7, 0.7 },
	["AchievementCriteria"] = { 0.7, 0.7, 0.7 },
	["AchievementCriteriaComplete"] = { 0, 1, 0 }, -- only shown for timed criteria
	
	["AchievementTimedTitle"] = { 0, 1, 0.6 },
	["AchievementTimedBackground"] = { 0, 0.9, 0.5, 0.5 }, -- has alpha
	["AchievementTimer"] = { 0.6, 1, 0.8 },
	["AchievementTimerMeta"] = { 0.5, 0.7, 1 },

	-- animations
	["ObjectiveProgressFlash"] = { 0.4, 1, 0.6 },
	["ObjectiveChangedGlow"] = { 0.3, 0.5, 1 },
	["ObjectiveAlertGlow"] = { 0.8, 0.6, 0.2 },
}