# QuestKing Consolidated Changelog

## Project outcome

QuestKing was advanced from the audited 3.0.24 line through the complete
recommended remediation sequence. The current release candidate is 3.0.50.

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

QuestKing 3.0.50 is a cross-version release candidate. Final release-ready
status requires live-client completion of the matrix recorded in
`RELEASE_READINESS_REPORT.md`.
