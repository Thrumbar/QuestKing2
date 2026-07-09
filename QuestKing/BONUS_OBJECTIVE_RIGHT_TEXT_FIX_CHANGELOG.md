# QuestKing Bonus Objective Right-Text Alignment Fix

## Problem
Bonus objectives could display their progress text, such as `0/10`, on the same vertical row as the bonus objective title instead of on the objective line. This made the tracker appear as if the bonus objective title and objective progress were merged or misaligned.

## Cause
`ui/watchbutton.lua` anchored every right-side line value to the top-right of the whole watch button:

```lua
right:SetPoint("TOPRIGHT", self, "TOPRIGHT", -lineRightInset, 0)
```

That reused the button's top edge for every objective line, so right-column values were drawn at the title row instead of beside their matching objective line.

## Fix
The right-side value is now anchored to the actual objective line:

```lua
right:SetPoint("TOPLEFT", line, "TOPRIGHT", 0, 0)
```

The left text width is still reduced by the right text width, so wrapping remains clean and the right-side objective counter stays aligned with the objective it belongs to.

## Files Changed
- `ui/watchbutton.lua`

## Result
Bonus objective rows now display like this:

```text
Bonus Objectives
[82] No Squatters
  Amani defectors slain                         0/10
```

instead of placing `0/10` on the title row.
