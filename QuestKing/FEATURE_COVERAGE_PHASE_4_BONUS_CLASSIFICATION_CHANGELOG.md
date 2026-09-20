# QuestKing 3.0.50 — Feature Coverage Phase 4

## Bonus-Objective Classification

### Panel verdict

- **Runtime and protected-action review:** The correction changes only task
  data mapping and the text selected for QuestKing's existing section header.
  It does not mutate secure attributes, anchors, parents, visibility, or mouse
  state.
- **Cross-version API review:** The supplied Mainline 12.1 tracker reads
  `isInArea`, `isOnMap`, `numObjectives`, `taskName`, and
  `displayAsObjective` from `GetTaskInfo()`. Its ordinary bonus-objective
  module admits an untracked task only when `isInArea` is true and changes the
  module header only when `displayAsObjective` is true. QuestKing now maps the
  same values at the same decision point.
- **Performance and reliability review:** Each task's visibility,
  objective-count, and classification values are consumed from one task-info
  query during population. No event, timer, polling, frame, or SavedVariables
  behavior was added.

Static verdict: the Phase 4 correction passes the deterministic harness.
Final acceptance remains dependent on live-client validation.

### Confirmed finding

The fallback form of `getQuestObjectiveInfoCompat()` returned the raw legacy
`GetQuestObjectiveInfo()` values. Its fourth and fifth values are objective
counts (`numFulfilled` and `numRequired`), but two callers treated the fourth
value as `displayAsObjective`.

In Lua, numeric zero is true in a conditional. A legacy objective returning
`0, 10` could therefore select the normal **Objectives** header even when the
task-level `displayAsObjective` value was false. Completed dummy tasks used the
same incorrect inference path.

### Corrections

- Made the fifth `GetTaskInfo()` result the only task-header classification
  source.
- Applied that classification while the task is admitted to the tracker and
  passed the same query's `numObjectives` value into row population.
- Preserved Blizzard's module-wide header behavior: each refresh begins as
  **Bonus Objectives**, and any displayed non-world task classified with
  `displayAsObjective` changes that shared header to **Objectives**.
- Kept map-visible but out-of-area tasks excluded unless they enter an existing
  explicit watched-world-quest fallback path.
- Stopped interpreting legacy objective-count return positions as
  classification or structured objective metadata.
- Classified completed dummy tasks only from the task-level fifth return.
- Retained the capability guard when `GetTaskInfo()` is unavailable.

### Changed files

- `buttons/bonusobjective.lua`
- `CONSOLIDATED_CHANGELOG.md`
- `FEATURE_COVERAGE_PHASE_4_BONUS_CLASSIFICATION_CHANGELOG.md`

No `.toc` file, XML file, bundled library, asset, or SavedVariables schema was
changed.

### Deterministic validation

The Phase 4 harness verifies:

1. An in-area true bonus objective uses **Bonus Objectives**.
2. An in-area task with `displayAsObjective = true` uses **Objectives**.
3. A mixed task list retains Blizzard's one-header module behavior.
4. A task visible on the map but outside its area is not populated.
5. A completed true bonus objective retains the bonus header.
6. Legacy `numFulfilled` and `numRequired` returns cannot affect the header.
7. A client without the task API creates neither a task row nor its header.
8. Each admitted task uses one population-time `GetTaskInfo()` query.
9. The supplied `QuestObjectiveInfo` structure has no
   `useFullPositionTooltip` field and QuestKing does not read it.

### Live test procedure

1. On Mainline, enter a standard bonus-objective area and confirm its row is
   under **Bonus Objectives**.
2. Enter an area containing a task Blizzard classifies with
   `displayAsObjective` and confirm the module header reads **Objectives**.
3. Open the map while a task is visible there but the character is outside its
   activation area; confirm the task does not appear early in QuestKing.
4. Complete a bonus objective and confirm its completion/reward dummy does not
   switch to the normal header.
5. Exercise an objective with zero current progress and confirm numeric zero
   does not change the header classification.
6. Repeat basic tracker loading on each supported Classic-family client and
   confirm clients without usable task data remain error-free.

### Acceptance result

`PARTIAL — runtime validation required`

### Remaining risks

The supplied sources prove the API mapping and the harness proves QuestKing's
branch decisions, but only a running client can confirm live task-area
transitions, completion-toast timing, localized header presentation, and taint
behavior across every supported flavor.
