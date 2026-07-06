# QuestKing Campaign Untrack Fix

## Fixed

- Campaign quests shown by QuestKing can now be removed from the tracker through the QuestKing right-click menu.
- Campaign pickup requirements that are not yet in the quest log can now be removed from QuestKing's tracker.
- QuestKing now follows Blizzard's watched-quest state for accepted campaign quests instead of forcing every campaign quest in the quest log back into the tracker.

## Behavior

- Right-click a tracked campaign quest and select **Stop Tracking**.
- Right-click a campaign pickup requirement and select **Stop Tracking**.
- Left-click still opens/tracks the campaign quest or pickup location.
- Campaign quests manually added back to the watch list are shown again.
- Campaign pickup suppressions are cleared automatically after the required quest is accepted or completed.

## Technical Notes

- Added a local tracker context menu fallback in `buttons/quest.lua` so QuestKing does not depend on missing external popup helpers.
- Added per-character suppression tables:
  - `QuestKingDBPerChar.untrackedCampaignQuests`
  - `QuestKingDBPerChar.untrackedCampaignRequirements`
- Added compatibility use of `C_QuestLog.GetQuestWatchType()` where available.
- Kept Classic behavior safe by limiting campaign-specific full-log logic to non-Classic clients.

## Validation

- All Lua files were syntax checked with `texluac -p`.
