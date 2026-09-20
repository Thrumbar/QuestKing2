# QuestKing Consolidated Changelog

**Current release:** 3.0.50  
**Release status:** Release candidate — static validation complete; live-client validation remains required  
**History covered:** 2.0.0 through 3.0.50, including bundled supplemental changelogs

This file replaces the scattered release notes in the supplied QuestKing package. Duplicate entries have been merged, repeated validation text and changed-file inventories have been removed, and superseded fixes are identified instead of being presented as current behavior.

Blizzard UI/API archives are compatibility references only and are not QuestKing release history. This consolidation does not change any `.toc` file, Lua source, XML file, or library.

### History normalization

- Legacy notes reused the `3.0.6`, `3.0.7`, and `3.0.8` labels for supplemental UI changes; those notes are merged into the matching rows below rather than treated as separate releases.
- The standalone Mainline tooltip changelog identifies its correction as `3.0.44`, although the legacy version ledger folded it into the `3.0.45` block. It is separated here for clarity.
- The current archive and every release loader use the exact path `core/AutoComplete.lua`; obsolete lowercase filename references are not retained.
- Historical notes describe a QuestKingSounds merge in `3.0.2`, but the two stated sound modules are absent from the supplied 3.0.50 package and are therefore not advertised as current functionality.

## Current Release — 3.0.50

### Campaign continuation

- Added Blizzard-style campaign continuation rows for available but unaccepted campaign steps, with an option to hide them.
- Uses QuestOffer map-pin supertracking for unaccepted campaign quests while retaining normal focus behavior for accepted quests.
- Added a dedicated right-click **Stop Tracking** action that suppresses only the exact continuation requirement for the current character.
- Clears stale suppression after the requirement is accepted, completed, replaced, or becomes inactive.
- Restored campaign classification through documented quest classification, parent campaign headers, campaign IDs, and guarded campaign APIs.
- Refreshes continuation data from targeted quest-line and major-faction changes without permanent polling.

### Quest-cap accuracy

- Uses Blizzard's accepted standard-quest count for the title numerator and the accepted-quest capacity for the denominator.
- Tracking, untracking, population-mode changes, and local World Quests no longer alter the accepted quest count.
- Retains guarded legacy capacity fallbacks while rejecting broad internal capacities such as `175`.

### Reliability and efficiency

- Removed one duplicate forced refresh from `QUEST_ACCEPTED`.
- Reuses population and local-World-Quest scratch tables to reduce allocations.
- Preserves Lua 5.1 compatibility, protected mouse reconciliation, secure quest-item ownership, and guarded Classic-family behavior.

### Packaging

- Updated the bundled Burning Crusade Classic loader metadata to interface `20506` for the supplied 2.5.6 client family.
- Preserved the same runtime file order and release version across all flavor loaders.

## Condensed Release History

### 3.0.44–3.0.49 — Security and tooltip hardening

| Version | Consolidated changes |
| --- | --- |
| **3.0.49** | Routed pooled-row body and title mouse initialization through the combat-safe setter. Mouse-state caches now update only after a successful protected API call, leaving blocked states for post-combat reconciliation. |
| **3.0.48** | Propagated the real result of Mainline tooltip line rendering through the protected call boundary. Rejected lines no longer count as rendered, preventing empty tooltips. |
| **3.0.47** | Established and verified both tooltip fonts before any text operation. Added packaged Source Sans Pro fallback fonts and keeps unusable rows out of the active layout. |
| **3.0.46** | Replaced Mainline `GameTooltipTemplate` use with a fully QuestKing-owned frame, text lines, textures, anchors, and lifecycle. Retained read-only `C_TooltipInfo` data and the legacy Classic tooltip path. |
| **3.0.45** | Removed protected `SetPropagateMouseClicks` calls from pooled rows and title buttons while preserving normal clicks and the single-open context-menu guard. |
| **3.0.44** | Stopped Mainline item tooltips from using widget-capable population calls. Sanitized `C_TooltipInfo` text is rendered privately without entering Blizzard's `GameTooltip`, comparison-tooltip, or UI widget processing paths. |

### 3.0.36–3.0.43 — Scenarios, population, performance, and packaging

