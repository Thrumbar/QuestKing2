# QuestKing 3.1.1 Release Readiness Report

## Current Phase 1 — Protected mouse and combat row layout

**Date:** 2026-10-09  
**Phase:** 1 — Protected mouse handling and combat updates  
**Implementation base:** `QuestKing_3.1.1_Quest_Start_Alert_Hotfix_Full.zip`  
**Input SHA-256:** `7f7b4e119007b4a61ca62eef4729f7ee9f1ed536111db575a41fe15c522cdbf2`  
**Acceptance:** `PARTIAL — runtime validation required`  
**Release verdict:** **Release candidate**

The requested quest-alert update is the implementation base. The older attached
Classic Quest Item Hotfix is a reference, not the output base. The newer supplied
client snapshots replace the older build labels in the audit. Differences in
reference build numbers are not treated as defects.

## Panel Verdict

- **Runtime reviewer:** The existing tracker-wide combat stop was already
  removed. However, retaining only the secure-item row's anchor is insufficient:
  a new row can be placed directly over it. Keep the displayed anchor chain
  stable when a combat-time population or ordering change needs deferral.
- **API reviewer:** A blanket combat stop would regress objective text updates.
  The supplied Retail and Forever definitions also allow secret results from
  `IsProtected` and `IsAnchoringRestricted`. Check those results before
  comparing them, following the pattern already used by the integration adapters.
- **Performance reviewer:** Do not freeze every ordinary combat layout or add a
  polling loop. Check for a changed row sequence first, reuse the displayed-order
  array, and retain the existing refresh coordinator and regen reconciliation.

The panel accepts the scoped implementation and offline results. Live protected
execution, taint, and actual rendering remain unverified.

## Confirmed Findings

### QK-COMBAT-LAYOUT-01 — Mixed deferred and movable anchors overlap

**Severity:** Medium.  
**Affected:** The shared layout path on all supported clients, when a secure-item,
protected, or anchor-restricted row is present and row membership or order changes
during combat.

**Input evidence:** `core/core.lua`, `LayoutRequestedButtons`, lines 525–599;
`ui/watchbutton.lua`, `WatchButton:Wipe`, beginning at line 371.

The input code defers an item row's external anchor but continues anchoring other
rows using the new request order. Starting with ordinary row A followed by item
row B, insertion of ordinary row C between them places C below A while B keeps
its existing anchor below A. Both rows therefore occupy the same position.

Executing the actual input layout function with mocked frames reproduced equal
top coordinates of **-33** for C and B. This proves the layout inconsistency in
the tested state; it does not reproduce a game-client protected-action error.

**Correction:** Retain the displayed order while that connected layout needs
combat deferral. Continue rendering requested, unprotected existing rows. Hide
new ordinary rows until reconciliation, and retain old anchor-owner rows in
the pool so their frames cannot be reassigned underneath secure-item anchors.

### Security-state contract correction

**Input evidence:** `core/core.lua`, `IsProtectedFrameSafe` and
`IsAnchoringRestrictedSafe`, lines 221–238; `ui/watchbutton.lua`,
`IsProtectedFrame`, lines 136–143.

The input helpers compared returned security values outside `pcall` without
first checking whether they were secret. Retail and Forever's supplied
`SimpleScriptRegionAPIDocumentation.lua` marks both methods with
`SecretReturnsForAspect = { Enum.SecretAspect.ObjectSecurity }`.
The methods exist with boolean return contracts in all six supplied snapshots.

In Retail 12.1.5's supplied definition, `IsAnchoringRestricted` begins at line
376 and `IsProtected` at line 516. Era, TBC, and Mists retain ordinary boolean
definitions for these calls.

The helpers now treat secret or failed reads conservatively and defer the
affected operation. Synthetic secret markers verify this routing; they do not
simulate WoW's secret-value enforcement. No live secret-comparison exception is
claimed as reproduced.

## Lifecycle Review

| Operation | Combat classification | Current handling |
| --- | --- | --- |
| Ordinary pooled row creation and acquisition | Safe only while the row is unprotected | Uses the existing ordinary Button path; deferred new rows remain hidden |
| Secure item creation, parenting, click setup, attributes, size and visibility | Deferred during combat | Existing guards in `ui/itembutton.lua` retained |
| Row and title mouse changes | Deferred for protected or unreadable security state | Existing mouse helper now recognizes secret results |
| Quest text, objective state, completion text and title counts | Continues during combat | Existing data refresh remains active |
| Existing ordinary row content geometry | Continues while the row is unprotected | Published anchor sequence retains its spacing as row heights change |
| Population or ordering changes affecting secure anchors | Deferred together | New displayed-order retention prevents partial-chain overlap |
| Retained row release and reuse | Deferred until reconciliation | `Wipe` preserves anchor owners; removed ordinary rows can be hidden |
| Tracker scrolling, movement and viewport sizing | Deferred during combat | Existing tracker presentation guards retained |
| PetTracker attachment to the last quest row | Deferred with the changed row layout | Adapter respects the shared deferred-layout flag |
| Post-combat reconciliation | Uses existing regen event and queued refresh | Publishes requested order, shows new rows and releases retired rows |

A removed secure-item row can remain displayed until combat ends because its
secure button cannot be hidden or reassigned then. Its frame retains the original
identity throughout that interval.

## Corrections and Changed Files

| File | Change |
| --- | --- |
| `core/core.lua` | Tracks displayed order; defers connected row membership/order changes; guards secret security-state results |
| `ui/watchbutton.lua` | Retains anchor-owner rows during combat; guards secret protected-state results |
| `ui/pettracker.lua` | Waits for the same deferred quest-row layout before repositioning its section |
| `CONSOLIDATED_CHANGELOG.md` | Adds this correction to the single changelog |
| `RELEASE_READINESS_REPORT.md` | Records this phase, evidence, test matrix and limitations |
| `SUPPLIED_PATCH_VALIDATION.md` | Records the current checks |

All six TOCs, load order, XML, fonts, textures, dependencies and SavedVariables
declarations remain byte-identical to the quest-alert base. No bundled library
directory exists in this archive; no external or Blizzard library is changed.
The alert fix's `buttons/popup.lua` and the existing secure-item implementation
remain byte-identical.

The changed-files archive contains complete replacement files under
`QuestKing/`. The full archive contains the complete addon. No manual code
merging or new runtime helper is required.

## Offline Validation

**16 regression cases passed** using the actual modified layout coordinator,
pool/mouse methods, and PetTracker deferral predicate with mocked frame services:

1. Initial spacing and insertion before a secure-item row.
2. Repeated combat refreshes retaining the displayed order.
3. Objective row-height growth retaining spacing and updated text.
4. Removal of an ordinary anchor-owner row without early recycling.
5. Reappearance of a retained row during the same combat.
6. Removal of an item row without reassignment or secure-item removal.
7. Tracker collapse and post-combat row release.
8. Publication of reordered and newly requested rows after combat.
9. Full combat layout updates when no restricted anchor chain is involved.
10. Conservative handling of secret protected-state results.
11. Conservative handling of secret anchor-state results while text updates.
12. Failed or missing security methods.
13. Deferred mouse changes and post-combat application.
14. Pool reuse clearing old quest IDs and click handlers.
15. PetTracker attachment waiting for the deferred quest-row layout.
16. One queued callback for ten refresh requests, current combat text/title
    counts, and one post-combat reconciliation without polling.

