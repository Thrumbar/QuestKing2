# QuestKing refactor package

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