| Version | Consolidated changes |
| --- | --- |
| **3.0.43** | Added explicit Mainline, Classic Era, Burning Crusade Classic, Cataclysm Classic, and Mists Classic release loaders; replaced the build-token version; verified Lua 5.1 syntax, XML, exact-case paths, dependencies, SavedVariables, archive structure, and packaged-source equality. |
| **3.0.42** | Added an anchor-only World Quest Tracker integration beneath QuestKing. World Quest Tracker retains ownership of its panel, data, settings, input, and refresh lifecycle; anchors defer safely during combat and restore when integration is disabled. |
| **3.0.41** | Separated World Quests from bonus objectives, de-duplicated local and watched World Quests, retained title-only rows while data loads, and replaced raw internal tags with a readable `[World]` label. |
| **3.0.40** | Fixed the Phase 7 startup regression that could produce an empty tracker. Added layout generations, population fingerprints, bounded readiness checks, achievement resynchronization, and render-failure recovery that preserves the last healthy layout. |
| **3.0.39** | Added one 50 ms event-burst refresh coordinator, targeted invalidation, cached quest and achievement data, event-driven bag scanning, keyed row reuse, reduced timer and layout churn, and the optional `/qk perf` profiler. |
| **3.0.38** | Added **Automatic**, **Watched Only**, and **All Accepted** population policies. Unified rendered rows, counts, dimming, duplicate suppression, world-quest watches, zero-objective quests, collapsed-header handling, and cross-version failed-quest display. |
| **3.0.37** | Fixed scenario body-hover nil access and normalized scenario, achievement, and bonus-objective hover callbacks to accept either a pooled row or its title child. |
| **3.0.36** | Corrected scenario reward arguments and modern field mapping; hardened bonus steps, weighted progress, completed state, Mists fallbacks, reward animations, proving-ground scores, challenge starts, death counts, and pooled bar reuse. |

### 3.0.29–3.0.35 — PetTracker and display consistency

| Version | Consolidated changes |
| --- | --- |
| **3.0.35** | Matched PetTracker's zone-progress bar width and insets to QuestKing progress bars without changing PetTracker-owned content. |
| **3.0.34** | Added five bounded PetTracker map-readiness retries after login and zoning. Retries use the existing coalesced refresh path; no permanent polling was introduced. |
| **3.0.33** | Prevented `/tm` and `/targetmarker` taint by no longer reassigning Blizzard's global `SlashCmdList` registry when registering QuestKing commands. |
| **3.0.32** | Standardized world-quest, bonus-objective, and scenario counters to the `1/3 Objective` order while preserving already formatted and weighted-progress rows. |
| **3.0.31** | Fixed PetTracker header font initialization, delayed its first scan until world data is ready, retained failed refreshes for retry, and sized the section from PetTracker's actual content height. |
| **3.0.30** | Removed the obsolete duplicate QuestKing PetTracker toggle and made PetTracker's own Zone Tracker setting authoritative. Improved runtime readiness and first-layout ordering. |
| **3.0.29** | Added a dedicated PetTracker-owned tracker instance inside QuestKing without moving or modifying PetTracker's Blizzard Objective Tracker module. Integrated lifecycle, collection, option, zone, and post-combat refreshes. |

### 3.0.19–3.0.28 — Tracking, menus, combat safety, and audit remediation

