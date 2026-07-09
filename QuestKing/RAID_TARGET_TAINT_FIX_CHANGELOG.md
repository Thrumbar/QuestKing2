# QuestKing Raid Target Taint Fix

## Issue

BugGrabber reported:

```text
[ADDON_ACTION_FORBIDDEN] AddOn 'QuestKing' tried to call the protected function 'SetRaidTarget()'.
```

QuestKing did not directly call `SetRaidTarget()`. The taint path came from QuestKing owning a quest item button that inherited `SecureActionButtonTemplate`. When another secure macro/action path attempted to run a raid-target command, Blizzard attributed the protected-call taint to QuestKing.

## Changed Files

- `ui/itembutton.lua`
- `ui/itembutton.xml`

## Fix

- Removed `SecureActionButtonTemplate` from `QuestKingItemButtonTemplate`.
- Removed secure action attributes from QuestKing quest item buttons:
  - `type = "item"`
  - `item = <itemLink>`
- Added a normal hardware-click handler for quest item buttons:
  - left-click uses `UseQuestLogSpecialItem(questLogIndex)`
  - modified chat-link click inserts the quest item link into chat when a chat edit box is active
- Queued the tracker refresh after quest item clicks with a zero-delay timer when available, keeping QuestKing UI rebuilds outside the click stack.
- Kept quest item cooldown, range, count, tooltip, pooling, and tracker-refresh behavior intact.

## Compatibility

This follows Blizzard's current Objective Tracker pattern in modern clients: the tracker quest item button is a normal button that stores quest metadata and calls `UseQuestLogSpecialItem()` from its click handler, instead of being an addon-owned secure action button.

The change is Lua 5.1 compatible and remains guarded for Classic-family clients where quest special item APIs may not exist.
