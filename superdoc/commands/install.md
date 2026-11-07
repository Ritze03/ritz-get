# install — clone, build, offer a shortcut, print setup lines

`ritz-get install NAME... [--branch B]` clones a manifest program, runs its `install.sh`, and reports what to do next. Installing an already installed program repairs it by re-running `install.sh`.

## How it works

- `ritz-get:cmd_install` needs at least one name (else usage error, exit 2), sets `PTOT` for the progress bar, and calls `ritz-get:install_one` per name after `prog_begin` ([progress-output](../features/progress-output.md)); it stops early on an interrupt (`INTR`).
- `install_one` validates the name (`valid`), looks it up (`lookup`), and refuses websites: "is a website, nothing to install".
- **Already installed**: `--branch` is refused with a pointer to `ritz-get switch NAME B` ([branches-switch-reset](branches-switch-reset.md)); otherwise it repairs (`installed, repairing`) and skips cloning. *Why:* the clone is the whole state (README), and SPEC says "The same command performs updates and repairs", so a repair is just the same `install.sh --install --yes` again.
- **Fresh**: branch is `--branch`, else the manifest branch (`DEFBR`), else the remote default. `git clone -q [-b B] $BASE/$SRC.git $SRCDIR/NAME`. `created` is set when the target folder did not exist, so a failed clone removes only what ritz-get made.
- **Build**: `ritz-get:build` ([build-runner](../features/build-runner.md)) syncs submodules and runs `install.sh --install --yes`. On success: `NAME: installed BRANCH HASH`, then `ritz-get:sc_refresh`, `ritz-get:sc_offer`, `ritz-get:setup_lines` (the manifest's `setup:` lines under `Additional steps required:`).
- **Failure after a fresh clone**: `ritz-get:cleanup_fresh NAME CREATED` runs the program's `install.sh --remove` against a throwaway log (`LOGTO=$TMP/cleanup.log`, so the install's own log is kept), then deletes the clone: the whole folder if ritz-get created it, otherwise only its contents. *Why:* SPEC says `--remove` MUST cope with a half-finished install because ritz-get runs it before deleting the clone of a failed first install. Message: `FAILED — nothing was installed`. A failed repair prints `FAILED — your installed version is unchanged and still works` (via `fail`).
- A program that needs a newer ritz-get (`build` rc 2, from its `# ritz-get-spec:` marker) prints `SKIPPED (needs a newer ritz-get; run: ritz-get update)`.
- Exit codes: failures call `bump` (3 missing dependency, 4 needs root, 1 other). Missing dependencies are collected and printed once as one `deps:` line at the end (`print_deps`).
- *Why the shortcut is offered, not made silently:* SPEC R39 says ritz-get installs `NAME.desktop` "only when the user asks for a shortcut", and `install.sh` must not write menu files itself. Details in [shortcuts](shortcuts.md).

## Using it

```sh
ritz-get install NAME              # clone, build, maybe add the start-menu shortcut
ritz-get install NAME --branch B   # first install from another branch
ritz-get install NAME              # again: repair
```

Run it as yourself: ritz-get passes `sudo` (terminal) or the GUI's `RITZ_GET_SUDO` to `install.sh`; with neither available, a build that needs root exits 4 and `needs root: run ritz-get install NAME` is printed ([update](update.md) covers the same mechanism).

## Options

| Flag | Meaning |
| --- | --- |
| `--branch B`, `-b B` | branch for a first install (`BR`) |
| `--yes`, `-y` | answer yes to the shortcut question |
| `--verbose`, `-v` | stream the whole build output instead of the bar and log tail |

## Related links

[build-runner](../features/build-runner.md) · [progress-output](../features/progress-output.md) · [shortcuts](shortcuts.md) · [update](update.md) · [remove-and-delete-data](remove-and-delete-data.md) · [locking-and-self-update](../features/locking-and-self-update.md) · [README.md](../../README.md)
