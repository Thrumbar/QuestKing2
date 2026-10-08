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


## 3.1.1 — Classic quest-log refresh hotfix candidate (2026-10-06)

### Base and evidence

Implementation base: `QuestKing_3.1.1_Classic_Quest_Item_Hotfix_Full.zip`.
The supplied addon was retained as the authoritative implementation target.

Input SHA-256: `ba6023f015b2d6bfb4be6a40662c96e1a6bebb5f34e5e6a0916eef5b95e10166`.

The reported MoP Classic capture contained 1,733 counted quest events, of
which 1,725 (99.5%) were QUEST_LOG_UPDATE. It also recorded 1,726 tracker
refreshes, 1,724 cached population refreshes, two full rebuilds, and 1,723
per-quest display-data reads. Recording duration was not provided. These
counts identify the dominant event; they do not establish its native origin.

### Panel verdict

- Runtime reviewer: retain real event delivery and collapsed-header scans;
  reject fixed-delay suppression and discarding the next log event.
- API reviewer: match Blizzard's internal two-argument header calls. The same
  form occurs in all six supplied client snapshots, while ordinary user
  header clicks use the single-argument form.
- Performance reviewer: make the retained per-event counts visible and add
  measured recording duration and request reasons before claiming a live
  refresh-frequency improvement.

### Production changes

| File | Change |
| --- | --- |
| buttons/quest.lua | Passes `true` on both temporary ExpandQuestHeader and restoring CollapseQuestHeader calls, matching native internal usage. |
| core/core.lua | Measures elapsed recording time with GetTimePreciseSec/GetTime, freezes it on stop, and counts request reasons only while profiling. |
| core/slashcommand.lua | Reports elapsed time/rate and sorted event/request-reason breakdowns through existing status controls. |

The existing immediate scan-depth guard and every genuine quest-event handler
are retained. There is no new timer, polling loop, delayed event-drop window,
SavedVariables change, option, protected mutation, dependency, or loader edit.
Classic hidden-quest item data is still collected while headers are expanded.

### Supplied primary-source comparison

Both internal header calls use `(questLogIndex, true)` in:

| Client snapshot | Blizzard source |
| --- | --- |
| Classic Era 1.15.9.69722 | Blizzard_UIPanels_Game/QuestMapFrame.lua, QuestMapFrame_ResetFilters |
| BCC 2.5.6.69795 | Blizzard_UIPanels_Game/QuestMapFrame.lua, QuestMapFrame_ResetFilters |
| MoP 5.5.4.70032 | Blizzard_UIPanels_Game/QuestMapFrame.lua, QuestMapFrame_ResetFilters |
| Retail 12.1.0.69933 | Blizzard_UIPanels_Game/QuestMapFrame.lua, QuestMapFrame_ResetFilters |
| Retail 12.1.5.70077 | Blizzard_UIPanels_Game/QuestMapFrame.lua, QuestMapFrame_ResetFilters |
| Forever 1.60.1.70235 | Blizzard_UIPanels_Game/Mainline/QuestMapFrame.lua, QuestMapFrame_ResetFilters |

The snapshots do not contain a named second parameter or the native C
implementation. Notification suppression is an inference from the internal
call pattern and remains a live-client acceptance item.

### Offline verification

- Actual Lua 5.1 compiled all 25 complete addon Lua files.
- Both XML files parsed successfully. All six TOCs and 162 declared load
  entries (27 per manifest) retained their exact-case paths.
- Eighteen checks executed the complete changed core/profiler and slash code
  with mocked game APIs. They cover coalescing, real refresh execution,
  combat-event attribution, elapsed-time freezing, start/reset/stop behavior,
  game-clock fallback, sorted status output, no status-triggered refresh,
  profiling-off behavior, and recovery of an existing profiler table shape.
- Eight modeled scenarios executed the actual scan, dispatcher, and log/watch
  handlers. They reproduce queued feedback in the base, end it under the
  modeled native flag, preserve later genuine log/watch updates and watch
  updates during scanning, and restore several headers/depth after errors.
- Two additional probes document an unchanged model limitation: the existing
  depth guard suppresses a synchronous QUEST_LOG_UPDATE received during a
  scan in both builds. Native timing and genuine event merging cannot be
  established from these offline models.
- Modeled C-engine behavior explicitly assumes that the second argument
  prevents header notifications. The test result proves Lua routing and
  restoration under that assumption; it does not prove the native API effect.
- Production byte comparison is limited to the three listed Lua files. All
  other production sources, XML, assets, libraries, and TOCs are unchanged.

### Installation and live acceptance