All **25 Lua sources** parse with the available **Lua 5.3** parser. Both XML files
parse. The changed code uses Lua 5.1 syntax; an actual Lua 5.1 runtime/parser was
not available for this turn, so a Lua 5.1 execution result is not claimed.
All six TOCs resolve **27 exact-case load entries** in the same order.

No live client was available. Mocks do not establish the absence of taint,
protected-action failures, secret-value exceptions or visual clipping in WoW.
No measured CPU or memory improvement is claimed.

## Supplied-Source Matrix

These are source and package checks, not six separate in-game test results.

| Client | Supplied snapshot | Frame security contracts | Lua/XML and existing loader paths | Live quest/combat display |
| --- | --- | --- | --- | --- |
| Classic Era | 1.15.9.69722 | Checked; ordinary booleans | Checked | Not run |
| Classic TBC | 2.5.6.69795 | Checked; ordinary booleans | Checked | Not run |
| Retail | 12.1.0.69933 | Checked; ObjectSecurity secret aspect | Checked | Not run |
| Retail/PTR | 12.1.5.70077 | Checked; ObjectSecurity secret aspect | Checked | Not run |
| Mists Classic | 5.5.4.70032 | Checked; ordinary booleans | Checked | Not run |
| WoW Forever | 1.60.1 (70235) | Checked; ObjectSecurity secret aspect | Checked | Not run |

No new Cataclysm or Wrath snapshot was supplied in this turn. Existing compatibility
paths remain unchanged; no fresh snapshot-specific or live result is asserted for
those clients. Right-click menus, live options and scenario/task behavior are
preserved from the requested base and are not declared newly validated here.

## Test Procedure

1. Exit WoW and replace the installed `Interface/AddOns/QuestKing` folder with
   the folder in the full archive, then start the client.
2. With a quest-starting item in bags, accept its quest. Confirm the offer alert
   disappears and stays gone after bag updates and a reload.
3. Track a quest with a usable quest-item button plus ordinary quests. Enter
   combat and advance an objective. Check the text and title counts.
4. While in combat, change quest focus or tracking when the client allows it.
   Confirm existing rows and item icons stay aligned, without overlap. Newly
   requested rows in a deferred chain should appear after combat.
5. Leave combat. Confirm the requested order, retired-row removal and new rows
   reconcile without another reload. Use the quest-item button again.
6. Repeat collapse/restore and row additions/removals during combat. When
   PetTracker is installed, confirm its section remains below the quest rows.
7. Capture the client build and any new BugSack/BugJar or protected-action
   errors. Repeat on the clients used for the release.

## Acceptance Result and Remaining Risks

**PARTIAL — runtime validation required. Release candidate.**

The source correction and offline checks are complete. The Phase 1 live
acceptance checks in the supplied recommended-order prompt remain outstanding.
That prompt says: “Do not proceed to Phase 2 until these conditions are met.”
This package therefore completes the scoped Phase 1 correction and leaves
subsequent phase work at the requested acceptance gate.

Remaining checks are actual combat rendering, secure-item alignment/use, mouse
behavior, PetTracker placement, and deterministic reconciliation in WoW.

## Earlier validation records

## Current hotfix — Forever ObjectiveTracker suppression

**Base:** `QuestKing_3.1.1_Phase_8_Native_Abandon_Dialog_Restored.zip`  
**Input SHA-256:** `a69c868d2a079a126e3f1f0a5755228cab3695d6e2eb3f04857576204009692d`  
**Reported client:** Forever 1.60.1, build 70205, interface 16001.  
**Available Forever source:** 1.60.1, build 70124.  
**Verdict:** Release candidate; `PARTIAL — runtime validation required`.

### Panel verdict

- **Runtime reviewer:** Remove the legacy tracker interception path from
  Forever's modern UI and defer changes to anonymous tracker children in
  combat. The reported C `Show` stack does not identify its failing callback;
  offline tests cannot establish that this was the sole cause.
- **API reviewer:** Select suppression by the ObjectiveTracker implementation,
  rather than treating every non-Mainline project ID as a legacy watch frame.
  Do not globally reclassify Forever or modify Blizzard scripts. Era/TBC watch
  frames also carry management flags, so those flags alone cannot select the
  modern suppression path for every individual frame.
- **Reliability reviewer:** Reuse the existing event frame, timer coalescing,
  and post-combat refresh. Add no polling, hooks, dependencies, globals, or
  repeated quest scans. Preserve all other production files.

### Confirmed finding

**Severity:** Medium — tracker suppression compatibility.  
**Affected path:** A modern ObjectiveTracker on a client whose project ID is
not `WOW_PROJECT_MAINLINE`.

In the input `core/util.lua`, `IS_MAINLINE` is computed at line 40. The
`ApplySuppressionToTrackerRoot` and `InstallTrackerVisualHooks` gates at lines
740 and 851 select safe alpha-only suppression and skip native tracker hooks
only for that project ID. Otherwise they allow legacy Show/update hooks and
mouse/parent-alpha writes on the discovered tracker frames, including its
anonymous Header. The already-computed `modernManaged` local did not change
that routing.

The supplied Forever `Blizzard_ObjectiveTracker.xml` derives the root from
`RightManagedFrameTemplate`, `EditModeObjectiveTrackerSystemTemplate`, and
`ObjectiveTrackerContainerTemplate`. Its `Blizzard_ObjectiveTracker.lua`
`ObjectiveTrackerFrameMixin:Update`, lines 62–85, calls `self.Header:Show()`
at line 68. Its container installs a dirty callback in `OnLoad`, and
`Blizzard_SharedXML/MixinUtil.lua` lines 339–343 call the stored method from
that callback. These locations match the reported stack. This supports a
correction to QuestKing's tracker routing, but does not prove the identity or
origin of the nil callback.

The supplied Era/TBC `Blizzard_UIParent/UIParent.xml` gives legacy watch
frames `layoutParent` and `isRightManagedFrame` too. The correction therefore
recognizes the modern ObjectiveTracker root/container at the environment
level, while retaining the separate legacy watch-frame behavior.

### Corrections and changed files

- `core/util.lua`: adds `UsesModernBlizzardTracker`; uses it for suppression
  and hook installation; includes all collected modern tracker children in
  combat deferral. General project flags and private-tooltip routing remain
  as in the supplied base.
- `CONSOLIDATED_CHANGELOG.md`: appends this hotfix to the single changelog.
- `RELEASE_READINESS_REPORT.md`: records evidence and the validation boundary.
- `SUPPLIED_PATCH_VALIDATION.md`: records this hotfix's checks.

