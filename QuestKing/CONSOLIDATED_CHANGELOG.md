# QuestKing Consolidated Changelog

## 3.1.1 hotfix — Classic quest-item clicks

- Corrected the quest-item button's click setting to match its mouse-release
  registration. This fixes a reproduced no-action path when the client's
  action-bar key-down preference is enabled.
- Set the button's own `useOnKeyDown` attribute to false during the existing
  out-of-combat secure-item configuration; action-bar settings stay unchanged.
- Retained secure item use, modifier-click behavior, pooled-button reuse,
  combat deferral, the combat row retention fix, and native abandon dialogs.
- Preserved all TOCs, libraries, XML, assets, dependencies, and SavedVariables.
- Reproduced the input failure with the five supplied Blizzard secure handlers;
  passed 46 targeted checks and compiled all 25 Lua files with Lua 5.1.
- Live retesting on the reported Classic Era 1.15.9 build 70003 remains required.

## 3.1.1 reliability continuation — Combat row retention

- Fixed a reproducible layout collision when an item quest row cannot be
  removed during combat but remaining rows reflow into its occupied slot.
- Preserve the displayed row order while item or protected rows remain;
  append newly requested ordinary rows below the retained slots.
- Keep retained rows out of the reusable pool until combat ends and ignore
  retired row/title clicks and hover dispatch.
- Continue active quest text updates through the existing refresh coordinator;
  restore logical ordering and release retired rows after combat without reload.
- Retained Blizzard's native abandon dialog, scrolling, six TOCs, XML, assets,
  dependencies, and all other production Lua unchanged.
- Verified 25 Lua files with Lua 5.1 and passed 12 targeted simulated behavior
  checks. Status: release candidate; live combat/taint checks remain required.

## 3.1.1 Phase 8 cleanup — Native abandon confirmation restored

- Confirmed that the reported unprompted abandonment originated in another
  addon and removed QuestKing's temporary custom confirmation dialog.
- Restored Blizzard's native `ABANDON_QUEST` and
  `ABANDON_QUEST_WITH_ITEMS` dialogs, including quest-item loss warnings.
- Kept next-frame popup creation and the single pending-request guard so one
  context-menu action cannot dispatch duplicate confirmations.
- Preserved selected-quest restoration and Classic-family fallback behavior.
- Left TOCs, loader order, XML, bundled libraries, SavedVariables, scrolling,
  combat reconciliation, and all unrelated tracker behavior unchanged.

## Project outcome

QuestKing was advanced from the audited 3.0.24 line through the complete
recommended remediation sequence. The current release candidate is 3.1.1.

## 3.1.1 Phase 8 — Scroll-fix package validation

- Used `QuestKing_3.1.1_Phase_7_Watch_Frame_Height_Scroll_Fix.zip` as the
  release base, retaining its maximum-height setting, clipped scroll area,
  fixed titlebar, pooled rows, secure quest-item buttons, and PetTracker layout.
- Checked the complete archive, all six existing loader manifests, 27 exact-case
  load paths, 25 Lua sources, two XML files, and the six newly supplied client
  interface snapshots.
- Updated the release-readiness matrix and corrected the previous note that
  counted 27 Lua files; there are 27 load entries, including the two XML files.
- Retained every production file and `.toc` byte-for-byte. No libraries or
  client-specific metadata were changed.
- Status: **release candidate; live client testing remains required**, with
  scroll overflow, combat reconciliation, and the WoW Forever client as the
  principal runtime checks.

## 3.1.1 Phase 7 — Watch frame height and scrolling

- Added a saved maximum watch-frame height and relabeled the existing row-width
  control as Watch Frame Width. The frame also stops above the screen bottom.
- Added a clipped scroll area, mouse-wheel scrolling, and an overflow scrollbar
  while keeping the titlebar fixed and preserving scroll position on refresh.
- Included quest rows, secure quest-item buttons, and the PetTracker section in
  the same scroll area. Protected scrolling and resizing wait until combat ends.
- Kept all packaged TOCs, XML, fonts, textures, and external libraries unchanged.

## Phase 1 — Protected mouse and combat updates

