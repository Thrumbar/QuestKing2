# Phase 2 — Live Option Propagation

## Panel Verdict

- **Runtime and protected-action expert:** The source-level combat boundary now keeps the last applied secure quest-item geometry and scale/alpha state until the existing post-combat reconciliation runs. Non-protected typography refreshes remain live. The mocked combat test passes; an active WoW client is still required to validate taint and protected-action behavior.
- **Cross-version Blizzard API expert:** The completed-objective rule is now shared by normal quest rows, progress-bar rows, bonus tasks, achievements, and scenario criteria. The changes use existing capability checks and stable frame/FontString operations; no branch-specific API was added speculatively.
- **Performance and reliability expert:** Presentation work is coalesced to one next-frame pass, ordinary appearance changes request a row render without forcing display-data reconstruction, and only the two structural population settings retain full-build semantics.

**Phase verdict:** `PARTIAL — runtime validation required`

## Confirmed Findings

### P2-01 — Existing tracker objects retained creation-time typography and geometry

- **Paths/functions:** `ui/watchbutton.lua` (`WatchButton:RefreshFonts`, lines 240-293; `WatchButton:Render`, lines 966-1150), `ui/tracker.lua` (`Tracker:RefreshTypography`, lines 467-483), `ui/progressbar.lua`, `ui/timerbar.lua`, `buttons/challengetimer.lua`, and `ui/pettracker.lua`.
- **Control flow:** Font face, size, outline, and draw layer were applied while objects were created. Existing pooled rows and attached progress, timer, challenge, and PetTracker text did not receive a complete reapplication path. Row title height and icon geometry also remained tied to creation-time values.
- **Deterministic effect:** Several supported settings required `/reload` or affected only newly allocated objects.
- **Affected branches:** All advertised branches; individual bar types apply only where the corresponding feature exists.
- **Severity:** Medium.
- **Correction:** Added validated dynamic font-layer helpers, a pooled-object typography refresh, and render-time row geometry application.
- **Validation:** `test_phase2_presentation.lua` mutates settings after objects exist and asserts updated face, size, style, layer, width, title height, icon dimensions, and pooled bar typography.

### P2-02 — Tracker border, backdrop, and saved lock state were not fully reversible live

- **Paths/functions:** `ui/tracker.lua` (`CreateButtonArt`, `Tracker:Init`, `Tracker:ApplyTrackerBackground`, and `Tracker:RefreshToggleButtonBorders`), `options_override.lua` (`opt.backdropTable`).
- **Control flow:** Toggle borders were conditionally created, so a border hidden at creation could not be restored. The simple backdrop kept a fixed top inset when title height changed, switching to the advanced backdrop did not explicitly clear the simple backdrop, and initialization overwrote a saved lock whenever dragging was enabled.
- **Deterministic effect:** Border visibility, backdrop layout, or the saved locked state could remain stale until reload or be lost at login.
- **Affected branches:** All advertised branches.
- **Severity:** Medium.
- **Correction:** Always retain the normal/pushed border textures and switch their alpha, derive the marked simple-backdrop inset from live title height, clear the inactive background mode, and preserve a valid saved lock state.
- **Validation:** The presentation harness verifies hide/show reversal, simple-to-advanced transition, dynamic title inset, and lock preservation through initialization and `ADDON_LOADED`.

### P2-03 — Protected item presentation state could diverge during combat

- **Paths/functions:** `ui/tracker.lua` (`Tracker:SetCustomAlpha`, lines 800-820; `Tracker:SetCustomScale`, lines 822-844; `Tracker:ApplyDeferredProtectedPresentation`, lines 1150-1181) and `ui/watchbutton.lua` (`WatchButton:Render`, lines 966-1150).
- **Control flow:** The global item alpha/scale was changed before the combat deferral check, while row geometry and item-anchor settings could be read from newly saved options before a protected item button was legally reconciled.
- **Deterministic effect:** Addon state could advertise new secure-item presentation values while the protected frame still used its prior state.
- **Affected branches:** Branches and rows that expose secure quest-item buttons.
- **Severity:** High for state consistency; live taint impact requires client validation.
- **Correction:** Move global item state changes behind the combat guard and preserve an applied geometry snapshot for item-bearing rows until post-combat reconciliation.
- **Validation:** The presentation harness changes width, line/title height, item side, and item scale under simulated combat, verifies no premature secure-state change, then verifies deterministic reconciliation.

### P2-04 — Completed-objective modes diverged across objective types

- **Paths/functions:** `core/util.lua` (`QuestKing.ShouldShowCompletedObjective`, lines 195-207), `buttons/bonusobjective.lua` (`setButtonToBonusTask`, lines 1015-1131), `buttons/achievement.lua` (`ShouldShowCompletedObjective`, lines 479-490; `AddCriteriaLine`, lines 724-770), and `buttons/scenario.lua` (`QuestKing:UpdateTrackerScenarios`, lines 1228-1299; `QuestKing.SetButtonToScenario`, lines 1301-1624). Normal quest and progress-bar rows already enter the same helper through `buttons/quest.lua`.
- **Control flow:** Bonus tasks did not apply the shared predicate, achievement criteria did not distinguish incomplete from completed achievements, and a completed scenario returned before the `"always"` mode could retain its detail row.
- **Deterministic effect:** `false`, `true`, and `"always"` produced different meanings depending on objective type.
- **Affected branches:** All branches where the relevant content type is available.
- **Severity:** Medium.
- **Correction:** Apply one parent-aware predicate everywhere: `false` never shows completed criteria, `true` shows them only while the parent quest or step is incomplete, and `"always"` shows them before and after parent completion.
- **Validation:** `test_phase2_objectives.lua` exercises the full mode × parent-state matrix for bonus text and progress bars, achievement criteria, and scenario criteria. The shared predicate and the normal quest/progress call site were also inspected directly.

