# QuestKing 3.0.22 — Single Track Option Fix

## Problem

The quest right-click menu displayed both **Set Active Quest** and **Track Quest**. For the requested workflow, both appeared to perform quest tracking and the active-quest action was unnecessary.

## Correction

- Removed **Set Active Quest / Clear Active Quest** from the right-click menu.
- Kept exactly one **Track Quest / Untrack Quest** action.
- Kept **Open Quest** and **Cancel**.
- Changed the compatibility fallback so right-click toggles watch tracking rather than supertracking if Blizzard's dropdown API is unavailable.
- Did not change party quest ownership, party progress, objective counting, left-click behavior, or duplicate-click protection.

## Changed file

- `buttons/quest.lua`
