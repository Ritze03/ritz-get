# ritz-get machine-readable output (porcelain 1)

For `ritz-get-gui` and scripts. Everything else ritz-get prints is for humans and may change.
The GUI sets `RITZ_GET_GUI=1` on every command, and `RITZ_GET_SUDO=pkexec` for install, remove, switch and reset.

## `ritz-get list --porcelain [NAME...] [--offline] [--all] [--data]`

Lines, in this order. Fields are separated by one TAB; no field ever contains a TAB or a newline.

```
#porcelain 1
#online 1|0
E<TAB>section<TAB>name<TAB>title<TAB>kind<TAB>source<TAB>state<TAB>status<TAB>held<TAB>branch<TAB>installed<TAB>latest<TAB>behind<TAB>dirty<TAB>ahead<TAB>desc<TAB>shortcut
S<TAB>name<TAB>text
D<TAB>name<TAB>path<TAB>kb          (only with --data)
#hidden N
```

- `#porcelain 1` is always the first line. Refuse any other version.
- `#online 0` = offline or `--offline`: versions and `latest` are unknown. ritz-get decides "offline" by fetching its own clone (or `ls-remote` when it is not installed); a failure or HTTP 429 means offline.
- `E` = one entry, in manifest order (sections in manifest order, then section `Unlisted` last). Always 17 fields; `desc` may be empty. Column 17 (`shortcut`) was appended after the first release of porcelain 1: a parser that reads the first 16 columns and ignores the rest keeps working, so the version stays 1.
- `S` = one per `setup:` line, in order, right after its `E`. Unlisted entries have none.
- `D` = leftover data, only with `--data` (without it the output is byte-identical to before): one per path declared by a `data:` line of the entry that EXISTS now, in manifest order, after the entry's `E` and `S` records. `path` is always in `~/…` form (never `~user`), `kb` is `du -sk` of it, or `-` when `du` fails; it is local, so it is filled with `--offline` too. Installed programs get `D` records too ("data: 12 MB"); for a program that is not installed they mean data is left behind (`ritz-get delete-data NAME`). A path containing a tab or newline is never listed, and neither is one that `delete-data` would refuse (outside `$HOME` once resolved, or equal to, inside or above ritz-get's own folders). Websites have none. The human `list` marks such a program `not installed, data left`.
- `#hidden N` only when N > 0 and `--all` is not given: N programs are not reachable and were left out.

| field | values |
|---|---|
| section | manifest `[Section]`; entries before the first header are `Software`; clones not in the manifest: `Unlisted` |
| name | manifest NAME (also folder name and `~/.local/bin` name) |
| title | `title:` line, else NAME |
| kind | `program` \| `website` |
| source | `OWNER/REPO` or the URL (`-` for unlisted) |
| state | `installed`, `available` (not installed, reachable), `unreachable` (only with `--all`), `offline` (not installed, network unknown), `website`, `unlisted` |
| status | `installed`/`unlisted` only, else `-`: `current`, `behind`, `modified` (wins over everything), `fetch-failed`, `unknown` (offline) |
| held | `1` \| `0` (`ritz-get hold NAME`) |
| branch | installed branch; not installed: manifest BRANCH or `-` |
| installed | `YYYY-MM-DD sha` or `-` |
| latest | installed: `YYYY-MM-DD sha` of the upstream; not installed: 7-char `sha`; else `-` |
| behind | commits behind upstream, `-` when n/a |
| dirty | changed files in the working tree (`git status --porcelain` lines), `-` when n/a |
| ahead | local commits not on upstream, `-` when n/a |
| desc | manifest description, may be empty |
| shortcut | `on` (start-menu shortcut exists), `off` (can have one, has none), `-` (cannot: program not installed, or its repo ships no `NAME.desktop`; unlisted entries). Websites are `on` or `off`. `ritz-get shortcut NAME [--remove]` toggles it |

`modified` = `dirty > 0` or `ahead > 0`. `update` skips modified programs; `ritz-get reset NAME` discards the changes.
Installed programs are never hidden. `list NAME...` shows the named entries regardless of reachability.

