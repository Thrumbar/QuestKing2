# QuestKing 3.0.45 — Protected Mouse Propagation Fix

## Reported failure

Creating a pooled bonus-objective row attempted this protected operation:

```text
QuestKing_PoolButton8:SetPropagateMouseClicks()
QuestKing/ui/watchbutton.lua:578
```

## Confirmed cause

`WatchButton:Create()` called `SetPropagateMouseClicks(false)` on both the
pooled row body and its nested title button. Mainline 12.1 marks
`SetPropagateMouseClicks` as a protected, restricted function. A method guard
proves only that the API exists; it does not make the call addon-safe.

## Correction

- Removed the propagation call from the pooled row body.
- Removed the propagation call from the nested title button.
- Kept ordinary `RegisterForClicks` and `OnClick` handlers unchanged.
- Kept the quest-ID-specific context-menu debounce and already-open guard.
- Added no combat deferral, hook, timer, polling, or Blizzard-frame mutation.

## Expected result

Bonus-objective and other pooled rows can be created without QuestKing calling
`SetPropagateMouseClicks`. Right-clicking a quest still opens one context menu.

## Changed runtime file

- `ui/watchbutton.lua`