1. Exit WoW. Extract either the Full archive or the Changed Files archive
   into Interface/AddOns, allowing its QuestKing folder to merge/replace the
   installed files. Both archives supply complete files; no Lua editing is
   required. Changed Files requires the supplied 3.1.1 item-hotfix base.
2. On MoP Classic, retain an accepted quest beneath a collapsed Blizzard
   quest-log header. Start `/qk perf on`, then use `/qk refresh` once to seed
   the same scan path. Leave the header collapsed and remain idle for 60
   seconds. Stop with `/qk perf off`, then print `/qk perf status`.
3. Repeat the objective-completion and turn-in reproduction. Keep at least
   one accepted quest in the log, wait for dialogs/rewards to settle, and
   observe a further 60-second idle interval. Capture the new duration,
   event breakdown, reasons, and counters.
4. Confirm objective progress still updates during combat, accepted/removed
   quest rows appear/disappear correctly, collapsed header state is restored,
   and the Classic quest-use item remains visible and usable. Capture any
   Lua, blocked-action, or taint report.

Accept only when the repeated QUEST_LOG_UPDATE/refresh growth settles after
activity, real quest and item updates remain correct, and no new error is
reported. The expanded and collapsed-header cases should both settle. Do
not interpret the combat-attribution counter alone as proof of in-combat
execution or protected-action safety.

### Acceptance result

**PARTIAL — native client validation required.** This is a release candidate,
not a claim that the live refresh stream has already been eliminated. Prior
branch observations remain evidence for the earlier build; they are not live
validation of this candidate on Era, BCC, MoP, Retail, or Forever.


## Phase 7 — MoP indexed objective-reader revision — 2026-10-06

### Panel verdict

The supplied runtime result rejects the preceding header-call candidate as a
complete MoP fix. The runtime reviewer found no recurring explicit selection
setter on the normal display path. The API reviewer supports Classic indexed
reads from native WatchFrame source. The performance reviewer rejects another
blind event-drop mechanism and requires unchanged zero-objective, hidden-row,
index-matching, error-fallback, and genuine-update behavior.

The reviewers agree that the indexed-reader revision is suitable for native
validation. They do not establish that the namespaced getter emitted the live
notification stream. The header calls could still contribute.

### Confirmed findings

The user supplied these post-candidate MoP counters:

| Measurement | Reported result |
| --- | ---: |
| Duration | 486.41 seconds |
| Requests / coalesced / refreshes | 4,310 / 45 / 4,264 |
| Refresh frequency | 8.766 per second |
| Full / cached population refreshes | 3 / 4,261 |
| Quest-log / per-quest display scans | 4 / 4,249 |
| QUEST_LOG_UPDATE / all counted quest events | 4,247 / 4,261 (99.67%) |
| Layout / anchor updates | 4,264 / 2 |
| Average / maximum tracker refresh time | 0.55 / 2.08 ms |
| Request reasons | questevent=4,259; achievement=47; quest=2; supertracking=2 |

The reasons sum to 4,310. Requests minus coalesced requests exceed recorded
refreshes by one, consistent with a queued refresh at profiling stop. The
refresh-frequency gate is **FAIL for this recorded preceding-build session**.
This confirms repeated cached objective work; it does not identify the native
endpoint generating the events. Refresh timings exclude preceding event
handlers, other addon work, and queue delay.

The ordinary source path is buttons/quest.lua:GetQuestDisplayData ->
GetQuestObjectivesText -> local GetQuestObjectives. It previously tried
C_QuestLog.GetQuestObjectives on every client before indexed reads. Explicit
selection mutations belong to click/share/abandon/completion paths.

### Supplied API evidence

The same direct Classic calls appear in all three supplied Classic snapshots,
Era 1.15.9.69722, BCC 2.5.6.69795, and MoP 5.5.4.70032:

| Blizzard source | Native call |
| --- | --- |
| Blizzard_UIPanels_Game/WatchFrame.lua:964 | GetQuestLogRequiredMoney(questIndex) |
| Same file:965 | GetNumQuestLeaderBoards(questIndex) |
| Same file:1025 | GetQuestLogLeaderBoard(j, questIndex) |

MoP WatchFrame:1023–1034 explicitly handles nil-text hidden objectives. Thus
nil text with meaningful objective metadata is not treated as an API failure.
An entirely unavailable row or malformed response still triggers fallback.
MoP QuestLogDocumentation.lua exposes the by-ID objective getter, but does not
expose GetRequiredMoney. Native getter implementation/side effects are absent
from the snapshots; availability alone does not prove purity or causation.

### Corrections and changed files

