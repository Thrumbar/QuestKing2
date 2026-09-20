# QuestKing Field Completion Fix

## Panel Verdict

- API review: Retail 12.0 and 12.1 expose the tracker flag through `C_QuestLog.GetInfo(questLogIndex).isAutoComplete`; the prior row detector did not read it.
- Runtime-flow review: `ReadyForTurnIn` is not a field-completion signal because ordinary NPC turn-ins also report it.
- UI review: the row label, icon, tooltip, popup, and click action now share one remote-completion contract.

Static acceptance result: `PARTIAL — runtime validation required`.

## Corrected Behavior

- A remotely completable quest displays:
  - A ready-check icon before the quest title.
  - `Quest Complete`.
  - `Click to complete`.
  - `Left-click to complete quest` in the tooltip.
- Left-click opens the native completion dialog and removes only that quest's matching `COMPLETE` popup.
- An ordinary completed quest that requires an NPC remains `Ready for turn-in`; left-click opens quest details.
- An incomplete quest that supports eventual field completion is not treated as currently completable.
- An `OFFER` popup is never treated as a completion popup.

## Cross-Version Contract

- Mainline 12.0/12.1 reads `C_QuestLog.GetInfo(questLogIndex).isAutoComplete` and calls `ShowQuestComplete(questID)`.
- Cataclysm/Mists Classic uses `GetQuestLogIsAutoComplete(questLogIndex)` when exposed and calls `ShowQuestComplete(questLogIndex)`.
- Classic Era/TBC can use the authoritative `QUEST_AUTOCOMPLETE` event when no query API is exposed.
- `QUEST_AUTOCOMPLETE` is recorded before tracker refresh to cover the event-to-quest-log update race.
- Recorded event state is cleared on `QUEST_REMOVED` and `QUEST_TURNED_IN`.

## Reliability Corrections

- Removed the broad `ReadyForTurnIn` completion-action gate.
- Removed generic `WatchButton` click wrappers that could intercept offer popups, bonus rows, and modified-click quest links.
- Preserved Shift-left quest-link insertion before the normal quest-row action.
- Centralized autocomplete metadata, event state, popup state, completion state, and client-specific completion arguments in `core/compatibility.lua`.
- Kept the secure quest-item action path separate from field completion.

## Changed Files

- `core/compatibility.lua`
- `core/events.lua`
- `core/util.lua`
- `core/AutoComplete.lua`
- `buttons/quest.lua`
- `buttons/popup.lua`
- `version.txt`
- `FIELD_COMPLETION_FIX_CHANGELOG.md`

## Runtime Test Procedure

1. On Retail, complete a field-completable quest and confirm the ready-check icon, both completion lines, completion tooltip, and native completion dialog.
2. Confirm an ordinary NPC turn-in shows only the normal ready state and opens quest details.
3. Confirm an incomplete autocomplete-capable quest does not open the completion dialog.
4. Confirm a `COMPLETE` popup completes the quest and removes only itself.
5. Confirm an `OFFER` popup opens the offer and is never routed to completion.
6. Shift-left a remotely completable quest while chat is active and confirm the quest link is inserted.
7. Repeat the completion-dialog test on Cataclysm/Mists Classic and confirm the correct quest opens.
8. On an event-only client path, confirm `QUEST_AUTOCOMPLETE` immediately exposes the completion action and that removal or turn-in clears it.
9. Right-click-dismiss a completion popup and confirm the genuine remotely completable tracked row remains actionable.
10. Test multiple simultaneous autoquest popups and confirm completing one does not remove the others.

## Remaining Validation

Static analysis cannot execute Blizzard's quest event timing or completion UI. The fix requires in-game confirmation on at least one Mainline and one Classic-family client before being marked `PASS`.
