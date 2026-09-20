# QuestKing 3.0.48 — Mainline Tooltip Render-Result Propagation

## Confirmed finding

The addon-owned Mainline tooltip renderer can reject a line when neither the
configured Blizzard font object nor QuestKing's packaged fallback establishes
a usable font. `AddMainlineTooltipLine()` and
`AddMainlineTooltipDoubleLine()` correctly return `false` in that case.

`AddPrivateTooltipDataLine()` protected those calls with `pcall`, but it used
only the `pcall` success flag. A call that ran without a Lua exception while
returning `false` was therefore reported as a successfully rendered line.
`PopulatePrivateTooltipFromData()` could then report success and show an empty
tooltip.

## Correction

- Capture both values returned by `pcall`: execution success and renderer
  result.
- Count the line only when execution succeeds and the renderer returns the
  literal Boolean `true`.
- Preserve safe rejection when a font, tooltip line, or source value cannot be
  used.

## Compatibility

- Mainline 12.x: corrected addon-owned `C_TooltipInfo` rendering path.
- Classic-family clients: unchanged legacy `GameTooltipTemplate` path.
- No new events, timers, hooks, protected calls, or Blizzard widget access.

## Acceptance result

`PARTIAL — runtime validation required`

Static validation can prove the result contract and failure behavior. Final
acceptance still requires hovering quest items and quest-start popups in a
live Mainline client.