### P2-05 — Appearance changes requested more refresh work than necessary

- **Paths/functions:** `ui/optionspanel.lua` (`ApplySetting`, lines 388-427; presentation queue, lines 305-329).
- **Control flow:** Every managed change immediately applied the full presentation path and also queued tracker work; some non-structural display settings were labeled as display-data refreshes.
- **Deterministic effect:** Rapid slider changes could repeat presentation work and request avoidable data reconstruction.
- **Affected branches:** All advertised branches.
- **Severity:** Low.
- **Correction:** Coalesce presentation changes through one zero-delay callback, request non-structural row refreshes with `forceBuild=false`, and reserve structural rebuilds for population-policy and campaign-continuation changes.
- **Validation:** The presentation harness sends three font-size changes in one frame and observes one presentation pass; all ordinary options requests remain non-structural.

## Corrections

- Added options-panel controls for tracker font, challenge-timer font, outline style, and FontString draw layer.
- Added live typography refresh for tracker controls, used and free row pools, progress bars, timer bars, challenge bars, and PetTracker-owned text.
- Applied row width, title height, line height, and icon size dynamically.
- Made toggle-border visibility reversible and background-mode transitions explicit.
- Preserved saved lock state and made an explicit `Allow dragging` change update lock state immediately.
- Kept protected item geometry and global item scale/alpha synchronized with combat-safe reconciliation.
- Preserved the titlebar's screen position when bottom- or center-anchored trackers change height during minimize and restore.
- Unified completed-objective handling across all relevant paths.
- Coalesced presentation changes and removed unnecessary display-data rebuild requests.

## Changed Files

Production source changes:

- `buttons/achievement.lua`
- `buttons/bonusobjective.lua`
- `buttons/challengetimer.lua`
- `buttons/scenario.lua`
- `core/util.lua`
- `options_override.lua`
- `ui/optionspanel.lua`
- `ui/pettracker.lua`
- `ui/progressbar.lua`
- `ui/timerbar.lua`
- `ui/tracker.lua`
- `ui/watchbutton.lua`

Documentation added:

- `FEATURE_COVERAGE_PHASE_2_LIVE_OPTIONS_CHANGELOG.md`
- `PHASE_2_MINIMIZE_HEADER_POSITION_FIX_CHANGELOG.md`

All six `.toc` files are byte-identical to the Phase 1 input. The addon contains no bundled library directory, and no library was added.

## Automated Validation

- `PASS` — 25 Lua files parsed successfully.
- `PASS` — 2 XML files parsed successfully.
- `PASS` — Phase 1 fallback migration and protected-presentation regression harness.
- `PASS` — Phase 2 live presentation, pooled-object refresh, combat deferral, SavedVariables, and bottom-anchored minimize/restore harness.
- `PASS` — Phase 2 completed-objective matrix across bonus tasks, achievements, and scenarios.
- `PASS` — No file-level scalar copies of the required mutable Phase 2 settings remain.
- `PASS` — Exactly the 12 intended production source files changed before this report was added; TOCs, fonts, textures, XML, and all other files remained byte-identical.

## Test Procedure

1. Back up the installed `QuestKing` folder and SavedVariables, then install the packaged `QuestKing` folder.
2. Enable Lua errors with `/console scriptErrors 1`, reload, and log in with a previously saved locked tracker.
3. On an existing populated tracker, change font face, challenge-timer font, font size, outline, draw layer, line height, row width, item scale/side, background alpha, border visibility, and drag permission. Confirm each change is immediate and the saved lock is preserved until explicitly changed.
4. Recycle rows by tracking/untracking quests and collapsing/expanding sections. Confirm reused rows match current typography and geometry.
5. Test completed-objective modes on an incomplete and completed quest, progress-bar objective, bonus task, achievement, and scenario step:
   - `false`: no completed objective rows;
   - `true`: completed rows only while the parent quest or step is incomplete;
   - `always`: completed rows before and after parent completion.
6. Enter combat with a quest-item row visible. Change layout/item settings and advance an objective. Confirm ordinary text stays current, the secure item remains stable and usable, and no blocked/protected action appears.
7. Leave combat and confirm the deferred item scale, side, anchors, and geometry reconcile without `/reload`, duplicates, or overlap.
8. Select the bottom-right position preset, minimize and restore the tracker, and confirm the titlebar remains at the same screen coordinates in both directions.
9. Repeat on each advertised client family available for runtime testing and retain Lua/taint logs.

## Runtime Validation Items

- Real-client protected-action and taint logging during option changes in combat.
- Pixel/layout inspection with localized and unusually long tracker text.
- Font availability and rendering on every supported client installation.
- Scenario and bonus-objective persistence after Blizzard retires completed criteria from its live API.
- SavedVariables round-trip across logout/login on each client family.

## Acceptance Result

`PARTIAL — runtime validation required`

All source-level and mocked-runtime Phase 2 checks pass. The phase cannot be declared a full runtime pass until the active-client steps above are completed without Lua, blocked-action, or taint errors.

## Remaining Risks

- The test environment cannot reproduce Blizzard's secure execution and taint engine.
- A completed objective can only remain visible when the client API still exposes that objective after completion; QuestKing does not synthesize retired criteria.
- Visual font metrics and third-party PetTracker implementations require live inspection even though all calls are capability-guarded.
