# QuestKing Quest Item Button Fix - Prophecy Stirs - Superseded

## Status

This change was superseded by `QUEST_ITEM_BUTTON_SECURE_ONCLICK_FIX_CHANGELOG.md` after BugGrabber confirmed that addon-owned direct calls to `UseQuestLogSpecialItem()` can still raise a protected `UNKNOWN()` action error.

## Why It Was Replaced

The previous package restored Blizzard-style direct `UseQuestLogSpecialItem(questLogIndex)` behavior. That can work for Blizzard-owned tracker code, but QuestKing's addon-owned click handler is not allowed to call that protected path safely on current clients.

## Current Behavior

- The item button is a secure action button again.
- XML no longer overrides `SecureActionButton_OnClick`.
- The protected use action is handled through secure `type1="item"` / `item1=<item link>` attributes.
- QuestKing's Lua click code no longer calls `UseQuestLogSpecialItem()`.

## Current Owner

- `QUEST_ITEM_BUTTON_SECURE_ONCLICK_FIX_CHANGELOG.md`
