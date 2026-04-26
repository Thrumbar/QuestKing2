# QuestKing Refactor Package

## Package status

This package is the consolidated QuestKing tracker refactor baseline for:
- Retail / Mainline
- Cataclysm Classic
- Classic Era
- Midnight-era testing

It keeps the split-file layout expected by `QuestKing.toc` and preserves the refactored tracker architecture built around:
- `core/`
- `ui/`
- `buttons/`

It also preserves the modernized compatibility work already present across the addon, including `C_QuestLog`, `C_ContentTracking`, and `C_SuperTrack` first-path handling with legacy fallbacks where needed.

## Consolidated structure

- Rebuilt the addon into the folder layout expected by `QuestKing.toc`
- Kept the audited split-file architecture: `core/`, `ui/`, and `buttons/`
- Preserved the refactored tracker/watch/achievement/scenario code paths
- Kept the safer visual-only Blizzard tracker suppression direction
- Kept the conservative PetTracker compatibility approach

## Additional merge fixes already applied

- Fixed obvious runtime bugs in `timerbar.lua` (`timerBarText` / `block` bad references, missing table locals)
- Added missing table locals to `itembutton.lua`
- Added bag API compatibility wrappers in `popup.lua` for `C_Container` vs legacy container APIs
- Hardened `bonusobjective.lua` with task/objective/progress compatibility wrappers and safer early returns when task APIs are unavailable
- Fixed dummy bonus-objective tracker usage to reference `dummyTaskID` instead of an undefined `questID`
- Hardened `scenario.lua` flag checks and stage-complete sound usage
- Hardened `challengetimer.lua` for missing elapsed-timer APIs and modern/legacy sound routing
- Prevented duplicate initialization in `core.lua`
- Made event registration resilient to unsupported events in older/newer clients
- Updated the TOC to a single package layout using comma-delimited interface values for multi-client support

## Latest tooltip and secret-value hardening

This follow-up package update documents the fixes made for the post-delve map-hover failures reported on Retail / Midnight-style clients.

The reported failures occurred after completing and leaving a delve, then hovering:
- world quests
- special assignments
- delve entrances
- suppressed quest-offer pins on the world map

The observed Blizzard failures were all consistent with QuestKing tainting tooltip/widget/layout numeric values before Blizzard performed width, height, or comparison math.

### Follow-up hardening applied

- Added shared secret-safe value handling so QuestKing does not store, compare, or reuse unsafe numeric and string values from Blizzard APIs
- Reworked QuestKing's private tooltip reset flow so embedded item-tooltip, progress bar, widget set, and comparison state are cleared more safely before reuse
- Hardened scenario and delve tracker paths against secret/tainted criteria quantities, weighted progress values, reward quest IDs, widget set IDs, and timer values
- Hardened world quest, special assignment, and bonus objective paths against secret/tainted objective counts, progress percentages, reward values, and line-flash comparison values
- Kept the safer visual-only Blizzard tracker suppression direction already established in prior fixes

## Sound system consolidation

### Summary

`QuestKingSounds` has now been folded into the main `QuestKing` addon package.

This means QuestKing no longer needs a separate sound addon folder for quest audio notifications. The sound functionality now loads as part of the main addon through:
- `core/sounds_options.lua`
- `core/sounds.lua`

### Why this was merged

The standalone sound addon still followed an older narrow event model and older quest-log assumptions. The refactored main addon already uses broader compatibility wrappers, delayed refreshes, and safer state handling, so the sound system was moved into the same architecture.

### What the merge changes

- Moves quest sound logic under the main `QuestKing` namespace
- Loads sound defaults from `core/sounds_options.lua`
- Loads runtime sound behavior from `core/sounds.lua`
- Keeps configurable sounds for:
  - objective progress
  - objective complete
  - quest complete
- Keeps optional quest complete UI message support
- Uses `C_QuestLog` first, with legacy fallback APIs where needed
- Uses queued refresh/state comparison instead of the older one-shot watcher behavior
- Resets or refreshes sound state more safely across:
  - quest accepted
  - quest removed
  - quest turn-in
  - auto-complete
  - player entering world
  - bursty quest log updates

### Operational note

After this merge, the old standalone `QuestKingSounds` addon should be removed or disabled. Keeping both active can cause duplicate sound playback.

## Changelog

## 3.0.5

