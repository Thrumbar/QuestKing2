# Objective Count Order Fix

## Problem

Normal quest objectives displayed numeric progress before the description:

```text
1/3 Objective
```

World quests, bonus objectives, and scenarios instead placed the description
first and rendered the count in the right-side text column:

```text
Objective  1/3
```

## Fix

QuestKing now builds non-formatted world-quest, bonus-objective, and scenario
criteria with the same count-first order used by normal quests:

```text
1/3 Objective
```

This matches the supplied Blizzard 12.0.7 and 12.1.0 Objective Tracker source,
which formats both scenario and bonus-objective criteria as
`"%d/%d %s"`.

Already-formatted criteria are retained unchanged to avoid duplicate counts.
Weighted percentage objectives continue to use their existing progress bars.
Progress values, completion state, failure state, timers, colors, and update
flashes are not changed.

## Files Changed

- `buttons/bonusobjective.lua`
- `buttons/scenario.lua`
- `version.txt`
