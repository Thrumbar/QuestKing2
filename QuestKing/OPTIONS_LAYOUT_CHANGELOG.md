# QuestKing Options Layout Cleanup

## Changed

- Reorganized the native QuestKing settings panel into clearer groups:
  - Main Tracker
  - Frame Appearance
  - Quest Text & Rows
  - Item Buttons, Rewards & Tooltips
  - Quest Behavior
  - Scenario, Dungeon & Raid Content
  - Compatibility
- Moved the background alpha and watch frame border controls into **Frame Appearance** so frame styling is handled in one place.
- Moved item button, reward, and tooltip anchoring options into their own section instead of mixing them with row sizing.
- Added short section descriptions to explain what each group affects.
- Added subtle divider lines between sections to make the scroll panel easier to scan.
- Standardized left alignment for checkboxes, sliders, and choice buttons.
- Added dynamic scroll-child height sizing so the panel remains scrollable if more settings are added later.

## Saved Variables

No saved variable names changed. Existing settings remain compatible.
