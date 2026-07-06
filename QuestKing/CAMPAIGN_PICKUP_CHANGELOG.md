# QuestKing Campaign Pickup Tracker Update

## Purpose

This update fixes the missing Blizzard tracker behavior for campaign quests that are **not yet in the quest log** but must be picked up to continue or complete the current campaign.

Blizzard does not treat these as normal watched quests. On Retail/Midnight it exposes them through campaign failure/next-step data and quest-line offer data.

## Changed File

- `buttons/quest.lua`

## What Changed

### Campaign pickup detection

QuestKing now checks stalled Retail/Midnight campaigns through:

- `C_CampaignInfo.GetAvailableCampaigns()`
- `C_CampaignInfo.GetState()`
- `C_CampaignInfo.GetFailureReason()`

When the campaign failure reason provides a quest ID or map ID, QuestKing now treats that as a possible campaign pickup requirement instead of only showing accepted campaign quests.

### Quest pickup lookup

QuestKing now resolves available campaign pickups through:

- `C_QuestLine.GetQuestLineInfo()`
- `C_QuestLine.GetAvailableQuestLines()`
- `C_QuestLine.GetForceVisibleQuests()`
- `C_QuestLine.RequestQuestLinesForMap()`

This lets the tracker show the next campaign quest even before the player accepts it.

### Tracker row behavior

Campaign pickup rows now:

- Display under the Campaign section.
- Show `Pick up: <quest name>` when the title is available.
- Use the campaign name as the row header.
- Avoid duplicates when the quest is already in the quest log.
- Avoid showing completed pickup quests.
- Become clickable instead of passive text.

### Super tracking

When Blizzard exposes the pickup quest ID, left-clicking the campaign pickup row now calls:

- `C_SuperTrack.SetSuperTrackedMapPin(Enum.SuperTrackingMapPinType.QuestOffer, questID)`

This matches Blizzard's quest-offer pin tracking model for quests that are not yet accepted.

Right-clicking the row opens the relevant map when a map ID is exposed.

## Compatibility Notes

- This feature is Retail/Midnight-only because Classic clients do not expose the modern `C_CampaignInfo` / `C_QuestLine` campaign-offer APIs.
- Classic, TBC Classic, Cataclysm Classic, and MoP Classic behavior is unchanged.
- All new API calls are guarded before use.

## Validation

All Lua files were syntax checked with `texluac -p`.
