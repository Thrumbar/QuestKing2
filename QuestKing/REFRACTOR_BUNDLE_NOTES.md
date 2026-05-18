# QuestKing refactor bundle

Integrated replacements in this bundle:

- core/util.lua
- core/compatibility.lua
- core/core.lua
- core/supertracking.lua
- core/slashcommand.lua
- core/events.lua
- buttons/quest.lua
- buttons/achievement.lua
- buttons/challengetimer.lua
- buttons/popup.lua
- ui/itembutton.lua
- ui/rewardsframe.lua
- ui/timerbar.lua
- ui/progressbar.lua
- ui/tracker.lua
- ui/watchbutton.lua
- ui/optionspanel.lua

Files retained from the source package in this build:

- buttons/bonusobjective.lua
- buttons/scenario.lua
- options.lua
- options_override.lua
- XML/assets files

Latest package additions:

- Added `ui/optionspanel.lua` as the native Blizzard AddOns settings panel for QuestKing.
- Updated `QuestKing.toc` to load `ui/optionspanel.lua` after `options_override.lua` so the GUI reflects the active option defaults.
- Updated `core/slashcommand.lua` so `/qk options`, `/qk config`, and `/qk settings` open the new panel.
- Added standalone slash aliases `/qkoptions` and `/questkingoptions` through the options panel module.
- Documented the settings UI addition in `REFRACTOR_NOTES.md`, `version.txt`, and `version.new`.

This bundle is intended as a consolidated test package from the conversation refactor pass.
