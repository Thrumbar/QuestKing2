# QuestKing 3.0.31 — PetTracker Runtime Fix

## Result

QuestKing displays PetTracker's current-zone capture progress in its own
tracker while retaining the complete 3.0.27 objective-menu update and the
3.0.28 Blizzard Focus/Track semantics correction.

## Confirmed runtime failure

The QuestKing-owned **Pets** header created a FontString without an inherited
font template and assigned its text before assigning QuestKing's configured
font. Retail 12.0.7 and 12.1.0 reject that sequence with:

`FontString:SetText(): Font not set`

The exception occurred before the section finished construction, so the
adapter's guarded layout path hid the incomplete section. Version 3.0.31 sets
the font first and then assigns the header text.

## Integration model

- QuestKing creates one additional tracker through PetTracker's installed
  `PetTracker.Tracker` class.
- PetTracker remains authoritative for collection data, progress, quality
  filtering, species rows, click actions, and its right-click menu.
- QuestKing supplies only the section header, placement, width, font alignment,
  and overall tracker-height integration.
- PetTracker's existing Blizzard Objective Tracker module is never reparented,
  hidden, restacked, or otherwise mutated by the adapter.

## Visibility

The section is shown only when:

1. PetTracker is installed, enabled, loaded, and initialized.
2. PetTracker's own **Zone Tracker** setting is enabled.
3. PetTracker reports unfinished content for its selected display condition.
4. QuestKing is fully expanded.

Old `QuestKingDB.options.enablePetTrackerCompatibility` values are intentionally
ignored. That setting belonged to the earlier non-rendering compatibility stub
and could silently block the dedicated adapter. PetTracker's own setting is now
the single authoritative visibility control.

## Refresh behavior

- PetTracker `COLLECTION_CHANGED` and `OPTIONS_CHANGED` signals request a
  coalesced content and layout pass.
- The first PetTracker content scan waits for `PLAYER_ENTERING_WORLD`, matching
  Blizzard Objective Tracker's world-data readiness.
- World entry, zone changes, and relevant addon lifecycle events mark the
  PetTracker content dirty before requesting a layout.
- A missing current map or failed content update remains dirty and is retried.
- PetTracker-only changes do not force QuestKing to rebuild quest data.
- Restricted layout work defers through QuestKing's existing post-combat
  reconciliation path.
- The QuestKing-owned section is anchored before PetTracker's independent
  tracker is constructed, giving the first PetTracker update a valid layout
  root.
- QuestKing uses PetTracker's native frame height after a successful update so
  the final progress/species rows are included in the watch-frame height.

## Preserved current behavior

The adapter was applied to `QuestKing_3.0.28_Focus_Track_Semantics_Fix(1)` as
the base. It does not replace the 3.0.27/3.0.28 versions of:

- `buttons/quest.lua`
- `buttons/bonusobjective.lua`
- `core/core.lua`
- `core/events.lua`
- `core/supertracking.lua`

Focus/Remove Focus, Track/Untrack, quest details, quest map, sharing, abandoning,
world-quest handling, and normal watch-limit enforcement therefore remain on
the latest implementation.