| Complete file | Current change |
| --- | --- |
| buttons/quest.lua | Classic indexed objectives first; authoritative zero counts; matching-index validation using the existing resolver; two-argument leaderboard calls; indexed money; native text/completion/hidden-row retention; backend/header counters. |
| core/core.lua | Resets the four added scalar profiler counters. Earlier elapsed-time/reason improvements are retained. |
| core/slashcommand.lua | Prints regular objective-reader indexed/modern counts and temporary header expand/restore counts. Earlier event/reason breakdowns are retained. |
| CONSOLIDATED_CHANGELOG.md | Appends this revision and the failed MoP gate. |
| SUPPLIED_PATCH_VALIDATION.md | Appends evidence, verification, and native acceptance limits. |
| RELEASE_READINESS_REPORT.md | Updates current branch gates and release status. |

The supplied quest index is forwarded from the active expanded scan and
verified against the quest ID. Both a stale hint and a wrong resolved index
are rejected. A successful empty indexed result does not call the modern
getter; unavailable, failed, or invalid indexed reads retain fallback. Both
objective and money reads receive the same verified index. Task/world-quest
readers retain modern-first behavior even when an indexed log entry exists.
Retail/task legacy fallback keeps its previous valid partial results. No new stale-data
window or event-drop rule is introduced.

Numeric progress flashes use the native x/y text when it provides counts.
Text without those numeric fields remains intact; full structured metadata
cannot be reconstructed in every locale. Classic progress bars can use the
existing percentage getter. Healthy Mainline reads retain structured data.

### Offline verification

- All 25 complete Lua files compile in actual Lua 5.1; both XML files parse.
- Twenty-one profiler checks pass, including the new backend/header counters,
  disabled behavior, reset/status, duration, coalescing, and combat attribution.
- Twenty-eight objective/event checks pass with complete compatibility, quest,
  core, and event modules loaded. Only rendering and game/engine APIs are mocked.
  They cover modeled baseline feedback, candidate settlement, genuine combat
  log/watch/completion/turn-in changes, stale/wrong indices, valid zero results,
  missing/error/invalid backend responses, hidden metadata, actual objective
  flash behavior, Retail/task metadata, money events, and collapsed item data.
  Targeted previous/candidate cases also preserve valid partial Retail/task
  fallback when modern data fails and a later indexed row raises an error.
- The objective model assumes a C getter read posts a delayed unique log event.
  Baseline remains queued after 20 refreshes; the candidate settles after one
  under that assumption. This is not proof of the native event source.
- One explicit model limitation remains: if the engine ignores the header flag,
  header notifications still sustain feedback despite indexed objective reads.
- Eight existing modeled header/event scenarios pass, including restoration
  after callback/nested errors. Their two unchanged synchronous-event guard
  probes remain limitations, not preservation passes or native assertions.
- Temporary test scripts and mocked APIs are outside the delivered addon.
- Package checks verify exact-case TOC entries, ZIP integrity, packaged Lua
  syntax, and byte-for-byte preservation outside the three Lua and three
  Markdown files listed above. All six TOCs and all libraries are unchanged.

### Runtime validation items and test procedure

1. Exit WoW and replace the QuestKing folder with the revised Full archive.
   The Changed Files archive also contains complete replacement files and
   merges onto the supplied 3.1.1 item-hotfix base or the preceding candidate.
2. On MoP, keep an accepted regular quest and start `/qk perf on`. Run
   `/qk refresh` once and remain idle for 60 seconds, then `/qk perf off` and
   `/qk perf status`. The report must now include `objective reads indexed=...`
   and `headers expand=... restore=...` so the reader revision is identifiable.
3. Repeat once with that quest's Blizzard header collapsed, then reproduce
   objective completion and turn-in with another quest remaining. Let dialogs
   and rewards settle and observe a further measured 60-second idle interval.
4. Confirm real objective progress/completion updates during combat, accepted
   and removed rows reconcile, collapsed header state remains correct, numeric
   count text/progress bars remain correct, and quest-use items still work.
   Include a money-requirement quest when available.
5. Capture the complete status including the new reader/header lines and any
   Lua/blocked-action errors. Backend counts cover buttons/quest.lua regular
   quest/tooltip reads only; separate popup/bonus-objective readers are outside
   that scope. Nonzero modern reads can be legitimate for tasks or fallback.

Acceptance requires refresh/event growth to settle after activity, with real
quest/objective/item updates still current and no new error. The indexed path
is expected for ordinary accessible Classic log rows. A healthy Era capture
from the preceding candidate does not validate this revision or the MoP gate.
Combat attribution alone does not establish protected-action safety.

### Acceptance result and remaining risks

