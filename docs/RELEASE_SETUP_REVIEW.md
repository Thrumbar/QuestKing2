# QuestKing CurseForge Release Setup Review

Reviewed: 8 October 2026  
Verdict: **Release configuration validated; addon release candidate.**

The replacement files correct the release pipeline for a repository containing
the supplied `QuestKing/` addon folder. Complete replacements are included;
no manual code merging is required. No addon Lua, TOC, or library source was
edited. This review does not replace in-game testing of the addon.

## Confirmed findings and corrections

| Finding | Severity | Evidence | Correction |
|---|---|---|---|
| The packager cannot find the addon in the supplied nested layout. | High: build blocker | The original `.pkgmeta` sets `package-as: QuestKing` but provides no folder mapping. With `QuestKing/QuestKing.toc` beneath the repository root, the actual packager exits with code 1 and reports that it cannot find an addon TOC. | Added `move-folders: QuestKing/QuestKing: QuestKing`. This lets the packager discover the nested manifests and produce one installable `QuestKing/` folder. |
| The manual changelog path names a file absent from the supplied archive. | Medium | The original path is `QuestKing/QuestKing_3.0.50_Consolidated_Changelog.md`. The archive contains `QuestKing/CONSOLIDATED_CHANGELOG.md`. A build using the original metadata warns and generates a different changelog. | Updated the path to the existing consolidated changelog and added input/output checks for its presence. |
| Automatic TOC generation conflicts with the instruction to preserve manifests. | Medium: instruction compliance | The original workflow uses `-S`, although six client manifests already exist. The original packaging settings regenerate flavor manifests and convert their line endings; comparison against the input shows all six output TOCs differ. | Removed `-S`, disabled TOC creation in `.pkgmeta`, and used `plain-copy` for TOCs. The workflow checks the complete TOC set and compares each packaged manifest byte for byte before publishing. |

`.gitattributes` has no confirmed defect in the supplied project. Its LF rules
and explicit binary declarations cover the supplied fonts and textures, so it
is included unchanged.

## Workflow improvements

- Manual **Run workflow** builds and saves a preview ZIP without uploading it.
  The previous manual trigger ran the same publishing step as a tag push.
- `v*` tag pushes check the existing `CF_API_KEY` repository secret, build
  without uploading, verify the ZIP, save a downloadable artifact, and then
  publish to CurseForge project **1516209** and GitHub Releases.
- Validation checks exact-case load paths, ZIP integrity, addon root structure,
  the changelog, and preservation of all supplied TOCs.
- Publication uses the packager's `-c -o` options to retain the already validated
  package directory. An offline rehearsal verified that this second pass
  preserves every packaged file's contents.
- Same-ref runs are serialized and the job has a 20-minute timeout.
- Supported `CF_API_TOKEN` and `GITHUB_API_TOKEN` environment variables are used.
  The repository secret name remains `CF_API_KEY`. The original environment
  names also work with the tested packager and were not authentication defects.
- Package filenames and release labels use `QuestKing2-Reborn` to avoid the
  packager converting the display name's spaces and equals sign into underscores.
  The addon's existing title remains in its unmodified TOCs.
- Three maintenance reports are excluded from the installable ZIP. The
  consolidated changelog, font license, runtime files, and client manifests remain.

## Validation performed

| Check | Result |
|---|---|
| Original metadata with the supplied nested folder | Reproduced build failure, exit code 1 |
| Original metadata with an addon-flat test fixture | Reproduced missing-changelog warning and changed output TOCs |
| Corrected metadata with the supplied nested folder | PASS: actual BigWigs packager run, uploads disabled |
| Source validation embedded in the workflow | PASS |
| Packaged ZIP validation embedded in the workflow | PASS |
| Supplied TOC set and byte preservation | PASS: 6 of 6 unchanged; no added manifests |
| TOC load entries | PASS: all 27 exact-case entries exist in source and package |
| ZIP root and integrity | PASS: one `QuestKing/` addon root; integrity check passed |
| Consolidated changelog | PASS: selected as the manual changelog and included in the ZIP |
| Preview/publication trigger routing | PASS: manual runs omit publication; tag pushes enable it |
| Reuse of validated package contents | PASS: all ZIP members have identical contents before and after the reuse pass |
| GitHub workflow validation | PASS: actionlint 1.7.12 reports no errors |

