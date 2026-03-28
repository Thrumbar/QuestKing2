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