**PARTIAL — native client validation required / Release candidate.**

The preceding MoP build failed. This revision has not run inside WoW here.
The C-getter notification and header-flag semantics remain unknown; tests
explicitly model them. If headers still generate delayed notifications, this
reader change alone cannot eliminate that feedback. The added counters make
that remaining seam visible without discarding genuine quest events.


## Current revision — Achievement refresh eligibility (2026-10-06)

### Activity evidence and interpretation

The user clarified that multiple quests were completed during the latest
1,373.58-second capture, which continues the MoP test discussion. It records
805 refreshes (0.586/second), 14 full and 791 cached refreshes, 28 quest scans,
541 objective reads, and a 0.59 ms mean / 5.76 ms maximum refresh body. Of 447
quest events, 354 are QUEST_LOG_UPDATE. These totals describe activity; they
do not establish a persistent idle loop or its absence. The lower rate than
earlier captures is observational because the activity and duration differ.

Achievement requests are 1,225 of 1,694 (72.3%), with no recorded achievement
list or criteria scans. The broad criteria handler calls the achievement queue,
which previously always requested a complete tracker presentation even when
achievement rows could not contribute content. These are request counts before
coalescing, not 1,225 independently executed refreshes. The objective-reader
and header-counter lines were not included in this paste, so backend attribution
remains open; omission alone does not prove an older installed build.

### Three-expert challenge and resolution

| Expert | Challenge | Resolution |
| --- | --- | --- |
| Runtime/protected actions | An empty initialized cache or a failed snapshot must not suppress real tracked progress; stale rows still require cleanup. | Fail open on unknown or pending state, preserve prior IDs on failed reads, keep stale-row presentation, and retain every list/world refresh. No protected operations changed. |
| Cross-version API | Classic consumes GetTrackedAchievements varargs; the supplied reader omitted that backend and its fixed-width helper could truncate a long list. | Use the complete validated bulk result, with modern GetTrackedIDs first when available. Existing optional indexed fallbacks are retained conservatively. |
| Performance/reliability | Avoid replacing refreshes with per-event list scans, timers, or hidden-state staleness. | Check existing state only on progress events, always invalidate display data, and rely on the existing mode/minimize presentation and list-settling callbacks. |

### Supplied native contracts

Classic Era 1.15.9.69722, BCC 2.5.6.69795, and MoP 5.5.4.70032 each use
`Blizzard_UIPanels_Game/WatchFrame.lua:669` to pass all GetTrackedAchievements
returns to the display function. Lines 754 and 773 count/select every vararg.
The current reader uses pcall with an explicit return count, distinguishing a
successful empty result from malformed/nil-hole/failing results.

Retail 12.1.0.69933, PTR 12.1.5.70077, and Forever 1.60.1 build 70235 use
`Blizzard_AchievementObjectiveTracker.lua:99-102` to retrieve a numeric ID array
with C_ContentTracking.GetTrackedIDs(Enum.ContentTrackingType.Achievement).
Its generated ContentTracking documentation confirms that argument and table
return. Successful native results are authoritative; errors retain fallback.
No new standalone Cataclysm client snapshot or native runtime pass is claimed.

### Changed complete files

Only `buttons/achievement.lua` changes beyond the preceding indexed-reader
candidate. Relative to the supplied item-hotfix archive, the complete changed
files are `buttons/achievement.lua`, `buttons/quest.lua`, `core/core.lua`,
`core/slashcommand.lua`, `CONSOLIDATED_CHANGELOG.md`,
`SUPPLIED_PATCH_VALIDATION.md`, and `RELEASE_READINESS_REPORT.md`.

There are no new production files. All other supplied bytes, all six TOCs,
libraries, XML, and assets are preserved. The Changed Files ZIP contains these
seven entire replacement files; the Full ZIP contains the complete addon.

### Verification results

- 42 actual-module achievement checks passed under Lua 5.1.
  They cover native legacy/modern lists, complete varargs, authoritative empty,
  malformed/error recovery, startup, list settling, visible tracked progress,
  hidden-mode invalidation/reopening, and stale-row removal. Game APIs, engine
  delivery, rendering widgets, and protected C behavior are mocked.
- All six supplied tracked-list source patterns match. All 25 packaged Lua
  files compile in Lua 5.1, both XML files parse, all 162 exact-case load entries
  resolve across the six unchanged TOCs, and both ZIPs pass integrity and
  packaged-source equality checks. One consolidated changelog is retained.
- The preceding indexed-reader revision's recorded 21 profiler checks and
  28 objective/event checks concern files retained byte-for-byte here. Its
  header/C-getter notification assumptions and native validation limits remain.

