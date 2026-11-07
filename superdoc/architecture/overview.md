# Architecture Overview

The first doc to read. It maps the code and links out to the per-command, per-feature and spec pages instead of repeating them. User-facing behaviour is described in [README.md](../../README.md), [SPEC.md](../../SPEC.md) and [PORCELAIN.md](../../PORCELAIN.md); this tree is the agent-side navigation layer.

## Big picture

Ritz-Get is a package manager for the author's own programs and websites, written as one POSIX `sh` script (`ritz-get`, shape: CLI with subcommands, no GUI in this repo; the GUI is a separate repo that consumes the porcelain output). Each program is a git clone in one folder. The clone is the only state: installed means the clone exists, the checked-out branch is the branch you run, `HEAD` is the version. Ritz-Get clones it, runs the program's `./install.sh --install --yes`, and handles update, remove, branch switching, shortcuts and data cleanup. What exists is described by the manifest file `programs`.

## Process model

Single process, no daemon. `ritz-get:lock` takes an exclusive `flock` on fd 9 for every mutating command (a second run exits 5, or exits 0 silently for a cron `update`). `ritz-get:cmd_update` updates ritz-get itself first and then `exec`s the new script with `RITZ_GET_SELF_UPDATED=1`; the lock fd is inherited, so that run skips `lock`. Builds run through `ritz-get:run_script` with a timeout (`RITZ_GET_TIMEOUT`).

## Data flow

argv to exit code. `ritz-get:main` parses options into globals (`YES`, `BR`, `OFFLINE`, `ALL`, `PORC`, `DATAF`, `VERB`), maps the subcommand, refuses root, resolves the clone folder and shortcut folder from the config file, parses the manifest, locks, then calls `cmd_<name>` and `finish`.

```
argv
  │  options -> globals, subcommand -> cmd_<name>
  ▼
ritz-get:main          [boundary; refuses root]
  │  cfg dir= / shortcuts=  ->  SRCDIR, SHORTDIR
  ▼
ritz-get:load_mf       [awk parses programs -> $TMP/mf: E, S, D records]
  │
  ▼
ritz-get:lock          [mutating commands only]
  │
  ▼
ritz-get:cmd_install | cmd_update | cmd_list | ...
  │  git in SRCDIR/NAME; build -> run_script -> NAME/install.sh
  ▼
ritz-get:finish        [exit code from EXIT, set by bump]
```

- *Why:* the manifest is parsed once into temp records (`load_mf`, fields joined by a unit-separator byte `$US`) so every command reads it the same way, and invalid `data:` paths are dropped there with a warning rather than at deletion time. `data_ok` re-checks the resolved path at use.
- Exit codes accumulate with `bump` (3 missing dependencies outranks 4, which outranks other nonzero codes), so a multi-program run reports the worst class.
- Output goes through `say`/`bar`: on a terminal one progress bar replaces the transient lines; `RITZ_GET_GUI=1` makes `prog_begin` print `#start NAME` instead.

## Module map

| Path | Role |
| --- | --- |
| `ritz-get` | the whole program: helpers, manifest parsing, clone state, shortcuts, build, `cmd_*`, `lock`, `main` |
| `programs` | the manifest: sections, programs, websites; documents its own format |
| `install.sh` | ritz-get's own installer (spec-conforming): links `~/.local/bin/ritz-get` to its clone |
| `install-ritz-get.sh` | one-time curl-piped bootstrap installer: asks for the clone folder, clones, runs `install.sh` |
| `template/install.sh` | starting file for a program's `install.sh` |
| `tests/cli/run.sh` | CLI test suite (`sh tests/cli/run.sh`) |
| `tests/spec-check.sh` | checks a program repo against SPEC.md rules; self-test builds fixtures from the template |
| `icons/` | per-program icons for the websites/frontends, rules in `icons/FAMILY.md` |
| `icon.svg`, `icon.png` | ritz-get's own icon |
| `SPEC.md`, `PORCELAIN.md`, `README.md` | user-facing sources; link, do not copy |

Inside `ritz-get`, by area: config and paths (`cfg`, `setcfg`, `abspath`, `rreal`, `data_ok`), manifest (`load_mf`, `lookup`, `setup_lines`, `data_have`), clone state (`is_installed`, `branch`, `gone`, `held`, `changes`, `modified`, `unlisted`), shortcuts (`sc_*`), build (`run_script`, `sync_subs`, `build`, `print_deps`), install and remove (`install_one`, `remove_one`, `delete_one`), list (`probe`, `inst_fields`, `cmd_list`), update (`upd_check`, `upd_apply`, `upd_run`, `cmd_update`).

## Where to look for X

- Add or change a command: write `cmd_<name>` in `ritz-get`, add it to the `case $cmd` allow-list in `ritz-get:main` (and the `lock` list if it mutates), and to `ritz-get:usage`. See [commands](../README.md).
- A new manifest key (indented line): extend the awk in `ritz-get:load_mf`, add a record type if needed, and update the format comment in `programs` and SPEC.md section 6. See [manifest](../features/manifest.md).
- Change what a program's `install.sh` is told or how it runs: `ritz-get:run_script`; spec side in [program spec](../spec/program-spec.md).
- Change `list --porcelain`: `ritz-get:cmd_list` and `ritz-get:irow`; the contract is [porcelain](../features/porcelain.md). The field count is part of the contract.
- A list state (`modified`, `branch-gone`, ...): `ritz-get:inst_fields`.
- Self-update or locking: `ritz-get:cmd_update`, `ritz-get:lock` ([locking](../features/locking-and-self-update.md)).
- Shortcuts: `ritz-get:sc_make`, `ritz-get:sc_offer`, `ritz-get:cmd_shortcut` ([shortcuts](../commands/shortcuts.md)).
- Data deletion safety: `ritz-get:data_ok`, `ritz-get:delete_one` ([remove and delete-data](../commands/remove-and-delete-data.md)).
- Tests: `tests/cli/run.sh` ([cli tests](../tooling/cli-tests.md)); spec checks: `tests/spec-check.sh` ([spec check](../spec/spec-check.md)).

The full page index is [superdoc/README.md](../README.md).