The changed-files archive contains complete replacement files under the same
`QuestKing/` root. The full archive contains the entire addon. No code merging
or helper installation is required.

### Offline validation

All 25 Lua files parsed using the available Lua 5.4 library. The changed code
uses Lua 5.1 syntax and no new runtime APIs; an actual Lua 5.1 interpreter was
not available, so no Lua 5.1 execution result is claimed. Both XML files parse.
All six TOCs retain exact bytes, load order, and 27 exact-case source entries.
Every other production file, including existing quest-item code, matches the
base byte-for-byte. This archive contains no bundled library directory, and
no external library or Blizzard source is modified.

Twelve offline checks passed:

1. Baseline demonstrates legacy hooks and mouse writes on a mocked modern
   tracker with a synthetic non-Mainline project ID.
2. Patched modern suppression uses alpha only; the supplied Forever Update
   method and dirty-callback code execute against mocked frame services.
3. An unknown project ID takes the modern path when its tracker is modern.
4. Mainline retains modern alpha-only suppression.
5. Combat defers the root and anonymous children; the registered regen event
   reconciles them afterward.
6. Disabling suppression restores root and child alpha.
7. Legacy quest-watch hiding/restoration retains its behavior, including the
   management fields present in the supplied Era/TBC templates.
8. The older WatchFrame suppression path remains available.
9. Late `Blizzard_ObjectiveTracker` loading selects modern handling.
10. A loaded container mixin prevents hooks before its root frame exists.
11. Twenty refresh requests coalesce to one callback; unrelated addon loads
    schedule no suppression refresh.
12. Missing `C_Timer` retains isolated, immediate modern suppression.

These tests use mocked hooks/frame methods. They do not reproduce the game's
C Show implementation, secure execution, taint propagation, or actual screen
layout. They do not reproduce the original nil callback.

### Current supplied-source matrix

| Client | Source build | Tracker source | Scoped offline result | Live result |
| --- | ---: | --- | --- | --- |
| Classic Era | 1.15.9.69722 | Legacy QuestWatchFrame | Source checked; legacy path tested | Not run |
| Classic TBC | 2.5.6.69795 | Legacy QuestWatchFrame | Source checked; legacy path tested | Not run |
| Forever | 1.60.1.70124 | Modern managed ObjectiveTracker | Source checked; suppression/callback tested | Not run |
| Retail | 12.1.0.69933 | Modern managed ObjectiveTracker | Template checked; modern path tested | Not run |
| Retail | 12.1.5.70077 | Modern managed ObjectiveTracker | Template checked; modern path tested | Not run |
| Reported Forever client | 1.60.1.70205 | Modern tracker identified in error log | Exact source not supplied | Retest required |

Mists, Wrath, and Cataclysm retain existing source routing. No new live or
snapshot-specific result is claimed for those clients in this hotfix.

### Client test procedure

1. Exit WoW. Copy the `QuestKing` folder from the full archive into
   `Interface/AddOns`, replacing the existing folder, then restart. For the
   changed-files archive, overwrite its four matching files in the existing
   installation. Existing hooks must be cleared by restarting or `/reload`.
2. Record `/dump WOW_PROJECT_ID, WOW_PROJECT_MAINLINE` and the client build.
3. With QuestKing enabled, accept a quest, track/untrack it, advance an
   objective, and change zones. Check for recurrence of the line-68 error.
4. Outside combat, toggle **Hide entire Blizzard Objective Tracker** off/on.
   Confirm restoration and suppression both work. Open/close Edit Mode when
   available and repeat a quest update.
5. In combat, advance an objective. Confirm QuestKing text remains current.
   Leave combat and confirm tracker suppression and deferred layout reconcile
   without another reload or protected-action error.
6. If the same error persists, repeat with QuestKing as the only third-party
   addon, then with QuestKing disabled. Capture both results and the project
   ID output. If the ID equals `WOW_PROJECT_MAINLINE`, the original legacy
   hook path was already bypassed; the nil callback needs separate diagnosis.

### Acceptance result and remaining risks

`PARTIAL — runtime validation required`; **Release candidate**.

The exact build-70205 callback and live project ID are unknown. A Blizzard or
other-addon callback failure remains possible. Existing bugs outside tracker
suppression are outside this hotfix. Earlier validation records follow below
and describe their own bases and test environments.

## Phase 8 abandon-confirmation cleanup

The unprompted abandonment was traced to another addon. QuestKing again uses
Blizzard's native abandon confirmation and item-loss warning dialogs. Popup
creation remains deferred until the next frame and duplicate requests remain
guarded.

Only `buttons/quest.lua` and the packaged validation documents changed. TOCs,
XML, libraries, assets, SavedVariables, loader order, scroll behavior, and all
other production Lua remain unchanged.

### Required live check

Right-click an abandonable quest, choose **Abandon Quest**, and verify the
native Blizzard dialog appears. Confirm item-loss warnings when applicable,
then verify **No** and Escape retain the quest and **Yes** abandons it.

### Acceptance result

`PARTIAL — live abandon-confirmation validation required`

## Current Phase 8 — Validation on the watch-frame scroll-fix base

**Input:** `QuestKing_3.1.1_Phase_7_Watch_Frame_Height_Scroll_Fix.zip`  
**Input SHA-256:** `77a0815d43e6c7f7c1bc15e33bd170254f82aad20037d877c0583c51c95f1995`  
**Result:** `PARTIAL — runtime validation required`; retain the **release
candidate** designation.

### Three-reviewer verdict

- **Protected-action reviewer:** The scroll, viewport, and resize functions
  guard presentation work during combat. That is source evidence, not a proof
  that the client cannot produce a protected-action or taint error. Keep the
  release at candidate status until an actual combat overflow test passes.
- **Client-contract reviewer:** The existing flavor loaders resolve all 27
  production load entries with exact capitalization. The six supplied snapshots
  document the scenario completion payload as `questID, xp, money` and expose
  `GetMaxNumQuestsCanAccept`; QuestKing consumes the former in that order. The
  older Cataclysm Classic branch has no dedicated loader in this release.
- **Performance reviewer:** No new source-level defect was proven by this
  packaging check. Preserve the coalesced refresh implementation and measure
  scrolling and quest-event bursts with `/qk perf` in a running client.

### Package checks

| Check | Result |
| --- | --- |
| ZIP integrity, one safe `QuestKing/` root, duplicate and case-folded paths | PASS — 44 packaged files |
| Flavor manifests and metadata | PASS — six existing TOCs, identical 27-entry load order and SavedVariables/dependencies |
| Referenced Lua/XML and exact filename case | PASS — 25 Lua, two XML, no missing or unreferenced production files |
| Lua parser and XML parse | PASS — all Lua files parse with the available Lua 5.4 parser; both XML files parse |
| Lua 5.1 release compatibility | Prior validation retained; no Lua source changed in this phase. Live client load remains required. |
| Supplied API documentation | PASS — scenario payload order and accepted-quest-cap API appear in all six snapshots |
| TOC, production Lua/XML, fonts, and textures | Preserved byte-for-byte from the scroll-fix base |