### Native acceptance procedure

1. Replace the QuestKing folder with this Full ZIP, then `/reload`. Existing
   settings remain usable. Confirm `/qk perf on` and `/qk perf status` include
   `objective reads indexed=... modern=...` and `headers expand=... restore=...`.
2. In combined mode with no tracked achievements, record 60 seconds of idle
   time, then a separate interval completing multiple quests. After turn-ins
   settle, record another separate 60-second idle interval. Use `/qk perf on`
   to start/reset each interval and `/qk perf off`, `/qk perf status` to finish.
   Include the complete output and any Lua errors.
3. Track one achievement, advance a criterion, and confirm prompt text/count
   and completion updates while visible, including combat where applicable.
   Untrack it and confirm its row and title count clear promptly.
4. Repeat progress while in quests/raids mode and while minimized. Return to
   combined/achievements mode or expand the tracker; criteria must immediately
   reflect current progress. Login/zone with tracked achievements must restore
   them regardless of the initial display mode.
5. Preserve the earlier real-quest gates: combat objective progress, accepted
   and removed rows, collapsed Blizzard headers, and usable quest-item buttons.

The no-tracked case should stop requesting presentation from broad criteria
events once a valid native list has settled. List changes and world recovery
may legitimately retain a small number of achievement requests. No fixed
refresh target is imposed on active play or visible tracked progress.

### Current verdict and remaining limits

**Release candidate — PARTIAL; native runtime validation required.** The latest
multiple-quest capture is substantially healthier, but it predates this new
eligibility guard and cannot validate it. An offline runtime cannot prove native
idle settlement, timing, taint, secure item use, or combat visual correctness.
All real quest and achievement list events remain connected; the patch adds no
event-drop window, polling, or delayed suppression.


## Current revision — Cached quest header-access preflight (2026-10-06)

### Latest native MoP evidence

| Metric | Reported result |
| --- | --- |
| Duration / refresh rate | 548.72 seconds / 0.590 per second |
| Requests / coalesced / executed | 339 / 15 / 324 |
| Full / cached refreshes | 7 / 317 |
| Quest scans / objective data reads | 8 / 343 |
| Regular objective backend attempts | Indexed 345 / modern 0 |
| Header expand / restore attempts | 294 / 294 |
| Layout / anchors / rows | 324 / 6 / +4, -3 |
| Mean / maximum refresh body | 0.62 / 2.14 ms |
| Quest events / QUEST_LOG_UPDATE | 339 / 314 |
| Combat quest events | 0 |
| Achievement requests / scans | 0 / 0, 0 |

The user explicitly identifies MoP Classic and the last patch. Reader counters
now show indexed access, and no achievement request reason is recorded. The
rate remains similar to the preceding multiple-quest capture (0.586/second).
The current report includes three accepts and two turn-ins, so it is not an
isolated idle measurement. Zero combat events cannot validate combat behavior.

Balanced header attempts establish matching call counts, not native restoration
success or event causation. QUEST_LOG_UPDATE is 314 of 339 quest events (92.6%);
header expansion is requested on a large fraction of refreshes. Source confirms
that the preceding cached-data and item scans expanded every collapsed header
before determining whether their existing rows required it. The counters do
not establish that those calls generated the recorded notifications.

### Panel challenge and correction

| Expert | Challenge | Resolved implementation |
| --- | --- | --- |
| Runtime/protected actions | Avoid losing hidden quests, using stale indices, or delaying combat/item updates. | Preflight the callback's exact eligible rows; re-resolve inside the callback; retain fallback and every full discovery scan. No protected operation changed. |
| API | Neither namespace presence nor supplied documentation proves collapse-independent indexing or interchangeable index projections. | Require actual matching quest-ID access, including the legacy title getter at the same index when available. Never assume a modern API bypasses collapsed headers. |
| Performance/reliability | Header/event correlation is insufficient to claim loop elimination; some expansion may be required. | Remove only unnecessary mutations. Preserve real event handlers, invalidation, and full-build recovery. Do not add suppression windows, polling, or timers. |

The new `CachedQuestRowsNeedHeaderExpansion` helper is used only by
`RefreshCachedQuestRows` and `RefreshQuestItemDisplayData`. Task and available
campaign rows are skipped. Item preflight also skips rows without display data.
It returns a decision without retaining indices or changing any row. An
inaccessible, invalid, or mismatched ordinary row keeps the old scan path.

### Primary source grounding

