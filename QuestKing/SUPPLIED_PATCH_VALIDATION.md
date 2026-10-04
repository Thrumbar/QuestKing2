# QuestKing 3.1.1 Supplied Patch Validation

## Current Forever ObjectiveTracker suppression hotfix (2026-10-04)

- Used the supplied Phase 8 Native Abandon Dialog Restored archive as the base.
- Replaced the suppression-only project-ID gate with recognition of the modern
  ObjectiveTracker root/container. No global client classification changes.
- Prevents legacy Show/update hooks and mouse/parent-alpha writes on Forever's
  modern tracker; defers anonymous modern tracker children during combat.
- Preserves legacy watch-frame handling even though current Era/TBC watch
  templates also carry frame-management flags.
- Passed 12 offline suppression checks, including actual supplied Forever
  Update/dirty-callback code executed with mocked frame services.
- Parsed all 25 Lua sources with the available Lua 5.4 library and both XML
  files with an XML parser. The changed code uses Lua 5.1 syntax; an actual
  Lua 5.1 interpreter was unavailable.
- Verified all six TOCs and every other production source/asset against the
  input bytes; checked exact-case loader paths and ZIP integrity.
- The full and changed-file downloads include complete source files.
- The reported Forever build is 70205; the supplied Forever source is 70124.
  The missing callback is not identified by the log or reproduced offline.

Static/mocked result: `PASS` for this suppression change.  
Acceptance: `PARTIAL — runtime validation required`.  
Release verdict: `Release candidate`.

The live test sequence, evidence, current source matrix, and limitations are
recorded in `RELEASE_READINESS_REPORT.md`. Previous validation records follow.

## Phase 8 abandon-confirmation cleanup

- Removed the temporary QuestKing-owned confirmation dialog after the
  unprompted abandonment was attributed to another addon.
- Restored Blizzard's native confirmation and quest-item loss warning flow.
- Retained next-frame popup creation to isolate the dropdown hardware click.
- Added a pending quest-ID guard to reject duplicate queued requests.
- Retained guarded Mainline, Forever, and Classic-family fallback paths.

Static result: `PASS`

Runtime result: `PARTIAL — live abandon-confirmation validation required`

## Current Phase 8 package validation

- Base archive SHA-256:
  `77a0815d43e6c7f7c1bc15e33bd170254f82aad20037d877c0583c51c95f1995`.
- Verified ZIP CRC and safe single-root structure: 44 packaged files, no
  case-insensitive duplicates, no missing referenced production files.
- Compared all six existing TOCs: exact interface values, 27 identical
  exact-case load entries, version 3.1.1, account/per-character SavedVariables,
  and PetTracker/WorldQuestTracker optional dependencies.
- Parsed 25 Lua files with the available Lua 5.4 parser and both XML files
  with an XML parser. The phase changes no Lua, XML, TOC, font, or texture bytes.
- Read scenario and quest-cap API documentation in supplied snapshots for
  Classic Era `1.15.9.69722`, Classic TBC `2.5.6.69795`, Mists Classic
  `5.5.4.69383`, Retail `12.1.0.69933` and `12.1.5.69952`, and WoW Forever
  `1.60.1.70009`. All six specify `SCENARIO_COMPLETED(questID, xp, money)`
  and document `GetMaxNumQuestsCanAccept()`.
- The previous Phase 7 line counted 27 Lua files. That number is the count of
  manifest entries; the package contains 25 Lua files and two XML files.
- The current supplied-build matrix and client-run steps are in
  `RELEASE_READINESS_REPORT.md`. Offline acceptance is
  `PARTIAL — runtime validation required`.

## Current Phase 7 watch-frame patch

- Parsed 25/25 packaged Lua files and checked the original Phase 7 archive
  against the updated file set.
- Simulated maximum-height clipping, retained scrollbar offset, slider drag,
  live width/height changes, screen-bottom bounds, collapsed height, and
  protected scrolling deferral.
- The existing TOCs, XML, bundled assets, and external libraries remain
  unchanged. No live WoW client was available for taint and rendering checks.

## Phase 7 continuation result

The exact Phase 6 package was reviewed for performance profiling and refresh
frequency. The existing 50 ms coordinator, targeted invalidation flags, cached
population refresh, keyed row reuse, layout generations, combat reconciliation,
and optional `/qk perf` profiler already implement the planned Phase 7 source
requirements.

All refresh entry points resolve to the same queued coordinator. Burst requests
preserve the strongest pending work, including full rebuilds and independent
quest or achievement invalidation. Profiling is disabled by default and adds no
counter churn during ordinary play.