The prior report's “27 Lua files” count was incorrect: 27 is the number of
loader entries. This phase does not claim that a Lua parser or source archive
can run the game's protected UI, prove frame layout, or verify server-driven
quest updates.

### Current supplied-client matrix

`Package PASS` checks the existing interface metadata, exact load paths,
syntax, and selected supplied API contracts. Every behavior column still
requires a real client session.

| Branch | Supplied build | Interface | Load/package | Quest display | Combat updates | Right-click | Options and scrolling | Scenario/task |
| --- | --- | ---: | --- | --- | --- | --- | --- | --- |
| Classic Era | 1.15.9.69722 | 11509 | Package PASS; client pending | Pending | Pending | Pending | Pending | Check supported content in client |
| Classic TBC | 2.5.6.69795 | 20506 | Package PASS; client pending | Pending | Pending | Pending | Pending | Check supported content in client |
| Mists Classic | 5.5.4.69383 | 50504 | Package PASS; client pending | Pending | Pending | Pending | Pending | Pending |
| Retail | 12.1.0.69933 | 120100 | Package PASS; client pending | Pending | Pending | Pending | Pending | Pending |
| Retail | 12.1.5.69952 | 120105 | Package PASS; client pending | Pending | Pending | Pending | Pending | Pending |
| WoW Forever | 1.60.1.70009 | 16001 | Package PASS; client pending | Pending | Pending | Pending | Pending | Pending |

Cataclysm Classic is not in this current supplied-build matrix. The existing
archive has no `QuestKing_Cata.toc`. Its status is **not validated**; do not
describe it as a currently covered loader. The attached instruction prohibits
TOC changes, so this phase does not add one.

### Required client run

1. Install the archive's single `QuestKing` folder on each listed client;
   confirm the AddOns screen loads version 3.1.1 without an interface warning.
2. Populate the watch frame beyond its maximum height. Scroll with the mouse
   wheel and slider; confirm the titlebar does not move, all rows remain
   reachable, and scrolling persists across an ordinary objective refresh.
3. Change watch-frame width and maximum height, minimize and expand, and move
   the titlebar near the screen bottom. Confirm there is no clipped or
   overlapping row and the header position remains fixed.
4. Repeat with a usable quest item and PetTracker content. In combat, advance
   an objective and attempt to scroll; confirm text progress stays current and
   no protected-action error occurs. After combat, confirm pending layout and
   secure item buttons reconcile without `/reload`.
5. Test right-click tracking, a live setting change, and scenario/task content
   where that content exists. Run `/qk perf reset`, `/qk perf on`, perform an
   objective burst, then capture `/qk perf status` and any taint log.
6. On WoW Forever, record the live `WOW_PROJECT_ID` and test the same sequence.

### Files changed in this phase

- `CONSOLIDATED_CHANGELOG.md`
- `RELEASE_READINESS_REPORT.md`
- `SUPPLIED_PATCH_VALIDATION.md`

**Production code:** none. **TOCs/libraries:** unchanged. **Remaining risk:**
the listed runtime results cannot be established from the supplied source
snapshots or from an offline syntax check.

## Current Phase 7 watch-frame patch

The watch frame now uses a saved maximum height, a screen-bottom limit, and a
scrollable content area. The existing width setting controls quest-row width;
the frame includes a narrow scrollbar margin. Its titlebar stays in place when
content or the maximum height changes. Quest rows, quest-item buttons, and the
PetTracker section share the clipped content area.

Earlier static verification parsed all 25 Lua files and compared the updated archive
with the Phase 7 base. Simulated layout checks covered overflow, wheel/slider
offsets, width and height changes, combat deferral, screen limits, and collapse.
TOCs, XML, packaged libraries, fonts, and textures are unchanged.

**Acceptance: PARTIAL — live-client layout and protected-action checks required.**
Exercise overflow and quest-item use in and out of combat on each supported
client, including a PetTracker section and a titlebar anchored near the screen
bottom. Protected scrolling is intentionally unavailable during combat.

## Current continuation — Feature Coverage Phase 7

The exact QuestKing 3.1.1 Feature Coverage Phase 6 package was used as the
Phase 7 base. Static review confirms that the established performance system
already satisfies the planned source-level requirements, so no production Lua,
XML, TOC, asset, or library change is justified.

The tracker uses one 50 ms coordinator for refresh bursts. Pending requests
merge full-rebuild, post-combat, quest-data, achievement-data, and performance
event flags before a single refresh runs. Targeted invalidation preserves
cached quest populations when only objectives, achievements, scenarios,
timers, presentation, or supertracking change. Keyed pooled-row reuse and
layout generations avoid unnecessary row churn and anchor writes.

The optional `/qk perf` profiler remains disabled by default. When enabled, it
reports request and coalescing counts, full and cached refreshes, quest and
objective scans, achievement scans, bag and autocomplete scans, layout and row
pool activity, refresh timing, and refresh-per-event ratios.

### Phase 7 acceptance result

`PARTIAL — cross-client live performance validation required`

Live validation must measure event bursts, objective updates in combat,
achievement changes, population-policy switches, and timed scenario content on
Classic Era, Classic TBC, Mists Classic, Retail, and WoW Forever. Static review
cannot provide live frame timing, event density, taint propagation, or server
quest-state behavior.

## Previous continuation — Feature Coverage Phase 6

The WoW Forever compatibility package was revalidated as the exact Phase 6
implementation base. All three source reviewers agree that Classic tracker
population is already implemented and that no additional production Lua patch
is justified.

Static validation confirms:

- Automatic, Watched Only, and All Accepted are explicit policies.
- Automatic resolves to all accepted quests on recognized Classic-family
  clients and watched quests on Retail and WoW Forever.
- Missing watch APIs fall back to all accepted quests.
- Collapsed headers, zero-objective quests, duplicate sources, failed quests,
  and actual-content dimming are handled by the existing code.
- The title retains the established accepted-standard-quest count/capacity
  rule rather than changing when a quest is merely watched or unwatched.

This continuation changes only the three packaged validation documents.
Production Lua, XML, TOCs, assets, libraries, SavedVariables declarations,
dependencies, and load order remain byte-for-byte unchanged.

### Phase 6 acceptance result

`PARTIAL — cross-client live validation required`

Live validation must exercise all three policies on Classic Era, Classic TBC,
Mists Classic, Retail, and WoW Forever. The Forever engine-assigned
`WOW_PROJECT_ID` also remains a live-client confirmation item.

## Current release — WoW Forever compatibility

QuestKing 3.1.1 now includes a dedicated WoW Forever loader for client
`1.60.1.69913`: `QuestKing_Camelot.toc`, interface `16001`. The supplied
Forever source identifies the game type as `camelot` and uses the modern
Mainline-family quest and Objective Tracker architecture. The engine-assigned
project ID is not present in the extracted Lua source and therefore remains a
live-client confirmation item.