- Removed the tracker-wide combat refresh stop.
- Continued non-protected text and objective updates during combat.
- Narrowly deferred protected mouse, secure attribute, anchor, and visibility
  changes.
- Added deterministic post-combat reconciliation for pooled rows and quest
  item buttons.

## Phase 2 — Live option propagation

- Applied saved font, row, objective, item-button, background, border, and drag
  settings to existing tracker elements without `/reload`.
- Unified completed-objective display semantics across normal, progress-bar,
  scenario, and bonus-objective rows.

## Phase 3 — Quest right-click and tracking

- Added one context menu per selected quest.
- Consolidated Focus and watch-list controls into one **Track Quest / Untrack
  Quest** action, eliminating the duplicate Active Quest behavior.
- Uses navigation supertracking where supported and an explicit quest-watch
  fallback on Classic-family clients without supertracking.
- Preserved quest details, quest map, sharing, abandon, and duplicate-open
  guards without generating menu rows for party members.

## Phase 4 — Bonus-objective classification

- Used `GetTaskInfo()`'s `displayAsObjective` result for header selection.
- Stopped treating legacy objective-count return values as task
  classification or structured objective metadata.
- Reused each admitted task's population-time `GetTaskInfo()` values for
  visibility, objective count, and header selection.
- Kept true bonus objectives under Bonus Objectives while normal task
  objectives use the normal objective header.

## Phase 4 Retail Area POI taint hotfix

- Removed the duplicate Mainline quest-map opener that bypassed the existing
  compatibility safety rule and rebuilt Blizzard's pooled map pins from a
  QuestKing click path.
- Routes Mainline quest clicks to popup details and omits **Open Quest Map**
  there; Classic-family clients retain their guarded legacy map action.
- Blocks only the Mainline map-ID fallback for campaign continuation rows;
  accepted-quest and QuestOffer supertracking remain unchanged.
- Leaves Blizzard GameTooltip, Area POI, UIWidget, LayoutFrame, TOC, XML, and
  library files untouched.

## Phase 5 — Scenario rewards and display

- Corrected `SCENARIO_COMPLETED` to consume `questID, xp, money`.
- Mapped documented modern scenario fields and guarded legacy fallbacks.
- Corrected bonus-step, weighted-progress, timed-content, reward, hover, and
  pooled-bar behavior.

## Phase 6 — Classic tracker population

- Added Automatic, Watched Only, and All Accepted population policies.
- Kept Classic-family accepted quests visible by default while Mainline remains
  watch-list based.
- Unified row population, title counts, dimming, failed state, and
  duplicate-suppression sources.

## Phase 7 — Performance and refresh frequency

- Added one 50 ms event-burst refresh coordinator.
- Removed duplicate broad event subscriptions and unnecessary full scans.
- Added targeted population, objective, achievement, bag, and item-button
  invalidation.
- Added keyed pooled-row reuse, layout generations, startup population
  recovery, failure containment, and the `/qk perf` profiler.

## Post-Phase 7 corrections

- 3.0.40 restored tracker titlebar and population visibility after the initial
  Phase 7 optimization.
- 3.0.41 separated World Quests from bonus-objective classification and removed
  the raw `(109)e` fallback presentation.
- 3.0.42 attached World Quest Tracker beneath QuestKing without reparenting or
  polling, while preserving World Quest Tracker ownership and native fallback.

## Phase 8 — Packaging and cross-version validation

- Added explicit Mainline, Classic Era, TBC, Cataclysm, and Mists flavor TOCs.
- Replaced the release-builder version placeholder with `3.0.43`.
- Validated Lua 5.1 syntax, XML, exact-case load paths, dependency declarations,
  SavedVariables, archive root structure, ZIP integrity, and packaged-source
  equality.
- Completed a static matrix against all seven supplied Blizzard builds.

## Post-Phase 8 Mainline tooltip taint correction

- Removed Mainline calls that populated QuestKing's private tooltip through
  `SetHyperlink`, `SetItemByID`, or `SetQuestLogSpecialItem`.
- Reads item tooltip text through `C_TooltipInfo` and renders only sanitized
  text lines into the QuestKing-owned tooltip.
