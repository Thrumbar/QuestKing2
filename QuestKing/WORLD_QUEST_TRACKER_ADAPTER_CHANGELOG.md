# QuestKing 3.0.42 — World Quest Tracker Anchor Integration

## Summary

QuestKing can now become the visual attachment target for World Quest
Tracker's existing tracker panel. World Quest Tracker remains the owner of the
panel, quest widgets, input behavior, timers, scale, saved settings, and refresh
lifecycle.

## Implementation

- Added `ui/worldquesttracker.lua`.
- Added `WorldQuestTracker` as an optional dependency so its public runtime
  object is available before QuestKing initializes when both addons are
  enabled.
- Securely post-hooks `WorldQuestTracker.RefreshTrackerAnchor()` and redirects
  only `WorldQuestTrackerScreenPanel`.
- Uses a one-pixel, invisible QuestKing-owned anchor host at the bottom-right of
  the completed QuestKing layout; the World Quest Tracker panel is not counted
  as QuestKing content and does not inflate QuestKing's height.
- Keeps the World Quest Tracker panel parented to `UIParent`; no frame
  reparenting, widget copying, tracker-module registration, or protected
  Objective Tracker mutation is performed.
- Honors World Quest Tracker's own `use_tracker` and
  `tracker_attach_to_questlog` settings.
- Anchors the panel's top-right edge beneath QuestKing's bottom-right edge so
  World Quest Tracker follows QuestKing movement, scaling, and height changes.
- Defers protected anchor changes during combat and reconciles them on
  `PLAYER_REGEN_ENABLED`.
- Checks modern frame anchoring restrictions in addition to protected-frame
  combat state before changing either anchor.
- Restores World Quest Tracker's native anchor when the QuestKing integration
  is disabled or QuestKing is unavailable.
- Added a saved QuestKing option, enabled by default:
  `attachWorldQuestTracker`.
- Added an Addon Integrations control to QuestKing's options panel.

## Compatibility

- Retail / Midnight: active when World Quest Tracker's supported runtime is
  present.
- Classic-family clients: inert because World Quest Tracker's runtime is not
  present; no unsupported API is called.
- PetTracker: unchanged. Its independent QuestKing-owned renderer remains
  separate from this anchor-only integration.

## Changed Files

- `QuestKing.toc`
- `options.lua`
- `ui/optionspanel.lua`
- `ui/worldquesttracker.lua`
- `version.txt`