Source comparison found no QuestKing production Lua or XML change required.
The Forever definitions used by QuestKing for quest logs, scenarios,
achievements, content tracking, supertracking, and protected UI handling match
the supplied Retail `12.1.5` contracts or are already capability-guarded. This
release therefore adds no Forever-only event, timer, hook, polling path, or
global.

The current supported loader set is Retail, WoW Forever, Classic Era, Classic
TBC, and Mists Classic. `QuestKing_Cata.toc` and obsolete interface values
`120007` and `11508` were removed. The generic `QuestKing.toc` remains as the
fallback/source manifest.

### Current supplied-client matrix

| Client | Supplied build | Interface | Static result | Runtime result |
| --- | ---: | ---: | --- | --- |
| Retail | 12.1.5.69848 | 120105 | PASS | Live validation required |
| Retail | 12.1.0.69875 | 120100 | PASS | Live validation required |
| WoW Forever | 1.60.1.69913 | 16001 | PASS | Live validation required |
| Classic Era | 1.15.9.69722 | 11509 | PASS | Live validation required |
| Classic TBC | 2.5.6.69795 | 20506 | PASS | Live validation required |
| Mists Classic | 5.5.4.69383 | 50504 | PASS | Live validation required |

### Current acceptance result

`PARTIAL — WoW Forever live-client validation required`

The remaining boundary is Blizzard's live client: static source validation
cannot reproduce protected execution, taint propagation, server quest state,
or SavedVariables persistence across a full client restart.

## Post-Phase 8 campaign continuation compatibility

QuestKing 3.1.1 includes the five compatibility corrections identified after the recent
campaign continuation and quest-cap changes. Unaccepted campaign quests now
use Blizzard's QuestOffer map-pin supertracking contract; right-click opens a
dedicated Stop Tracking menu without executing left-click navigation; and
per-character suppression is keyed to the exact active requirement and cleaned
when that requirement changes.

Campaign classification now uses documented quest classification, parent
campaign-header, campaign ID, and campaign API signals. The title count now
pairs Blizzard's accepted standard-quest count with the accepted standard-quest
capacity. Targeted quest-line and major-faction events force continuation
rebuilds without adding campaign polling to ordinary objective refreshes.

The related Blizzard contracts are unchanged between supplied Mainline
12.0.7.68367 and 12.1.0.68569. Classic-family branches retain guarded behavior
when campaign or QuestOffer APIs are unavailable.

## Post-Phase 8 pooled-row creation mouse-state hardening

QuestKing 3.0.49 closes the remaining creation-time exception to the Phase 1
mouse-state policy. `WatchButton:Create()` still called the protected
`EnableMouse` API directly for the pooled row body and its title button even
though later row reuse already used `SetMouseEnabledSafe()`.

Both initial states now use the same combat-lockdown and frame-protection
guard. The body and title cache fields are written only when the API call
succeeds. If a row is created on a protected path during combat, the desired
state remains uncached and the existing render/post-combat reconciliation
applies it later. Click registration and secure quest-item ownership are
unchanged.

## Post-Phase 8 Mainline tooltip render-result propagation

QuestKing 3.0.48 corrects the result contract at the protected
`C_TooltipInfo` rendering boundary. `AddPrivateTooltipDataLine()` previously
treated a successful `pcall` as a rendered line even when the addon-owned
`AddLine` or `AddDoubleLine` method returned `false` because the pooled row
could not establish usable fonts.

The caller now accepts a line only when the protected call succeeds and the
renderer explicitly returns `true`. If all candidate lines are rejected, the
item tooltip remains hidden. This changes no Blizzard tooltip, widget,
comparison-tooltip, secure-frame, event, or Classic-family behavior.

## Post-Phase 8 Mainline tooltip font initialization

QuestKing 3.0.47 corrects the initialization order of the addon-owned Mainline
tooltip line pool. A newly created FontString previously received
`SetText("")` in `AcquireMainlineTooltipLine()` before
`SetMainlineTooltipLineFont()` ran in the caller. Since the FontStrings are
intentionally created without a Blizzard tooltip template, the first hover
could raise `FontString:SetText(): Font not set`.

The line pool now establishes and verifies both left and right fonts before any
text operation. It first uses the intended Blizzard font object when that
object resolves to a usable font. If it does not, QuestKing uses its packaged
Source Sans Pro font. A row whose font cannot be established is not activated
or laid out. The Classic-family tooltip path is unchanged.

## Post-Phase 8 Mainline tooltip ownership isolation

QuestKing 3.0.46 completes the Mainline tooltip boundary correction begun in
3.0.44. Mainline no longer creates `QuestKingTooltip` from
`GameTooltipTemplate`. It uses an ordinary addon-owned frame, FontStrings,
textures, anchors, and line pool.

This removes QuestKing tooltip creation, display, and cleanup from Blizzard
`GameTooltip`, `TooltipComparisonManager`, `ShoppingTooltip`, embedded item
tooltip, and `UIWidgetManager` state. Read-only `C_TooltipInfo` retrieval and
secret-value filtering remain in place. Classic-family clients retain the
legacy `GameTooltipTemplate` path for their legacy item-tooltip APIs.

Focused validation confirms that the Mainline path:

- creates no `GameTooltip` object;
- accepts sanitized single and double text lines and reward textures;
- rejects secret text and secret height results before arithmetic;
- supports all five configured tooltip anchors and tooltip scaling; and
- hides and clears without invoking Blizzard tooltip or widget cleanup.

## Post-Phase 8 protected mouse-propagation correction

QuestKing 3.0.45 removes both `SetPropagateMouseClicks(false)` calls from
pooled watch-button creation. Mainline 12.1 documents the method as protected
and restricted; checking that the method exists does not authorize an addon to
call it. Row and title clicks remain registered normally, and the existing
quest-ID context-menu guard retains single-open behavior.

## Post-Phase 8 Mainline tooltip taint correction

QuestKing 3.0.44 added one Mainline-only runtime correction after the Phase 8
release candidate. QuestKing's private tooltip no longer calls the Blizzard
population methods that can process or register UI widgets. It retrieves
tooltip text through `C_TooltipInfo` and adds sanitized text lines directly to
the QuestKing-owned tooltip.

The correction does not replace, hook, reparent, restyle, or write state onto
Blizzard `GameTooltip`, `UIWidgetManager`,
`UIWidgetTemplateTextWithStateMixin`, Area POI pins, or Blizzard tooltip widget
containers. Classic-family clients keep their guarded legacy population path.

## Phase 8 — Packaging and Cross-Version Release Validation

### Panel verdict

- **Runtime and protected-action expert:** No new Lua correction is justified.
  The Phase 1 narrow deferral and Phase 7 coalesced update paths remain intact.
  Live combat and taint tests are still required.
- **Cross-version Blizzard API expert:** The current compatibility guards match
  the supplied branch contracts. Explicit flavor TOCs are required so each
  client receives its exact interface value.
- **Performance and reliability expert:** Packaging changes must not add
  runtime files, hooks, events, timers, or polling. The completed Phase 8
  correction changes only loader metadata and release documentation.

**Panel result:** `PARTIAL — runtime validation required`

