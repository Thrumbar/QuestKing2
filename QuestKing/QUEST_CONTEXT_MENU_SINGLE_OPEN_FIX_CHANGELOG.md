# Quest Context Menu Single-Open Fix

## Problem

Right-clicking a quest in the QuestKing watch window could open the quest context menu more than once. The visible duplicates were especially noticeable in a group when repeated quest-related dispatches occurred for members sharing the same quest.

## Confirmed source condition

QuestKing made both the pooled quest-row body and its nested title button independently clickable. The title child did not explicitly stop mouse-click propagation to the clickable parent. The context-menu opener also had no protection against repeated calls for the same quest while the menu was already visible.

## Changes

### `ui/watchbutton.lua`

- Keeps the row body clickable for objective/body clicks and keeps the title button clickable for title clicks.
- QuestKing 3.0.45 removes the former `SetPropagateMouseClicks(false)` calls
  because current clients mark that method protected and restricted.

### `buttons/quest.lua`

- Detects when the QuestKing dropdown is already open for the requested quest and treats the repeated call as handled.
- Adds a short quest-ID-specific debounce for duplicate calls delivered during the same physical click.
- Closes a stale level-one dropdown before opening a new quest menu.
- Preserves all existing menu actions: open quest, set/clear active quest, track/untrack quest, and cancel.

## Compatibility

The menu guard uses only Lua 5.1-compatible syntax and the existing
cross-version `UIDropDownMenu` path. The single-open behavior does not depend
on protected mouse-propagation state.

## Expected result

One right-click on one QuestKing quest row opens one quest context menu, regardless of how many group members have the quest.
