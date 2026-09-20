# QuestKing 3.0.50 — Feature Coverage Phase 3

## Quest Right-Click Menu and Tracking

### Panel verdict

- **Runtime and protected-action review:** The menu continues to open from the
  user's right-click hardware event. The correction changes quest-tracking
  state only and does not mutate secure row attributes, anchors, parents, or
  mouse state.
- **Cross-version API review:** Mainline uses the supplied
  `C_SuperTrack.GetSuperTrackedQuestID()` and
  `C_SuperTrack.SetSuperTrackedQuestID()` contract. The supplied Classic Era,
  Burning Crusade Classic, and Mists Classic sources do not expose that
  supertracking contract, so those clients explicitly fall back to their
  available quest-watch APIs.
- **Performance and reliability review:** One reusable dropdown is retained.
  The existing quest-specific open guard and debounce remain active, and no
  party-member loop creates menu entries.

Static verdict: the Phase 3 correction passes the deterministic harness.
Final acceptance remains dependent on live-client validation.

### Confirmed finding

`buttons/quest.lua`, in `EnsureQuestContextMenu()`, created two independent
tracking controls: a Focus/Remove Focus row and a quest-watch Track/Untrack
row. This violated the Phase 3 single-action contract and could appear to the
user as duplicate tracking behavior.

### Corrections

- Removed the separate Focus/Remove Focus menu row.
- Retained exactly one **Track Quest / Untrack Quest** row.
- On clients with accepted-quest supertracking, the row selects or clears the
  clicked quest as the navigation target.
- On Classic-family clients without supertracking, the same row explicitly
  adds or removes the selected quest from Blizzard's quest watch list.
- If neither tracking contract exists, the single action remains visible but
  disabled instead of calling an unavailable function.
- Changed the tooltip state text from Focus terminology to the active tracking
  backend: navigation tracking or quest-watch tracking.
- Preserved sharing, abandonment, remote-completion handling, party progress,
  and the single-open guard. A later Retail taint hotfix routes Mainline clicks
  to popup quest details and retains quest-map actions only on Classic-family
  clients.

### Changed files

- `buttons/quest.lua`
- `CONSOLIDATED_CHANGELOG.md`
- `FEATURE_COVERAGE_PHASE_3_QUEST_TRACKING_CHANGELOG.md`

No `.toc` file or bundled library was changed.

### Deterministic validation

The Phase 3 harness verifies:

1. Mainline presents one **Track Quest** action for an unfocused quest.
2. Selecting it targets the clicked quest without changing its watch-list
   membership.
3. The same row becomes **Untrack Quest** for the selected navigation target
   and clears only that target.
4. Classic clients without supertracking add and remove the selected quest
   through the quest-watch fallback.
5. A branch without either API shows one disabled tracking action.
6. Completed quests use the same selected-quest path.
7. A grouped quest with sharing available still produces one tracking row.
8. Repeated delivery of the same right-click opens the menu once.
9. Tooltip tracking state matches the Mainline navigation backend or Classic
   quest-watch backend while retaining the right-click options hint.

### Live test procedure

1. In solo play, right-click an untracked quest and verify exactly one tracking
   row appears as **Track Quest**.
2. Select it and verify the clicked quest becomes the navigation target; open
   the menu again and verify the row reads **Untrack Quest**.
3. Test a completed quest and a quest without a usable navigation waypoint;
   confirm the client remains error-free and the selected-quest state is
   accurate.
4. Join a party in which two or more members share the quest. Right-click once
   and confirm one menu and one tracking row appear.
5. Repeat on Classic Era, Burning Crusade Classic, and Mists Classic. Confirm
   the single action changes Blizzard's watch state without requiring a
   Mainline supertracking API.
6. Verify popup quest details on Mainline, quest-map actions on Classic,
   sharing, abandon confirmation, left-click, Shift-click, and
   field-completion behavior.

### Acceptance result

`PARTIAL — runtime validation required`

### Remaining risks

- The supplied source snapshots prove API presence and the harness proves the
  selection logic, but only an active client can confirm navigation waypoint
  availability for every quest type and localized menu text.
- Protected-action and taint behavior must still be observed during live
  combat testing even though Phase 3 introduces no protected-frame mutation.
