# QuestKing 3.1.1 — Diganostic Options

Adds the requested **Diganostic** submenu for the existing performance profiler.
The submenu title uses the spelling requested.

## Installation

1. Exit WoW or log out before replacing addon files.
2. Extract the Changed Files archive into `Interface/AddOns`, allowing the
   complete replacement files to merge into your existing `QuestKing` folder.
   The Full archive provides the complete supplied addon with this patch.
3. Log in or run `/reload`. Open `/qk options` or `/qkoptions`.
4. Select **QuestKing → Diganostic** in the settings category list. A Diganostic
   button is also available at the bottom of the main QuestKing options page.

The release base is `QuestKing_3.1.1_Forever_ObjectiveTracker_Hotfix.zip`.
The full archive contains the files from that supplied base.
No manual code editing is required.

## Controls

| Button | Existing command | Behavior |
| --- | --- | --- |
| Start Profiling | `/qk perf on` | Clears counters and starts profiling. |
| Show Status | `/qk perf status` | Prints the existing performance report in chat. |
| Reset Counters | `/qk perf reset` | Clears counters and preserves the recording state. |
| Stop Profiling | `/qk perf off` | Stops profiling and retains counters for inspection. |

Profiling is off by default and remains session-only. Opening options does not
start profiling or clear counters. Panel state refreshes when it is opened or
a profiling button is clicked. The original slash commands remain available.

## In-game check

1. Confirm the submenu opens and initially reports **Profiling: Off**.
2. Click **Start Profiling**. Confirm the indicator switches to On, Start is
   disabled, and Stop becomes available.
3. Advance quest objectives or reproduce the tracker issue on Forever or Retail.
4. Click **Show Status** and capture the report printed in chat.
5. Click **Reset Counters**. Confirm the next report has zero counters and
   profiling remains On.
6. Generate another update, click **Stop Profiling**, then **Show Status**.
   Confirm the retained counters remain available.
7. Close and reopen options. Confirm the state is retained within the session.

## Change and validation scope

- Complete changed Lua file: `QuestKing/ui/optionspanel.lua`.
- Updated the single existing `QuestKing/CONSOLIDATED_CHANGELOG.md`.
- Added this installation and test document.
- TOCs, libraries, XML, assets, core profiler, and slash-command files are
  unchanged. Existing addon behavior outside these controls is preserved.
- All 25 addon Lua files passed syntax checks using Lua 5.4. The new code uses
  Lua 5.1-compatible syntax; an actual Lua 5.1 interpreter was unavailable.
- Mocked modern Settings, legacy Interface Options, and missing-subcategory
  fallback checks passed. They exercised the actual supplied profiler and
  slash-command code, button state, counter reset/retention, chat reports,
  frame reuse, and unavailable-profiler handling.
- The native panel has not been rendered inside WoW. Release status for this
  patch is **PARTIAL — in-game validation required**.
- These controls expose the existing baseline profiler. Additional protected
  action, tracker-position, and diagnostic-history recording is not included.

Input archive SHA-256: `3badfd8b09fbdff70566d11f237333f92dd9b2157905394c958c7b309ac06f24`

Updated optionspanel.lua SHA-256: `a0be7c1131100e7fc495d801e64abf4363cdb1d557dc396f5552d90649e8a47f`
