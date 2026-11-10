# list — programs, websites and what is installed or behind

`ritz-get list` shows every manifest entry (programs and websites) plus installed clones the manifest does not know, and says for each whether it is installed, current, behind, modified or reachable. It never changes anything; it only fetches when you do not pass `--offline`.

## How it works

- `ritz-get:cmd_list` builds one tab-separated row file (`$TMP/rows`), then either prints it raw (`--porcelain`, see [porcelain](../features/porcelain.md)) or formats it with an awk table. The manifest comes from `ritz-get:load_mf` ([manifest](../features/manifest.md)); `ritz-get:unlisted` finds installed clones that are not in it (section `Unlisted`).
- `list NAME...` sets `WANT` and implies `ALL`, so named entries are shown whatever their reachability. Unknown names go through `ritz-get:unknown`. *Why:* "Installed programs are never hidden. `list NAME...` shows the named entries regardless of reachability" ([PORCELAIN.md](../../PORCELAIN.md)).
- **Probing** (`ritz-get:probe`): an installed clone gets `git fetch -q --prune --no-recurse-submodules`; an uninstalled program gets one `git ls-remote` of its branch (or `HEAD`). The result lands in `$TMP/f.NAME` (exit code), `r.NAME` (ls-remote output), `e.NAME` (stderr). All probes run as background jobs and `wait` joins them, so listing costs about one network round trip. `ritz-get:probed_ok` reads `f.NAME`.
- **Offline detection**: unless `--offline`, ritz-get's own repo is probed first. If that fails, or its stderr contains `429`, the whole run is treated as offline (`OFF=1`) and no other probe runs. *Why:* the comment in `cmd_list` says ritz-get's own repo "tells offline from 'no access'", so a lost network is not reported as every private repo being unreachable.
- **Installed rows** (`ritz-get:inst_fields`, then `ritz-get:irow`): sets `BRN VER HELD ST LAT BEH DIRTY AHEAD`. State `ST` is `unknown` offline, `fetch-failed` when the probe failed, `branch-gone` when `ritz-get:gone` says the upstream vanished, else `current`/`behind` from `rev-list --count HEAD..@{u}`. `modified` (dirty files or local commits) overrides all of them. Row construction is `ritz-get:row`.
- **Uninstalled rows**: `available`, `offline`, or `unreachable`. Unreachable rows are hidden unless `--all` and are counted in `#hidden N` (porcelain) or `N program(s) hidden (no access)`. A `429` in the probe's stderr counts as `offline`, not `unreachable`.
- **Remembered unreachability** (`$CACHE/unreachable`, `$CACHE` = `${XDG_CACHE_HOME:-$HOME/.cache}/ritz-get`, one manifest name per line): an online run over the whole manifest (no `NAME...`) rewrites it atomically (temp file + `mv`) with the names that came out `unreachable`. An offline run (`--offline`, or `OFF=1` from the self-probe) treats an uninstalled program listed there as `unreachable`: omitted unless `--all`, counted in `#hidden` / the human line. Named entries (`list NAME`) still show, as `unreachable`. A subset run (`WANT` set) never rewrites the file, because it probed only part of the manifest and would forget the rest. No file (cold start) means offline rows show every uninstalled program. *Why:* offline output used to leak programs the user has no access to (private repos), and the GUI paints `list --offline --porcelain` first, so they flashed up and stayed visible when truly offline. ritz-get owns reachability, so it remembers the last online answer; on a cold start it cannot know, so it accepts the leak. No new porcelain state: the rows are simply omitted.
- **Websites** are never probed (source starts with `http`); the state is `website`.
- **Setup and data records**: each entry also emits its `S` setup lines. `D` data records come from `ritz-get:data_have`: in porcelain mode only with `--data`, in the human table always (shown as `data left` on uninstalled programs). With `--porcelain --data` the size is `du -sk` via `ritz-get:kb`, otherwise `-`.
- The shortcut column comes from `ritz-get:sc_col` (see [shortcuts](shortcuts.md)).

## Using it

```sh
ritz-get list                       # table, fetches each remote
ritz-get list --offline             # no network: versions shown, status unknown
ritz-get list NAME... --all         # detail view for the named entries
ritz-get list --porcelain --data    # machine format, see PORCELAIN.md
```

A human row shows `branch date hash` plus a status such as `up to date`, `update available: N behind, latest ...`, `modified: N changed files, N local commits`, `branch X deleted on the remote; pick another: ritz-get branches NAME`, `fetch failed`, `[held]`. With names given, the table also shows source, shortcut state and setup steps. The footer prints `offline: not checking for updates` when offline.

## Options

| Flag | Meaning |
| --- | --- |
| `--offline` | skip every network call (`OFFLINE`) |
| `--all` | also show programs you cannot reach (`unreachable`) |
| `--porcelain` | tab-separated output for frontends, format in [PORCELAIN.md](../../PORCELAIN.md) |
| `--data` | with `--porcelain`: add `D` records with sizes |

## Related links

[porcelain](../features/porcelain.md) · [manifest](../features/manifest.md) · [update](update.md) · [hold](hold.md) · [remove-and-delete-data](remove-and-delete-data.md) · [shortcuts](shortcuts.md) · [overview](../architecture/overview.md) · [README.md](../../README.md)