| Version | Consolidated changes |
| --- | --- |
| **3.0.28** | Separated **Focus** navigation from **Track/Untrack** watch-list membership, corrected Mainline watch APIs and world-quest helpers, added watch-limit checks, and aligned Classic accepted-but-unwatched behavior. |
| **3.0.27** | Rebuilt the right-click menu with Focus, quest details, quest map, Track/Untrack, Share, and Abandon actions. Added guarded cross-version behavior and changed ordinary left-click to open the quest map. |
| **3.0.26** | Removed redundant **Open Quest** and **Cancel** menu rows while retaining normal outside-click and Escape dismissal. |
| **3.0.25** | Added explicit remove, share, and abandon actions with live quest-index resolution, group and eligibility checks, world-quest handling, and Blizzard's confirmation flow. |
| **3.0.24** | Kept non-protected quest text and progress current during combat while narrowly deferring secure attributes, anchors, visibility, and protected mouse state. Added deterministic `PLAYER_REGEN_ENABLED` reconciliation and corrected cross-version field-completion detection and actions. |
| **3.0.23** | Corrected the single **Track Quest** action to control the selected navigation target rather than merely toggling watch-list membership. |
| **3.0.22** | Removed the duplicate active-quest action so the menu exposed one tracking choice. |
| **3.0.21** | Distinguished active navigation from watch-list tracking and confirmed that grouped party members do not generate duplicate menu rows. |
| **3.0.20** | Added quest-ID open-state and debounce guards so one right-click opens one menu. The original mouse-propagation call used in this release was later removed in 3.0.45. |
| **3.0.19** | Applied the ten logic-audit fixes: scenario contracts, combat updates, live settings, completed-objective modes, task classification, right-click support, PetTracker startup state, safe-call failure semantics, AutoComplete event filtering, and loader filename-case alignment. The current package uses `core/AutoComplete.lua`. |

### 3.0.14–3.0.18 — Quest-item stabilization

Several intermediate quest-item implementations were tested and then superseded. The active result retained by the current release is:

- The quest-use button inherits `SecureActionButtonTemplate`.
- Blizzard's secure click handler owns the protected item action.
- QuestKing performs only safe post-click refresh and modified-click chat-link work.
- Secure item attributes use a plain `item:<itemID>` payload and are changed only outside combat.
- Addon-owned direct calls to `UseQuestLogSpecialItem()` are no longer in the active click path.
- Modified chat-link clicks do not also activate the item.

Historical 3.0.14–3.0.16 normal-button and direct-use approaches, along with the first incomplete secure-button attempt, are superseded by this final model.

### 3.0.10–3.0.13 — Options, clicks, and Classic compatibility

| Version | Consolidated changes |
| --- | --- |
| **3.0.13** | Corrected drag enable/lock behavior, saved anchor normalization, preset-relative frame resolution, reset behavior, titlebar guidance, and the missing Tooltip Anchor setting. |
| **3.0.12** | Restored Classic-family quest rows by preserving legacy multi-return quest-log values, correcting field order, and adding a compatible quest-ID lookup alias. |
| **3.0.11** | Restored left-click quest opening, fixed nil click dispatch and pooled-row assumptions, preserved modified clicks, and added safe quest-index resolution. |
| **3.0.10** | Added the native AddOns settings panel with modern Retail registration and Classic fallback, graphical tracker controls, and settings slash commands. |

### 3.0.0–3.0.9 — Modernization foundation

| Version | Consolidated changes |
| --- | --- |
| **3.0.9** | Removed Mainline Objective Tracker method hooks and Blizzard tooltip cleanup helpers from QuestKing execution, further reducing reward-tooltip taint exposure. |
| **3.0.8** | Removed the global TextWithState widget replacement and kept tooltip safety inside QuestKing. The bundled UI update also replaced deprecated slider templates with QuestKing-owned, cross-version slider rendering. |
| **3.0.7** | Restored visual suppression of the legacy Classic/TBC quest watch after Blizzard refreshes. The bundled UI update also reorganized settings into clearer sections without changing saved keys. |
| **3.0.6** | Updated current-client interface metadata and added outer watch-frame border control. The supplemental appearance update added separately saved quest-frame background alpha. |
| **3.0.5** | Added an early TextWithState secret-value guard for map POI tooltips. This invasive approach was later removed by 3.0.8 and replaced by the private Mainline tooltip boundary in 3.0.44–3.0.46. |
| **3.0.4** | Hardened private tooltip reset and sanitized scenario, delve, world-quest, and bonus-objective values before storage, formatting, comparison, or reuse. |
| **3.0.3** | Restored missing safe helper functions, stabilized visual-only Blizzard tracker suppression, and improved private tooltip cleanup. |
| **3.0.2** | Historical notes recorded a QuestKingSounds merge with modern quest APIs and queued state comparison. The stated sound modules are not present in the supplied 3.0.50 package, so this entry is historical only and not a current feature claim. |
| **3.0.1** | Strengthened private tooltip item-state cleanup and reapplied safe visual Blizzard tracker suppression after tracker refreshes. |
| **3.0.0** | Completed the major multi-client modernization: modular compatibility and event handling, saved settings, tracker layout and pooling, classifications, achievements, rewards, scenarios, supertracking, popups, item handling, presentation controls, and taint-safer Blizzard tracker suppression. |

