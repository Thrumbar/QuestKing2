# QuestKing 3.0.24 — Phase 1 Protected Mouse and Combat Updates

## Panel Verdict

- Runtime/protected-action review: the stable-parent secure item-button design is retained and its remaining combat deferrals are narrowed.
- Cross-version API review: the changes use frame, event, and timer APIs available throughout the supported Classic-family and Mainline branches. Optional protection checks remain capability guarded.
- Performance/reliability review: post-combat work is now driven by `PLAYER_REGEN_ENABLED`; the prior combat-time zero-delay refresh loop is removed.

Static acceptance result: `PARTIAL — runtime validation required`.

## Confirmed Findings

1. Item-bearing rows skipped their complete `Render()` pass during combat even though the row itself was no longer the parent of the secure item button. This left safe text geometry and progress-bar layout stale.
2. `Tracker:Resize()` queued another immediate tracker update while combat was still active. Each update reached the same guarded resize and could queue the next zero-delay update.
3. Combat reconciliation depended on per-frame polling even though `PLAYER_REGEN_ENABLED` supplies the exact transition needed by deferred protected work.
4. A quest-item link change detected during combat replaced the displayed Lua link while the protected secure attributes still targeted the old item. Tooltip state and click behavior could temporarily disagree.
5. Pooled-row mouse-state caching updated only when both the body and title changes succeeded. A partially deferred request could cause an already-applied mouse mutation to be retried.

## Corrections

- Secure quest-item buttons remain parented to the stable QuestKing tracker and remain anchored to their visual row.
- Item-row external anchors and secure item-button anchors remain unchanged during combat.
- Unprotected row text, line height, progress bars, completion text, and ordinary row rendering continue during combat.
- Actually protected legacy rows defer their complete geometry pass.
- Rows holding a secure item button are not hidden or recycled until combat ends.
- Deferred work is reconciled once from `PLAYER_REGEN_ENABLED`.
- The tracker layout guard records deferred work without scheduling repeated zero-delay refreshes during combat.
- Active item metadata remains consistent with the secure attributes until the post-combat rebuild applies a changed item link.
- Body and title mouse states are cached independently after successful application.

## Changed Files

- `core/core.lua`
- `core/events.lua`
- `ui/actionbuttonlayout.lua`
- `ui/itembutton.lua`
- `ui/tracker.lua`
- `ui/watchbutton.lua`
- `PHASE_1_PROTECTED_COMBAT_CHANGES.md`

## Compatibility Impact

- Lua 5.1 syntax is preserved.
- No external libraries were added.
- No quest classification, tracking-menu, option-policy, scenario-contract, or Classic tracker-population behavior was changed.
- `Frame:IsAnchoringRestricted()` is used only when the client exposes it.
- The implementation remains capability safe for Classic Era, Burning Crusade Classic, Cataclysm Classic, Mists Classic, Mainline, and Midnight-compatible clients.

## Runtime Test Procedure

1. Install this build with BugGrabber/BugSack or equivalent Lua error capture enabled.
2. Track one quest with a usable quest item, one multi-objective quest, and one percentage progress-bar quest.
3. Enter combat and advance ordinary objective counts several times.
4. Confirm counts, completion color/text, tracker title counts, and progress bars update before combat ends.
5. Confirm the quest-item button remains aligned with its quest row and still uses the correct item.
6. Complete or untrack the item quest during combat where the game permits it; confirm no pooled row inherits its click or mouse state.
7. Trigger scenario criteria changes during combat on a supported scenario.
8. Leave combat and confirm anchors, visibility, secure attributes, tracker height, and released rows reconcile once without `/reload`.
9. Repeat with rapid `QUEST_LOG_UPDATE` and `QUEST_WATCH_UPDATE` bursts and confirm no recurring zero-delay update loop.
10. Repeat the load and basic tracker test on each supported client family.

## Runtime Validation Items

- Blizzard-client confirmation that no `ADDON_ACTION_BLOCKED` or `ADDON_ACTION_FORBIDDEN` event occurs.
- Visual confirmation that a deferred item-row external anchor cannot overlap a newly inserted or resized neighboring row during combat.
- Secure click confirmation for an item whose quest log index changes during combat.
- Cross-flavor validation on the target Classic-family and Mainline builds.

## Remaining Risks

Static inspection cannot reproduce combat lockdown, frame protection propagation, restricted anchoring, or secure click execution. Phase 1 must not be marked `PASS` until the runtime test procedure completes without a protected-action error, stale combat text, row overlap, or failed post-combat reconciliation.
