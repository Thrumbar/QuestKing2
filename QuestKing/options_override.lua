-- options_override.lua
-- Optional local overrides for QuestKing.
-- This file is safe to keep outside the main defaults so you can tune
-- layout and colors without editing the base options file.

local addonName, QuestKing = ...
if not QuestKing or not QuestKing.options then
    return
end

local opt = QuestKing.options
local colors = opt.colors or {}

opt.colors = colors

-- ---------------------------------------------------------------------------
-- Fonts
-- ---------------------------------------------------------------------------

opt.font = [[Fonts\FRIZQT__.TTF]]
opt.fontChallengeTimer = [[Fonts\FRIZQT__.TTF]]
opt.fontSize = 12
opt.fontStyle = "OUTLINE"

-- ---------------------------------------------------------------------------
-- Tracker sizing
-- ---------------------------------------------------------------------------

opt.buttonWidth = 280
opt.lineHeight = 18
opt.titleHeight = 18

opt.dbAllowTrackerScale = true
opt.dbAllowTrackerAlpha = true

opt.trackerScale = 1.00
opt.trackerAlpha = 0.92

-- ---------------------------------------------------------------------------
-- Item / reward placement
-- ---------------------------------------------------------------------------

opt.itemAnchorSide = "right"
opt.itemButtonScale = 1.00
opt.rewardAnchorSide = "right"

-- ---------------------------------------------------------------------------
-- Behavior
-- ---------------------------------------------------------------------------

opt.enableItemPopups = true
opt.showCompletedObjectives = false
opt.hideSupersedingObjectives = true
opt.allowDrag = true
opt.disableBlizzard = true

-- ---------------------------------------------------------------------------
-- Tooltip handling
-- ---------------------------------------------------------------------------

opt.tooltipAnchor = "ANCHOR_RIGHT"
opt.tooltipScale = nil

-- ---------------------------------------------------------------------------
-- Tracker title colors
-- ---------------------------------------------------------------------------

colors.TrackerTitlebarText = { 0.85, 0.85, 0.95 }
colors.TrackerTitlebarTextDimmed = { 0.55, 0.55, 0.65 }

-- ---------------------------------------------------------------------------
-- Objective colors
-- ---------------------------------------------------------------------------

colors.ObjectiveGradient0 = { 0.95, 0.35, 0.35 }
colors.ObjectiveGradient50 = { 1.00, 0.75, 0.30 }
colors.ObjectiveGradient99 = { 0.35, 0.90, 0.45 }
colors.ObjectiveGradientComplete = { 0.50, 0.85, 1.00 }

colors.ObjectiveComplete = colors.ObjectiveComplete or { 0.50, 0.85, 1.00 }
colors.ObjectiveAlertGlow = colors.ObjectiveAlertGlow or { 1.00, 0.82, 0.30 }

-- ---------------------------------------------------------------------------
-- Popup colors
-- ---------------------------------------------------------------------------

colors.PopupOfferTitle = { 1.00, 0.95, 0.65 }
colors.PopupOfferDescription = { 0.85, 0.85, 0.85 }
colors.PopupOfferBackground = { 0.07, 0.07, 0.09, 0.85 }

colors.PopupCompleteTitle = { 0.65, 1.00, 0.75 }
colors.PopupCompleteDescription = { 0.85, 0.85, 0.85 }
colors.PopupCompleteBackground = { 0.07, 0.09, 0.07, 0.85 }

colors.PopupItemTitle = { 0.95, 0.90, 1.00 }
colors.PopupItemDescription = { 0.85, 0.85, 0.85 }
colors.PopupItemBackground = { 0.09, 0.07, 0.09, 0.85 }

-- ---------------------------------------------------------------------------
-- Section / scenario colors
-- ---------------------------------------------------------------------------

colors.SectionHeader = colors.SectionHeader or { 0.85, 0.72, 0.30 }
colors.ScenarioStageTitle = colors.ScenarioStageTitle or { 1.00, 0.82, 0.00 }
colors.ScenarioTimer = colors.ScenarioTimer or { 0.85, 0.25, 0.25 }

-- ---------------------------------------------------------------------------
-- Background / border handling
-- ---------------------------------------------------------------------------

opt.enableAdvancedBackground = true

opt.advancedBackgroundTable = opt.advancedBackgroundTable or {
    bgFile = [[Interface\ChatFrame\ChatFrameBackground]],
    edgeFile = [[Interface\Tooltips\UI-Tooltip-Border]],
    tile = false,
    tileSize = 0,
    edgeSize = 12,
    insets = {
        left = 3,
        right = 3,
        top = 3,
        bottom = 3,
    },
    _backdropColor = { 0, 0, 0, 0.72 },
    _borderColor = { 0.35, 0.35, 0.40, 1 },
    _alpha = 0.90,
    _alphaStep = 0.10,
    _anchorPoints = {
        topLeftX = -6,
        topLeftY = 6,
        bottomRightX = 6,
        bottomRightY = -6,
    },
    _hideWhenEmpty = true,
}

opt.backdropTable = opt.backdropTable or {
    bgFile = [[Interface\ChatFrame\ChatFrameBackground]],
    insets = {
        left = -2,
        right = -2,
        top = opt.titleHeight + 1,
        bottom = -2,
    },
    _backdropColor = { 0, 0, 0, 0.50 },
    _alphaStep = 0.10,
}

-- ---------------------------------------------------------------------------
-- Placement presets
-- ---------------------------------------------------------------------------

opt.positionPresets = {
    { "TOPRIGHT", "UIParent", "TOPRIGHT", -12, -160 },
    { "TOPRIGHT", "UIParent", "TOPRIGHT", -200, -24 },
    { "TOPLEFT", "UIParent", "TOPLEFT", 16, -160 },
    { "BOTTOMRIGHT", "UIParent", "BOTTOMRIGHT", -16, 220 },
}