Each supplied Era 1.15.9.69722, BCC 2.5.6.69795, and MoP 5.5.4.70032
WatchFrame display function reads its watched index, title/quest ID, required
money, objectives, and quest item directly. It does not expand headers during
that display function. Its separate click handler explicitly expands a header
and reacquires the index because expansion sorts indices. These patterns
support attempting validated direct access; they do not prove that every
unwatched or collapsed quest remains accessible.

The supplied MoP generated QuestLog documentation marks QUEST_LOG_UPDATE as a
unique event. It does not specify the native notification behavior of header
mutations. Retail's index and shown-entry contracts likewise do not establish
collapse-independent access. The current patch therefore makes its decision
from matched live data and retains expansion when the match cannot be proven.

### Changed files and verification

Only `buttons/quest.lua` changes beyond the preceding achievement candidate.
The three existing Markdown records are appended. Relative to the supplied
item-hotfix archive, the complete changed files remain four Lua files and three
Markdown files; all other bytes, all six TOCs, libraries, XML, and assets are
unchanged. Full and Changed Files ZIPs contain entire replacement files.

35 regression scenarios passed under actual Lua 5.1.
The harness loads complete production modules and compares preceding and
current scan behavior with explicit engine/API/UI models. It covers accessible
rows with unrelated collapsed headers, genuinely inaccessible rows, mismatched
index projections, reordered indices, task/campaign eligibility, item refresh,
full population discovery, error restoration, and real objective/event updates.
Modeled delayed header notifications are identified as assumptions; preserving
the inaccessible fallback can also preserve modeled feedback.
The result is 35 passing scenarios, one explicitly retained modeled limitation,
and zero failures.

All 25 packaged Lua sources compile, both XML files parse, all 162 exact-case
load entries resolve across six unchanged TOCs, both ZIPs pass integrity and
source equality, and one consolidated changelog is retained. The preceding
achievement implementation is byte-identical and retains its 42 recorded
mocked regression results and native validation limits.

### Native acceptance procedure

1. Replace QuestKing with the revised Full ZIP and `/reload`. In combined mode,
   use `/qk perf on`, remain idle for 60 seconds, then `/qk perf off` and
   `/qk perf status`. Include all backend/header and request-reason lines.
2. Repeat a separate 60-second idle interval with the Blizzard quest headers
   open, then with one collapsed header. Record whether that header contains
   a quest displayed by QuestKing. Counts need not be zero when expansion is
   required; no fixed threshold is imposed on active play.
3. Advance objectives and use quest items for accessible and collapsed-header
   quests. Confirm current counts/completion, icons/charges, preserved header
   states, accepted/removed rows, and normal full-population discovery.
4. Repeat a genuine objective update during combat and confirm post-combat
   item/layout reconciliation. This capture contains no combat evidence.
5. Keep the preceding tracked-achievement test: track, advance, untrack, and
   reopen after hidden-mode progress. The achievement code is unchanged.

### Current acceptance result

**Release candidate — PARTIAL; native runtime validation required.** This
correction avoids proven unnecessary header work when live indices already
match. If an actual quest is inaccessible while its header is collapsed, the
fallback remains active and the candidate does not promise loop elimination.
Native idle settling, header notifications, secure item use, taint, and combat
visual correctness cannot be established by mocked engine behavior.


## Phase 7 continuation — Native six-client results and supertracking correction — 2026-10-08

### Native evidence from the preceding header-access revision

The supplied six-client capture provides the following measurements. These
are observations of the previously delivered revision, before this correction.
Each valid idle capture records zero tracker requests and zero refreshes.

| Client | Build | Idle duration / refreshes | Activity duration / refreshes | Activity refreshes/sec | Header expand / restore |
| --- | --- | --- | --- | ---: | --- |
| Classic Era | 1.15.9.69722 | 193.48 s / 0 | 3,169.55 s / 59 | 0.019 | 0 / 0 |
| BCC | 2.5.6.69795 | 329.77 s / 0 | 1,564.48 s / 47 | 0.030 | 0 / 0 |
| MoP Classic | 5.5.4.70032 | 481.11 s / 0 | 995.29 s / 144 | 0.145 | 16 / 16 |
| WoW Forever | 1.60.1.70235 | 674.99 s / 0 | 4,683.98 s / 226 | 0.048 | 0 / 0 |
| Retail | 12.1.0.69933 | 0.00 s / 0 — inconclusive | 1,448.79 s / 5,518 | 3.809 | 0 / 0 |
| Retail PTR | 12.1.5.70077 | 431.70 s / 0 | 1,626.72 s / 2,660 | 1.635 | 0 / 0 |

