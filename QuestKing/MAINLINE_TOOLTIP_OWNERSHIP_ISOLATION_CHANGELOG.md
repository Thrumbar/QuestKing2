# QuestKing 3.0.46 — Mainline Tooltip Ownership Isolation

## Problem

QuestKing 3.0.44 stopped using widget-capable item population methods on
Mainline, but its private tooltip was still created from Blizzard's
`GameTooltipTemplate`.

That template participates in Blizzard's shared tooltip lifecycle. Its load
and hide paths reference global comparison tooltips, embedded item tooltip
cleanup, `TooltipComparisonManager`, and widget-set teardown. QuestKing also
cleared the template's `shoppingTooltips`, which are Blizzard-owned global
frames. A later Area POI hover could therefore enter Blizzard widget setup
with QuestKing-tainted execution and fail when Blizzard performed arithmetic
on secret width or height values.

Observed failures included:

- `UIWidgetTemplateTextWithStateMixin:Setup()` using a secret `textHeight`; and
- `UIWidgetBaseStatusBarTemplateMixin:InitPartitions()` using a secret
  `barWidth`.

## Correction

- Mainline now creates an ordinary addon-owned frame rather than a
  `GameTooltip`.
- All tooltip FontStrings, reward textures, background, border, anchors, line
  pooling, layout, scaling, display, and cleanup are QuestKing-owned.
- Item tooltip text still comes from read-only `C_TooltipInfo`.
- Secret text, colors, dimensions, and textures are rejected before use.
- Mainline performs no QuestKing tooltip call into Blizzard
  `GameTooltip`, `TooltipComparisonManager`, `ShoppingTooltip`, embedded item
  tooltip, or `UIWidgetManager` state.
- Classic-family clients retain the legacy `GameTooltipTemplate` path because
  their item-tooltip population APIs and security model differ.

## Preserved behavior

- Quest, bonus-objective, scenario, achievement, item, and popup tooltips.
- Single and double text lines.
- Scenario reward textures.
- Tooltip scaling.
- Right, Left, Cursor, Top, and Bottom anchors.
- All QuestKing 3.0.45 protected mouse-propagation and earlier corrections.

## Validation

- Lua 5.1 syntax parsing for every Lua file.
- Focused Mainline runtime harness with no `GameTooltip` creation.
- Secret text and secret height rejection.
- Tooltip lifecycle, line, double-line, texture, anchor, scale, show, hide,
  and clear coverage.
- Mainline source audit for Blizzard tooltip and widget state access.
- XML, TOC, archive integrity, and packaged-source equality checks.
