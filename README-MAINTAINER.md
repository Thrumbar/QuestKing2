# QuestKing Release and Maintenance Guide

This release kit is set up for a GitHub-driven CurseForge workflow for the QuestKing addon.

It uses:
- Git tags for versions
- GitHub Actions for packaging
- CurseForge uploads through the WoW Packager action
- `@project-version@` in the TOC so you do not hand-edit the release version every time

## Files in this kit

- `.pkgmeta`
- `.github/workflows/release.yml`
- `QuestKing.toc.example`
- `CHANGELOG.md`

## One-time setup

### 1. Update your TOC

Replace the header of `QuestKing.toc` with the one from `QuestKing.toc.example`.

Important lines:
- `## Version: @project-version@`
- `## X-Curse-Project-ID: 1516209`

### 2. Copy `.pkgmeta` to the repo root

This controls package naming and changelog/license handling.

### 3. Copy the workflow file

Copy `.github/workflows/release.yml` into your GitHub repository.

### 4. Add the GitHub repository secret

Add this repository secret in GitHub:
- `CF_API_KEY` = your CurseForge API token

The workflow uses GitHub's built-in token for the GitHub Release step, so you do not need to create a separate `GITHUB_OAUTH` repository secret for the included workflow.

## Recommended repo structure

The workflow assumes:
- the addon root is the Git repository root
- `QuestKing.toc` is in the root
- the addon is packaged as a single addon

That matches your current TOC layout.

## Daily development flow

For normal development:

```bash
 git add .
 git commit -m "QuestKing: describe change"
 git push origin main
```

That updates GitHub only. It does not publish a release.

## Release flow

When you want to publish a new version:

### 1. Update your changelog

Edit `CHANGELOG.md`.

### 2. Commit and push

```bash
 git add .
 git commit -m "QuestKing: release prep 3.0.3"
 git push origin main
```

### 3. Create and push a Git tag

For version `3.0.3`:

```bash
 git tag -a v3.0.3 -m "QuestKing 3.0.3"
 git push origin v3.0.3
```

## What the tag does

A Git tag marks one exact commit as a release version.

In this setup:
- `v3.0.3` becomes the packaged project version
- GitHub Actions runs when the tag is pushed
- the addon zip is built
- the package is uploaded to CurseForge
- a GitHub Release is created for the tag

## Versioning rules

Use tags in this format:

- `v3.0.3`
- `v3.0.4`
- `v3.1.0-beta.1`
- `v3.1.0-alpha.1`

This matches the workflow trigger:

```yaml
on:
  push:
    tags:
      - "v*"
```

If you tag `3.0.3` without the `v`, the included workflow will not run.

## How to verify a release worked

After pushing a tag:

1. Open the GitHub repository `Actions` tab and confirm the workflow passed.
2. Open the GitHub repository `Releases` page and confirm the release exists.
3. Open CurseForge -> QuestKing -> Files and confirm the new package is listed.

## If you need to fix a bad tag

Delete local tag:

```bash
 git tag -d v3.0.3
```

Delete remote tag:

```bash
 git push origin :refs/tags/v3.0.3
```

Then create the corrected tag and push again.

## Notes about the workflow

The included workflow uses:
- `BigWigsMods/packager@v2`
- `args: -S`

The `-S` mode is included because your TOC uses a single file with comma-separated interface values for multiple supported game flavors.

## Notes about `.pkgmeta`

The included `.pkgmeta` uses:
- `package-as: QuestKing`
- `manual-changelog: CHANGELOG.md`
- `license-output: LICENSE.txt`
- `enable-nolib-creation: no`

If your repository does not already contain a license file, either:
- add `LICENSE.txt`, or
- remove the `license-output` line from `.pkgmeta`

## Quick release checklist

```text
1. Make code changes
2. Update CHANGELOG.md
3. git add .
4. git commit -m "QuestKing: <summary>"
5. git push origin main
6. git tag -a vX.Y.Z -m "QuestKing X.Y.Z"
7. git push origin vX.Y.Z
8. Check GitHub Actions
9. Check CurseForge Files
10. Check GitHub Release
```