- Prevents QuestKing from registering private tooltip widgets with Blizzard's
  global `UIWidgetManager`.
- Leaves Blizzard `GameTooltip`, Area POI tooltips, widget templates, and
  secret dimension calculations unmodified.
- Preserves the legacy population path on Classic-family clients.

## Post-Phase 8 protected mouse-propagation correction

- Removed `SetPropagateMouseClicks(false)` from pooled row and title-button
  creation.
- Preserved normal row/title clicks and the quest-ID context-menu debounce.
- Avoids calling the protected and restricted propagation API during tracker
  population, including bonus-objective row creation.

## Post-Phase 8 Mainline tooltip ownership isolation

- Replaced Mainline `GameTooltipTemplate` use with an ordinary QuestKing-owned
  frame and addon-owned FontStrings.
- Removed QuestKing tooltip creation and cleanup from Blizzard
  `GameTooltip`, `TooltipComparisonManager`, `ShoppingTooltip`, embedded item
  tooltip, and UI widget state.
- Retained read-only `C_TooltipInfo` retrieval and secret-value filtering.
- Preserved QuestKing tooltip text, double-line objectives, reward icons,
  scaling, and Right, Left, Cursor, Top, and Bottom anchors.
- Preserved the legacy `GameTooltipTemplate` path on Classic-family clients.

## Post-Phase 8 Mainline tooltip font initialization

- Established and verified both fonts on every addon-owned Mainline tooltip row
  before the first `FontString:SetText()` call.
- Retained Blizzard tooltip font objects when they provide a usable font and
  otherwise falls back to QuestKing's packaged Source Sans Pro fonts.
- Prevented a failed font assignment from entering the tooltip line pool's
  active layout.
- Preserved the Classic-family tooltip implementation unchanged.

## Post-Phase 8 Mainline tooltip render-result propagation

- Propagated the actual Boolean result from addon-owned `AddLine` and
  `AddDoubleLine` calls through the protected tooltip-data rendering boundary.
- Prevented a successful `pcall` from being misinterpreted as a successfully
  rendered line when font initialization rejected the row.
- Prevented empty item tooltips from being shown after every candidate line
  was safely rejected.
- Preserved the Mainline ownership boundary, secret-value filtering, and the
  Classic-family legacy tooltip path.

## Post-Phase 8 pooled-row creation mouse-state hardening

- Routed initial pooled-row body and title-button mouse states through the
  existing combat-safe setter.
- Removed the two direct `EnableMouse` calls from `WatchButton:Create()`.
- Records each cached mouse state only after the underlying protected API call
  succeeds, leaving blocked creation-time states pending for the existing
  post-combat reconciliation path.
- Preserved click registration, ordinary row/title behavior, stable-parent
  secure item buttons, and all tooltip ownership corrections.

## Post-Phase 8 campaign continuation compatibility

- Corrected unaccepted campaign navigation to use QuestOffer map-pin
  supertracking rather than accepted-quest focus.
- Added continuation right-click Stop Tracking behavior with bounded
  per-character suppression cleanup.
- Restored documented campaign classification and parent-header fallbacks.
- Paired Blizzard's accepted-quest count with the accepted-quest capacity.
- Added targeted quest-line and major-faction invalidation without campaign
  polling, removed one duplicate acceptance refresh, and reused population
  fingerprint scratch tables.

## Current status

QuestKing 3.1.1 is a cross-version release candidate. Final release-ready
status requires live-client completion of the matrix recorded in
`RELEASE_READINESS_REPORT.md`.

## Feature Coverage Phase 5 — Scenario rewards and display

### Panel verdict

- The existing scenario reward payload, modern scenario-field mapping,
  bonus-step routing, weighted progress, reward pooling, and event-driven
  challenge updates remain correct.
- One source-proven Classic-family challenge-timer defect remained: QuestKing
  treated Blizzard's medal-time table as three scalar returns and could route
  Mists challenge content through the Retail Mythic+ presentation.
- The correction is limited to the challenge-timer compatibility path. The
  Phase 4 Retail Area POI taint hotfix remains byte-for-byte unchanged.

