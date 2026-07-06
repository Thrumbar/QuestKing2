# QuestKing Background Alpha Option Update

## Changed files

- `options.lua`
  - Added `opt.trackerBackgroundAlpha` as the default quest frame background opacity setting.

- `options_override.lua`
  - Added an override default for `opt.trackerBackgroundAlpha` matching the current advanced background visual style.

- `ui/optionspanel.lua`
  - Added `Quest Frame Background Alpha` slider under the Background section.
  - Saves the value into `QuestKingDB.options.trackerBackgroundAlpha`.
  - Applies the setting live through the existing QuestKing tracker refresh path.

- `ui/tracker.lua`
  - Added separate background alpha handling so tracker text/button alpha and quest frame background alpha are controlled independently.
  - Applies the same saved alpha to both advanced background and simple backdrop modes.
  - Keeps mousewheel background-alpha adjustment on the tracker toggle button, but now persists it through saved variables.
  - Preserves old no-background behavior when both background options are disabled.

- `buttons/popup.lua`
  - Fixed the Lua syntax error caused by using reserved keyword `and` as a table key.

- `core/autocomplete.lua`
  - Renamed from `AutoComplete.lua` to `autocomplete.lua` so the filename matches the existing TOC entry.

## New saved variable

```lua
QuestKingDB.options.trackerBackgroundAlpha = 0.72
```

The slider range is `0.00` to `1.00` in `0.05` steps.

## Validation

Parsed all Lua files with `texlua loadfile()` syntax validation. All 23 Lua files parsed successfully.
