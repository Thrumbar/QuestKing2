# QuestKing 3.0.23 - Right-click Track Quest Action Fix

## Confirmed issue

The 3.0.22 menu retained the watch-list `AddQuestWatch` / `RemoveQuestWatch` action after the separate Active Quest row was removed. A quest shown in QuestKing is already part of the tracker display, so clicking **Track Quest** did not select it as the player's navigation target.

## Correction

- Kept a single **Track Quest / Untrack Quest** menu row.
- **Track Quest** now calls QuestKing's cross-version supertracking wrapper for the clicked quest ID.
- **Untrack Quest** clears supertracking only when that same quest is active.
- Changed the no-dropdown fallback to use the same supertracking behavior.
- Did not alter party quest progress, quest watch enumeration, left-click quest opening, objective data, or the duplicate-menu guards.

## Changed file

- `buttons/quest.lua`
