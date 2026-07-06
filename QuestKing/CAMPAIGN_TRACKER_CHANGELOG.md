# QuestKing Campaign Tracker Update

## Changed

- Added Retail/Midnight campaign quest discovery from the full quest log, not only from the watched quest list.
- Added support for modern `Enum.QuestClassification.Campaign` and `C_QuestInfoSystem.GetQuestClassification()` checks.
- Added campaign requirement rows from `C_CampaignInfo.GetAvailableCampaigns()` and `C_CampaignInfo.GetFailureReason()` when a campaign is stalled by a required quest or requirement.
- Preserved Classic behavior by keeping the full quest-log scan limited to Classic family clients and using the new campaign scan only outside Classic.
- Prevented duplicate campaign entries when a campaign quest is already watched.

## Result

QuestKing now surfaces campaign quests that Blizzard treats as campaign-progress quests even when the player did not manually add them to the watch list. If a Retail/Midnight campaign is stalled by a required quest, QuestKing can show the campaign requirement text under the Campaign section.

## Files changed

- `buttons/quest.lua`
