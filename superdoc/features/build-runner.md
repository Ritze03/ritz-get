# Build runner — running a program's install.sh

Every install, update, repair, switch, reset, remove and `dir` move runs the clone's `install.sh` through one function, `run_script`; `build` wraps it for the install-like cases.

## How it works

- `ritz-get:build NAME` syncs submodules (`sync_subs`), requires an executable `install.sh`, reads its optional `# ritz-get-spec: N` header (first 5 lines) and returns 2 when N is newer than `SPEC` (callers print `SKIPPED (needs a newer ritz-get)`). Then it calls `run_script NAME --install` and maps `RC`: 3 to `needs: ...` (from the log's `missing:` lines, class 3), 4 to `needs root; run: ritz-get install NAME` (class 4), 124 to `timed out after N min`, anything else `install.sh exit RC`. Return 0 ok, 1 failed with `BK` (exit class) and `WHY` set.
- `ritz-get:run_script NAME ARG` runs `./install.sh ARG --yes` from the clone with stdin `/dev/null`, `NO_COLOR=1`, `TERM=dumb`, `RITZ_GET_SPEC` and `RITZ_GET_SUDO=$SUDO`, under `timeout -k 10 $TMO`. `TMO` is `RITZ_GET_TIMEOUT` seconds, default 3600 (SPEC: a run over 60 minutes counts as failed).
- Log: stdout and stderr both go to `$CACHE/logs/NAME.log` (`$CACHE` is `${XDG_CACHE_HOME:-~/.cache}/ritz-get`), overwritten per run, first line `# DATE NAME install.sh ARG --yes COMMIT`. If the cache folder is not writable the log falls back to `$TMP/log`. `cleanup_fresh` sets `LOGTO` so a failed first install's log is not overwritten by its cleanup `--remove`.
- Three output modes, all fed by two fifos (`$TMP/of`, `$TMP/ef`):
  - GUI (`RITZ_GET_GUI`): one `tee -a LOG` per stream, full output live, stdout and stderr apart (the GUI reads them separately).
  - `--verbose`: the stream goes to the screen through `tee`; no bar.
  - default (quiet): one `awk` appends everything to the log and lets only `missing:`, `deps:`, `note:`, `restart:`, `setup:` lines through, with the bar underneath. See [progress-output](progress-output.md) and [quiet-builds-design](quiet-builds-design.md).
- After the run `missing:` lines (exit 3) are appended to `$TMP/missing` and `needs root:` lines (exit 4) to `$TMP/rootneed`.
- `ritz-get:print_deps` merges all `missing:` lines into one line like `deps: sudo pacman -S --needed a b`, picking the manager from `RITZ_GET_OS_RELEASE` (default `/etc/os-release`) `ID`/`ID_LIKE` (arch/cachyos, fedora/rhel, debian/ubuntu). Unknown distro, or a line with no package for that manager: the raw `missing:` line is printed instead.
- `ritz-get:finish` closes the last progress step, prints deps and the `needs root:` lines once, then `exit "${INTR:-$EXIT}"`.
- Child processes of a build are started with `9>&-`, so they do not inherit the lock fd (see [locking-and-self-update](locking-and-self-update.md)).

### Signals

`run_script` traps INT, TERM and HUP: it sets `SIG` (130/143/129) and sends TERM to the build process `BP`; `timeout` forwards TERM to `install.sh`. The `wait` is repeated while `BP` is alive. *Why:* code comment: a trapped signal cuts a `wait` short. Afterwards the trap goes back to `exit 1`, `INTR` stays set so command loops `break`, and `build` reports `interrupted`.

### Sudo and root

- `SUDO` is chosen in `main`: `RITZ_GET_SUDO` if set (the GUI sets `pkexec`; set but empty means "no root available"), else `sudo` when stdin is a terminal, else empty. It applies to every command, `update` included (latest change: `update` used to force it empty).
- On a terminal (`SUDO=sudo`) `timeout` gets `--foreground`. *Why:* code comment: without it `timeout` makes the build a background process group and `sudo` cannot read the password from the terminal. Known ceiling (same comment): `--foreground` signals only `install.sh`, so a timed-out terminal build may leave its children running.
- ritz-get refuses to run as root: `main` exits 2 with `ritz-get: do not run with sudo; it asks for root itself when needed`. *Why:* SPEC: ritz-get is per-user and asks for root only through `$RITZ_GET_SUDO` when an `install.sh` needs it (R11, R33); `install.sh` always runs as the normal user.

## Using it

Quiet is the default; add `--verbose` (`-v`) to see everything. A failed build prints `NAME: FAILED (reason) — build log: PATH` and, unless `--verbose`, the last 15 log lines (`failed`). Under the GUI the log suffix is dropped because the contract has none.

## Options

| Name | Default | Meaning |
| --- | --- | --- |
| `RITZ_GET_TIMEOUT` | 3600 | seconds before `install.sh` is killed (tests use small values) |
| `RITZ_GET_SUDO` | `sudo` on a terminal, else empty | passed through to `install.sh`; the GUI sets `pkexec` |
| `RITZ_GET_OS_RELEASE` | `/etc/os-release` | file read by `print_deps` (tests) |
| `--verbose`, `-v` | off | stream the whole build output |

## Related links

- [Program spec](../spec/program-spec.md), [install](../commands/install.md), [update](../commands/update.md)
- [progress-output](progress-output.md)
- [SPEC.md](../../SPEC.md), [PORCELAIN.md](../../PORCELAIN.md)
