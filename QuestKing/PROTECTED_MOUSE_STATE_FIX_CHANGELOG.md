# QuestKing Protected Mouse-State Fix

## Fixed error

```text
[ADDON_ACTION_BLOCKED] AddOn 'QuestKing' tried to call the protected function
'QuestKing_PoolButton1:EnableMouse()'.
```

## Root cause

QuestKing reparented each secure quest-item button to a recyclable watch row. The item button inherits `SecureActionButtonTemplate`, so its row became protected. The pool could later reuse that protected row as a section header, where an in-combat refresh called `EnableMouse(false)`. Blizzard blocked that mutation.

## Changes

- Secure quest-item buttons remain parented to the stable QuestKing tracker and are anchored to their visual row instead of becoming children of pooled rows.
- Recycled rows no longer become protected merely because they displayed a quest-use item.
- All pooled-row mouse modes now go through a combat-safe setter. During combat, only the protected interaction-state change is deferred; quest text and objective progress continue to refresh.
- Repeated quest-row `RegisterForClicks()` calls were removed. Click registration remains performed once when each pooled row is created.
- The same safe mouse-mode handling is used for quest and campaign rows, section headers, popup rows, achievements, bonus objectives, and challenge timers.

## Compatibility

The fix uses the same frame APIs available across Classic Era, Burning Crusade Classic, Cataclysm Classic, Mists Classic, Retail, and Midnight builds. No external library or helper addon is required.