No production correction was supported by the supplied source. This package
therefore changes validation documentation only and preserves all production
files byte-for-byte from Phase 6.

### Phase 7 static checks

| Check | Result |
| --- | --- |
| Shared refresh coordinator | PASS |
| 50 ms burst coalescing | PASS |
| Strongest pending request retained | PASS |
| Targeted quest/achievement invalidation | PASS |
| Cached population refresh path | PASS |
| Keyed pooled-row reuse | PASS |
| Layout-generation anchor suppression | PASS |
| Combat data refresh and deferred reconciliation | PASS |
| Profiler disabled by default | PASS |
| Profiler command and counter coverage | PASS |
| New polling loops or broad event subscriptions | PASS — none added |

### Phase 7 acceptance result

`PARTIAL — cross-client live performance validation required`

## Previous Phase 6 continuation result

The WoW Forever compatibility package was used as the exact base. Phase 6
Classic tracker population is already implemented, so no production Lua, XML,
TOC, asset, library, SavedVariables, dependency, or load-order change was
made. This continuation updates validation documentation only.

The three-expert review confirmed the explicit population policy, the
Classic-family all-accepted default, the Retail/Forever watched default,
watch-API fallback, zero-objective row retention, collapsed-header scan
transaction, duplicate suppression, failed/completed state handling, and
actual-content dimming.

The tracker header intentionally retains the later accepted standard quest
count/capacity rule. It is not changed to the number of displayed rows because
that would regress the corrected `current/max` behavior.

## Forever compatibility result

The Phase 5 `3.1.1` release is the implementation base. Its production Lua,
XML, fonts, textures, SavedVariables declarations, dependencies, and loader
order remain unchanged.

WoW Forever `1.60.1.69913` is now packaged through
`QuestKing_Camelot.toc` with interface `16001`. The supplied Forever quest,
scenario, achievement, content-tracking, and Objective Tracker source uses the
Mainline-family contracts already guarded by QuestKing. No speculative Lua
branch or new runtime polling was added.

The active loader set now covers Retail, WoW Forever, Classic Era, Classic
TBC, and Mists Classic. Cataclysm Classic loader metadata was removed because
that superseded progression client is absent from the current supplied client
matrix.

## Static verification

| Check | Result |
| --- | --- |
| Lua 5.1 parse | PASS — 25/25 files |
| XML parse | PASS — 2/2 files |
| TOC referenced paths | PASS — no missing files |
| Exact-case TOC paths | PASS |
| Flavor TOC load order | PASS — identical across six TOCs |
| Release version | PASS — 3.1.1 in every TOC |
| Mainline interfaces | PASS — 120105 and 120100 |
| WoW Forever interface | PASS — 16001 via `QuestKing_Camelot.toc` |
| Classic Era interface | PASS — 11509 |
| Burning Crusade interface | PASS — 20506 |
| Mists interface | PASS — 50504 |
| Obsolete flavor cleanup | PASS — `QuestKing_Cata.toc` removed |
| Production Lua/XML preservation | PASS — byte-for-byte unchanged from Phase 5 |
| Protected mouse propagation | PASS — no `SetPropagateMouseClicks` call |
| Secure quest-item template | PASS — `SecureActionButtonTemplate` retained |
| Campaign QuestOffer navigation | PASS — guarded map-pin contract retained |
| Campaign Stop Tracking | PASS — exact-requirement suppression retained |
| Campaign classification | PASS — documented and guarded fallbacks retained |
| Accepted quest-cap count | PASS — supported API pairs the accepted count and capacity |
| Targeted campaign invalidation | PASS — quest-line and major-faction events retained |
| PetTracker adapter | PASS — module, optional dependency, and startup recovery retained |
| World Quest Tracker adapter | PASS — module and optional dependency retained |
| Phase 6 population policy | PASS — Automatic, Watched Only, and All Accepted retained |
| Classic all-accepted fallback | PASS — used when requested or when watch APIs are unavailable |
| Zero-objective quest rows | PASS — title row retained without objective lines |
| Collapsed-header scan | PASS — bounded expansion, reverse restoration, generated-event suppression |
| Population de-duplication | PASS — watched, world, local-world, prey, and accepted-log sources |
| Header count rule | PASS — accepted standard quests paired with accepted capacity |

## Validation boundary

Static validation confirms syntax, packaging, load order, supplied
source-level contracts, and the Phase 6 implementation state. Live client
testing remains required on Classic Era, Classic TBC, Mists Classic, Retail,
and WoW Forever for policy switching, collapsed headers, zero-objective rows,
failed/completed state, dimming, SavedVariables persistence, and tracker
rendering.
