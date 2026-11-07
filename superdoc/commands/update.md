# update — rebuild only what changed

`ritz-get update [NAME...] [--yes]` fast-forwards installed programs whose branch has new commits and rebuilds them. A failure in one program does not stop the others.

## How it works

- `ritz-get:cmd_update` picks the programs: no names means every installed program of the manifest (`is_installed`); named programs set `EXPL=1`. ritz-get itself goes first; the self-update and restart are described in [locking-and-self-update](../features/locking-and-self-update.md), not here.
- `ritz-get:upd_run` has two phases. First `ritz-get:upd_check` per name; then one confirmation (`Will update: ... Continue? [y/N]`, skipped by `--yes`); then `ritz-get:upd_apply` per queued name.
- `upd_check` skips, in this order, printing a line and counting `SK`:
  - installed but not in the manifest: `SKIPPED (not in the manifest; only remove works)`;
  - website: `website, nothing to update`;
  - **held** and not named explicitly: `held (ritz-get unhold NAME)` ([hold](hold.md)). *Why:* the usage text says hold leaves NAME out of `update` "without a name", so naming it overrides the hold.
  - **modified** (`ritz-get:modified`: changed files or local commits): `SKIPPED (local changes; ritz-get reset NAME to discard them)`. *Why:* README: "so your work is never overwritten".
  - then `fetch -q --prune --no-recurse-submodules`; failure is `fetch failed`.
  - **branch gone** (`ritz-get:gone`: an upstream is configured but no longer resolves after the prune): `SKIPPED (branch X was deleted on the remote; ritz-get branches NAME, then ritz-get switch NAME BRANCH)`. `gone` must be called after `fetch --prune` (its comment), which is why the fetch prunes.
  - otherwise `rev-list --count HEAD..@{u}`: zero is `up to date`, more is queued in `todo`.
- `upd_apply` remembers `HEAD`, runs `merge --ff-only @{u}` (failure: `cannot fast-forward; ritz-get reset NAME`), then `ritz-get:build`. Success prints `NAME: updated OLD -> NEW`, refreshes the shortcut (`sc_refresh`) and counts `UP`. A failed build runs `git reset --keep OLD` and re-syncs submodules, so clone and installed version stay as before; "needs a newer ritz-get" is a skip. *Why:* SPEC R18, a failed build must leave the old install working.
- **Root**: `build` runs `install.sh` with `RITZ_GET_SUDO` set in `main`: the GUI's value if set, `sudo` on a terminal, empty otherwise (cron). So `update` asks for the password itself like the other commands; with none available a program that needs root exits 4 (`needs root; run: ritz-get install NAME`). For terminal sudo `ritz-get:run_script` passes `timeout --foreground`. *Why:* without it `timeout` moves the build to its own process group, which is a background group, and `sudo` cannot read the password from the terminal (comment in `run_script`). Known ceiling, same comment: a timed-out terminal build may leave child processes running.
- The run ends with `N updated, N skipped, N failed` and writes it, timestamped (plus `failed: NAMES`), to `$CACHE/last-run`.

## Using it

```sh
ritz-get update            # all installed, asks first
ritz-get update --yes      # for cron or your system update script
ritz-get update NAME       # explicit: ignores hold, still skips modified
```

From cron (no terminal, no GUI) a busy lock exits 0 silently (`ritz-get:lock`).

## Related links

[locking-and-self-update](../features/locking-and-self-update.md) · [build-runner](../features/build-runner.md) · [hold](hold.md) · [branches-switch-reset](branches-switch-reset.md) · [list](list.md) · [progress-output](../features/progress-output.md) · [README.md](../../README.md)
