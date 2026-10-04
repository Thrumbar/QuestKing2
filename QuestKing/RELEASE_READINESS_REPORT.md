# QuestKing 3.1.1 Release Readiness Report

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
