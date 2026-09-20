# Quest Item Secure Click Taint Fix - Superseded

## Status

This change was superseded by `QUEST_ITEM_BUTTON_SECURE_ONCLICK_FIX_CHANGELOG.md`.

The original secure-button direction was correct, but the first version still let QuestKing's custom XML `<OnClick>` replace Blizzard's `SecureActionButton_OnClick`, so the secure action never fired.

## Current Owner

The active fix is now documented in:

- `QUEST_ITEM_BUTTON_SECURE_ONCLICK_FIX_CHANGELOG.md`

## Current Behavior

- The quest item button inherits `SecureActionButtonTemplate`.
- The XML uses `SecureActionButton_OnClick` for left-click item use.
- QuestKing's own logic runs only in `PostClick` for safe refresh and chat-link handling.
- The active click path no longer calls `UseQuestLogSpecialItem()` from QuestKing Lua.
