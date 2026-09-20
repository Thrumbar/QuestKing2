# QuestKing 3.0.19 — Logic and Reliability Audit Fix

This release applies the ten confirmed defects from the supplied static audit without introducing helper addons or third-party libraries.

## Corrected

1. `SCENARIO_COMPLETED` now consumes `(questID, xp, money)` in Blizzard's documented order.
2. `C_ScenarioInfo.GetScenarioInfo()` now maps `type`, `area`, and `uiTextureKit`; guarded legacy scenario data supplements bonus-step flags only where needed.
3. Non-protected tracker data and text refresh during combat. Secure item-button and protected layout mutations retain their existing combat deferral.
4. Font and completed-objective settings are read dynamically and applied to pooled rows after saved variables or live settings change.
5. The `false`, `true`, and `"always"` completed-objective modes now have one shared meaning across normal objectives, progress bars, and scenario criteria.
6. Bonus/task section headers use the fifth `GetTaskInfo()` return, `displayAsObjective`, instead of a nonexistent objective-structure field.
7. Right-clicking a quest now opens a Blizzard dropdown menu with open, supertrack, track/untrack, and cancel actions.
8. PetTracker compatibility can be enabled from saved or live options and no longer becomes permanently disabled before saved variables load. It remains deliberately state-based and does not reparent or mutate PetTracker frames.
9. Protected safe-call wrappers return failure after exceptions, allowing intended fallback refresh paths to run.
10. AutoComplete filters `ADDON_LOADED`, unregisters it after QuestKing loads, and subscribes only to events required by its own completion-state work.

## Packaging

- The TOC now references `core\autocomplete.lua` with exact archive case.
- Mainline interface metadata covers the supplied 12.0.7 and 12.1.0 snapshots.
- No external helper addon or library was added.

## Validation boundary

The Lua source was syntax-loaded with a Lua 5.1-compatible interpreter, TOC paths were checked case-sensitively, and API/event contracts were compared with all supplied Blizzard snapshots. Live-client taint, protected-action execution, and secret-value timing still require in-game testing on each branch.
