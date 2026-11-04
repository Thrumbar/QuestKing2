# QuestKing Consolidated Changelog

## 3.1.7 — TOC update (2026-11-04)

- Packaged the Classic Objective Display Followup with seven TOCs that report version 3.1.7.
- Added Retail PTR interface 120107 to the generic and Mainline TOCs. Retained Retail interfaces 120105 and 120100.
- Added QuestKing_Forever.toc alongside QuestKing_Camelot.toc. Both use interface 16001.
- Verified the ZIP and all 27 load paths in each manifest against the full follow-up build. In-game loading of this package remains unverified.

| Client source snapshot | Game version | Build | TOC interface |
| --- | --- | ---: | ---: |
| Retail PTR | 12.1.7 | 70668 | 120107 |
| Retail | 12.1.5 | 70688 | 120105 |
| WoW Forever | 1.60.1 | 70532 | 16001 |
| Mists of Pandaria Classic | 5.5.4 | 70631 | 50504 |
| Burning Crusade Classic Anniversary | 2.5.6 | 70577 | 20506 |
| Classic Era | 1.15.9 | 70576 | 11509 |

## 3.1.7 — Classic objective display follow-up (2026-11-03)

- Uses the quest log's completed state when an objective flag or count lags behind. This addresses completed quests that still display an incomplete objective.
- Replaces a stale trailing counter such as (0/1) with the client's localized Complete label when the objective or quest is finished. Preserves valid counters and the existing progress-bar path.
- Changed buttons/quest.lua. In-game validation of the follow-up remains pending.

## 3.1.7 — Classic objective display test build (2026-11-03)

- Shows the localized Complete label when Blizzard marks an objective finished and the numeric counts are missing or still incomplete.
- Preserves normal count formatting for in-progress objectives and avoids duplicating progress text already supplied by the client.
- The follow-up extends this fix to stale counters embedded in the objective text and to completion reported at the quest level.

## 3.1.7 — Baseline review (2026-11-03)

- Recorded user-reported passes on the 3.1.6 Campaign Title Icons baseline for Classic Era build 70576, Burning Crusade Classic build 70577, Mists Classic build 70631, WoW Forever build 70707, and Retail build 70688.
- Verified that the baseline already filters ADDON_LOADED for QuestKing and coalesces tracker updates. The review was documentation-only.

## 3.1.6 — World Quest Tracker hide hotfix (2026-10-19, separate build)

- Extended the hide option to cover detached Blizzard tracker modules and the separate World Quest Tracker addon's screen panel.
- Restores the addon panel according to its own settings, honors combat deferral, and routes quest-watch changes through the existing refresh queue.
- Passed 21 mocked behavior checks. The hotfix shipped separately from Campaign Title Icons, the base used for the 3.1.7 Classic objective builds.

## 3.1.6 — Campaign quest title icons (2026-10-11)

- Replaced repeated [Campaign] prefixes on accepted quest titles and next-campaign hints with a compact icon. Kept the Campaign header and its existing tooltip label.
- Scales and caches the icon with the tracker font and uses a book fallback when the campaign atlas is unavailable.
- Set the version to 3.1.6 in all six TOCs shipped with this build.

## 3.1.1 — Combat row layout (2026-10-09)

- Prevented rows from overlapping when a quest-item button's anchor is protected during combat.
- Keeps the displayed row order and its anchor owners stable while objective text, completion state, and title counts continue updating. Reconciles deferred rows and their PetTracker attachment after combat.
- Guards secret frame-security values on modern clients. Passed 16 mocked regression cases.

## 3.1.1 — Quest-starting item alert hotfix (2026-10-09)

- Clears a retained quest-starting item's alert after the associated quest is accepted, including from bags and with collapsed Classic quest headers.
- Uses native item quest metadata and active quest state, checks the exact quest ID, and rechecks available offers after abandonment. Duplicate copies share one scan entry.
- Refreshes cached starter slots when popup state changes. Passed 20 mocked regression cases.

## 3.1.1 — Classic quest item button hotfix (2026-10-06)

- Restored secure quest-item clicks by selecting mouse-up explicitly while preserving the player's action-bar settings.
- Captures quest-item data before Classic quest headers are collapsed again so the icon and action remain available for unwatched quests shown by Automatic or All Accepted.
- Validates log indices before native lookups, falls back to cached item data, and refreshes item changes on the existing bag event. Passed 19 offline checks, including secure dispatch with both click settings.

## 3.1.1 — Diganostic options submenu (2026-10-06)

- Added a child settings category and a shortcut from the main options page.
- Exposed Start Profiling, Show Status, Reset Counters, and Stop Profiling through the existing /qk perf commands, with a live On/Off indicator.

## 3.1.1 — Forever ObjectiveTracker suppression hotfix (2026-10-04)

- Detects Forever's modern objective tracker by frame capabilities and applies the modern alpha-only suppression path.
- Defers protected visual changes until after combat and keeps the legacy Classic quest-watch suppression path. Passed 12 offline suppression checks.

## 3.1.1 — Phase 8 native abandon confirmation cleanup

- Restored Blizzard's native confirmation dialogs, including quest-item loss warnings, after the unprompted abandonment was traced to another addon.
- Retained the single pending request guard, next-frame popup creation, and selected-quest restoration.

## 3.1.1 — Phase 8 scroll-fix package validation

- Verified six TOCs, 27 load entries per TOC, 25 Lua sources, two XML files, and six supplied client snapshots.
- Carried forward the watch-frame height, clipped scrolling, fixed titlebar, quest-item buttons, and PetTracker layout.

## 3.1.1 — Phase 7 watch-frame height and scrolling

