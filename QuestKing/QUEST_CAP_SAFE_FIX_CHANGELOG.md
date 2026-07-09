# Quest Cap Safe Fix

## Summary

QuestKing's watch-frame titlebar was displaying values such as `1/175` because the addon used `C_QuestLog.GetMaxNumQuests()`. On modern clients that API can return Blizzard's broad internal quest bucket capacity instead of the normal accepted quest-log limit.

This patch changes only the quest-cap display helper functions. It does not alter quest scanning, tracking, watch-button creation, sorting, filtering, or list layout.

## Files Updated

- `core/core.lua`
- `ui/tracker.lua`

## Technical Details

The cap lookup now prefers:

```lua
C_QuestLog.GetMaxNumQuestsCanAccept()
```

It keeps `C_QuestLog.GetMaxNumQuests()` only as a guarded fallback for older clients, rejecting suspicious internal-cap values above `50`.

Final fallback remains compatible with older clients:

```lua
_G.MAX_QUESTLOG_QUESTS or _G.MAX_QUESTS or 25
```

## Expected Result

The watch-frame titlebar should show the normal accepted quest capacity, such as `1/35`, instead of an internal value such as `1/175`.