### Corrections

- Normalized `C_ChallengeMode.GetChallengeModeMapTimes()` as its documented
  table return while retaining compatibility with historical scalar returns.
- Uses the instance map ID for Classic medal-time queries and falls back to the
  challenge-map ID only when the instance ID is unavailable.
- Selects the modern Mythic+ timer only when the modern keystone API exists;
  Classic-family clients retain their medal-threshold presentation.
- Corrected the capability-free timer-type fallbacks to Blizzard's documented
  values: Challenge Mode `1` and Proving Grounds `2`.
- Corrected each legacy medal segment to begin at the next faster threshold,
  matching Blizzard's reverse medal traversal.
- Corrected the three Mists medal-transition sound-kit keys to Blizzard's
  shipped `MEDALEXPIRE` constants while retaining legacy string fallbacks,
  including Blizzard's previous-medal behavior when a delayed update skips a
  threshold.

### Changed files

- `buttons/challengetimer.lua`
- `CONSOLIDATED_CHANGELOG.md`

No `.toc`, XML, bundled library, font, texture, SavedVariables schema, event,
polling interval, or Phase 4 hotfix file was changed.

### Validation

- Confirmed the table-return contract in the supplied Classic Era 1.15.9,
  Burning Crusade Classic 2.5.6, and Mists Classic 5.5.4 API definitions.
- Confirmed the instance-map lookup and reverse medal traversal against the
  supplied Mists `WorldStateFrame.lua` implementation.
- Confirmed all three medal-transition sound-kit keys against the supplied
  Mists `SoundKitConstants.lua` and covered them with mocked sound assertions.
- Passed mocked modern scenario/event checks, table and scalar medal-time
  routing, Classic-versus-Retail capability selection, map-ID selection, and
  bronze/silver/gold segment-boundary checks.
- Passed full Lua and XML static validation and archive-integrity checks.

### Runtime validation items

1. Complete a Mists Classic challenge run and confirm medal transitions,
   remaining time, sounds, and the no-medal state.
2. Start a Retail Mythic+ run and confirm the keystone timer, level, and death
   count remain unchanged.
3. Complete ordinary and bonus-step scenarios on available clients and confirm
   XP, money, criteria, tooltips, and reward animations.
4. Retest the Retail Area POI hover sequence with taint logging enabled.

### Acceptance result

`PARTIAL — runtime validation required`

### Remaining risk

Static and mocked-runtime checks cannot reproduce Blizzard's live scenario
state, protected execution, animation timing, or taint engine.

## Version 3.1.1 — Phase 5 release promotion

- Promoted the validated Feature Coverage Phase 5 package from 3.0.50 to
  3.1.1.
- Updated only the release version in all six flavor loaders, `version.txt`,
  and current release documentation.
- Preserved every production Lua and XML file byte-for-byte, including the
  Phase 4 Retail Area POI taint hotfix and all Phase 5 scenario and
  challenge-timer corrections.
- Preserved every interface value, loader path and order, bundled asset,
  SavedVariables declaration, event, and polling interval.
- Retains the Phase 5 acceptance result:
  `PARTIAL — runtime validation required`.

## Documentation consolidation

- Removed the superseded per-feature changelogs, phase change notes, refactor
  change notes, and duplicate `version.txt` release ledger from the packaged
  addon.
- `CONSOLIDATED_CHANGELOG.md` is now the only packaged changelog.
- Retained `RELEASE_READINESS_REPORT.md` and
  `SUPPLIED_PATCH_VALIDATION.md` as validation records rather than release
  histories.
- No Lua, XML, TOC, interface, loader-order, bundled-asset, SavedVariables,
  event, polling, Phase 4 hotfix, or Phase 5 behavior changed.

## Version 3.1.1 — WoW Forever compatibility

### Compatibility result

- Added a dedicated `QuestKing_Camelot.toc` for WoW Forever
  `1.60.1.69913` with interface `16001`.
- Confirmed that Forever ships the Mainline-family quest, scenario,
  achievement, content-tracking, and modern Objective Tracker contracts
  already used by QuestKing. Live-client project-ID confirmation remains
  required because that engine assignment is not present in the extracted
  Lua source.
