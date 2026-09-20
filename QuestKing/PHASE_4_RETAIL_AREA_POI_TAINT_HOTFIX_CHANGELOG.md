# QuestKing 3.0.50 — Phase 4 Retail Area POI Taint Hotfix

## Reported failure

Hovering a Retail Area POI could enter Blizzard's tooltip widget pipeline with
execution tainted by QuestKing. Blizzard then attempted arithmetic or layout
comparison with secret geometry values in:

- `UIWidgetBaseItemTemplateMixin:Setup()`;
- `UIWidgetTemplateTextWithStateMixin:Setup()`; and
- `ResizeLayoutMixin:Layout()` while the widget set was being cleared.

These are three stages of one tainted tooltip lifecycle, not three independent
QuestKing arithmetic defects.

## Panel verdict

- **Runtime and protected-action review:** QuestKing's ordinary quest click
  called `QuestMapFrame_OpenToQuestDetails()` before its safe details fallback.
  The Blizzard path changes `WorldMapFrame`'s map ID and rebuilds pooled map
  pins from QuestKing execution. A caught protected-operation failure does not
  roll back pins already acquired by that path.
- **Cross-version API review:** This duplicate call contradicted
  `Compat.OpenQuestDetails()`, which already excludes the quest-map path on
  Mainline and uses the popup detail frame. Classic-family clients still need
  the guarded legacy map path and retain it.
- **Performance and reliability review:** The correction adds no frame, event,
  hook, timer, polling, or allocation loop. QuestKing's existing Mainline
  tooltip remains an anonymous ordinary `Frame`; no Blizzard tooltip or widget
  function is replaced or wrapped.

The source-level bypass is confirmed. Final taint acceptance still requires a
live Retail client because the terminal error stack does not contain the first
write recorded by a level-2 taint log.

## Corrections

- Mainline quest left-click now uses the isolated popup-details route selected
  by `Compat.OpenQuestDetails()`.
- **Open Quest Map** is omitted from QuestKing's Mainline context menu; the
  legacy action remains available on supported Classic-family clients.
- Mainline hover instructions now say **open quest details** rather than
  promising the removed map action.
- The map-ID fallback for a campaign continuation row is not called on
  Mainline. Quest and QuestOffer supertracking remain unchanged, and Classic
  retains the guarded `OpenWorldMap()` fallback.

## Explicit exclusions

The hotfix does not patch, hook, or wrap Blizzard's `GameTooltip`, Area POI
mixins, UIWidget templates, layout mixins, secret-number getters, or map-pin
mixins. `pcall`, `xpcall`, and zero-delay timers are not treated as taint
cleansers.

No `.toc`, XML, bundled library, asset, SavedVariables key, frame pool, event,
or polling behavior was changed.

## Changed files

- `buttons/quest.lua`
- `CONSOLIDATED_CHANGELOG.md`
- `FEATURE_COVERAGE_PHASE_3_QUEST_TRACKING_CHANGELOG.md`
- `QUEST_CONTEXT_MENU_ACTIONS_CHANGELOG.md`
- `PHASE_4_RETAIL_AREA_POI_TAINT_HOTFIX_CHANGELOG.md`

## Live validation

1. Install this package over the previous QuestKing folder and run `/reload`.
   The reload is required to discard already-tainted pooled pins and tooltip
   widget-container state.
2. With only QuestKing enabled, click an ordinary QuestKing quest, then hover
   the Area POI whose reward widget set previously failed.
3. Confirm left-click opens the popup detail frame, and confirm the Mainline
   right-click menu has no **Open Quest Map** row.
4. Repeat with **Hide Blizzard Objective Tracker** disabled and enabled.
5. On each Classic-family client, confirm quest-map actions and legacy item
   tooltips still work.
6. If an error remains, enable `/console taintLog 2`, reload, reproduce once,
   and inspect the first QuestKing entry in `Logs/taint.log` rather than only
   the later BugSack sink.

## Acceptance result

`PARTIAL — runtime validation required`
