# QuestKing 3.0.36 — Phase 5: Scenario Rewards and Display

## Result

Phase 5 corrects QuestKing's scenario reward, stage, bonus-objective, weighted-progress, and challenge-timer paths while preserving all earlier reliability and protected-action work.

## Scenario API contracts

- Consumes `SCENARIO_COMPLETED` as `questID, xp, money`.
- Displays only the event's real XP and money values; the quest ID is never treated as XP.
- Reads modern `ScenarioInformation` through its documented `name`, `currentStage`, `numStages`, `flags`, `isComplete`, `xp`, `money`, `type`, `area`, `uiTextureKit`, and `scenarioID` fields.
- Uses legacy `C_Scenario.GetInfo()` only when the modern information API is absent, fails, or returns unusable data.
- Keeps the current-stage ordinal separate from the scenario step ID.
- Uses current-step criteria APIs for the active stage and step-specific criteria APIs for explicit bonus step IDs.

## Scenario and bonus display

- Honors `shouldShowBonusObjective` before creating modern bonus rows.
- Supports the separate single-bonus-step API used by the supplied Mists branch.
- Preserves authoritative zero criteria counts and retains unnamed Mists bonus steps under Blizzard's fallback label.
- Prevents explicit bonus-step lookups from falling through to current-stage criteria.
- Gives top-level weighted progress precedence over ordinary criteria completion and renders weighted criteria on a true 0–100 scale.
- Preserves the three-state completed-objective policy for completed weighted rows.
- Uses modern scenario spell names while retaining the legacy spell-name fallback.
- Displays documented completed-scenario state even when there is no active stage ordinal.
- Avoids stage-complete sound and banner feedback when merely entering stage 1.
- Clears incompatible pooled timer/progress bars before reusing scenario lines.

## Rewards and challenge content

- Suppresses XP rewards at effective maximum level through modern and legacy-compatible checks.
- Uses the supplied Mists LFG bonus-currency APIs for legacy bonus tooltips instead of labeling the scenario's main XP or money as a bonus reward.
- Snapshots reward-row identity so a delayed reward animation cannot anchor to a pooled row that has been reused for unrelated content.
- Fixes proving-grounds score dispatch to receive the actual score.
- Refreshes challenge content on `CHALLENGE_MODE_START`.
- Updates challenge death counts from `CHALLENGE_MODE_DEATH_COUNT_UPDATED` instead of polling that API twenty times per second.

## Validation scope

Static validation covers Lua 5.1 syntax, documented API fields and event payloads, modern/legacy routing, TOC references, and archive integrity. Final in-client sign-off still requires ordinary, bonus-step, completed/reward, timed/challenge, and Mists legacy scenario runs because Blizzard runtime data cannot be synthesized conclusively outside the game client.

## Changed files

- `buttons/scenario.lua`
- `buttons/bonusobjective.lua`
- `buttons/challengetimer.lua`
- `core/events.lua`
- `ui/progressbar.lua`
- `ui/rewardsframe.lua`
- `version.txt`