- Preserved all validated Phase 5 production Lua and XML byte-for-byte; no
  Forever-only runtime branch, event, timer, hook, polling loop, or library was
  required.

### Active loader maintenance

- Updated Mainline loader support to interfaces `120105` and `120100`.
- Updated Classic Era loader support to interface `11509`.
- Retained current Classic TBC `20506` and Mists Classic `50504` loaders.
- Removed the superseded `QuestKing_Cata.toc` loader and its base-manifest
  metadata.
- Removed obsolete Mainline `120007` and Classic Era `11508` interface values.
- Retained `QuestKing.toc` as the fallback/source manifest and added
  `Interface-Camelot: 16001` metadata.
- Updated the addon notes in every retained loader to include WoW Forever.

### Changed files

- `QuestKing.toc`
- `QuestKing_Mainline.toc`
- `QuestKing_Camelot.toc` (new)
- `QuestKing_Vanilla.toc`
- `QuestKing_TBC.toc`
- `QuestKing_Mists.toc`
- `QuestKing_Cata.toc` (removed)
- `CONSOLIDATED_CHANGELOG.md`
- `RELEASE_READINESS_REPORT.md`
- `SUPPLIED_PATCH_VALIDATION.md`

### Validation

- Verified interface `16001` and the `camelot` game type against the supplied
  Forever source snapshot.
- Compared the Forever quest, scenario, achievement, and content-tracking API
  definitions with the supplied Retail `12.1.5` source; QuestKing's used
  contracts are compatible and capability-guarded.
- Verified identical load order, dependencies, SavedVariables declarations,
  version metadata, and exact-case paths across all six packaged TOCs.
- Retained the previously validated Lua 5.1 source byte-for-byte and passed
  XML parsing, TOC path, archive-root, and ZIP-integrity checks.

### Runtime validation items

1. Confirm QuestKing appears as version `3.1.1` in the WoW Forever AddOns list
   without an out-of-date warning.
2. Confirm accepted and watched quests populate correctly, including the
   `current/max` quest count.
3. Advance quest objectives in and out of combat and confirm immediate text
   updates without blocked or forbidden actions.
4. Confirm right-click tracking, quest-item buttons, tooltips, minimization,
   dragging, and post-combat reconciliation.
5. Restart the Forever client and confirm account and per-character settings
   persist.

### Acceptance result

`PARTIAL — WoW Forever live-client validation required`

## Feature Coverage Phase 6 — Classic tracker population validation

### Panel verdict

- The runtime reviewer confirmed that the explicit population policy, combat
  refresh path, zero-objective rows, failed-state rendering, and post-combat
  reconciliation are already present in the 3.1.1 Forever base.
- The Blizzard API reviewer confirmed the quest-log and watch-list contracts
  against the supplied Classic Era `1.15.9`, Classic TBC `2.5.6`, Mists
  Classic `5.5.4`, Retail `12.1.x`, and WoW Forever sources.
- The performance reviewer confirmed that the population cache, duplicate
  suppression, and collapsed-header scan transaction do not require another
  event, timer, polling loop, or full-log scan.

No production Lua correction is justified by the supplied source. Phase 6 is
promoted as a validation-only continuation so the already-tested runtime code
is not rewritten or regressed.

### Validated behavior

- **Automatic** shows all accepted quests on recognized Classic-family
  clients and watched quests on Retail and WoW Forever.
- **Watched Only** and **All Accepted** provide explicit cross-client policy
  overrides and apply through the existing options refresh path.
- A client without a usable watch API safely falls back to All Accepted so
  valid quests do not disappear.
- Accepted quests with no objectives retain their title row.
- Collapsed Classic quest-log headers are expanded only for the bounded scan
  and restored afterward; scan-generated quest-log updates are suppressed.
- Watched, world, local-world, prey, and accepted-log sources are de-duplicated
  before rendering.
- Failed and completed quest states use the existing branch-compatible
  normalization and display paths.
- Tracker dimming follows actual visible content. The header numerator retains
  the later project rule of accepted standard quests versus accepted capacity;
  watch toggles therefore do not alter `current/max`.

