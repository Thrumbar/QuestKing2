# QuestKing 3.0.43 — Phase 8 Packaging and Cross-Version Validation

## Packaging corrections

- Replaced the literal `@project-version@` release-builder token with the
  install-ready version `3.0.43`.
- Limited the fallback `QuestKing.toc` to the two validated Mainline interface
  values.
- Added explicit flavor TOCs for Mainline, Classic Era, Burning Crusade
  Classic, Cataclysm Classic, and Mists Classic.
- Added the missing `Interface-BCC` and `Interface-Mists` package metadata.
- Preserved one identical file order, dependency list, and SavedVariables
  contract across every flavor TOC.
- Preserved the exact `core\AutoComplete.lua` path capitalization used by the
  archive.

## Static validation

- Lua 5.1 syntax: 25/25 Lua files parsed.
- XML syntax: 2/2 XML files parsed.
- TOC load paths: 27/27 exact-case paths resolved in every flavor TOC.
- Duplicate case-insensitive source paths: none.
- Archive root: one `QuestKing` directory.
- Unsafe archive paths: none.
- ZIP integrity: passed.
- Packaged-source equality: passed.

## Compatibility scope

The supplied Blizzard snapshots were checked for:

- Classic Era `1.15.8.65888`;
- Burning Crusade Classic `2.5.5.67157`;
- Burning Crusade Classic `2.5.5.68101`;
- Cataclysm Classic `4.4.2.60895`;
- Mists Classic `5.5.4.68159`;
- Mainline `12.0.7.68367`;
- Mainline `12.1.0.68569`.

No Lua runtime behavior changed in this phase. QuestKing 3.0.42's World Quest
Tracker anchor adapter, 3.0.41 world-quest classification, and all completed
Phase 1 through Phase 7 behavior remain unchanged.

## Release status

Static Phase 8 validation passes. Live client verification is still required
for final release sign-off, so this package is a release candidate rather than
a fully live-certified release.
