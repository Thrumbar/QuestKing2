# QuestKing Campaign Available Step Update

## Purpose
Adds Blizzard-style campaign continuation guidance to the QuestKing tracker.

When Blizzard exposes a stalled campaign with a next available quest, QuestKing now displays the localized campaign hint line, for example:

> Continue the campaign by accepting the quest "Quest Name" in Zone Name.

## Files Changed

### `buttons/quest.lua`
- Adds Retail/Midnight-safe campaign stalled-step detection through `C_CampaignInfo`.
- Reads `C_CampaignInfo.GetAvailableCampaigns()`, `C_CampaignInfo.GetState()`, and `C_CampaignInfo.GetFailureReason()` when those APIs exist.
- Adds a new internal tracker row type: `available_campaign`.
- Displays the campaign name under the Campaign section with Blizzard's localized `failureReason.text` as the tracker line.
- Avoids duplicate display when the next campaign quest is already accepted and present in the quest log.
- Left-clicking the row attempts to super-track the next campaign quest ID when Blizzard provides one.
- Falls back safely when the API does not exist, so Classic Era, TBC Classic, Wrath/Cata/MoP Classic clients do not error.

### `ui/watchbutton.lua`
- Clears campaign continuation row fields when pooled watch buttons are reused.

## Compatibility Notes
- This feature is active only when `C_CampaignInfo` exists and provides campaign failure reason data.
- No new saved variables are required.
- No helper file is required.
- Classic clients skip the feature automatically because the required campaign APIs are absent.
