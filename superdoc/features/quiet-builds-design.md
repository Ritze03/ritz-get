# Quiet Builds — Design Spec

**Date:** 2026-10-25
**Status:** Implemented (bar refined 2026-10-27)
**Feature:** a terminal run hides build output in a log and shows one progress bar; only prefixed `install.sh` lines show by default

---

## Goal & motivation

Commits "quiet builds: build output to a log, bar through the build, --verbose for the full stream" and "progress: a terminal progress bar, and #start/#progress lines for the GUI" (2026-10-25). A build's own output is long and not for most users; they need to see lines they must act on and know the run is alive.

## What it does

- `run_script` writes the whole `install.sh` output to `$CACHE/logs/NAME.log` (overwritten per run). In the default terminal mode only lines starting with `missing:`, `deps:`, `note:`, `restart:` or `setup:` reach the screen, above the bar. SPEC: every line a user must act on MUST carry one of those prefixes.
- A failed build prints the log path and its last 15 lines (`failed`), unless `--verbose`.
- `--verbose` (`-v`) streams everything and draws no bar. The GUI (`RITZ_GET_GUI`) also gets the full stream, stdout and stderr apart, and the log is written too.
- Pipes and cron: no bar; output otherwise as for a terminal without bar.
- 2026-10-27, "progress bar: one bar that fills by steps instead of redrawing from zero": one bar per run, two steps per program (get the source, build), fill never goes back.

## Non-goals

- No change to what `install.sh` prints; SPEC rule R28 still says plain text lines, no ANSI, no `\r` bars. The bar is drawn by ritz-get, never by a program.
- The bar is not part of the machine contract ([PORCELAIN.md](../../PORCELAIN.md)); frontends get `#start`/`#progress` lines instead.

## Key decisions & rationale

- **Prefix whitelist instead of a filter list.** Showing only five known prefixes means a program cannot flood the terminal, and the SPEC then obliges programs to prefix whatever the user must see. A reason beyond that is not recorded.
- **Log kept after failure and overwritten per run.** One log per program, no log rotation or state.
- **`--verbose` has no bar** because it would fight the stream (commit message).

## Related links

- [build-runner](build-runner.md), [progress-output](progress-output.md)
- [SPEC.md](../../SPEC.md), [README](../../README.md)
