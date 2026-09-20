# Phase 2 Minimize Header Position Fix

## Problem

Minimizing or restoring the tracker changes its height. When the tracker was anchored from `BOTTOM`, `BOTTOMLEFT`, `BOTTOMRIGHT`, `LEFT`, `CENTER`, or `RIGHT`, keeping the same anchor offset caused the top edge and titlebar to move with that height change.

The bottom-right preset made the regression directly reproducible: collapsing a populated tracker to its title height moved the header downward, and restoring it moved the header upward.

## Correction

`ui/tracker.lua` now marks minimize and restore operations for header-position preservation. During the next successful `Tracker:Resize` pass it:

1. Records the titlebar's top coordinate.
2. Applies the new tracker height.
3. Measures the titlebar again.
4. Corrects the existing anchor's vertical offset by the measured difference.
5. Saves the corrected position for the next login.

This follows Blizzard's own measured-position correction pattern and avoids assumptions about which vertical anchor is active. Top-anchored trackers require no correction. If resize is deferred during combat, the preservation marker remains pending until the legal post-combat resize.

## Files Changed

- `ui/tracker.lua`
- `FEATURE_COVERAGE_PHASE_2_LIVE_OPTIONS_CHANGELOG.md`
- `PHASE_2_MINIMIZE_HEADER_POSITION_FIX_CHANGELOG.md`

No `.toc`, library, font, texture, or XML file was changed.

## Validation

- Reproduced the failure with a 300-pixel-high tracker anchored `BOTTOMRIGHT` to `UIParent`.
- Verified that minimizing to the 18-pixel title height keeps the titlebar at the original coordinate.
- Verified that restoring the tracker to 300 pixels also keeps that coordinate.
- Re-ran the complete Phase 2 presentation, SavedVariables, pooling, and combat-deferral harness.

## Status

`PARTIAL — live client validation required`

The deterministic mock regression passes. Final pixel placement, UI-scale combinations, and protected-action behavior still require an active World of Warcraft client.
