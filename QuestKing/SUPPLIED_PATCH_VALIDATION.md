# QuestKing 3.0.50 Supplied Patch Validation

## Result

All QuestKing patches recorded in the supplied `3.0.50` campaign source are
present in the runtime source and retained in this package. One loader metadata
gap was corrected: Burning Crusade Classic `2.5.6.68575` uses interface
`20506`, replacing the older `20505` value in `QuestKing.toc` and
`QuestKing_TBC.toc`.

The separately supplied Carbonite patch archives were not copied into
QuestKing. They target Carbonite modules and have no compatible QuestKing file
or namespace targets.

## Static verification

| Check | Result |
| --- | --- |
| Lua 5.1 parse | PASS — 25/25 files |
| XML parse | PASS — 2/2 files |
| TOC referenced paths | PASS — no missing files |
| Exact-case TOC paths | PASS |
| Flavor TOC load order | PASS — identical across six TOCs |
| Release version | PASS — 3.0.50 in every TOC |
| Mainline interfaces | PASS — 120100 and 120007 |
| Classic Era interface | PASS — 11508 |
| Burning Crusade interface | PASS — corrected to 20506 |
| Cataclysm interface | PASS — 40402 |
| Mists interface | PASS — 50504 |
| Protected mouse propagation | PASS — no `SetPropagateMouseClicks` call |
| Secure quest-item template | PASS — `SecureActionButtonTemplate` retained |
| Campaign QuestOffer navigation | PASS — guarded map-pin contract retained |
| Campaign Stop Tracking | PASS — exact-requirement suppression retained |
| Campaign classification | PASS — documented and guarded fallbacks retained |
| Accepted quest-cap count | PASS — second quest-log return paired with accepted capacity |
| Targeted campaign invalidation | PASS — quest-line and major-faction events retained |
| PetTracker adapter | PASS — module, optional dependency, and startup recovery retained |
| World Quest Tracker adapter | PASS — module and optional dependency retained |

## Validation boundary

Static validation confirms syntax, packaging, load order, and source-level
contracts. Live client testing remains required for combat lockdown, taint,
optional-addon interaction, campaign progression, and tracker rendering.
