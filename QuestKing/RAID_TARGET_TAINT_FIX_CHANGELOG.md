# QuestKing 3.0.33 — Raid Target Macro Taint Fix

## Issue

BugGrabber reported:

```text
[ADDON_ACTION_FORBIDDEN] AddOn 'QuestKing' tried to call the protected function 'SetRaidTarget()'.
```

The stack reaches `SetRaidTarget()` through Blizzard's macro executor, chat edit
box parser, and target-marker slash command. QuestKing does not call
`SetRaidTarget()` directly.

The earlier item-button diagnosis was superseded by the live stack and the
supplied Blizzard 12.0.7/12.1.0 source. The current quest-item button uses a
valid secure `item:<itemID>` action and is not the macro action shown in this
failure.

## Root Cause

`ui/optionspanel.lua` registered `/qkoptions` after performing this assignment:

```lua
_G.SlashCmdList = _G.SlashCmdList or {}
```

`SlashCmdList` is Blizzard's existing shared slash-command registry. Assigning
its global reference from addon execution taints that reference even when the
right-hand side resolves to the same table.

On both supplied Mainline builds, Blizzard's chat parser imports
`SlashCmdList` before dispatching a slash command. A macro containing `/tm` or
`/targetmarker` therefore reached Blizzard's protected `SetRaidTarget()` call
through a command path carrying QuestKing taint.

## Changed Files

- `ui/optionspanel.lua`
- `RAID_TARGET_TAINT_FIX_CHANGELOG.md`
- `version.txt`

## Fix

- QuestKing now reads Blizzard's existing `SlashCmdList` table into a local.
- If the registry is unavailable, only the optional `/qkoptions` registration
  is skipped.
- QuestKing adds its own `QUESTKINGOPTIONS` entry without replacing or
  reassigning Blizzard's global table reference.
- The secure quest-item button remains unchanged, preserving functional quest
  items and its existing combat-lockdown guards.

## Compatibility

Every supplied Classic-family and Mainline interface snapshot creates
`SlashCmdList` before ordinary addons load and expects addons to add their own
entries to that table. The defensive type check retains safe failure behavior
without creating or replacing Blizzard's registry.

The change is Lua 5.1 compatible and does not alter quest rendering, quest-item
use, tracking, focus, PetTracker integration, or objective progress.
