# QuestKing Click-to-Turn-In Tracker Fix

## Fixed
- Quest tracker rows now recognize click-to-turn-in quests using the full autocomplete detection path:
  - `C_QuestLog.IsAutoComplete(questID)`
  - legacy `GetQuestLogIsAutoComplete(questLogIndex)`
  - `C_QuestLog.GetInfo(questLogIndex).isAutoComplete`
  - active Blizzard auto quest popup entries with popup type `COMPLETE`
- Completed clickable quests now show `Click to turn in` instead of falling through to the generic ready turn-in text.
- Completed clickable quests keep the ready-check icon marker in the tracker title.
- Left-clicking a completed clickable quest now calls QuestKing's safer completion opener first, then falls back to the direct `ShowQuestComplete` compatibility path.
- The `QUEST_AUTOCOMPLETE` event now accepts ReadyForTurnIn-only autocomplete payloads so Blizzard's native auto quest popup can still be added when the older autocomplete boolean is false.
- Kept the previous `popup.lua` reserved-key syntax fix: `and = true` remains corrected to `["and"] = true`.
- Added lowercase `core/autocomplete.lua` in the patch bundle so it matches the TOC path exactly.

## Files changed
- `QuestKing/buttons/quest.lua`
- `QuestKing/core/events.lua`
- `QuestKing/buttons/popup.lua`
- `QuestKing/core/autocomplete.lua`
- `QuestKing/QuestKing.toc` included for path context only.

# QuestKing Config / Tracker Drag Fix

## Changed

- Fixed the **Allow QuestKing tracker dragging** AddOns setting so enabling it also unlocks the tracker drag state.
- Fixed the tracker drag gate so both conditions are now required before dragging works:
  - `QuestKing.options.allowDrag == true`
  - `QuestKingDB.dragLocked == false`
- Fixed disabling tracker dragging so it forces the tracker locked and moves it back to the configured preset position.
- Fixed reset defaults so the drag lock state is restored consistently from the default `allowDrag` value.
- Added safe anchor normalization for saved tracker points and preset points.
- Resolved preset relative frame names such as `"UIParent"` to the actual global frame before calling `SetPoint`.
- Updated the unlocked titlebar hint to say `Unlocked - Drag titlebar`, matching the actual drag target.
- Added the missing `Tooltip Anchor` AddOns setting. The key was already managed by the options system but had no visible control in the panel.

## Files changed

- `QuestKing/ui/optionspanel.lua`
- `QuestKing/ui/tracker.lua`

## Install

Copy the `QuestKing/ui/optionspanel.lua` and `QuestKing/ui/tracker.lua` files over the matching files in the addon.

## Config Drag Fix v2

### Fixed
- Enabling **Allow QuestKing tracker dragging** no longer calls `InitDrag()` and no longer re-anchors the tracker.
- The tracker now keeps its exact current screen position when the option is checked or unchecked.
- `allowDrag` is now authoritative during saved-option load, so a stale `QuestKingDB.dragLocked = true` value cannot keep the tracker locked while the option is enabled.
- Dragging is now bound directly to the titlebar frame, matching the UI text and avoiding reliance on the parent frame receiving drag events through a child titlebar.
- The current tracker anchor is captured before changing lock state, so the next reload restores the same position instead of falling back to an older/default drag point.

### Notes
- Dragging is intentionally limited to the tracker titlebar. Quest rows remain clickable and are not used as drag handles.


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

## Native AddOns settings UI integration

### Summary

QuestKing now includes a native Blizzard AddOns settings panel through:
- `ui/optionspanel.lua`

The panel exposes the existing QuestKing options in the default Blizzard settings UI instead of requiring users to edit the options files directly.

### What the panel adds

- Registers a QuestKing category under Blizzard's AddOns settings list on modern clients.
- Falls back to the legacy Interface Options category path when the modern `Settings` API is not available.
- Uses existing QuestKing option storage instead of introducing a new saved-variable format.
- Keeps the options UI dependency-free; Ace3 is not required.
- Adds `/qk options`, `/qk config`, `/qk settings`, `/qkoptions`, and `/questkingoptions` access paths.

### UI controls added

- Blizzard Objective Tracker visibility
- QuestKing tracker dragging behavior
- Tracker scale
- Tracker alpha
- Item-start quest popups
- Completed objective display mode
- Superseded objective hiding
- Scenario, dungeon, and raid objective behavior
- Tracker button width
- Line height
- Title height
- Font size
- Quest item button scale
- Item and reward anchor side
- Advanced background
- Simple backdrop
- PetTracker compatibility helpers

### Compatibility notes

