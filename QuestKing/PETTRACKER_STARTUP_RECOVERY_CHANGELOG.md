# QuestKing 3.0.34 — PetTracker Startup Recovery

## Issue

PetTracker remained absent from QuestKing's watch frame after login even though
the integration file and TOC entry were still present.

## Root Cause

QuestKing performs its first PetTracker layout after
`PLAYER_ENTERING_WORLD`. On some loads, `C_Map.GetBestMapForUnit("player")`
temporarily has no valid map.

The adapter correctly kept its content dirty, but it did not schedule another
layout. When the map check failed, the independent PetTracker frame had not yet
been created and therefore could not receive its own later zone refresh. The
section could remain hidden until an unrelated QuestKing update occurred.

## Fix

- Added five bounded map-readiness retries at 0.1, 0.25, 0.5, 1, and 2
  seconds.
- A retry marks PetTracker content dirty and uses QuestKing's existing
  coalesced tracker update path.
- A valid player map cancels and resets the remaining retry budget.
- Login, world-entry, addon-load, and zone-change lifecycle events reset the
  retry budget.
- No permanent polling or OnUpdate handler was added.

## Preserved Behavior

- PetTracker's own Zone Tracker setting remains the only visibility switch.
- Completed zones remain hidden when PetTracker reports the selected target
  quality as complete.
- QuestKing still creates a separate PetTracker-owned tracker and does not
  reparent or modify PetTracker's Blizzard Objective Tracker module.
- QuestKing 3.0.33's slash-command taint fix, secure quest-item behavior, and
  3.0.32 objective-count ordering are unchanged.
