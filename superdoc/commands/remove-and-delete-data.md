# remove and delete-data — uninstall keeps data, delete-data erases it

`ritz-get remove NAME...` (alias `uninstall`) uninstalls a program and deletes its clone but keeps its config and data. `ritz-get delete-data NAME...` is the separate, deliberate step that deletes that data afterwards. The reasoning behind the split is in [delete-data-design](delete-data-design.md).

## How it works: remove

- `ritz-get:cmd_remove` needs a name and calls `ritz-get:remove_one` per name. `main` maps `uninstall` to `remove`.
- `remove_one` refuses `ritz-get` itself: remove it with its own `install.sh --remove`, then delete the folder.
- **Not installed**: unknown name is an error; a program prints `not installed`; a website drops its shortcut if it has one (`shortcut removed`) else `no shortcut`. *Why:* a website has no clone, so the shortcut is all `remove` can take away; README: "`remove NAME` takes the shortcut away by itself, a website's too."
- **Installed**: if the clone has an executable `install.sh`, it runs `install.sh --remove` through `ritz-get:run_script` ([build-runner](../features/build-runner.md)). A non-zero exit keeps the clone: `FAILED (install.sh --remove exit N; clone kept)` with the log path. Then the shortcut is removed (`sc_rm`, `sc_db`), the clone is deleted, and `NAME: removed` is printed.
- A leftover `~/.local/bin/NAME` symlink is deleted only if it points into the clone (compared both literally and via `pwd -P`). *Why:* the comment says "no dangling link", and the check keeps a link that points anywhere else untouched.
- After a successful removal `ritz-get:data_hint` prints `NAME: data kept in ~/PATH, ... (delete with: ritz-get delete-data NAME)` for each declared data path that still exists.

## How it works: delete-data

- `ritz-get:cmd_delete_data` loops `ritz-get:delete_one`. Each name goes through these gates, each with its own message: invalid name; unknown program; website (`a website has no data`); **still installed** (`FAILED (uninstall first: ritz-get remove NAME)`); no declared data exists (`no data left`).
- **Where the paths come from**: only the `data:` lines of the program's manifest entry ([manifest](../features/manifest.md)), parsed in `ritz-get:load_mf` into `D` records. `ritz-get:data_have NAME [raw]` lists those that exist, as `PATH<US>~/PATH`; without `raw` it also applies `data_ok`.
- **Safety check** `ritz-get:data_ok PATH`: the resolved place (parent resolved, last name kept so a symlink is removed rather than followed) must be a strict descendant of the real `$HOME`, and neither equal to, inside nor above any folder from `ritz-get:prot_raw` (clone dir, config dir, cache, ritz-get's data dir, `~/.local/bin`, the shortcuts dir, the applications dir). A symlink's target is checked the same way. Refused paths print `not deleted: ~/PATH`, exit 1. Helpers: `rreal` (a `readlink -f` that works for not-yet-existing tails), `xdg_below_home`. The same rules are applied once more when the manifest is parsed, so bad `data:` lines are dropped with a warning.
- **Confirmation**: the survivors are listed with `du -sh` sizes. With `--yes` it deletes straight away. Otherwise it needs a terminal and no `RITZ_GET_GUI`; without one it prints `nothing deleted (pass --yes)` and exits 0. On a terminal it prints a warning and asks you to type the repository name (last path part of the manifest source, not the title); anything else prints `aborted`.
- **Deletion**: `data_ok` is checked again immediately before `rm`, and `rm -rf -- ./NAME` runs inside the parent directory that `data_ok` resolved, after verifying `pwd -P` still equals it. *Why:* the comment says that if the parent was swapped for a symlink in the meantime, nothing is removed. Success prints `NAME: data deleted`; any refusal sets exit 1 and suppresses that line.
- It never uses root.

## Using it

```sh
ritz-get remove NAME            # keeps data, prints where it is
ritz-get delete-data NAME       # type the repository name to confirm
ritz-get delete-data NAME --yes # no question (what the GUI calls after asking itself)
```

`ritz-get list` shows `data left` for an uninstalled program whose data exists (see [list](list.md)).

## Related links

[delete-data-design](delete-data-design.md) · [manifest](../features/manifest.md) · [shortcuts](shortcuts.md) · [build-runner](../features/build-runner.md) · [porcelain](../features/porcelain.md) · [README.md](../../README.md) · [PORCELAIN.md](../../PORCELAIN.md)