- Retail / Midnight clients use the modern `Settings.RegisterCanvasLayoutCategory` and `Settings.RegisterAddOnCategory` path when available.
- Classic-family clients fall back to `InterfaceOptions_AddCategory` when the modern settings system is unavailable.
- The options panel avoids protected-frame manipulation and only writes QuestKing-owned options, then requests a QuestKing tracker refresh.
- The panel is loaded after `options_override.lua` so override defaults are visible in the GUI at startup.

## Classic watch window compatibility fix

### Summary

QuestKing now fixes the Classic-family watch window path where quests did not appear because the legacy quest-log fallback lost the quest ID returned by `GetQuestLogTitle()`.

Classic Era and Classic progression clients can still rely on the legacy quest-log API path. That path returns the quest ID as the 8th return value from `GetQuestLogTitle(questLogIndex)`. Several QuestKing safe-call wrappers only preserved the first few values from `pcall()`, so the quest ID was discarded before the tracker could build quest rows.

### What changed

- Expanded QuestKing safe-call wrappers so legacy multi-return Blizzard APIs keep enough values for Classic quest-log handling.
- Added `Compat.GetQuestIDForLogIndex()` as a compatibility alias for callers that use the `ForLogIndex` name.
- Fixed the legacy `GetQuestLogTitle()` return-order assignment used by `SafeGetQuestInfoByIndex()`.
- Preserved normalized `isCollapsed` and `isComplete` values from Classic quest-log rows.
- Kept Retail / Midnight on the existing `C_QuestLog.GetInfo()` first path.

### Files changed

- `core/compatibility.lua`
- `core/events.lua`
- `core/supertracking.lua`
- `core/util.lua`
- `buttons/quest.lua`

### Operational note

This update targets the confirmed Classic watch-window blocker. It does not add speculative behavior, helper-addon requirements, or protected-frame changes.

## Quest watch click handling and pooled-button hardening

### Summary

QuestKing now restores expected quest-watch interaction behavior from the custom tracker.

Left-clicking a quest in the QuestKing watch tracker now opens the selected quest instead of failing silently, opening the wrong behavior path, or showing only non-open options. The fix applies to both the quest title row and the quest objective/body area.

### What changed

- Added shared quest-watch click handling for title and body clicks.
- Restored left-click quest opening from the QuestKing tracker.
- Added auto-complete quest handling so completed auto-complete quests attempt to open the completion dialog before falling back to quest details.
- Preserved right-click behavior by routing to QuestKing's existing quest menu when available.
- Added a super-track fallback when no QuestKing quest menu handler is registered.
- Fixed the mouse-handler dispatch path so the watch button frame is not treated as the handler table.
- Replaced bad/missing quest ID fallback lookup with the compatibility-safe quest log index resolver.
- Hardened pooled watch button handling so missing `EnableMouse`, `RegisterForClicks`, title objects, or pooled button factories do not crash tracker rebuilds.

### Files changed

- `buttons/quest.lua`

### Operational note

This update focuses on tracker interaction and runtime hardening. No saved-variable format changes are required.

## Changelog

## 3.0.12

### Fixed
- Fixed Classic-family quest rows not appearing in the QuestKing watch window when the addon had to use legacy quest-log fallbacks.
- Fixed local safe-call wrappers that discarded later `GetQuestLogTitle()` return values, including the Classic quest ID return value.
- Added the missing `Compat.GetQuestIDForLogIndex()` alias used by event-side fallback code.
- Fixed legacy `GetQuestLogTitle()` field assignment in `SafeGetQuestInfoByIndex()` so `isHeader`, `isCollapsed`, `isComplete`, `frequency`, `questID`, and `startEvent` are preserved in the correct order.

### Changed
- Expanded safe-call return preservation in `core/compatibility.lua`, `core/events.lua`, `core/supertracking.lua`, and `buttons/quest.lua` for legacy multi-return Blizzard APIs.
- Kept Retail / Midnight on the existing `C_QuestLog.GetInfo()` path while correcting Classic fallback behavior.

### Compatibility
- Fixes Classic Era, TBC Classic, Cataclysm Classic, and Mists Classic watch-window quest ID resolution.
- Keeps Lua 5.1 compatibility.
- Does not change saved-variable format or require helper addon code.

### Files changed
- `core/compatibility.lua`
- `core/events.lua`
- `core/supertracking.lua`
- `core/util.lua`
- `buttons/quest.lua`

## 3.0.11

### Fixed
- Restored left-click quest opening from the QuestKing watch tracker.
- Fixed quest title clicks and quest body/objective clicks so both route through the same quest-open behavior.
- Fixed completed auto-complete quests so left-click attempts to open the completion dialog before falling back to quest details or the quest log.
- Fixed the mouse-handler dispatch bug that caused `attempt to call a nil value` when clicking tracked quests.
- Fixed repeated tracker rebuild errors caused by pooled watch rows that did not expose expected frame methods.
- Hardened `EnableMouse`, `RegisterForClicks`, header title access, and watch button factory lookups with defensive guards.
- Fixed quest ID fallback resolution by using the compatibility-safe quest log index lookup path.