## Exit codes (all commands)

| code | meaning |
|---|---|
| 0 | ok, including chosen states: held, modified, aborted, busy-from-cron |
| 1 | something failed (clone, fetch, build, unknown program, ...) |
| 2 | usage error |
| 3 | a program needs tools that are missing; a `deps:` line follows |
| 4 | a program needs root setup (`needs root:`); run `ritz-get install NAME` in a terminal |
| 5 | busy: another ritz-get holds the lock |

If several programs fail, 3 beats 4 beats 1.

## Lines worth parsing

- `missing: TOOL (try: pacman:PKG dnf:PKG apt:PKG)`: written by a program's install.sh on stderr before it exits 3. PKG may be comma-joined; a manager may be absent. ritz-get echoes these live.
- `deps: sudo pacman -S --needed a b` / `deps: sudo dnf install a b` / `deps: sudo apt install a b`: printed once, at the end, merged and de-duplicated over all programs of the run (distro from `/etc/os-release` `ID`/`ID_LIKE`). Unknown distro, or a line without a package for this manager: the raw `missing:` lines are printed instead (for the latter, in addition).
- `needs root: ...`: from install.sh (exit 4); repeated once at the end of the run.
- `busy: another ritz-get is running` (stderr, exit 5). Changing commands (install, update, remove, delete-data, switch, reset, hold, unhold, shortcut, shortcuts PATH, dir PATH) take one non-blocking lock; `list` and `branches` take none. `update` from cron (no tty, no `RITZ_GET_GUI`) exits 0 silently instead.
- Per program in `install`/`update`/`switch`/`reset`: `NAME: up to date`, `NAME: updated A -> B`, `NAME: held (ritz-get unhold NAME)`, `NAME: SKIPPED (local changes; ritz-get reset NAME to discard them)`, `NAME: SKIPPED (needs a newer ritz-get)`, `NAME: FAILED (reason)`. Reasons include `needs: a, b` (exit 3), `timed out after 60 min`, `fetch failed`, `install.sh exit N`.
- Every failed build, update, switch or reset is followed by the line `FAILED — your installed version is unchanged and still works` (true: the clone is reverted).
- Build log: each run of a program's install.sh (install, update, remove, ...) is also written to `${XDG_CACHE_HOME:-~/.cache}/ritz-get/logs/NAME.log` (stdout and stderr, overwritten per run, first line `# DATE NAME install.sh ARG --yes COMMIT`). With `RITZ_GET_GUI` set the full output still streams live, stdout and stderr apart; a plain terminal run is quiet and prints only `missing:`, `deps:`, `note:`, `restart:` and `setup:` lines, unless `--verbose`.
- `update` ends with `N updated, N skipped, N failed`. `ritz-get install` prints `Additional steps required:` followed by indented setup lines after a successful install.

## Progress lines (`RITZ_GET_GUI` set only)

`install`, `update`, `switch`, `reset` and `delete-data` print two machine lines per program on stdout, both starting with `#`:

```
#start NAME            <- just before NAME's apply step begins
#progress NAME N/M     <- after NAME's result lines: N programs done of M in this run
```

- `#start` comes before the program's own lines (`NAME: cloning ...`, `NAME: building`, install.sh output), `#progress` after its result line (`NAME: installed ...`, `NAME: updated A -> B`, `NAME: FAILED (...)`, `NAME: SKIPPED (...)`), also when it failed or was skipped. `install` with a name that is unknown or invalid still gets the pair, around the error line.
- M is the apply list of the run: for `install NAME...` and `delete-data NAME...` the number of names; for `update` only the programs that are actually updated (phase 2, after all the phase-1 checks, so programs that are up to date, held or skipped are not counted); 1 for `switch` and `reset`. N counts 1..M in order. `update` that updates ritz-get itself and other programs does it in two steps and counts each step on its own (`1/1`, then `1/M`).
- Both lines appear only under `RITZ_GET_GUI=1`. Without it (a pipe, cron, a terminal) they are never printed; a terminal gets a progress bar instead, which is not part of this contract.
- Readers must ignore unknown record letters in `list --porcelain` (first column other than `E`, `S`, `D`), so new record types can be added.
- Readers must ignore unknown lines that start with `#`, like the `#porcelain` header lines of `list --porcelain`, and fall back to guessing from the human lines when a run prints none of these.