### Confirmed findings

#### P8-01 — Literal build-time version token in the install-ready archive

- **File:** `QuestKing.toc`
- **Control flow:** The game reads the TOC directly when the folder is installed.
- **Effect:** An archive not processed by the release builder displays
  `@project-version@` instead of a real addon version.
- **Affected branches:** All.
- **Severity:** Low packaging defect.
- **Correction:** Replaced the token with `3.0.43` in every release TOC.
- **Validation:** Exact metadata comparison across all packaged TOCs.

#### P8-02 — One fallback TOC carried unrelated flavor interface values

- **File:** `QuestKing.toc`
- **Control flow:** Flavor clients select a flavor-specific TOC when present;
  otherwise they fall back to the base TOC.
- **Effect:** The supplied package did not provide a dedicated TOC for every
  advertised client family, and BCC/Mists package metadata was missing.
- **Affected branches:** Classic Era, BCC, Cataclysm Classic, Mists Classic.
- **Severity:** Medium release-loader defect.
- **Correction:** Added `QuestKing_Mainline.toc`,
  `QuestKing_Vanilla.toc`, `QuestKing_TBC.toc`,
  `QuestKing_Cata.toc`, and `QuestKing_Mists.toc`.
- **Validation:** Exact interface, load-order, dependency, SavedVariables, and
  file-path comparison for every TOC.

### Static validation results

| Check | Result |
| --- | --- |
| Lua 5.1 syntax | PASS — 25/25 |
| XML syntax | PASS — 2/2 |
| Mainline tooltip taint-boundary harness | PASS — normal-data and no-data fallback paths |
| Mainline tooltip font-order harness | PASS — no `SetText` before two verified fonts |
| Protected mouse-propagation audit | PASS — no QuestKing runtime call sites |
| Mainline `C_TooltipInfo` source contract | PASS — 12.0.7 and 12.1.0 |
| Global-write audit | PASS — only declared slash/XML entrypoints |
| Exact-case TOC paths | PASS — 27/27 in each flavor TOC |
| `core\AutoComplete.lua` capitalization | PASS |
| Optional dependencies | PASS — PetTracker, WorldQuestTracker |
| SavedVariables | PASS — account and per-character declarations preserved |
| Load order | PASS — identical across all flavor TOCs |
| Missing declared files | PASS — none |
| Case-insensitive duplicate source paths | PASS — none |
| Archive root | PASS — one `QuestKing` directory |
| Unsafe archive paths | PASS — none |
| ZIP integrity | PASS |
| Packaged-source equality | PASS |

### Cross-version test matrix

`Static PASS` means the package, syntax, load paths, and supplied API contracts
passed inspection. It does not replace launching that client.

| Branch | Build | Load | Quest display | Combat updates | Right-click | Options | Scenario/task features |
| --- | ---: | --- | --- | --- | --- | --- | --- |
| Classic Era | 1.15.8.65888 | Static PASS | Static PASS; live required | Static PASS; live required | Static PASS; live required | Static PASS; live required | Not available in ordinary branch content; guarded |
| BCC | 2.5.5.67157 | Static PASS | Static PASS; live required | Static PASS; live required | Static PASS; live required | Static PASS; live required | Not available in ordinary branch content; guarded |
| BCC | 2.5.5.68101 | Static PASS | Static PASS; live required | Static PASS; live required | Static PASS; live required | Static PASS; live required | Not available in ordinary branch content; guarded |
| BCC | 2.5.6.68575 | Static PASS; interface 20506 | Static PASS; live required | Static PASS; live required | Static PASS; live required | Static PASS; live required | Not available in ordinary branch content; guarded |
| Cataclysm Classic | 4.4.2.60895 | Static PASS | Static PASS; live required | Static PASS; live required | Static PASS; live required | Static PASS; live required | Not available in ordinary branch content; guarded |
| Mists Classic | 5.5.4.68159 | Static PASS | Static PASS; live required | Static PASS; live required | Static PASS; live required | Static PASS; live required | Static PASS; live required |
| Mainline | 12.0.7.68367 | Static PASS | Static PASS; live required | Static PASS; live required | Static PASS; live required | Static PASS; live required | Static PASS; live required |
| Mainline | 12.1.0.68569 | Static PASS | Static PASS; live required | Static PASS; live required | Static PASS; live required | Static PASS; live required | Static PASS; live required |

### Runtime validation items

Run the following on every applicable branch:

1. Install only the `QuestKing` folder and confirm the AddOns list shows
   version `3.1.1` without an out-of-date warning.
2. Log in with accepted quests and confirm the expected population policy,
   title count, dimming, objectives, completed rows, and zero-objective quests.
3. Enter combat and advance an objective. Confirm text and counts update during
   combat and no blocked/forbidden action is reported, including
   `SetPropagateMouseClicks`.
4. Leave combat and confirm deferred row anchors, mouse state, item buttons,
   and visibility reconcile without `/reload`.
5. Right-click one quest and test each enabled context-menu action once.
6. Change font, row, completed-objective, item-button, background, border,
   lock, and drag settings; confirm immediate propagation.
7. On Mists/Mainline, test an ordinary scenario, a completed scenario, bonus
   criteria, and reward display.
8. On Mainline, test a World Quest, a true bonus objective, and a task displayed
   as a normal objective.
9. With PetTracker installed, confirm its block matches QuestKing width and
   survives login, zoning, combat, enable, and disable transitions.
10. On Mainline, hover a QuestKing quest-item button and a quest-start item
    popup, then hover an Area POI whose tooltip includes a Story Variant
    TextWithState widget. Confirm the tooltip renders without
    `Blizzard_UIWidgetTemplateTextWithState.lua:35` and without QuestKing taint.
11. With World Quest Tracker installed on Mainline, confirm its panel attaches
    beneath QuestKing, follows movement/scale/height, and restores its native
    anchor when the integration is disabled.
12. Run `/qk perf reset`, `/qk perf on`, exercise a representative quest-event
    burst and one combat objective update, then record `/qk perf status`.
13. On Mainline, finish a campaign step without accepting the next quest.
    Left-click its continuation row and confirm the QuestOffer pin and
    navigation arrow select that offered quest.
14. Right-click the continuation row, choose **Stop Tracking**, and confirm the
    menu does not execute left-click navigation. Advance or complete that
    requirement and confirm stale suppression does not hide a later one.
15. Track/untrack accepted quests and enter/leave a World Quest area. Confirm
    the title numerator changes only when a standard quest is accepted,
    abandoned, or turned in.
16. Unlock a continuation through quest-line progress or major-faction renown
    and confirm it updates without zoning or `/reload`.

### Changed files

- `buttons/quest.lua`
- `core/core.lua`
- `core/events.lua`
- `core/util.lua`
- `ui/watchbutton.lua`
- `QuestKing.toc`
- `QuestKing_Mainline.toc`
- `QuestKing_Vanilla.toc`
- `QuestKing_TBC.toc`
- `QuestKing_Cata.toc`
- `QuestKing_Mists.toc`
- `CONSOLIDATED_CHANGELOG.md`
- `RELEASE_READINESS_REPORT.md`
- `SUPPLIED_PATCH_VALIDATION.md`