### Fixed
- Added a targeted Retail/Midnight guard around Blizzard's `UIWidgetTemplateTextWithStateMixin:Setup` path.
- Prevented the reported map POI tooltip crash where Blizzard attempted arithmetic on a secret `textHeight` number while execution was tainted by QuestKing.
- Preserved Blizzard's original setup path first, then falls back only when the original widget setup errors.

### Changed
- Added sanitized fallback handling for TextWithState widget width, height, bottom padding, scale, tooltip location, order index, layout direction, and text setup.
- Kept the guard Mainline-only so Classic Era and Cataclysm Classic remain unaffected.

### Files changed
- `core/util.lua`
- `version.txt`
- `REFRACTOR_NOTES.md`

## 3.0.4

### Fixed
- Hardened QuestKing against the post-delve world-map hover failures where Blizzard widget, tooltip, and layout code received secret number values tainted by `QuestKing`.
- Reduced the chance of arithmetic and comparison failures in Blizzard tooltip/widget code when hovering special assignments, delve entrances, world quests, and suppressed quest-offer pins.
- Reworked QuestKing's private tooltip reset path to clear embedded item-tooltip state, inserted frames, progress bars, status bars, widget sets, comparison state, and related handler state more safely before reuse.
- Prevented QuestKing from reusing unsafe scenario, bonus objective, and world-quest values in tracker lines or hover-tooltip preparation after delve completion.

### Changed
- Added shared secret-safe helper handling for numbers, booleans, and strings so tracker data is sanitized before QuestKing stores, formats, compares, or reuses it.
- Updated `buttons/scenario.lua` to sanitize scenario info, scenario step info, criteria quantities, weighted progress, reward quest IDs, widget set IDs, timer values, and title/description strings.
- Updated `buttons/quest.lua` and `buttons/bonusobjective.lua` to sanitize objective counts, progress percentages, reward values, and `_lastQuant` comparison values used for line flashing and tooltip data.
- Updated `core/util.lua` so QuestKing-owned tooltip preparation remains isolated from Blizzard-managed tooltip substructures as much as possible.

### Files changed
- `core/util.lua`
- `buttons/scenario.lua`
- `buttons/quest.lua`
- `buttons/bonusobjective.lua`

### Notes
- This entry documents the follow-up fix set for the reported post-delve hover errors on world-map quest content.
- The change is primarily a taint-hardening and secret-value sanitization pass rather than a feature addition.

## 3.0.3

### Fixed
- Hardened QuestKing's private tooltip/reward-tooltip flow to reflect the QuestKing tooltip issue follow-up, reducing embedded-item tooltip reuse problems and keeping the safer QuestKing-owned tooltip reset direction documented.
- Restored Blizzard Objective Tracker suppression stability after the tooltip-related fix path by correcting the visual-only suppression implementation used when `opt.disableBlizzard = true`.
- Fixed the follow-up runtime regression in `core/util.lua` where the suppression path attempted to call missing helper functions such as `SafeSetAlpha`, producing `attempt to call global 'SafeSetAlpha' (a nil value)`.
- Restored the missing local helper wrappers used by the Blizzard tracker suppression path before first use so repeated tracker refreshes no longer fail at runtime.

### Changed
- Updated the documented `core/util.lua` suppression flow to keep the safer visual-only Blizzard tracker hiding model while using complete local safe helpers for alpha and mouse-state application.
- Kept the tooltip hardening and Blizzard tracker suppression notes aligned so the documentation reflects both the original tooltip/taint mitigation and the post-fix helper-regression correction.
- Preserved the conservative `options.lua` default of `opt.disableBlizzard = false` while keeping the corrected suppression path available for override-based QuestKing tracker setups.

### Files changed
- `core/util.lua`
- QuestKing private tooltip / reward-tooltip handling paths previously adjusted under the QuestKing tooltip issue follow-up

### Notes
- This entry documents the two reported post-3.0.2 issues together: the QuestKing tooltip issue and the follow-up `SafeSetAlpha` nil-function regression introduced after the recommended Objective Tracker suppression adjustment.

## 3.0.2

### Added
- Merged the standalone `QuestKingSounds` addon into the main `QuestKing` package
- Added `core/sounds_options.lua` for integrated sound defaults
- Added `core/sounds.lua` for integrated quest sound event handling

### Changed
- Sound notifications now use the same compatibility-first architecture as the main QuestKing refactor
- Quest sound logic now prefers `C_QuestLog` APIs with legacy fallbacks
- Sound update handling now uses queued refresh/state comparison instead of relying only on the legacy narrow watch-update flow
- QuestKing now owns quest audio behavior directly through the main addon TOC

