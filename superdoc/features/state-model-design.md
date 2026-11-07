# State Model — Design Spec

**Date:** 2026-10-24
**Status:** Implemented
**Feature:** the git clone is the only state; no metadata file, no tags or versions, everything built from source

---

## Goal & motivation

ritz-get installs and updates the author's own programs for other people. README ("Where things live"): each program is a git clone in one folder, and the clone is the whole state. A program is installed if its clone exists, the checked-out branch is the branch you run, and `HEAD` is the version. There are no other state files.

In code: `is_installed` is `[ -e "$SRCDIR/$1/.git" ]`; `branch` and `short` read `git`; hold is `git config ritz-get.hold`; "modified" is `git status`/`rev-list` (`changes`). Everything ritz-get puts elsewhere (`~/.local/bin/NAME`, shortcuts) is a symlink into the clone folder or a generated file inside it (`.ritz-get/`). Under `${XDG_CACHE_HOME:-~/.cache}/ritz-get/` only caches live: build logs and `last-run`. The only setting file is the optional config (`dir=`, `shortcuts=`).

## Non-goals

SPEC.md, "Deliberately left out":

- A metadata file in the repo (name, version, category). The manifest and `install.sh` cover it.
- Version numbers and tags. ritz-get shows the commit date and the short hash.
- Prebuilt binaries and release downloads. Everything builds from source.
- Dependencies between programs.
- Root for anything but symlinks; system packages and services are the maintainer's job by hand.
- A purge mode that deletes config and user data. (Later added in a limited form as `delete-data`, which only removes the folders the manifest declares with `data:` lines and only after uninstall.)
- Skipping a rebuild when nothing changed: ritz-get calls `--install` when something did, and the build tool's own cache makes a repeat cheap.

## Key decisions & rationale

- **Clone as state.** Moving the folder is one `mv` plus re-running each `install.sh` (`ritz-get dir PATH`), and the folder may be the user's own development folder: clones with changes are never touched (README). Reasons beyond those in README and SPEC are not recorded.
- **Local changes are visible, not hidden.** Edited files or local commits mark a program `modified`; `update` skips it and `reset NAME` re-clones.
- **Failed builds leave the old version.** `upd_apply` resets the clone to the previous commit when the build fails, so the clone and the installed program stay in step.

## Related links

- [Manifest](manifest.md), [build-runner](build-runner.md)
- [Program spec](../spec/program-spec.md), [Architecture overview](../architecture/overview.md)
- [README](../../README.md), [SPEC.md](../../SPEC.md)
