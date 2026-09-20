# QuestKing 3.0.50 Release Readiness Report

## Post-Phase 8 campaign continuation compatibility

QuestKing 3.0.50 corrects five compatibility gaps identified after the recent
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
   version `3.0.50` without an out-of-date warning.
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
- `version.txt`
- `CAMPAIGN_CONTINUATION_COMPATIBILITY_FIX_CHANGELOG.md`
- `POOLED_ROW_CREATION_MOUSE_STATE_FIX_CHANGELOG.md`
- `CONSOLIDATED_CHANGELOG.md`
- `RELEASE_READINESS_REPORT.md`
- `SUPPLIED_PATCH_VALIDATION.md`

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
