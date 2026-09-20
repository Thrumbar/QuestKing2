# QuestKing 3.0.47 — Mainline Tooltip Font Initialization

## Corrected failure

Mainline could report:

```text
FontString:SetText(): Font not set
QuestKing/core/util.lua:1031
```

The addon-owned Mainline tooltip intentionally creates ordinary FontStrings
without `GameTooltipTemplate`. Its line-acquisition path cleared new rows with
`SetText("")` before the caller assigned the row's font.

## Runtime correction

- Assign and verify the left and right fonts inside line acquisition.
- Perform that work before every text-clearing or text-population operation.
- Prefer the intended Blizzard tooltip font objects when they resolve to a
  usable font.
- Fall back to QuestKing's packaged Source Sans Pro fonts when necessary.
- Keep a row inactive if neither font route succeeds.
- Preserve the Classic-family tooltip path unchanged.

## Scope

This correction changes only `core/util.lua` at runtime. It does not restore
`GameTooltipTemplate`, call Blizzard item-tooltip population methods, register
UI widgets, or alter the World Quest Tracker and PetTracker adapters.