Release history is retained only in `CONSOLIDATED_CHANGELOG.md`; superseded
per-feature changelogs and the duplicate `version.txt` ledger are intentionally
not packaged.

Five Lua runtime files changed: `buttons/quest.lua`, `core/core.lua`,
`core/events.lua`, `core/util.lua`, and `ui/watchbutton.lua`.
The supplied-source validation also updates only BCC loader metadata from
interface `20505` to `20506`; it adds no runtime path, hook, event, or polling.

### Acceptance result

`PARTIAL — runtime validation required`

### Remaining risks

- Static source inspection cannot prove absence of live execution taint.
- Static source inspection cannot measure real client refresh timings.
- Optional-addon startup and combat transitions require both external addons
  in a live Mainline client.

### Final verdict

`Release candidate`


## 3.1.1 Classic quest item button hotfix — 2026-10-06

### Scope and base

This hotfix uses `QuestKing_3.1.1_Diganostic_Options_Full.zip` as its complete
base. The reported issue is on Classic: an item works in bags, fails when
clicked in QuestKing, and its icon can require a watch toggle to appear.
The earlier sections of this report describe earlier releases.

Input archive SHA-256:
`e38c5884675a0bc217ce8959ac5cc3e136d10a1ff4ebee4f43c3c8246bf8bfd9`.

### Review verdict

| Review focus | Source finding | Correction |
|---|---|---|
| Protected actions | XML registers AnyUp, but every supplied SecureTemplates.lua can select mouse-down through ActionButtonUseKeyDown. | Explicit false useOnKeyDown attribute; retain the inherited secure item handler. |
| Classic API and identity | Item lookup occurs after expanded quest headers are restored; a displayed quest can then lack a valid visible log index. | Capture item data during the population scan; retain quest/item IDs and validate live indices before native lookups. |
| Refresh cost and recovery | BAG_UPDATE_DELAYED refreshes only quest-start popups, so active-item changes can wait for another quest/watch event. | Refresh item metadata in the existing handler and render only on a change, sharing any popup refresh. |

The missing-icon reproduction proves the collapsed-header path. It does not
prove that every delayed icon has the same cause, or that the client's native
item API requires a quest to be watched. The patch does not alter watch lists
or infer quest associations from bag quest-starter metadata.

### Changed files

- `ui/itembutton.xml`: initializes the secure click phase to mouse-up.
- `ui/itembutton.lua`: permits cached item data without a visible log index;
  maintains stable quest identity, native index validation, item-ID fallbacks,
  combat deferral, chat links, and pool cleanup.
- `buttons/quest.lua`: captures item data inside the existing expanded-header
  scan, renders that data after header restoration, and provides the targeted
  item-metadata refresh and verified index resolver. The index predicate is
  shared rather than allocating a new closure for each range check.
- `core/events.lua`: checks active item metadata on the existing delayed bag
  event. An item-only change requests a cached render without invalidating
  objectives; a simultaneous popup change uses the same refresh request.
- `CONSOLIDATED_CHANGELOG.md` and `RELEASE_READINESS_REPORT.md`: appended the
  hotfix entry and this verification record.

All other supplied files are retained byte-for-byte, including all six TOCs
and the complete diagnostic-options implementation. There are no new libraries,
production files, SavedVariables, repeating timers, or bag scans.

### Offline validation

Nineteen checks passed in Lua 5.1. These include three reproductions of the
supplied base's failure paths, the corrected visibility/click/refresh checks,
and syntax parsing of all 25 addon Lua sources. Both XML files are well formed.

The behavior checks execute the complete changed addon Lua modules in a
mocked Classic environment. The secure-dispatch checks execute the actual
item parser, item action, and click-phase functions from each supplied client
snapshot, with the protected C item-use endpoint mocked. Both action-bar click
settings dispatch the corrected item once. Modified chat-link and right-click
inputs do not dispatch item use.

The regression cases also cover:

- an unwatched accepted quest inside a collapsed zone header;
- acquisition, unchanged item data, charge changes, and item removal on bag
  events, without objective scans in the targeted item refresh;
- one refresh request for simultaneous popup and active-item changes;
- retained header states and unchanged watch lists;
- no header polling or recurring missing-index refresh requests;
- reordered quest indices without reading another quest's item;
- combat deferral of secure reassignment, removal, and creation;
- post-combat reconciliation and reuse without a previous item's attributes;
- show-item-when-complete visibility semantics;
- Watched Only population;
- tooltip and chat-link operation without a visible quest index.

### Client snapshot matrix

| Branch | Supplied build | Secure dispatch in Lua 5.1 | API/source review | Live client |
|---|---|---|---|---|
| Classic Era | 1.15.9.69722 | PASS, both click settings | PASS | Not run |
| Burning Crusade Classic | 2.5.6.69795 | PASS, both click settings | PASS | Not run |
| Mists Classic | 5.5.4.70032 | PASS, both click settings | PASS | Not run |
| Retail | 12.1.0.69933 | PASS, both click settings | PASS | Not run |
| Retail PTR | 12.1.5.70077 | PASS, both click settings | PASS | Not run |
| WoW Forever | 1.60.1, build 70235 | PASS, both click settings | PASS | Not run |

The source checks verify the click-phase attribute and the existing special-item
contracts, plus the C_Container.GetItemCooldown and C_Item.IsItemInRange fallback
signatures. No new Cataclysm source snapshot was supplied, so this hotfix does
not claim a new Cataclysm runtime or source-matrix pass.

### In-game acceptance procedure

1. Close WoW, replace the QuestKing folder using the full hotfix archive, and
   restart. Keep the existing saved settings.
2. On the affected Classic client, set **Tracker Quest Population** to
   **Automatic** or **All Accepted**. Accept a quest with a usable item without
   manually watching it. Confirm the icon appears beside its displayed quest.
3. Collapse the quest's zone header in Blizzard's quest log. Confirm the icon
   remains present and usable from QuestKing with a valid target and location.
4. Repeat item use with the action-bar mouse-down setting enabled and disabled.
   Confirm each click uses the item once and restore the preferred setting.
5. Move the item between bags, obtain/use additional charges where applicable,
   and remove the item. Confirm its icon/count updates without a watch toggle.
6. Use an already configured quest-item button in combat. Confirm no blocked
   action. Any new icon or protected reassignment discovered during combat must
   reconcile when combat ends without reload.
7. Confirm tooltip, Shift-click chat link, completed-quest item visibility,
   scrolling, and a second quest's item after the first row is removed.
8. If using **Watched Only**, confirm untracked quests remain excluded and
   tracked quests still show their item. Diagnostic controls must still work.

### Acceptance result and limitations

`PARTIAL — runtime validation required` / `Release candidate`.

A live WoW client was unavailable. Hardware input authorization, server-side
quest-item readiness, actual bag effects, secure ancestry, and taint cannot be
proven by an offline Lua runtime. Test the affected Classic quest before
considering the reported issue resolved in game.

