# QuestKing Secure Quest Item Button OnClick Fix

## Issue

QuestKing still produced this protected-call error when clicking a quest-use item in the watch frame:

```text
[ADDON_ACTION_FORBIDDEN] AddOn 'QuestKing' tried to call the protected function 'UNKNOWN()'
[C]: in function 'UseQuestLogSpecialItem'
QuestKing/ui/itembutton.lua
```

The previous package restored a direct `UseQuestLogSpecialItem(questLogIndex)` call. That matches Blizzard Lua, but addon-owned Lua is not allowed to call this protected path safely on current clients.

## Root cause

The first secure patch inherited `SecureActionButtonTemplate`, but the XML also replaced the secure template's `<OnClick>` with QuestKing's custom `QuestKing_QuestObjectiveItem_OnClick`. That meant the secure `type1="item"` / `item1=<item link>` attributes were set but never executed.

## Fix

- `QuestKingItemButtonTemplate` now inherits `SecureActionButtonTemplate`.
- The XML now uses Blizzard's `SecureActionButton_OnClick` for the actual click action.
- QuestKing's custom logic moved to `PostClick`, where it only performs safe work:
  - queueing a tracker refresh after left-click;
  - inserting a chat link on modified chat-link clicks.
- The direct `UseQuestLogSpecialItem()` call was removed from the active click path.
- Modified left-click combinations clear secure action attributes so chat-link clicks do not also use the item.
- Secure attributes are only changed out of combat.

## Files changed

- `ui/itembutton.lua`
- `ui/itembutton.xml`
- `version.txt`
- `QUEST_ITEM_BUTTON_SECURE_ONCLICK_FIX_CHANGELOG.md`
