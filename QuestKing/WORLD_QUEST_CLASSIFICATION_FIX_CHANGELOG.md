# QuestKing 3.0.41 — World Quest Classification Fix

## Corrected classification

- World Quests returned by Blizzard's shared `GetTasksTable()` input are now
  routed to QuestKing's **World Quests** section.
- The **Bonus Objectives** renderer now rejects World Quests unconditionally,
  matching Blizzard's separate World Quest and Bonus Objective tracker modules.
- Local untracked World Quests and explicitly watched World Quests are
  de-duplicated into the same QuestKing quest population.

## Corrected fallback display

- Watched World Quests without an ordinary quest-log row now use a synthetic
  quest display snapshot instead of the bonus-objective row renderer.
- The snapshot reads the title, level, completion state, objectives, and
  progress directly by quest ID.
- If Blizzard quest objective data is still loading, the World Quest remains
  visible as a title-only row instead of being mislabeled or hidden.
- World Quest titles now use QuestKing's readable `[World]` prefix and separate
  level field; raw internal tags such as `(109)e` are no longer exposed by this
  fallback path.

## Phase 7 preservation

- The task-world-quest ID set is included in the Phase 7 population fingerprint,
  so entering or leaving a World Quest area invalidates the cached population.
- Synthetic World Quest rows support the cached display-refresh path and do not
  force a full quest-population rebuild on every objective update.
- Phase 7 startup visibility recovery, coalesced refreshes, failure containment,
  profiling, pooled-row indexing, and all earlier behavior remain intact.

## Blizzard references

The correction follows the supplied 12.0.7 and 12.1.0 FrameXML behavior:

- `Blizzard_WorldQuestObjectiveTracker.lua` accepts World Quests from
  `GetTasksTable()` and the watched World Quest list.
- `Blizzard_BonusObjectiveTracker.lua` explicitly excludes World Quests before
  adding bonus-objective rows.

## Changed files

- `buttons/quest.lua`
- `version.txt`
- `WORLD_QUEST_CLASSIFICATION_FIX_CHANGELOG.md`
