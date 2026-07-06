# QuestKing Slider Classic Display Fix

## Issue

The QuestKing options panel used Blizzard's deprecated `OptionsSliderTemplate` for every slider. Retail and Retail PTR render that template correctly, but Classic branches can render incomplete slider art depending on the client branch and loaded template path.

## Fix

- Replaced the options panel's `OptionsSliderTemplate` dependency with a QuestKing-owned slider renderer.
- Created slider labels, minimum text, maximum text, current-value text, track, border lines, and thumb explicitly in Lua.
- Kept saved variable keys unchanged.
- Preserved existing slider behavior for:
  - Tracker Scale
  - Tracker Alpha
  - Quest Frame Background Alpha
  - Button Width
  - Line Height
  - Title Height
  - Font Size
  - Quest Item Button Scale
- Added mousewheel support on sliders for small step adjustments.
- Added runtime value snapping for Classic branches that do not obey step values while dragging.

## Checked branch targets

The patch avoids branch-specific slider templates and uses only basic Frame, Slider, Texture, and FontString APIs available across the supplied Blizzard interface references:

- Classic Era 1.15.8
- TBC Anniversary 2.5.5
- Cataclysm Classic 4.4.2
- MoP Classic 5.5.4
- Retail / Midnight 12.0.7

## Files changed

- `ui/optionspanel.lua`
- `version.txt`
- `SLIDER_CLASSIC_FIX_CHANGELOG.md`