### Changed
- Right-click now preserves existing QuestKing quest menu behavior when a menu handler is available.
- Right-click falls back to super-tracking the quest when no QuestKing quest menu handler is registered.
- Quest opening now follows a safer fallback order:
  1. Shift-click inserts a quest link into chat when possible.
  2. Completed auto-complete quests attempt to open completion.
  3. QuestKing compatibility quest detail opening is attempted.
  4. Blizzard quest detail/map fallback is attempted.
  5. Classic quest log fallback is attempted.

### Compatibility
- Keeps Lua 5.1 compatibility.
- Keeps Retail / Midnight, Classic Era, and Classic progression compatibility by checking frame methods and Blizzard quest APIs before use.
- Avoids protected-frame manipulation and only touches QuestKing-owned watch rows.

### Files changed
- `buttons/quest.lua`

## 3.0.10

### Added
- Added `ui/optionspanel.lua` as a native Blizzard AddOns settings panel for QuestKing.
- Added modern Settings API registration for Retail / Midnight clients with a Classic-safe `InterfaceOptions_AddCategory` fallback.
- Added settings controls for tracker visibility, dragging, scale, alpha, quest popup behavior, objective display, sizing, font layout, item button scale, reward anchoring, backgrounds, and PetTracker compatibility helpers.
- Added `/qk options`, `/qk config`, `/qk settings`, `/qkoptions`, and `/questkingoptions` access paths.

### Changed
- Updated `QuestKing.toc` to load `ui/optionspanel.lua` after `options_override.lua` so the panel reads the active configured defaults.
- Updated `core/slashcommand.lua` to route settings slash commands into the new options panel when available.
- Documented the new UI panel in the refactor notes, bundle notes, and version files.

### Compatibility
- Keeps the settings UI dependency-free and Lua 5.1 compatible.
- Keeps Retail / Midnight, MoP Classic, Cataclysm Classic, TBC Anniversary, and Classic Era compatibility by checking Blizzard settings APIs before use.
- Avoids new secure hooks or protected-frame manipulation; the panel only updates QuestKing-owned options and requests QuestKing-owned refresh behavior.

### Files changed
- `QuestKing.toc`
- `core/slashcommand.lua`
- `ui/optionspanel.lua`
- `REFRACTOR_BUNDLE_NOTES.md`
- `REFRACTOR_NOTES.md`
- `version.txt`
- `version.new`

## 3.0.9

### Fixed
- Further isolated QuestKing from Blizzard's `GameTooltip` world-map reward path after the follow-up `GameTooltipMoneyFrame1` / `EmbeddedItemTooltip_UpdateSize` secret-number errors.
- Removed Mainline/Retail secure hooks on Blizzard Objective Tracker `Show`, update functions, and `ObjectiveTrackerManager` methods.
- Stopped QuestKing's private tooltip reset from calling Blizzard `GameTooltip_Clear*` and `EmbeddedItemTooltip_*` helpers from addon code.

### Changed
- Retail / Midnight Blizzard tracker suppression now refreshes from QuestKing-owned events instead of Blizzard-owned hook callbacks.
- Modern managed tracker frames receive only a single alpha write; Classic-family frames keep the legacy visual hard-hide path.
- QuestKingTooltip cleanup now hides QuestKing-owned inserted money/item state locally without invoking Blizzard tooltip helper pipelines.

### Files changed
- `core/util.lua`
- `version.txt`
- `version.new`
- `REFRACTOR_NOTES.md`


## 3.0.8

### Fixed
- Removed the global `UIWidgetTemplateTextWithStateMixin.Setup` replacement added in 3.0.5.
- Stopped QuestKing from tainting Blizzard's default `GameTooltip` world-map hover flow before `EmbeddedItemTooltip_UpdateSize` runs.
- Fixes the reported world-quest reward hover error where Blizzard's embedded reward tooltip attempted arithmetic on secret width/height values while execution was tainted by QuestKing.

### Changed
- `QuestKing.InstallTextWithStateWidgetGuard` is now a no-op compatibility stub.
- QuestKing continues to sanitize values and reset state only for QuestKing-owned tooltip and tracker UI paths.
- Blizzard's `GameTooltip`, UIWidget setup mixins, and embedded item-tooltip sizing functions are no longer monkey-patched by QuestKing.

### Files changed
- `core/util.lua`
- `version.txt`
- `REFRACTOR_NOTES.md`


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
