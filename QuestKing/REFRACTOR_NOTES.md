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

This package is a strong merged baseline for Retail, Cataclysm Classic, Classic Era, and Midnight-era testing. Midnight-specific secure and taint restrictions are still partly dependent on runtime Blizzard behavior, so in-game validation is still recommended after each protected-UI change.


### Follow-up fixes merged on top of the modernization baseline
- Raised the quest special item button above its owning watch entry and reapplied its z-order whenever pooled buttons are acquired or reassigned.
- Restored completed-quest click handling so true auto-complete quests can still open the completion flow without mislabeling normal turn-in quests.
- Prevented false positive complete popups for non-auto-complete quests.
- Improved bonus objective and achievement hover tooltips so they show objective/progress information before rewards-only content.
- Standardized tooltip presentation across quest-adjacent tracker entries.

## 2.3.0
- Refactored QuestKing for modern Blizzard API usage with Retail, Cataclysm Classic, and Classic Era compatible code paths.
- Updated TOC metadata and addon structure for the new modular layout (core, ui, and buttons files) with SavedVariables and per-character settings.
- Reworked quest tracking to support normal quests, campaign quests, watched world quests, special assignments, prey quests, and task / bonus objective quests with modern API fallbacks.
- Added validated scenario, dungeon, raid, and challenge-content tracker handling, including scenario criteria visibility refreshes and better world-entry / completion syncing.
- Added tracked achievement support using modern content-tracking and achievement APIs, with legacy fallbacks where available.
- Added improved supertracking and quest watch handling, including closer compatibility with current `C_SuperTrack` and `C_QuestLog` flows.
- Added slash command controls for mode switching, tracker alpha, tracker scale, drag locking, drag origin reset, and saved-variable resets.
- Added customizable tracker presentation options, including advanced background support, drag/preset positioning, tooltip anchor options, and toggle button border control.
- Added quest popup and quest-start item tracking improvements with container compatibility updates, including `C_Container` support and reagent bag awareness.
- Added taint-safer compatibility behavior by keeping Blizzard tracker suppression visual-only and replacing the old PetTracker reparent hack with a conservative opt-in compatibility stub.
- Improved pooled UI components for watch buttons, item buttons, timer bars, progress bars, reward displays, and popup rendering.

## 2.2.4
- Fixed a bug with PetTracker integration where the pet zone tracker would frequently reappear even when disabled.
- Added an option to hide the border of the mode toggle buttons (`opt.hideToggleButtonBorder`, false by default).

## 2.2.3
- Added a very ugly hack that enables compatibility with PetTracker's objective tracker panel.

## 2.2.2
- Increased TOC for patch 6.2.
- Fixed bug with bonus objective display (caused by 6.2 patch).
- Fixed bug related to new text format for some reputation objectives (caused by 6.2 patch).
- Fixed display color for objectives whose quota is exceeded rather than merely met.

## 2.2.1
- Attempted to fix a bug which happened sometimes when multiple bonus objectives were displayed at the same time.

## 2.2.0
- Improved how superseding objectives are displayed (e.g. Garrison invasion point objectives). If you want the old behavior (all objectives always visible), then set `opt.hideSupersedingObjectives` to false.
- Slightly increased the time bonus rewards are displayed from 7 to 10 seconds.
- Fixed how reputation-style objectives are displayed to avoid truncation.
- Fixed some issues in locales that show objective description/count in reverse order (e.g. `ruRU`).

## 2.1.1
- Fixed an error that happened when the tracker queued an update for after combat.
- Changed supertracking to always check for the closest POI when accepting a quest.

## 2.1.0
- Added `/qk scale` to set the tracker scale.
- Added an advanced background option for better looking backgrounds.
- Fixed the default objective tracker re-appearing after visiting the barber.
- Fixed the scenario stage objective overlay appearing twice when zoning into a scenario or dungeon. (Workaround for a Blizzard bug with `LevelUpDisplay`.)
- Cleaned up some code.

## 2.0.0
- Massive re-write for WoD.

## What was consolidated
- Rebuilt the addon into the folder layout expected by `QuestKing.toc`.
- Kept the audited split-file architecture: `core/`, `ui/`, and `buttons/`.
- Preserved the modernized C_QuestLog/C_ContentTracking/C_SuperTrack-based work already present in the audited files.

## Additional merge fixes applied
- Fixed obvious runtime bugs in `timerbar.lua` (`timerBarText` / `block` bad references, missing table locals).
- Added missing table locals to `itembutton.lua`.
- Added bag API compatibility wrappers in `popup.lua` for `C_Container` vs legacy container APIs.
- Hardened `bonusobjective.lua` with task/objective/progress compatibility wrappers and safer early returns when task APIs are unavailable.
- Fixed dummy bonus-objective tracker usage to reference `dummyTaskID` instead of an undefined `questID`.
- Hardened `scenario.lua` flag checks and stage-complete sound usage.
- Hardened `challengetimer.lua` for missing elapsed-timer APIs and modern/legacy sound routing.
- Prevented duplicate initialization in `core.lua`.
- Made event registration resilient to unsupported events in older/newer clients.
- Updated the TOC to a single package layout using comma-delimited interface values for multi-client support.