MoP's idle capture includes one indexed objective read outside any recorded
tracker refresh. The counter also covers callers outside the refresh body;
this single read does not demonstrate a refresh loop. MoP activity has 155
indexed and zero modern regular-objective reads, 83 QUEST_LOG_UPDATE events,
and 16 header pairs across 144 refreshes. The preceding activity report had
294 pairs across 324 refreshes. Conditions and activity differ, so this is
scoped evidence of quiet idle and reduced observed header work, not a measured
causal speedup or proof of native header-event origin.

Era/BCC use the indexed reader in these captures; Retail uses the modern
reader. Forever and PTR have both reader types represented. This does not by
itself identify which individual quests used each backend. All six have
balanced header counts. The activity rates for Era, BCC, MoP, and Forever do
not resemble the earlier persistent refresh flood.

Retail records 22,728 requests, of which 21,869 (96.2205%) are supertracking;
PTR records 10,961 requests, of which 10,536 (96.1226%) are supertracking.
These are request shares before coalescing, not shares of executed refreshes.
The old common reason does not distinguish native changed events, path events,
or calls from the focus module. The native source of the notifications is
not established by this capture.

QUEST_DATA_LOAD_RESULT accounts for 1,867 Retail and 1,515 PTR quest events.
The dispatcher records those events before its relevance filter; only 305 and
181 total questevent requests are reported. These raw events are not equivalent
to refreshes. No correction to that relevance filter is supported here.

### Panel verdict

- Runtime reviewer rejected a blanket path-event no-op: it could lose pending
  accepted-quest focus when distance becomes usable without another POI event.
  The reviewer also found that committing identity before a failed render could
  suppress a later recovery. The final implementation retains existing queued
  Pre/Post execution and commits only after a successful tracker generation.
- API reviewer verified the supplied Retail, PTR, and Forever supertrack API
  documents. Quest ID and highest-priority type may legitimately be nil; both
  supertracking events have no payload. Failed or malformed reads stay unknown.
  Legacy quest-focus fallback and an absent optional type API remain supported.
- Performance reviewer reproduced the unconditional path refresh in complete
  modules, challenged the mutable active cache as a comparison signature, and
  verified request/refresh reductions with a separate committed snapshot.

Agreement: the correction passes supplied-source and modeled regression gates.
Native reduction and feature correctness remain runtime gates.

### Confirmed findings

1. **Unchanged path notifications request presentation work.** In the previous
   core/events.lua, Events.SUPER_TRACKING_PATH_UPDATED at lines 903–905 always
   calls UpdateTracker(false, "supertracking"). The shared coordinator queues a
   cached tracker refresh and layout even when focused quest/type and pending
   focus work are unchanged. The complete addon contains no C_Navigation or
   GetNextWaypointForMap consumer; row sorting and bonus focus icons use quest
   identity. The supplied SuperTrackManagerDocumentation.lua documents the
   distinct changed/path events at lines 193–203. The deterministic modeled
   effect is repeated layout work; Retail/PTR are the noisy observed clients.
   Severity: performance cost. The captures alone do not attribute all native
   supertracking requests to this handler.
2. **Active-cache comparison can consume a focus change before repaint.** The
   previous QuestKing:OnSuperTrackedQuestChanged at supertracking.lua lines
   547–564 compares against activeSuperTrackedQuestID. Getters and setters
   synchronize that same cache before the notification. A modeled change from
   quest 101 to 102 followed by such a call and SUPER_TRACKING_CHANGED leaves
   the old sort order without requesting a refresh. A separate committed
   identity fixes this and retains type-change presentation. Affected branches:
   clients using the shared focus module and those cache calls. Severity:
   stale focus presentation when no other refresh occurs. Native occurrence
   timing is not inferred from the supplied counters.

### Corrections

The path handler delegates to QuestKing:OnSuperTrackingPathUpdated. It requests
an existing cached refresh only for unknown presentation/read state, changed
quest/type identity, an objective-driven PostCheck flag, or uncontested pending
or invalid focus that requires the existing PreCheck recovery. The handler
does not set native focus or mutate UI. Real quest, POI, completion, removal,
turn-in, item, presentation, and combat reconciliation handlers remain active.

PreCheck stages three scalars after its normal focus decisions, including the
invalid-focus early return. Core commits them after a successful layout and
before PostCheck. Aborted quest generations retain the prior committed state;
PostCheck focus changes retain their queued follow-up. Neither ordinary getters
nor setters update this presentation snapshot. No path-coordinate cache,
allocation per event, delay window, timer, polling, or visibility-based filter
was added. Existing scalar cache assignments and the coordinator are retained.

Three counters are reset and printed even at zero:

