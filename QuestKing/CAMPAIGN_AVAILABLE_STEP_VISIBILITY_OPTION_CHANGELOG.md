# QuestKing Campaign Continuation Visibility Option

## Summary

Added an options-panel toggle to hide Blizzard-style campaign continuation rows from the QuestKing watch frame.

## User-facing change

A new checkbox appears under **Quest Behavior**:

- **Show campaign continuation hints**

When enabled, QuestKing can show rows such as:

> Continue the campaign by accepting the quest "Quest Name" in Zone Name.

When disabled, those available-campaign rows are not added to the watch frame. Normal tracked quests, campaign quests already in the quest log, world quests, objectives, item buttons, rewards, scenarios, and bonus objectives are unchanged.

## Files changed

- `options.lua`
  - Added the default option `showAvailableCampaignSteps = true`.

- `options_override.lua`
  - Added the override default so this bundle keeps the feature enabled unless the user disables it in the options panel.

- `ui/optionspanel.lua`
  - Added `showAvailableCampaignSteps` to the saved managed options table.
  - Added the **Show campaign continuation hints** checkbox under **Quest Behavior**.
  - The checkbox saves to `QuestKingDB.options.showAvailableCampaignSteps` and refreshes the tracker immediately.

- `buttons/quest.lua`
  - Added an early return in the available-campaign row builder when `QuestKing.options.showAvailableCampaignSteps == false`.

## Compatibility

Classic clients remain safe because the actual campaign row builder already checks for `C_CampaignInfo` before using Retail/Midnight campaign APIs. This change only adds a user setting before that API path runs.
