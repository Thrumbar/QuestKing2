# QuestKing 3.0.37 — Scenario Hover Callback Fix

## Failure

Hovering the scenario watch row could call `mouseHandlerScenario:TitleButtonOnEnter()` with the pooled row as its source. The handler assumed the source was always the title child and read `self.parent`, which is nil for the pooled row.

That produced:

```text
buttons/scenario.lua:1689: attempt to index local 'button' (a nil value)
```

## Root cause

QuestKing's watch-button dispatcher intentionally supports two hover sources:

- Title hover passes the title child, whose `parent` is the pooled row.
- Body hover passes the pooled row directly.

Popup, quest, and available-campaign handlers already resolve both forms. Scenario, achievement, and bonus-objective hover handlers accepted only the title-child form.

## Correction

- Scenario hover now resolves the owning row as `self.parent or self`.
- Achievement and bonus-objective hover handlers use the same dual-source resolution so the equivalent body-hover path does not silently omit their tooltips.
- Tooltip creation still receives the original hovered frame, preserving its existing anchor behavior.
- The central dispatcher, mouse enablement, click behavior, scenario APIs, and reward logic are unchanged.

## Validation

- Both title-child and pooled-row hover sources resolve to the same owning row.
- The exact reported scenario body-hover path no longer dereferences nil.
- All Lua files parse with Lua 5.1 grammar.
- TOC paths and XML files remain valid.
- The complete archive passes integrity and path-safety checks.