- superTrackingChangedEventCount: raw dispatched SUPER_TRACKING_CHANGED events.
- superTrackingPathEventCount: raw dispatched SUPER_TRACKING_PATH_UPDATED events.
- superTrackingPathRefreshRequestCount: requests emitted by the path handler,
  including its conservative dispatcher fallback; these are not executions.

The new status line is:

```text
supertracking events changed=<count> path=<count> path requests=<count>
```

These counters remain separate from quest and combat event totals, and collect
nothing when profiling is disabled.

### Changed files and packaging

This continuation changes four complete Lua files: core/core.lua,
core/events.lua, core/supertracking.lua, and core/slashcommand.lua. It appends
this entry, the changelog entry, and the release-readiness entry. Previous
quest/header/objective and achievement corrections remain byte-identical.
Relative to the authoritative supplied implementation ZIP, the cumulative
Changed Files ZIP contains nine complete files, and the Full ZIP contains the
same 45-file set. All six TOCs, libraries, other code/assets, and XML are
preserved. Version remains 3.1.1 because TOC edits are forbidden.

### Offline validation

Actual Lua 5.1 executed seven complete modules: compatibility, quest,
achievement, supertracking, core, slash commands, and events. Native APIs,
frames, renderer, distance availability, and timer delivery are mocked.
The first run saved stdout and exact source hashes: **41 scenarios passed,
zero failed**. A separate actual core/slash profiler harness passed **25 checks**.

| Modeled path notifications after startup | Previous additional requests / refreshes | Candidate additional requests / refreshes |
| --- | ---: | ---: |
| 200 events in one coalesced burst | 200 / 1 | 0 / 0 |
| 1,000 events across separate flushes | 1,000 / 1,000 | 0 / 0 |

The candidate still counts all injected path events. Cases also cover getter
and setter cache overwrites; changed identity/type; unchanged changed events;
pending distance without POI; contested tracking and release; invalid focus
and the PreCheck early return; objective flags and genuine combat quest events;
PostCheck mutation after commit; modeled synchronous setter notification;
uninitialized presentation; missing, failed, malformed, nil, and legacy reads;
missing/throwing path handlers; persistent renderer failure with bounded retry;
read-only status, counter reset, and disabled recording. Actual cached quest
sorting and objective data updates run; visible UI rendering is mocked.

All 25 Lua files compile in Lua 5.1; both XML files parse; six unchanged TOCs
reference 162 valid exact-case paths. ZIP membership, complete-file contents,
CRC, original input bytes, and append-only documentation are checked. Earlier
header and achievement test records remain applicable to their unchanged code.
No offline result establishes native timing, taint, protected behavior, or the
source of the user's notifications.

### Native test procedure

Prioritize Retail and PTR for this revision. After loading the complete
replacement files, let startup settle. Capture two separate recordings:

1. `/qk perf on`, leave the tracker idle for at least 60 seconds, then
   `/qk perf off` and `/qk perf status`. Retail needs a timed baseline because
   the supplied zero-second recording is inconclusive.
2. `/qk perf on`, move toward a focused quest, advance an objective, complete
   and turn in a quest, change focus between two quests, clear focus, and switch
   to and from a user waypoint or available-quest offer. Include objective
   progress during combat where possible. Then stop and print status.

Include the new supertracking line with the existing event/reason breakdowns.
Many path notifications may legitimately be received during movement; confirmed
unchanged identity should not produce matching path requests or layouts. Real
focus changes must reorder regular quests and update bonus/world focus icons;
newly accepted quests must still recover focus when distance becomes available;
waypoint or other contested tracking must not be overwritten. Objective text,
secure item alignment, post-combat reconciliation, and the existing collapsed
header fallback must remain correct. Report any observed Lua or blocked-action
error with its stack. The quiet idle results on the other four clients are
retained as evidence of the preceding revision; this candidate's native focus
and combat behavior has not been observed here.

### Acceptance result and remaining risks

- Prior revision timed idle frequency: **PASS** on Era, BCC, MoP, Forever, PTR;
  **inconclusive** on Retail.
- Prior revision activity flood: **FAIL** for Retail/PTR; the raw request
  attribution is insufficient to identify each native event subtype.
- Current supplied-source, packaging, and mocked regression gates: **PASS**.
- Current native frequency and feature gate: **PARTIAL — runtime validation
  required**. Final verdict: **Release candidate**.

Unknown/failed reads, persistent render failure, or invalid/inaccessible focused
quest data deliberately retain recovery refreshes. These conditions can still
produce path requests. No guarantee that every supertracking request is removed
is made. Native event timing, visible combat/secure behavior, and the earlier
inaccessible-header feedback limitation remain unproved offline.
