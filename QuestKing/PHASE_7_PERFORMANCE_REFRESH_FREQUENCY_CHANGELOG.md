# QuestKing 3.0.39 — Phase 7 Performance and Refresh Frequency

## Refresh coordination

- All tracker refresh requests now converge on one 50 ms event-burst coordinator.
- The coordinator merges force-build, quest-data, achievement-data, post-combat, and profiling flags before one effective refresh.
- The former quest-event sequence of an immediate request, a zero-delay request, and a 150 ms follow-up request has been removed.
- Structural quest events still force population rebuilds. Ordinary objective events refresh live display data against the cached population.
- Combat does not block ordinary text or objective updates. Only protected work remains deferred to the existing post-combat reconciliation path.

## Targeted invalidation and scan reduction

- Quest population, count, duplicate-suppression state, and resolved policy are cached between structural changes.
- Quest objective events reuse that population and refresh only the display snapshots. Classic collapsed-header clients do this inside one guarded expand/restore transaction.
- Collapsed trackers can rebuild population and title counts without reconstructing every objective.
- Achievement list changes use one bounded settle timer and one tracked-ID scan. Criteria, earned, and progress events no longer poll the tracked-ID list.
- Non-achievement content-tracking events are ignored by the achievement refresh path.
- Achievement display rows and criteria containers are cached and reused; unrelated tracker refreshes reuse those snapshots.
- Quest-start item bags are scanned only at initialization, when item popups are enabled, or on `BAG_UPDATE_DELAYED`.
- Popup rendering and automatic-popup suppression use the last bag-event cache instead of rescanning every bag.
- Merged quest-data refreshes revalidate cached item popups without a bag scan, so objective and special-item changes cannot leave stale quest-start rows.
- Secret or unparseable loot payloads defer discovery to the next bag event instead of starting an immediate bag scan.
- AutoComplete retains only its uniquely needed `QUEST_ITEM_UPDATE` subscription. Broad duplicate quest, world-entry, and permanent addon-load refresh paths were removed.
- Mainline quest-data load results refresh only successful IDs in QuestKing's current population and never force an unrelated population rebuild.

## Layout, pooling, and item buttons

- Pooled rows are indexed by row type and stable key, replacing repeated linear searches.
- Stable row anchors and tracker layout metrics are reapplied only when their relationship or dimensions change.
- Reused text lines release stale timer or progress bars while same-objective progress bars retain delta animation and same-timer rows do not re-arm an already-expired timer.
- The separate action-layout event driver was removed; the existing render hook remains the single layout authority.
- Quest-item metadata failures and charge changes are throttled and latched, preventing an every-frame refresh loop.
- Item-button post-click updates now use the central coordinator rather than creating an additional zero-delay timer.
- PetTracker refreshes are gated on runtime availability and world readiness, and post-combat work is requested only when a layout was actually deferred.

## Built-in profiler

Profiling is disabled by default and can be controlled without a reload:

- `/qk perf on`
- `/qk perf off`
- `/qk perf reset`
- `/qk perf status`

The profiler reports refresh requests, coalesced requests, effective refreshes, full and cached population work, all instrumented full quest-log passes, quest-objective/achievement/bag/AutoComplete fallback scans, layout and anchor passes, row acquisition/release, average/last/maximum refresh time, quest-event refresh ratio, and combat quest-event refresh ratio.

QuestKing's own temporary Classic header expansion/restoration events are excluded from quest-event ratios, so the denominator represents external quest-state traffic rather than internal scan mechanics.

## Statically provable before/after results

- Common quest-state handling: multiple same-path requests and timers reduced to one effective refresh per event burst.
- AutoComplete event subscriptions: five registrations reduced to two, with `ADDON_LOADED` removed after QuestKing loads.
- AutoComplete tracked-state polling: removed; only actual full-log lookup fallbacks increment its scan counter.
- Popup bag scans during unrelated tracker refreshes: one or more reduced to zero.
- Achievement criteria events: repeated tracked-ID signature polling reduced to zero tracked-ID scans.
- Pooled keyed lookup: repeated linear search per row reduced to one table lookup per stable key.
- Supertracked-quest reads during quest sorting: repeated comparator reads reduced to one read per sort.
- Missing quest-item metadata: an unbounded every-frame request loop reduced to at most one pending request until reconciliation.

These are source-level guarantees. The built-in profiler is provided for live-client timing and representative combat measurements.

## Changed files

- `buttons/achievement.lua`
- `buttons/popup.lua`
- `buttons/quest.lua`
- `buttons/scenario.lua`
- `core/AutoComplete.lua`
- `core/core.lua`
- `core/events.lua`
- `core/slashcommand.lua`
- `core/supertracking.lua`
- `core/util.lua`
- `ui/actionbuttonlayout.lua`
- `ui/itembutton.lua`
- `ui/optionspanel.lua`
- `ui/pettracker.lua`
- `ui/progressbar.lua`
- `ui/rewardsframe.lua`
- `ui/timerbar.lua`
- `ui/tracker.lua`
- `ui/watchbutton.lua`
- `version.txt`
- `PHASE_7_PERFORMANCE_REFRESH_FREQUENCY_CHANGELOG.md`

## Validation status

Static validation covers Lua 5.1 syntax, all advertised interface snapshots, event and API capability contracts, coalescing behavior, targeted invalidation, protected-work deferral, TOC paths, XML, archive integrity, and packaged-source equality.

Live-client sign-off remains required for representative combat objective profiling and timing measurements on each supported client family.
