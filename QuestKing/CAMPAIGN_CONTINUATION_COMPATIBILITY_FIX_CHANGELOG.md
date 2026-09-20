# QuestKing 3.0.50 — Campaign Continuation Compatibility

## Corrected behavior

- Campaign continuation rows now supertrack an unaccepted quest through
  `C_SuperTrack.SetSuperTrackedMapPin()` with
  `Enum.SuperTrackingMapPinType.QuestOffer`.
- Accepted campaign quests continue to use ordinary accepted-quest focus.
- Right-clicking a continuation row opens a dedicated menu and does not run
  the left-click navigation action.
- **Stop Tracking** hides only that exact continuation requirement for the
  current character and clears only a matching QuestOffer pin.
- Suppression entries are automatically removed after the requirement is
  accepted, completed, replaced, or no longer active.
- Continuation hints rebuild after quest-line updates and major-faction
  renown/unlock changes. No campaign polling was added.

## Campaign classification

- Uses the documented `questClassification` field first.
- Recognizes a campaign-classified parent quest-log header for Blizzard quest
  log grouping parity.
- Preserves positive `campaignID` and `isCampaign` compatibility signals.
- Falls back to `C_QuestInfoSystem.GetQuestClassification()`,
  `C_CampaignInfo.GetCampaignID()`, and
  `C_CampaignInfo.IsCampaignQuest()`.
- A synthetic or legacy `isCampaign = false` value no longer suppresses
  authoritative campaign signals.

## Quest-cap display

- The title numerator now uses the second return from
  `C_QuestLog.GetNumQuestLogEntries()`, Blizzard's accepted quest count.
- The denominator remains `C_QuestLog.GetMaxNumQuestsCanAccept()`.
- Tracking, untracking, population-mode changes, and local World Quests no
  longer alter the accepted-cap numerator.

## Reliability and resource use

- Added only targeted structural campaign events; objective progress events
  do not rescan every available campaign.
- Removed one duplicate forced tracker request from `QUEST_ACCEPTED`.
- Reused local-World-Quest and population-fingerprint scratch tables.
- Preserved Lua 5.1 syntax, Classic-family guarded behavior, pooled-row mouse
  reconciliation, and secure quest-item ownership.

## Runtime validation required

1. Finish a campaign step without accepting the next quest.
2. Left-click the continuation row and confirm the QuestOffer pin and
   navigation arrow select the offered quest.
3. Right-click the row and choose **Stop Tracking**; confirm no left-click
   navigation action runs.
4. Accept or complete the requirement, then later reproduce that continuation
   and confirm it can appear again when appropriate.
5. Track and untrack accepted quests and enter a World Quest area; confirm the
   title numerator does not change unless a standard quest is accepted,
   abandoned, or turned in.
6. Unlock a campaign continuation through renown or quest-line progress and
   confirm the hint updates without `/reload`.

## Acceptance result

`PARTIAL — runtime validation required`

