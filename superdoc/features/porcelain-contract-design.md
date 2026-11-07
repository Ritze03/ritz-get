# Porcelain Contract — Design Spec

**Date:** 2026-10-24
**Status:** Implemented (extended 2026-10-25 and 2026-10-28)
**Feature:** a stable machine-readable output so a frontend in a separate repo can drive ritz-get

---

## Goal & motivation

SPEC.md: a CLI (`ritz-get`) and a GUI both drive the same `install.sh`. The GUI lives in its own repository (`ritz-get-gui` in `programs`) and parses ritz-get's output, so everything it depends on must not change by accident. [PORCELAIN.md](../../PORCELAIN.md) states that everything else ritz-get prints is for humans and may change.

Introduced with the core rewrite (2026-10-24): `list --porcelain`, the exit-code table and the lines worth parsing.

## What the contract covers

- `list --porcelain`: a versioned (`#porcelain 1`), tab-separated record stream (`E`, `S`, `D`, `#hidden`).
- Exit codes 0 to 5 and the 3-beats-4-beats-1 rule.
- Lines worth parsing (`missing:`, `deps:`, `needs root:`, `busy:`, per-program result lines, the failure trailers, `N updated, N skipped, N failed`).
- Environment from the frontend: `RITZ_GET_GUI=1` on every command and `RITZ_GET_SUDO=pkexec` for the changing ones.
- `#start`/`#progress` lines under `RITZ_GET_GUI` (added 2026-10-25).
- `last-run` and the build log in the cache folder.

## Non-goals

- Human output (`list` without `--porcelain`, the bar) is not a contract.
- No second parser protocol (JSON etc.); not recorded why.

## Key decisions & rationale

- **Evolve without a version bump.** Readers ignore unknown record letters and unknown `#` lines, and read only the columns they know; so new records and columns (the 17th, `shortcut`) were added while the version stayed 1. `branch-gone` as a new `status` value: readers that do not know it treat it like `unknown`.
- **The trailer lines are part of the contract** (2026-10-28, "honest trailer on a failed first install"): a failed first install says `FAILED — nothing was installed`; a failed update, switch, reset or repair says `FAILED — your installed version is unchanged and still works`. Frontends treat either as end of failure.
- **Frontends pass `--yes`** to `update`, `reset` and `dir PATH`, because stdin is never a terminal for the GUI.

## Related links

- [porcelain](porcelain.md), [progress-output](progress-output.md)
- [PORCELAIN.md](../../PORCELAIN.md), [list](../commands/list.md)