## Practical note
This package is a strong merged baseline for Retail, Cataclysm Classic, and Classic Era style clients. Midnight-specific secure/taint restrictions are still partly dependent on runtime Blizzard behavior, so further branch testing in-game is still recommended.

# Changelog

## Unreleased

### fix(taint): harden QuestKing tracker integrations and safely suppress Blizzard Objective Tracker

This consolidated patch resolves the World Map protected-action taint tied to QuestKing and preserves suppression of Blizzard's Objective Tracker without using the older high-risk frame control approach.

#### Problem addressed

QuestKing was triggering a protected UI failure while Blizzard refreshed World Map quest pins:

```text
AddOn 'QuestKing' tried to call the protected function 'Button:SetPassThroughButtons()'
```

The most likely taint sources in the addon were:

- destructive suppression of Blizzard's Objective Tracker
- reparenting and reanchoring of third-party objective UI into `QuestKing.Tracker`
- dynamic handling of secure quest item buttons in a way that increased taint risk

#### Consolidated changes

##### `options.lua`
- kept the base default:
  - `opt.disableBlizzard = false`

##### `options_override.lua`
- updated override behavior as part of the final consolidated patch:
  - enables Blizzard tracker suppression through the safer visual-suppression path
- no longer relies on the older destructive suppression flow

##### `util.lua`
- rewrote `QuestKing:DisableBlizzard()` into a taint-safer implementation
- removed the older destructive suppression behavior:
  - no `UnregisterAllEvents()` on Blizzard tracker frames
  - no hard `:Hide()` loop on Blizzard-managed tracker frames
  - no hook that forces `ObjectiveTrackerFrame:Show()` to immediately hide again
- replaced it with safe visual suppression:
  - applies alpha-based hiding to Blizzard Objective Tracker UI
  - disables mouse interaction on the Blizzard tracker where applicable
  - reapplies the visual suppression after Blizzard updates, instead of forcing frame state changes
- preserved unrelated utility behavior

##### `compatibility.lua`
- removed taint-prone PetTracker objective integration behavior
- disabled reparenting/reanchoring of PetTracker objective UI into `QuestKing.Tracker`
- replaced live-objective manipulation with safe compatibility behavior that does not alter external tracker ownership

##### `itembutton.lua`
- stabilized secure quest item button handling
- reduced risky dynamic parenting and frame churn around secure buttons
- preserved secure quest item usage support
- kept QuestKing's private tooltip usage for quest-item hover behavior

#### Final behavior

- reduces or removes the taint path that led to the blocked `SetPassThroughButtons()` call
- keeps Blizzard's Objective Tracker from visibly overlapping QuestKing
- avoids the previous high-risk suppression method that was more likely to taint Blizzard-managed UI
- leaves QuestKing as the visible custom tracker while Blizzard's tracker is visually suppressed in a safer way

#### Files changed

- `options.lua`
- `options_override.lua`
- `compatibility.lua`
- `util.lua`
- `itembutton.lua`

#### Suggested squashed commit message

```git
fix(taint): harden QuestKing tracker integrations and safely suppress Blizzard objective tracker
```

#### Notes

This is a behavioral compatibility and taint-hardening patch, not just a cosmetic UI cleanup.

If a follow-up taint still appears after this consolidated patch, the next area to audit should be the remaining secure button lifecycle and any late map/tracker interaction outside these files.

3.0.0
- Massive modernization pass for QuestKing for Retail, Classic, Cataclysm Classic, and Midnight-era clients.
- Reworked the options system with safer override guidance, updated defaults, improved layout controls, alpha/scale support, drag presets, tooltip settings, and a documented color palette.
- Rebuilt quest/event compatibility handling with safer C_QuestLog-based wrappers and legacy fallbacks.
- Fixed auto-watch handling for QUEST_ACCEPTED across client variants, including task quests and delayed quest-data retries.
- Refactored the tracker core, saved variables, drag handling, layout flow, background handling, and mode/collapse controls.
- Expanded slash commands with help, lock, origin, alpha, scale, reset, and resetall.
- Improved quest classification for normal quests, campaign quests, world quests, special assignments, prey quests, and task content.
- Updated tracked achievement handling for Content Tracking and modern achievement APIs, with safer tooltip behavior.
- Improved reward popups/animations and pooled reward frame handling for XP, money, currencies, and item rewards.
- Improved scenario, proving grounds, and timer-bar handling.
- Replaced the old PetTracker integration hack with a conservative taint-safe compatibility path.
- General cleanup for safer fallbacks, lower maintenance cost, and better cross-version stability.

### Fixed
- Restored Blizzard tracker hiding when QuestKing is active and `opt.disableBlizzard = true`.
- Reworked tracker suppression into a safer hybrid model:
  - Retail `ObjectiveTrackerFrame` now uses visual suppression only.
  - Classic-family tracker frames still use stronger hide/reparent behavior.