### Changed files

- `CONSOLIDATED_CHANGELOG.md`
- `RELEASE_READINESS_REPORT.md`
- `SUPPLIED_PATCH_VALIDATION.md`

Production Lua, XML, TOCs, fonts, textures, SavedVariables declarations,
dependencies, loader order, events, timers, polling, and bundled libraries are
byte-for-byte unchanged from the 3.1.1 Forever compatibility release.

### Runtime validation items

1. On Classic Era, Classic TBC, and Mists Classic, verify that Automatic shows
   every accepted quest, including quests under collapsed headers and quests
   with no objectives.
2. On Retail and WoW Forever, verify that Automatic remains watch-list based.
3. Switch between Automatic, Watched Only, and All Accepted and confirm that
   rows, dimming, and saved policy update without `/reload`.
4. Confirm failed and completed quests retain the correct state and color.
5. Confirm the `current/max` numerator changes only when a standard quest is
   accepted, abandoned, or turned in.
6. Record WoW Forever's live `WOW_PROJECT_ID`, which is assigned by the client
   and is not present in the extracted UI source.

### Acceptance result

`PARTIAL — cross-client live validation required`

## Feature Coverage Phase 7 — Performance and refresh-frequency validation

### Panel verdict

- The runtime reviewer confirmed that all public tracker refresh entry points
  converge on the existing 50 ms coordinator and that burst requests merge
  their strongest rebuild, post-combat, quest-data, and achievement-data
  requirements before one refresh is executed.
- The Blizzard API reviewer confirmed that the coordinator adds no
  client-specific event, timer, hook, or API dependency. Classic-family,
  Retail, and WoW Forever branches retain their guarded event paths.
- The performance reviewer confirmed that cached quest populations, targeted
  invalidation, keyed row reuse, layout generations, and the optional
  `/qk perf` counters are already present. Profiling remains disabled unless
  explicitly enabled.

No production Lua correction is justified by the supplied source. Replacing
the established coordinator would add regression risk without a demonstrated
duplicate-refresh defect, so Phase 7 is a validation-only continuation.

### Validated behavior

- `RequestTrackerUpdate()`, `QueueTrackerUpdate()`, and `UpdateTracker()` share
  the same coalesced update path.
- A queued full rebuild cannot be weakened by a later presentation-only
  request in the same burst.
- Quest and achievement invalidations remain independent until a combined
  refresh is required.
- Cached quest rows refresh without a full population scan when population
  structure has not changed.
- Layout anchors update only when the preceding row, anchor class, or layout
  generation changes.
- Combat-time data refreshes remain active while protected presentation work
  is deferred to post-combat reconciliation.
- `/qk perf on|status|reset|off` reports requests, coalescing, rebuilds, scans,
  layout work, row-pool activity, timing, and refresh-per-event ratios.

### Changed files

- `CONSOLIDATED_CHANGELOG.md`
- `RELEASE_READINESS_REPORT.md`
- `SUPPLIED_PATCH_VALIDATION.md`

Production Lua, XML, TOCs, fonts, textures, SavedVariables declarations,
dependencies, loader order, events, timers, polling, and bundled libraries are
byte-for-byte unchanged from Feature Coverage Phase 6.

### Runtime validation items

1. Run `/qk perf on`, advance several quests rapidly, and run `/qk perf status`;
   confirm requests can exceed refreshes and coalescing increases during bursts.
2. Advance objectives in combat and confirm immediate text updates, no blocked
   action, and one clean post-combat reconciliation.
3. Track and untrack achievements while quest events occur; confirm both data
   sets refresh without missing or duplicated rows.
4. Switch between Automatic, Watched Only, and All Accepted; confirm only a
   policy or population change forces a full quest-log rebuild.
5. Enter a scenario, Delve, raid, or timed challenge and confirm smooth timers
   without continuous full tracker rebuilds.
6. Repeat on Classic Era, Classic TBC, Mists Classic, Retail, and WoW Forever,
   then capture the profiler status output.

### Acceptance result

`PARTIAL — cross-client live performance validation required`
