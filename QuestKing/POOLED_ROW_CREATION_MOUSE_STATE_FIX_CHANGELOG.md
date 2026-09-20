# QuestKing 3.0.49 — Pooled-Row Creation Mouse-State Hardening

## Confirmed finding

QuestKing's Phase 1 pooled-row policy routes mouse-state changes through
`SetMouseEnabledSafe()` so protected rows are not mutated during combat.
`WatchButton:Create()` was the remaining exception: it called
`button:EnableMouse(false)` and `titleButton:EnableMouse(true)` directly.

The supplied API documentation marks `EnableMouse` as protected on Classic
Era, both supplied Burning Crusade Classic builds, Mists Classic, Mainline
12.0.7, and Mainline 12.1.0. Cataclysm exposes the same API without the
protected annotation, so using the guarded path remains compatible there.

## Correction

- Initialize the body and title mouse-state caches as pending.
- Apply both initial states through `SetMouseEnabledSafe()`.
- Cache a state only when its underlying API call succeeds.
- Leave a protected combat-time state pending for the existing render and
  `PLAYER_REGEN_ENABLED` reconciliation path.

## Compatibility

- Uses the existing Lua 5.1-compatible helper and protection checks.
- Adds no event, timer, hook, frame, allocation loop, or polling path.
- Does not change click registration, context-menu dispatch, secure item-button
  parenting, row pooling, tooltip rendering, or Classic population policy.

## Acceptance result

`PARTIAL — runtime validation required`

Static validation proves that `WatchButton:Create()` has no direct
`EnableMouse` call and that cache writes follow successful guarded calls.
Final acceptance requires creating new quest, bonus-objective, scenario, and
achievement rows during combat on a live client without a blocked action.
