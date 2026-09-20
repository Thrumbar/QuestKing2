# QuestKing 3.0.50 — Feature Coverage Phase 1: Replacement Safety

## Verdict

Static and mocked validation: **PASS**.

In-game combat, taint, and cross-client validation: **REQUIRED** before this
candidate is promoted as a fully validated release.

## Scope

This tranche implements the first recommendation from the feature-coverage
comparison: keep QuestKing's tracker active without concealing Blizzard-only
tracker content by default, and defer QuestKing presentation mutations that can
be protected during combat.

It does not add new tracker modules or change quest classification, objective
completion rules, scenario behavior, or achievement behavior.

## Changes

### Safe fallback default

- `options_override.lua` no longer changes `disableBlizzard` from the base
  fail-open default of `false` to `true`.
- A fresh install, or an existing install with no saved choice for this option,
  leaves Blizzard's Objective Tracker visible.
- An explicitly saved `true` value remains supported. The settings panel labels
  it as an advanced whole-tracker suppression choice and warns Retail users that
  unsupported tracker content can disappear.
- The Retail panel names the currently uncovered Blizzard module categories:
  UI Widgets, Adventures, Monthly Activities, Initiative Tasks, and Profession
  Recipes.
- Runtime detection based on module visibility or mutable layout state was not
  introduced; it cannot reliably distinguish missing content from collapsed,
  deferred, or height-limited content.

### Combat-safe presentation reconciliation

- Tracker alpha, scale, background, titlebar presentation, layout metrics,
  tracker height, drag state, and position changes now defer during combat.
- Drag start is rejected during combat. A drag that began immediately before
  combat is stopped and normalized after combat.
- The latest pending initial/preset position is applied after combat.
- `PLAYER_REGEN_ENABLED` drains pending presentation work before queuing the
  existing post-combat tracker refresh.
- Public tracker methods contain their own guards, so settings controls, slash
  commands, and titlebar handlers share the same protection boundary.
- Quest/objective data refresh logic remains unchanged; only presentation and
  protected frame mutations are deferred.

## Changed Files

- `options.lua`
- `options_override.lua`
- `ui/optionspanel.lua`
- `ui/tracker.lua`
- `core/core.lua`
- `FEATURE_COVERAGE_PHASE_1_REPLACEMENT_SAFETY_CHANGELOG.md`

## Preserved Files

- Every `.toc` file is byte-for-byte unchanged.
- No bundled library, font, texture, XML file, or Blizzard source snapshot was
  edited.

The supplied Classic Era `11508` interface metadata therefore remains unchanged
even though the supplied reference snapshot is `1.15.9`; this is intentional to
honor the no-TOC-change constraint.

## Validation Performed

- Parsed all QuestKing Lua files successfully with the available Lua parser.
- Executed a mocked combat regression covering alpha, scale, layout, preset
  positioning, drag start/stop, post-combat drain, and the three SavedVariables
  fallback states (`nil`, `false`, and `true`).
- Confirmed the mocked combat path made no protected presentation calls and the
  deferred path applied them after combat.
- Confirmed an explicitly saved Retail suppression choice emits one warning per
  session and remains effective.
- Confirmed `.toc` hashes match the immutable 3.0.50 input.

## Required In-Game Validation

1. On Retail 12.1/Midnight, test fresh, saved-false, and saved-true installs.
2. With a usable quest item tracked, change tracker scale, alpha, background,
   drag lock, and preset during combat; confirm no blocked/forbidden action.
3. Confirm ordinary quest, scenario, progress, and title-count text continues to
   update during combat.
4. Leave combat and confirm scale, background, drag state, position, secure item
   alignment, and tracker height reconcile without `/reload`.
5. Repeat fallback enable/disable and combat exit on Classic Era, TBC Classic,
   Cataclysm Classic, and Mists Classic.
6. On Retail, verify unsupported module content remains visible with the default
   setting: UI Widgets, Adventures, Monthly Activities, Initiative Tasks, and
   Profession Recipes.

## Deferred to the Next Ordered Tranche

- Existing-row `titleHeight` propagation.
- Live toggle-button border propagation.
- Viewport-aware title/height budgeting.
- Regular-quest parity, World Quest expiry/rewards, achievement parity, and the
  five missing Retail tracker modules.
