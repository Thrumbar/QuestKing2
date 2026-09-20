# Quest Context Menu Actions

## Summary

QuestKing's quest right-click menu now follows Blizzard's current objective
tracker action order and terminology:

- **Focus / Remove Focus** controls the active navigation target.
- **Open Quest Details** opens the dedicated quest-details view when supported.
- **Open Quest Map** opens the map directly to the selected quest on supported
  Classic-family clients.
- **Untrack** removes the quest from the watched tracker list.
- **Share Quest** shares an eligible quest with the current group.
- **Abandon Quest** opens Blizzard's confirmation dialog.

Ordinary left-click opens popup quest details on Mainline and the quest map on
supported Classic-family clients. Shift-click still inserts a quest link, and
field-completable quests retain their click-to-complete behavior.
The redundant **Cancel** row remains omitted because the dropdown closes
through Blizzard's normal menu behavior.

## Safety and compatibility

- Mainline actions use quest IDs and current `C_QuestLog` APIs.
- Classic-family actions resolve the live quest-log index before acting.
- Focus changes only Blizzard's navigation supertracking state.
- Track Quest and Untrack Quest change only Blizzard's quest watch list.
- Untrack no longer clears Focus directly; on Mainline, Blizzard's
  `QUEST_WATCH_LIST_CHANGED` handler may then clear the matching focused quest.
- Focus is disabled on clients without an exact quest-supertracking API.
- Open Quest Map is omitted on Mainline so QuestKing cannot rebuild Blizzard's
  pooled Area POI pins from addon-tainted execution. It remains disabled where
  no legacy quest map exists and while combat lockdown makes that path unsafe.
- Era and Burning Crusade sharing and abandonment preserve and restore the
  player's selected quest-log entry.
- Share Quest remains visible but disabled while solo or when the quest cannot
  be shared.
- Abandon Quest remains visible but disabled when Blizzard reports that the
  quest cannot be abandoned.
- Abandon Quest never bypasses Blizzard's confirmation or item-destruction
  warning.
- World quests use Blizzard's `QuestUtil.TrackWorldQuest` and
  `QuestUtil.UntrackWorldQuest` helpers when available.
- Track Quest observes Blizzard's normal quest, Classic, and manual world-quest
  watch limits and reports the standard too-many-quests error.

QuestKing intentionally displays every accepted quest on Classic-family
clients. A quest that is not on Blizzard's watch list therefore remains visible
and changes its menu action to **Track Quest**. This preserves QuestKing's
Classic display policy without redefining Blizzard's tracking state.
