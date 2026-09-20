# QuestKing 3.0.40 — Phase 7 Tracker Visibility Recovery

## Corrected regression

QuestKing 3.0.39 could initialize as a small empty rectangle after login or
reload. Two Phase 7 optimizations could combine to produce that state:

- The options loader could cache tracker width and title height before
  `Tracker:Init` created the titlebar, labels, and controls. The completed
  initialization pass then skipped their sizing and anchors.
- The first 50 ms refresh could cache an empty watched-quest population while
  Blizzard was still restoring quest watches. Later `QUEST_LOG_UPDATE` traffic
  compared only the accepted quest-log entry count and could incorrectly reuse
  the empty population.

## Layout recovery

- Layout metrics are cached only after every titlebar control exists.
- `Tracker:Init` always performs one complete metric and anchor pass.
- Successful metric changes advance a tracker layout generation.
- Pooled rows reapply their external anchors when that generation changes.

## Population recovery

- Cached quest populations now include a fingerprint of:
  - resolved tracker population policy;
  - ordinary watched quest IDs;
  - watched world quest IDs;
  - active prey quest ID.
- Cached rows are reused only when the fingerprint and quest-log entry count
  still match.
- A late quest-data result checks Blizzard's live watch lists when the cached
  population does not yet contain the quest.
- Under All Accepted, that relevance check also validates the quest against the
  live quest log, including a collapsed-header-safe Classic scan.
- Relevant quest data already in the cache refreshes only display data; a live
  member absent from the cache forces the one structural repair it requires.
- Login and UI reload receive two bounded, conditional readiness checks at
  0.20 and 0.75 seconds. They stop doing work as soon as quest content exists.
- Tracked achievements are resynchronized during the same startup settle path.

## Failure containment

- The pooled-row manager retains the last completed request order while a new
  generation is built.
- If the quest population or quest renderer raises a transient runtime error,
  QuestKing restores the completed order, preserves the current tracker
  geometry, and queues one forced recovery.
- A failed render can no longer free every healthy row and commit an empty
  title-height tracker.

## Preserved Phase 7 behavior

- One 50 ms event-burst coordinator remains the normal refresh path.
- Profiling, targeted invalidation, scan reductions, pooled keyed lookup,
  progress/timer state preservation, and PetTracker lifecycle gating remain
  active.
- No saved-variable migration is required.
