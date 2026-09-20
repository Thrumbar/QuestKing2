# QuestKing 3.0.21 — Group Quest Track Menu Label Fix

## Confirmed cause

QuestKing exposes two separate right-click actions:

1. **Set Active Quest** — controls Blizzard supertracking/navigation.
2. **Track Quest** — controls whether the quest is in the player's watched quest list.

The first action incorrectly reused Blizzard's `TRACK_QUEST` / `UNTRACK_QUEST` text constants. When a grouped quest was neither active nor watched, both separate actions were therefore labeled **Track Quest**, making the menu appear to contain one option for each party member.

## Correction

- The supertracking row now always uses the distinct labels **Set Active Quest** and **Clear Active Quest**.
- The watch-list row remains **Track Quest** or **Untrack Quest**.
- No menu rows are generated for party members.
- Group quest ownership/progress data is not changed.
- The click-propagation and duplicate-open guards from 3.0.20 remain in place.

## Changed file

- `buttons/quest.lua`
