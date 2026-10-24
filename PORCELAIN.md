# ritz-get machine-readable output (porcelain 1)

For `ritz-get-gui` and scripts. Everything else ritz-get prints is for humans and may change.
The GUI sets `RITZ_GET_GUI=1` on every command, and `RITZ_GET_SUDO=pkexec` for install, remove, switch and reset.

## `ritz-get list --porcelain [NAME...] [--offline] [--all]`

Lines, in this order. Fields are separated by one TAB; no field ever contains a TAB or a newline.

```
#porcelain 1
#online 1|0
E<TAB>section<TAB>name<TAB>title<TAB>kind<TAB>source<TAB>state<TAB>status<TAB>held<TAB>branch<TAB>installed<TAB>latest<TAB>behind<TAB>dirty<TAB>ahead<TAB>desc
S<TAB>name<TAB>text
#hidden N
```

- `#porcelain 1` is always the first line. Refuse any other version.
- `#online 0` = offline or `--offline`: versions and `latest` are unknown. ritz-get decides "offline" by fetching its own clone (or `ls-remote` when it is not installed); a failure or HTTP 429 means offline.
- `E` = one entry, in manifest order (sections in manifest order, then section `Unlisted` last). Always 16 fields; `desc` may be empty.
- `S` = one per `setup:` line, in order, right after its `E`. Unlisted entries have none.
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
- `busy: another ritz-get is running` (stderr, exit 5). Changing commands (install, update, remove, switch, reset, hold, unhold) take one non-blocking lock; `list` and `branches` take none. `update` from cron (no tty, no `RITZ_GET_GUI`) exits 0 silently instead.
- Per program in `install`/`update`/`switch`/`reset`: `NAME: up to date`, `NAME: updated A -> B`, `NAME: held (ritz-get unhold NAME)`, `NAME: SKIPPED (local changes; ritz-get reset NAME to discard them)`, `NAME: SKIPPED (needs a newer ritz-get)`, `NAME: FAILED (reason)`. Reasons include `needs: a, b` (exit 3), `timed out after 60 min`, `fetch failed`, `install.sh exit N`.
- Every failed build, update, switch or reset is followed by the line `FAILED — your installed version is unchanged and still works` (true: the clone is reverted).
- `update` ends with `N updated, N skipped, N failed`. `ritz-get install` prints `Additional steps required:` followed by indented setup lines after a successful install.

## `${XDG_CACHE_HOME:-~/.cache}/ritz-get/last-run`

Written by every `update` run (cache, not state):

```
2026-10-24T03:00:01 2 updated, 1 skipped, 0 failed
failed: NAME NAME        <- only when something failed
```

## Other commands

- `branches NAME`: one line per remote branch, `* ` marks the current one, two spaces otherwise.
- `hold NAME` / `unhold NAME`: `git config ritz-get.hold true` in the clone; `update` without names skips held programs, `update NAME` does not.
- `reset NAME --yes`, `remove NAME` (alias `uninstall`), `switch NAME BRANCH`, `install NAME [--branch B]` (on an installed program: repair, re-runs install.sh). Always pass `--yes` to `update` and `reset`; stdin is never a terminal for the GUI.
