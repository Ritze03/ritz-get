# Locking and self-update

One changing ritz-get at a time, and an `update` that replaces ritz-get itself then carries on with the new code.

## How it works

- `ritz-get:lock` opens `${XDG_RUNTIME_DIR:-${XDG_CACHE_HOME:-~/.cache}}/ritz-get.lock` on fd 9 and takes `flock -n 9`. It never blocks; the lock is released when the process dies. On failure: `update` from cron (no tty on stdin or stdout, no `RITZ_GET_GUI`) exits 0 silently; otherwise `busy: another ritz-get is running` on stderr, exit 5. *Why:* README: a second ritz-get running at the same time is detected, so `update --yes` is safe from cron.
- `main` calls `lock` for install, update, remove, delete-data, switch, reset, hold, unhold and shortcut; `cmd_shortcuts` and `cmd_dir` lock only when given a PATH. `list`, `branches` and `open` take none.
- `run_script` starts `install.sh` and its stream helpers with `9>&-`, so builds do not inherit the lock fd.

### Self-update in `cmd_update`

1. Collect names (installed manifest programs when none given, else `EXPL=1`). `ritz-get` is split out as `self`; the rest go to `rest`.
2. If `self`: `upd_run ritz-get` runs first. `upd_apply` sets `SELFUP` when ritz-get itself was rebuilt.
3. If `SELFUP` and `rest` is not empty: print `ritz-get: updated itself, restarting`, `rm -rf "$TMP"`, `export RITZ_GET_SELF_UPDATED=1`, then `exec "$SRCDIR/ritz-get/ritz-get" update --yes [--verbose] [rest]` (names only when they were explicit). The code comment: "continue in the new script; the lock fd stays open".
4. In the new process `main` skips `lock` because `RITZ_GET_SELF_UPDATED` is set (fd 9 is inherited across `exec`, so the lock is still held); `cmd_update` sets `UP=1` so the self-update counts in the summary, and clears `self` so ritz-get is not checked a second time. The new script then updates the rest.

*Why ritz-get goes first:* README: "`update` first updates Ritz-Get itself and, if that changed, continues with the new version". The new version matters because `build` skips a program whose `install.sh` declares a newer spec than the running script speaks (`SKIPPED (needs a newer ritz-get)`).

Ordering constraints visible in the code: the temp dir is removed before the `exec` (an `exec` replaces the shell, so its `EXIT` trap does not run); `RITZ_GET_SELF_UPDATED` must be exported before the `exec`, and it is what makes the new process skip both `lock` and the self step. With no other programs to update there is no restart; the run just ends with the summary.

## Related links

- [update command](../commands/update.md)
- [progress-output](progress-output.md) (exit code 5), [PORCELAIN.md](../../PORCELAIN.md)
