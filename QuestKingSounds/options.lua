local addonName, QuestKingSounds = ...
_G.QuestKingSounds = QuestKingSounds

local opt = {}
QuestKingSounds.options = opt

--------------------------------------------------------------------
--------------------------------------------------------------------
---- This file lists all the default options for QuestKingSounds.
---- 
---- Instead of editing the options here directly, please consider
---- adding overrides for the default settings instead. You can do
---- this in options_override.lua
--------------------------------------------------------------------
--------------------------------------------------------------------

-- Default options

opt.playObjProgress = true
opt.soundObjProgress = "AuctionWindowOpen"

opt.playObjComplete = true
opt.soundObjComplete = "AuctionWindowClose"

opt.playQuestComplete = true
opt.soundQuestComplete = "ReadyCheck"

opt.showQuestCompleteMessage = true
opt.questCompleteMessageFormat = "Quest Complete! (%s)"
opt.questCompleteMessageColor = { r = 0.3, g = 0.8, b = 1 }
