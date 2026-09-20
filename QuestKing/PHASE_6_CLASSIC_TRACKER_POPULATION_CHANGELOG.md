# QuestKing 3.0.38 — Phase 6 Classic Tracker Population

## Population policy

QuestKing now has one explicit, configurable quest-population policy:

- `automatic` preserves branch-appropriate tracker behavior:
  - Classic Era, Burning Crusade Classic, Cataclysm Classic, and Mists Classic show every accepted quest that the client exposes through its quest log, including quests with no objectives.
  - Mainline shows watched quests only.
- `watched` shows watched quests only on every client.
- `all` shows every accepted quest on every client.

The setting is available under **Quest Behavior → Tracker Quest Population** and applies immediately.

## Reliability corrections

- Quest rows and the tracker-title numerator use the same resolved population.
- Tracker-title dimming uses that population plus actually requested scenario, bonus, challenge, popup, and campaign-hint rows, so a nonempty tracker never looks disabled.
- Mainline ordinary and world-quest watch lists are unioned and de-duplicated before rows are built.
- Watched Mainline world quests that have no ordinary quest-log row use the quest-ID-based task renderer and remain visible outside their active area.
- Fallback world quests with unavailable objective data remain title-only instead of being mislabeled complete.
- The quest population is built once per tracker refresh and reused by the normal quest renderer and bonus-objective duplicate filter.
- Population scans temporarily expand collapsed quest-log headers where required, snapshot the visible quest data, and restore the original collapsed headers in reverse order.
- QuestKing suppresses only the synthetic `QUEST_LOG_UPDATE` signals produced inside that transaction, preventing recursive tracker refreshes while preserving real quest-log updates.
- Captured rows revalidate their live quest-log index after header restoration, so shifted or hidden indices cannot target the wrong quest.
- Campaign continuation hints remain visible when enabled but are not counted as accepted quest rows.
- Active prey quests obey the resolved population rule instead of bypassing watched-only mode.
- Mainline no longer reports the complete quest-log count when only watched rows are displayed.
- Classic accepted quests with no objective lines retain their title row under the automatic or all-accepted policies.
- Failed quests now use Blizzard's documented branch contracts:
  - Mainline uses `C_QuestLog.IsFailed(questID)`.
  - Classic-family clients use the negative legacy completion state returned with quest-log data.
- Failed quests display a localized **Failed** row and the configured failed-objective color instead of being presented as ordinary incomplete quests.
- Negative legacy completion states can no longer be misread as successful completion.
- Reused bonus-task text lines release stale timer and progress bars before rendering new content.
- Invalid saved tracker-collapse and display-mode values are normalized so the title and requested rows cannot silently use different modes.

## Changed files

- `options.lua`
- `ui/optionspanel.lua`
- `buttons/quest.lua`
- `buttons/bonusobjective.lua`
- `core/core.lua`
- `core/events.lua`
- `ui/tracker.lua`
- `version.txt`
- `PHASE_6_CLASSIC_TRACKER_POPULATION_CHANGELOG.md`

## Validation status

Static validation passed:

- 24/24 Lua files parse as Lua 5.1.
- 108/108 source, TOC, supplied-Blizzard-snapshot, and population-behavior checks pass.
- 2/2 XML files are well formed.
- Three-expert challenge review found no remaining static release blocker.

Final in-game validation remains required on each supported client family, especially collapsed-header refreshes and watched world quests outside their active area.