### Preserved
- Objective progress sound support
- Objective complete sound support
- Quest complete sound support
- Optional quest-complete message display
- Watched-quest-only behavior as a configurable option

### Notes
- Disable or remove the standalone `QuestKingSounds` addon after updating
- This is a consolidation change; it is intended to reduce addon sprawl and keep quest sound logic aligned with the refactored main tracker flow

## 3.0.1

### Fixed
- Hardened QuestKing's private tooltip reset path to fully clear embedded item-tooltip state, comparison/shopping tooltip state, and stored item metadata before reuse
- Reduced the likelihood of secret-value and embedded-item tooltip taint during world-map reward hovers and quest-item tooltip reuse
- Restored Blizzard Objective Tracker hiding when `opt.disableBlizzard = true` by reapplying safe visual suppression after Blizzard tracker refreshes
- Prevented Blizzard tracker children from visibly reappearing after map, quest, or objective tracker updates
- Kept Blizzard tracker suppression in the safer visual-only path instead of returning to destructive tracker manipulation

### Changed
- Updated `util.lua` so `QuestKing:DisableBlizzard()` works as a repeated visual suppressor rather than a one-shot fade
- Applied suppression recursively across the active Blizzard tracker frame tree using alpha and mouse disabling only
- Standardized private tooltip preparation so QuestKing reuses its own tooltip more safely across quest, reward, and item-hover flows
- Kept `options.lua` on the conservative default of `opt.disableBlizzard = false` while allowing `options_override.lua` to opt into suppression for users who want QuestKing as the visible tracker

## 3.0.0

- Massive modernization pass for QuestKing for Retail, Classic, Cataclysm Classic, and Midnight-era clients
- Reworked the options system with safer override guidance, updated defaults, improved layout controls, alpha/scale support, drag presets, tooltip settings, and a documented color palette
- Rebuilt quest/event compatibility handling with safer `C_QuestLog`-based wrappers and legacy fallbacks
- Fixed auto-watch handling for `QUEST_ACCEPTED` across client variants, including task quests and delayed quest-data retries
- Refactored the tracker core, saved variables, drag handling, layout flow, background handling, and mode/collapse controls
- Expanded slash commands with help, lock, origin, alpha, scale, reset, and resetall
- Improved quest classification for normal quests, campaign quests, world quests, special assignments, prey quests, and task content
- Updated tracked achievement handling for Content Tracking and modern achievement APIs, with safer tooltip behavior
- Improved reward popups/animations and pooled reward frame handling for XP, money, currencies, and item rewards
- Improved scenario, dungeon, raid, and challenge-content tracker handling, including scenario criteria visibility refreshes and better world-entry / completion syncing
- Added improved supertracking and quest watch handling, including closer compatibility with current `C_SuperTrack` and `C_QuestLog` flows
- Added customizable tracker presentation options, including advanced background support, drag / preset positioning, tooltip anchor options, and toggle button border control
- Added quest popup and quest-start item tracking improvements with container compatibility updates, including `C_Container` support and reagent bag awareness
- Added taint-safer compatibility behavior by keeping Blizzard tracker suppression visual-only and replacing the old PetTracker reparent hack with a conservative opt-in compatibility stub
- Improved pooled UI components for watch buttons, item buttons, timer bars, progress bars, reward displays, and popup rendering
- Raised the quest special item button above its owning watch entry and reapplied z-order during pooled reuse
- Restored completed-quest click handling for true auto-complete quests while preventing false complete popups for normal turn-in quests
- Improved bonus objective and achievement hover tooltips so they include objective/progress information more consistently

## Practical note

This package remains a strong merged baseline for Retail, Cataclysm Classic, Classic Era, and Midnight-era testing. Midnight-specific secure and taint restrictions are still partly dependent on runtime Blizzard behavior, so in-game validation is still recommended after each protected-UI or tooltip-related change.

## 3.0.6 - Current Warcraft TOC metadata update

### Changed

- Updated `QuestKing.toc` from:
  - `## Interface: 120001, 40400, 11503`
- Updated `QuestKing.toc` to:
  - `## Interface: 120005, 120001, 50503, 40402, 20505, 11508`

### Notes

- This is a metadata-only update.
- No Lua execution behavior, frame code, secure hooks, tooltip guards, or ObjectiveTracker suppression logic was changed.