- Added a maximum watch-frame height and renamed the width option to Watch Frame Width.
- Added mouse-wheel scrolling and an overflow scrollbar with a fixed titlebar. Preserves the scroll position through refreshes.
- Places quest rows, secure quest-item buttons, and PetTracker in the same scroll area, with protected layout changes deferred until after combat.

## 3.1.1 — Feature Coverage Phase 7 performance validation

- Verified that tracker update entry points share the 50 ms refresh coordinator and keep the strongest invalidation in a burst.
- Validated cached population, independent quest and achievement invalidation, pooled-row reuse, layout generations, and /qk perf counters in the existing implementation.

## 3.1.1 — Feature Coverage Phase 6 Classic tracker population validation

- Verified Automatic population for accepted Classic quests and watched Retail and Forever quests. Reviewed explicit Watched Only and All Accepted overrides.
- Checked zero-objective rows, temporary Classic header expansion, source de-duplication, completion and failure states, and accepted quest counts.

## 3.1.1 — WoW Forever compatibility

- Added QuestKing_Camelot.toc for Forever interface 16001 and updated Classic Era to 11509. Retained Burning Crusade 20506 and Mists 50504.
- Recorded Retail interfaces 120105 and 120100, retired the Cataclysm manifest, and removed the superseded Retail 120007 and Classic Era 11508 values.
- Validated the quest, scenario, achievement, and objective-tracker contracts against supplied UI source snapshots.

## 3.1.1 — Phase 5 release promotion and documentation consolidation

- Promoted the Phase 5 build from 3.0.50 to 3.1.1 and consolidated packaged release notes into this changelog.
- Fixed Mists Challenge Mode medal-time table handling, instance-map lookup, medal segments, timer classification, and medal-expiry sounds. Keeps the separate Retail Mythic+ timer path.

## 3.0.50 — Phase 4 Retail Area POI taint hotfix

- Removed a duplicate Mainline quest-map opener that rebuilt Blizzard map pins through QuestKing's click handler.
- Routes Mainline quest clicks to details, keeps the guarded Classic map action, and restricts the Mainline map-ID fallback for unaccepted campaign rows.

## 3.0.50 — Campaign continuation compatibility

- Uses QuestOffer map-pin supertracking for unaccepted campaign quests and adds a right-click Stop Tracking action with per-character suppression.
- Restored campaign classification and header fallbacks. Pairs the accepted standard-quest count with its matching capacity.
- Uses targeted quest-line and major-faction refreshes for campaign continuation.

## 3.0.49 — Pooled-row mouse-state hardening

- Routes initial row and title mouse states through the combat-safe setter and records each state after a successful call.

## 3.0.48 — Mainline tooltip rendering result

- Uses the tooltip renderer's actual result so an empty tooltip stays hidden when every candidate line is rejected.

## 3.0.47 — Mainline tooltip font initialization

- Establishes fonts before writing text into pooled tooltip rows and falls back to the packaged Source Sans Pro fonts.

## 3.0.46 — Mainline tooltip ownership

- Moved Mainline tooltips to QuestKing-owned frames and text while preserving sanitized tooltip data, reward icons, scaling, and anchor options.

## 3.0.45 — Protected mouse propagation

- Removed protected click-propagation calls from pooled-row creation and retained normal row and title clicks.

## 3.0.44 — Mainline item tooltip taint correction

- Reads item tooltip text through C_TooltipInfo and renders sanitized lines in the QuestKing tooltip, avoiding Blizzard UI widget registration from that path.

## 3.0.43 — Phase 8 packaging and cross-version validation

- Added explicit client-specific manifests and replaced the build-time version token with 3.0.43.
- Validated loader path capitalization, Lua, XML, dependencies, SavedVariables, and the install archive structure against the supplied sources.

## 3.0.42 — World Quest Tracker attachment

- Added event-driven attachment of World Quest Tracker beneath QuestKing while preserving its panel ownership and native placement fallback.

## 3.0.41 — World Quest classification

- Separated World Quests from bonus objectives and removed raw fallback suffixes such as (109)e from their titles.

## 3.0.40 — Tracker visibility recovery

- Restored the tracker titlebar and quest population after the initial Phase 7 optimization.

## Earlier feature coverage phases

### Phase 7 — Performance and refresh frequency

- Added the 50 ms refresh coordinator, targeted data invalidation, pooled-row reuse, layout generations, startup recovery, and the /qk perf profiler.
- Reduced repeated event handling and full scans.

### Phase 6 — Classic tracker population

- Added Automatic, Watched Only, and All Accepted policies, and unified row population, dimming, title counts, failed states, and duplicate suppression.

### Phase 5 — Scenario rewards and display

- Corrected the SCENARIO_COMPLETED payload to questID, xp, money and mapped modern scenario fields with legacy fallbacks.
- Updated bonus-step, weighted progress, timed content, reward pooling, and hover behavior.

### Phase 4 — Bonus-objective classification

- Classifies task rows using GetTaskInfo()'s displayAsObjective result and reuses the populated task data for visibility and objective counts.

### Phase 3 — Quest right-click and tracking

- Consolidated duplicate tracking actions into one Track Quest or Untrack Quest entry. Uses native supertracking where available and quest-watch fallback on Classic clients.
- Retained quest details, map, sharing, and abandon actions.

### Phase 2 — Live option propagation

- Applies saved layout and display settings to existing rows immediately and unifies completed-objective visibility across quest, scenario, and bonus rows.

### Phase 1 — Protected mouse and combat updates

- Keeps ordinary objective updates active in combat and defers protected mouse, anchor, visibility, and secure-attribute work until combat ends.