### 2.x — Earlier foundation

| Version | Consolidated changes |
| --- | --- |
| **2.3.0** | Refactored for modern Retail, Cataclysm Classic, and Classic Era APIs; introduced the modular core/UI/buttons layout, SavedVariables, broader quest types, scenarios, achievements, supertracking, slash controls, tracker presentation, popups, containers, and safer compatibility paths. |
| **2.2.4** | Prevented PetTracker's zone tracker from repeatedly reappearing when disabled and added a mode-toggle border option. |
| **2.2.3** | Added the original PetTracker Objective Tracker compatibility workaround; this was later replaced by the dedicated 3.0.29–3.0.35 adapter. |
| **2.2.2** | Updated for patch 6.2 and fixed bonus objectives, reputation-objective formatting, and over-quota objective colors. |
| **2.2.1** | Attempted to correct intermittent multiple-bonus-objective display problems. Later tracker work superseded this implementation. |
| **2.2.0** | Improved superseding objectives, extended bonus reward visibility, fixed reputation text truncation, and corrected reverse-order locale formatting. |
| **2.1.1** | Fixed queued post-combat updates and improved closest-POI supertracking after quest acceptance. |
| **2.1.0** | Added tracker scaling and advanced backgrounds; fixed Blizzard tracker reappearance and duplicate scenario stage overlays. |
| **2.0.0** | Rewrote QuestKing for Warlords of Draenor. |

## Additional Bundled UI Refinements

These changes are present in the supplied 3.0.50 source but were recorded in standalone notes rather than a unique release-number block:

- Long objective text uses true layout insets and indented wrapping, with a compatibility fallback for clients lacking `SetIndentedWordWrap`.
- Bonus-objective right-side counters anchor to their matching objective line instead of the quest title row.
- Background opacity is saved independently from overall tracker alpha and applies live to both advanced and simple backgrounds.
- The watch-frame border can be hidden without removing the background fill.
- Settings are grouped by tracker, appearance, text and rows, item/reward/tooltip behavior, quest behavior, scenario content, and integrations.
- Classic-safe sliders use addon-owned artwork, value labels, mousewheel adjustment, and step snapping.
- Campaign continuation visibility applies live without affecting accepted quests, World Quests, scenarios, achievements, or bonus objectives.

## Superseded Approaches

The following historical approaches are intentionally not active in 3.0.50:

- Direct addon calls to `UseQuestLogSpecialItem()` for quest-use buttons.
- QuestKing XML overriding the secure button's protected click handler.
- `SetPropagateMouseClicks(false)` on pooled tracker rows.
- Global replacement or hooking of Blizzard TextWithState widget setup.
- Mainline QuestKing tooltips created from `GameTooltipTemplate` or populated through widget-capable item-tooltip methods.
- The original PetTracker reparenting workaround and the later non-rendering compatibility stub.
- Treating Focus/supertracking and quest watch-list membership as one state.
- Using Blizzard's broad internal quest bucket size as the accepted quest cap.

## Validation Status

Static validation for the supplied 3.0.50 package reports:

- Lua 5.1 parse: **PASS — 25/25 files**
- XML parse: **PASS — 2/2 files**
- Exact-case loader paths and load order: **PASS**
- Release version across flavor loaders: **PASS — 3.0.50**
- Protected mouse propagation audit: **PASS — no runtime call remains**
- Secure quest-item template, campaign navigation, PetTracker adapter, and World Quest Tracker adapter: **PASS by static inspection**

Compatibility references supplied with this consolidation cover Classic Era `1.15.9.69547`, Burning Crusade Classic `2.5.6.69546`, Mists Classic `5.5.4.69383`, and Mainline `12.1.0.69587`.

Final release sign-off still requires live-client testing of combat lockdown, secure item clicks, tooltip taint, campaign progression, scenarios, Classic population, and optional-addon integrations.

**Final status:** `Release candidate`