- Removed direct shared `GameTooltip:Hide()` calls from `watchbutton.lua` and
  `itembutton.lua`.

### Changed
- `util.lua` now uses a hybrid tracker hider with:
  - original state capture
  - `OnShow` re-hide hooks
  - combat-lockdown deferral
  - separate Retail vs. legacy tracker handling

### Compatibility
- Safer behavior for Retail/Mainline widget and tooltip paths.
- Preserves Classic/Anniversary/MoP Classic style tracker hiding behavior.

Add a fourth tracker display mode for raid objectives and extend the
existing tracker mode system from Q/A/C to Q/R/A/C.

Rework scenario handling so scenario-backed raid content can be labeled
and filtered as raid content, while keeping the tracker lightweight and
compatible with the existing QuestKing watch window architecture.

Update core tracker routing, scenario criteria visibility handling,
watch button line plumbing, and slash commands to support direct mode
switching and cleaner objective separation.

## Commit Message

**fix(tracker): restore click-to-complete flow for completed quests**

Restore the completed quest turn-in flow in the custom QuestKing watch.

Completed tracked quests now always render a visible completion action line,
and left-clicking a completed quest now opens the Blizzard completion UI
before falling back to normal navigation behavior.

Also update popup quest handling to use a quest-safe resolution path for
quest offers and quest completions, and replace the generic completed popup
label with explicit action text.

### Changed

- fix popup quest offer/completion handling in `popup.lua`
- fix completed quest click behavior in `quest.lua`
- always render completion action line for completed watched quests
- update item button anchoring after final row generation

### Footers

- Refs: click-to-complete regression
- Affects: `popup.lua`
- Affects: `quest.lua`

## [Unreleased]

### Added
- Bonus objective tooltips now show objective/progress lines before rewards.
- Achievement tooltips now show tracked criteria/objectives directly in the hover tooltip.
- Timed achievement criteria now display remaining time text when available.

### Changed
- QuestKing tooltips now use Blizzard-style default tooltip anchoring when available.
- Achievement tooltip layout was adjusted to better match the quest tooltip layout.
- Tooltip presentation across quest-adjacent tracker entries is now more consistent.

### Fixed
- Improved tooltip visibility by restoring a readable background/frame treatment.
- Bonus objective tooltips no longer show rewards only; they now include objective state as well.
- Achievement hover tooltips no longer omit criteria that are already rendered in the tracker body.

### UI
- Improved tooltip readability with clearer background styling.
- Standardized objective formatting across quest, bonus objective, and achievement hover tooltips.

# QuestKing Changelog

## Unreleased

### Fixed
- Raised the quest special item button above its owning watch entry by explicitly applying a higher frame level.
- Kept the item button on the same effective frame strata as the owning watch button instead of forcing a more aggressive strata like `TOOLTIP`.
- Reapplied item button z-order whenever a pooled item button is acquired or reassigned, which helps prevent neighboring quest rows from drawing or clicking over the quest use item.
- Preserved secure item-button behavior by avoiding unnecessary XML template changes.

### Technical Notes
- Added `ApplyItemButtonZOrder(itemButton, baseButton)` in `itembutton.lua`.
- Applied frame ordering from the owning watch button:
  - `SetFrameStrata(baseButton:GetFrameStrata())`
  - `SetFrameLevel(baseButton:GetFrameLevel() + 25)`
  - `SetToplevel(true)`
- Called the z-order helper when:
  - acquiring an item button from the pool
  - reusing an existing item button
  - assigning the button in `QuestKing.WatchButton:SetItemButton(...)`

### Files
- `itembutton.lua`
- No change required in `itembutton.xml`

## Suggested Git Commit Message

```text
fix(tracker): raise quest item button above watch rows
```

## Longer Git Commit Body

```text
Raise the QuestKing special item button above its owning watch entry.

The item button was created under QuestKing.Tracker without an explicit
frame level adjustment, which could allow neighboring watch rows or title
buttons to visually or interactively overlap the quest use item.

This change keeps the item button on the same effective strata as the
base watch button, but raises its frame level and marks it top-level for
safer draw and click priority. The z-order is reapplied during pooled
button acquisition and item assignment.

No XML template change was required.
```

### Fixed
- Corrected QuestKing quest watch behavior so normal completed quests no longer appear as **click-to-complete** when they still require a normal NPC turn-in.
- Added explicit auto-complete validation in the quest watch button flow so the ready-check completion presentation is only shown for true auto-complete quests.
- Restricted tracker click handling so `ShowQuestComplete(...)` is only attempted for quests that actually support auto-complete behavior.
- Prevented misleading `"COMPLETE"` auto-quest popup creation by validating `QUEST_AUTOCOMPLETE` before adding the popup.
- Preserved normal completed quest visibility in the tracker without implying the player can finish the quest directly from the watch entry.

### Technical
- Updated `quest.lua` to separate **quest completion state** from **auto-complete quest state** in tracker rendering.
- Updated `events.lua` to avoid creating false positive completion popups for non-auto-complete quests.



