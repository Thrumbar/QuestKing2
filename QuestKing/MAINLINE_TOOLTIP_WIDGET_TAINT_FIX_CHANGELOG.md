# QuestKing 3.0.44 — Mainline Tooltip Widget Taint Fix

## Reported failure

Mainline Area POI hover could fail in Blizzard code while rendering a
TextWithState widget:

```text
Blizzard_UIWidgetTemplateTextWithState.lua:35:
attempt to perform arithmetic on local 'textHeight'
(a secret number value, while execution tainted by 'QuestKing')
```

The stack passed through `AreaPoiUtil.TryShowTooltip`,
`GameTooltip_AddWidgetSet`, `UIWidgetManager:ProcessAllWidgets`, and
`UIWidgetTemplateTextWithStateMixin:Setup`.

## Confirmed taint boundary

QuestKing already used a separate `QuestKingTooltip`, but its item hover paths
still called `SetHyperlink`, `SetItemByID`, and `SetQuestLogSpecialItem` on
Mainline. Those methods enter Blizzard's full tooltip-data processing path from
QuestKing execution rather than remaining inside QuestKing-owned text layout.

The reported failure occurs later in that same shared Blizzard tooltip system:
an Area POI adds a widget set, the global UI widget manager processes it, and
Blizzard attempts arithmetic using the secret result of
`FontString:GetStringHeight()`. Removing QuestKing from the full tooltip
population path eliminates the remaining source-level boundary by which its
execution can enter that system. Live-client reproduction remains the final
taint verification.

## Correction

- Mainline item hover now obtains read-only tooltip data from:
  - `C_TooltipInfo.GetHyperlink`
  - `C_TooltipInfo.GetItemByID`
  - `C_TooltipInfo.GetQuestLogSpecialItem`
- QuestKing renders only the returned left/right text and color data into its
  private tooltip.
- Secret strings, secret numbers, inaccessible colors, and unsupported lines
  are skipped or replaced with safe defaults.
- QuestKing does not call `ProcessInfo` and does not process widget, model,
  progress-bar, or embedded-item payloads.
- Mainline never falls back to the widget-capable population methods when
  read-only tooltip data is unavailable; it displays the safe item-name
  fallback instead.
- Classic-family clients retain their existing population path.

## Explicit exclusions

This fix does not:

- replace or hook `UIWidgetTemplateTextWithStateMixin:Setup`;
- patch Blizzard's secret-value arithmetic;
- mutate the shared `GameTooltip`;
- modify Area POI pins or their widget-set data;
- reparent or restyle Blizzard widget containers; or
- add polling, timers, events, or recurring refresh work.

## Changed runtime files

- `core/util.lua`
- `ui/itembutton.lua`
- `buttons/popup.lua`
