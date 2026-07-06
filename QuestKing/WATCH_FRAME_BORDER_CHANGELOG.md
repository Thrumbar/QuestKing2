# QuestKing Watch Frame Border Option

## Added

- Added `opt.hideWatchFrameBorder` with a default value of `false`.
- Added a native options checkbox named **Hide watch frame border** under the **Background** section.
- Saved the setting in `QuestKingDB.options.hideWatchFrameBorder`.
- Applied the setting live through `Tracker:ApplyTrackerBackground()`.

## Behavior

- When enabled, QuestKing hides only the outer watch frame border.
- The quest frame background fill still uses `trackerBackgroundAlpha`.
- Quest text, objective rows, titlebar buttons, quest item buttons, and the separate tracker alpha setting are unchanged.
- The original backdrop tables are not permanently modified; QuestKing builds a borderless runtime backdrop copy so the border can be restored immediately when the option is disabled.