The corrected preview contains 42 files. The original flat-layout build contains
46, including a fallback-generated changelog and the three excluded maintenance
reports. The packager's `-u` option produces LF text; the supplied rewards XML
has CRLF line endings and is normalized when packaging the local archive. No
XML logic changes were made. All 25 packaged Lua files match the tested source
bytes. Lua execution and performance were not retested because this update
changes release configuration only.

The tested `BigWigsMods/packager@v2` ref resolved to commit
`c1e2b134b6865bb78897a9be06a4c1109e7a22ab`.

## Client metadata retained

These are static packaging results, not successful in-game load tests.

| Client | Supplied reference build | Existing manifest | Interface value | Packaging |
|---|---|---|---|---|
| Classic Era | 1.15.9.69722 | `QuestKing_Vanilla.toc` | 11509 | PASS |
| Burning Crusade Classic | 2.5.6.69795 | `QuestKing_TBC.toc` | 20506 | PASS |
| Mists Classic | 5.5.4.70032 | `QuestKing_Mists.toc` | 50504 | PASS |
| Retail | 12.1.0.69933; 12.1.5.70077 | `QuestKing_Mainline.toc` | 120105, 120100 | PASS |
| WoW Forever | 1.60.1 (70235) | `QuestKing_Camelot.toc` | 16001 | PASS |
| Cataclysm Classic | No current reference supplied | No Cata manifest or interface declaration in this base | Not declared | Not advertised by this package |

The fallback `QuestKing.toc` is also retained unchanged. No new client support
or interface versions were added. The older reliability audit targets another
archive; its findings must not be treated as fresh defects in this supplied
base. For example, the current source already consumes scenario completion as
`questID, xp, money`, reads completed-objective settings dynamically, and uses
the exact-case `core/AutoComplete.lua` load path.

## Applying and publishing

1. Extract `QuestKing_CurseForge_Release_Files.zip` into the repository root
   that contains the `QuestKing/` folder. The ZIP places `.pkgmeta` and
   `.gitattributes` at the root and `release.yml` in `.github/workflows/`.
2. Commit the replacement files. The included review goes under `docs/` and
   is excluded from the addon package. `.gitattributes` is unchanged.
3. Verify that the repository Actions secret `CF_API_KEY` contains your
   CurseForge upload token. Do not put the token into any source file.
4. On the default branch, open **Actions → Release QuestKing2 Reborn → Run
   workflow**. Download the resulting `QuestKing2-Reborn-<run number>` artifact
   and check the contained addon ZIP.
5. After preview and client testing, push a new version tag beginning with
   `v` from the intended release commit. The tag run performs validation and
   publication automatically. Do not reuse an existing release tag.

This setup deliberately targets the supplied nested repository layout. An
addon-flat repository has different metadata paths and should not use these
files unchanged; the source check will explain the mismatch before packaging.

The supplied addon declares version **3.1.1** in all TOCs. The release filename
and label come from the Git tag, while these protected TOC version fields stay
unchanged. A different addon version therefore needs a separately authorized
TOC version update before it can have matching in-game and release metadata.

## Remaining release checks

The following could not be performed in this session:

- Authenticated execution in the user's GitHub repository, including verification
  of the CurseForge token, repository permissions, and current CurseForge game
  version mappings.
- A real CurseForge or GitHub release upload. No publication was attempted.
- In-game addon loading, quest-item use, tracker position retention, combat
  reconciliation, options, context menus, scenarios, or taint testing.

The release tooling passes its local checks. The addon remains a **release
candidate** until the relevant client and authenticated publishing checks pass.

## Input integrity

SHA-256 of the supplied validation base,
`QuestKing_3.1.1_Classic_Quest_Item_Hotfix_Full.zip`:

```text
ba6023f015b2d6bfb4be6a40662c96e1a6bebb5f34e5e6a0916eef5b95e10166
```

SHA-256 of the tested packager script:

```text
59b15a8d851b09e6d0fdec702aec91331b9b49d84dbe778da6c621b48f268703
```

## Primary references

- [BigWigs packager documentation](https://github.com/BigWigsMods/packager)
- [Tested packager implementation](https://github.com/BigWigsMods/packager/blob/c1e2b134b6865bb78897a9be06a4c1109e7a22ab/release.sh)
- [PackageMeta directives](https://github.com/BigWigsMods/packager/wiki/Preparing-the-PackageMeta-File)
- [GitHub workflow file placement](https://docs.github.com/en/actions/get-started/quickstart)
- [Running a workflow manually](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/manually-run-a-workflow)