## Quest-starting item alert hotfix — 2026-10-09

### Scope and base

Base: `QuestKing_3.1.1_Classic_Quest_Item_Hotfix_Full.zip`.
This is a focused correction to the item-start offer alert. It does not advance
the broader feature-coverage plan or certify unrelated addon features.

### Panel verdict

| Review position | Finding and resolution |
| --- | --- |
| Runtime and protected actions | Fix popup data and acceptance identity; add no secure attributes, frame methods, hooks, or combat restrictions. Live client behavior still needs confirmation. |
| Client APIs | Name matching cannot prove which quest an item starts. All six supplied client snapshots document native `ItemQuestInfo.questID`, `isActive`, and `C_QuestLog.IsOnQuest`; use exact quest identity first. |
| Performance and reliability | Avoid new polling or broad quest-event bag scans. Recheck only cached candidate slots when popup state is dirty, keep existing bag scans, and deduplicate identical item IDs within a scan. |

**Acceptance:** `PARTIAL — runtime validation required`.  
**Release status:** `Release candidate`.

### Confirmed findings

1. **Accepted quest item remains an offer — Medium.** In the supplied
   `buttons/popup.lua`, `ScanQuestStartItemPopups` (lines 867–909) detects
   candidates from a fixed item list but reads no native item quest metadata.
   `ShouldHideQuestStartItemPopup` (lines 672–688) depends on a special item,
   prior tracker-click association, eight hardcoded quest links, or text
   matching. `OnQuestStartItemQuestAccepted` (lines 1111–1139) has no general
   link for an item accepted from bags. If that item remains in inventory and
   its name differs from the quest title/objectives, subsequent scans recreate
   or retain its offer row. The offline harness reproduced this path on the
   supplied base.

2. **Pending item click can be associated with the wrong quest — Medium.**
   The supplied acceptance handler associates any pending tracker item click
   with the next accepted quest without comparing quest IDs. A player can
   close the item offer, then accept an unrelated quest; the starter becomes
   suppressed by an unrelated association. The correction requires the
   item's quest ID to match the accepted quest ID.

These defects affect the shared popup code on every branch using the relevant
item. They do not establish that every quest-starting item is affected.

### Corrections and full changed files

- `buttons/popup.lua`: cache each detected starter's bag slot, native quest ID,
  and active state; validate cached slot identity before reading metadata;
  hide accepted or completed linked quests; use `IsOnQuest` independently of
  visible quest-log indices; associate acceptance by exact quest ID; preserve
  identity through a tracker click and further loot; recheck cached slots on
  popup-state invalidation.
- `CONSOLIDATED_CHANGELOG.md`: append this entry to the existing single
  changelog.
- `RELEASE_READINESS_REPORT.md`: append this focused validation record.

No TOC, XML, library, other Lua file, SavedVariables declaration, or addon
version marker changes. Full contents of all changed files are included in the
changed-files archive. The complete archive retains the `QuestKing/` root.

### Supplied-client contract matrix

| Client snapshot | Native container quest metadata | `C_QuestLog.IsOnQuest` | Acceptance payload | Actual client run |
| --- | --- | --- | --- | --- |
| Classic Era 1.15.9.69722 | Verified | Verified | questIndex, questId | Required |
| BCC 2.5.6.69795 | Verified | Verified | questIndex, questId | Required |
| Mists Classic 5.5.4.70032 | Verified | Verified | questIndex, questId | Required |
| Mainline 12.1.0.69933 | Verified | Verified | questId | Required |
| Mainline/PTR 12.1.5.70077 | Verified | Verified | questId | Required |
| Forever 1.60.1 (70235) | Verified | Verified | questId | Required |

Evidence: each supplied snapshot's
`Blizzard_APIDocumentationGenerated/ContainerDocumentation.lua` declares
`GetContainerItemQuestInfo(containerIndex, slotIndex)` returning
`ItemQuestInfo`, whose fields include a nullable numeric `questID` and a
non-null boolean `isActive`. Its `QuestLogDocumentation.lua` declares
`IsOnQuest(questID)` and the acceptance payload above. Supplied Classic and
Mainline container UI code uses `questID and not isActive` for the
quest-start exclamation mark.

Cataclysm and other older branches have no dedicated snapshot in this turn.
Existing capability checks and fallbacks are retained; no fresh load or
runtime certification is claimed for those branches.

### Offline verification

- Reproduced the reported accepted-item alert on the unmodified supplied base.
- Passed 20 regression cases executing the actual patched popup module and
  event dispatcher with simulated client APIs: both acceptance payload shapes,
  acceptance from bags, event timing before log/bag settlement, reload with
  collapsed headers, native active state without a quest ID, abandonment,
  turn-in, unrelated starters, cancelled item offers, tracker clicks, duplicate
  loot/copies, stale slot identity, unrelated matching titles, invalid payloads,
  unavailable/erroring APIs, secret metadata, and clean popup rendering.
- Verified that normal clean popup rendering adds no inventory/metadata reads;
  targeted popup-state reconciliation does not enumerate all bag slots.
- Verified the native API structures and acceptance payloads in all six supplied
  snapshots.
- Parsed all 25 Lua files successfully with the available Lua 5.3 compiler.
  Changed code uses only Lua 5.1-compatible constructs. An actual Lua 5.1
  compiler/runtime was unavailable; the offline execution results above are
  from Lua 5.3, not an active WoW client.
- Verified only the three listed files differ from the supplied base, that all
  six TOCs match byte for byte, and that all other files, including any libraries,
  remain unchanged.

### Exact client test procedure

1. Install the full package over the supplied QuestKing build and start/reload
   the client once to load the patch. Enable quest-starting item popups.
2. Hold an item that starts an unaccepted quest. Confirm one offer alert.
3. Accept its quest directly from bags while the item remains in inventory.
   Confirm the offer disappears and stays gone after another bag update.
4. Relog with that quest active and the item still in bags. Confirm no offer
   alert. On Classic, repeat with the quest's log header collapsed.
5. Where possible, abandon that quest while retaining the item. Confirm the
   available offer returns without a reload. Reaccept and confirm it clears.
6. Complete/turn in the quest while retaining the starter where applicable.
   Confirm the completed linked quest does not produce a new offer.
7. Keep a second unrelated starter in bags. Confirm it remains visible when
   accepting the first quest. Open an item offer through QuestKing, cancel it,
   then accept an unrelated quest; confirm that starter is still available.
8. Move the starter between bags or loot another copy. Confirm there is one
   offer row when appropriate and no repeated alert for the active quest.

### Remaining limitations

Real inventory state changes, secure ancestry, actual item use, combat taint,
and login restoration require in-game checks. The existing curated starter
item list is unchanged. If native metadata is unavailable for an item, existing
known-quest/special-item/text fallbacks remain; no exact relationship can be
claimed from item presence alone. Loader compatibility is inherited from the
supplied TOCs and was intentionally not changed.