## `${XDG_CACHE_HOME:-~/.cache}/ritz-get/last-run`

Written by every `update` run (cache, not state):

```
2026-10-24T03:00:01 2 updated, 1 skipped, 0 failed
failed: NAME NAME        <- only when something failed
```

## Other commands

- `branches NAME`: one line per remote branch, `* ` marks the current one, two spaces otherwise.
- `hold NAME` / `unhold NAME`: `git config ritz-get.hold true` in the clone; `update` without names skips held programs, `update NAME` does not.
- `open NAME`: websites only, runs `xdg-open URL` detached; for a program it fails with `NAME is a program, not a website` (exit 1).
- `shortcut NAME` / `shortcut NAME --remove`: creates / removes the start-menu shortcut (`NAME: shortcut created (PATH)`, `NAME: shortcut removed`). A program needs to be installed and its repo to ship `NAME.desktop`, else exit 1; a website can always have one. `remove`, `reset`, repair-`install`, `switch` and `update` keep an existing shortcut in step.
- `shortcuts` prints the shortcuts folder; `shortcuts PATH` moves every shortcut there and stores `shortcuts=` in the config. Default `${XDG_DATA_HOME:-~/.local/share}/applications`.
- `dir` prints the repo folder; `dir PATH --yes` moves the whole folder (one `mv`, same filesystem, empty or new target only), stores `dir=` in the config, then re-runs each program's `install.sh --install --yes` (no root) and regenerates the shortcuts. A program that cannot be repaired prints `NAME: needs repair: ritz-get install NAME`, exit non-zero, nothing is rolled back. Without `--yes` it asks first.
- `delete-data NAME...` [--yes]: deletes the data an UNINSTALLED program left behind: the `data:` paths its manifest entry declares (`~/…` below `$HOME`, XDG-mapped), never anything else, never with sudo. `remove NAME` keeps the data and, if any declared path exists, ends with the normal line `NAME: data kept in ~/.config/x, ~/.local/share/x (delete with: ritz-get delete-data NAME)`. `delete-data` prints, per name: unknown program: `unknown program: NAME` (exit 1); website: `NAME: a website has no data` (0); installed: `NAME: FAILED (uninstall first: ritz-get remove NAME)` (1); nothing declared exists: `NAME: no data left` (0); else each existing path as `  SIZE<TAB>~/PATH`, then asks `Delete these? [y/N]` (No by default) and prints `NAME: data deleted`. `--yes` means yes. It never prompts under `RITZ_GET_GUI=1`, and without a terminal it asks nothing: without `--yes` both print `NAME: nothing deleted (pass --yes)` and exit 0; answering no prints `aborted` (exit 0). A symlink at a data path is removed, never followed; a path whose resolved place is not strictly below the real `$HOME`, or is equal to, inside or above ritz-get's own folders (clone dir, config, cache, `~/.local/share/ritz-get`, `~/.local/bin`), is refused (an XDG dir outside `$HOME` is never used to map `~/.config/…`): `ritz-get: NAME: not deleted: ~/PATH`, exit 1. The GUI asks itself, then calls `delete-data NAME --yes`.
- `shortcut`, `shortcuts PATH`, `dir PATH` and `delete-data` take the lock like the other changing commands.
- `reset NAME --yes`, `remove NAME` (alias `uninstall`), `switch NAME BRANCH`, `install NAME [--branch B]` (on an installed program: repair, re-runs install.sh). Always pass `--yes` to `update`, `reset` and `dir PATH`; stdin is never a terminal for the GUI.
