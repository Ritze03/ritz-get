# spec-check — verify a program repo against the SPEC

`tests/spec-check.sh` runs the routine of SPEC section 7 against a program repo and prints one `PASS`, `FAIL` or `SKIP` line per check, each citing the rule it tests (R1 to R39). The last line is `ALL PASS` (exit 0) or `N FAILED` (exit 1). "Done" for a port means `ALL PASS`.

## How it works

- **Two modes** (`tests/spec-check.sh` bottom line): with arguments it calls `check_repo REPO_DIR [TOOL...]`; with none it calls `selftest`. `TOOL...` are build tools to hide from `PATH` for the exit-3 test.
- **Static checks on the real checkout** (`check_repo`): git mode 100755 (R1), `#!/bin/sh`, `sh -n` and `dash -n` when dash exists (R2), the marker in the first 5 lines (R3), `NAME=` (R4), `icon.png` present, tracked and exactly 1024x1024 read from the PNG header with `od` (R5), and greps over non-comment lines for the never-list: direct `sudo`/`pkexec`/`su`/`doas`, state-changing git commands, `npm install`, `go mod tidy`, `cargo build` without `--locked`, writes into `.../applications` (R37, R6), and `NAME.desktop` validity (R39, plus `desktop-file-validate` when installed). A missing icon FAILs with "Do NOT create one": the script never offers to fix it.
- **Throwaway world.** It `git clone`s the repo into a temp dir, runs the submodule update ritz-get runs, then copies over uncommitted and untracked changes (`git ls-files -mo`), so the checkout and the real HOME stay untouched. `run LOG ARGS...` executes `./install.sh` like ritz-get does: cwd is the clone, stdin `/dev/null`, `HOME` and all four `XDG_*` variables point into the temp dir, `RITZ_GET_SPEC=1`, `NO_COLOR=1`, `TERM=dumb`, no session bus, `timeout` (default 1800 s, `SPEC_CHECK_TIMEOUT`) if present. Toolchain caches (Go, Cargo, npm) stay in the real home so builds are fast.
- **Runtime phases, in order:** usage errors exit 2 and change nothing (R9); `--remove` on nothing installed exits 0 (R23); with tools hidden, `--install` exits 3 with well-formed `missing:` lines naming concrete packages and changes nothing (R21, R25, R26; `missing_lines` rejects `base-devel`, `build-essential` and `@groups`); if `install.sh` uses `need_pc`, a run with `PKG_CONFIG_LIBDIR=/nonexistent` must exit 3 too; for `ROOT_LINK=yes` programs, exit 4 without a helper and the pkexec exit codes 127/126 through a fake password helper that only accepts the shape `/bin/sh -c SCRIPT sh ARGS` with `ln -sfn` and `rm -f` (R27, R32 to R36); install twice, same links and unchanged `git status --porcelain` (R6, R17, R12 to R14, R28); restart line when a background part exists (R30); move the clone, install again, links follow (R15); `--remove` with tools hidden, config and data survive, nothing left, twice, and on a partly installed program (R22 to R24).
- **Exit 3 or a missing tool at runtime.** If the first install itself exits 3 (a tool really is missing on this machine), the runtime checks print `SKIP` and the script returns; passing tool names only hides them for the exit-3 test.
- **Self-test.** `selftest` builds five fixture repos from `template/install.sh` with `awk`, replacing the text between the `per-program section` marker lines with a per-fixture section: `basic` (script plus `need_pc`), `service` (autostart P4 plus systemd P5, with a `NAME.desktop`, and `svc_hook` for R20/R30), `dirswap` (P3, with `swap_hook`), `root` (P6) and `sub` (a git submodule). A fake `pkg-config` and a fake build tool are put first on `PATH`, and `mkpng` writes a 1024x1024 PNG header as the icon. It sets `GIT_ALLOW_PROTOCOL=file` for the submodule fixture only. Run it from a ritz-get clone because it finds the template at `tests/../template/install.sh`. *Why:* the template must pass its own check in every variant, so a template edit that breaks a rule is caught before a port copies it ([program-template](program-template.md)).
- **Environment guards.** `run` exports `RITZ_GET_INSTALL_HERE=1` because ritz-get's own root `install.sh` would otherwise redirect into the default clone folder instead of linking the checkout under test ([bootstrap-installers](../tooling/bootstrap-installers.md)). It also sets `VK_LOADER_LAYERS_DISABLE='*LS_frame_generation*'` because an implicit Vulkan layer writes a config file whenever Vulkan loads, which would look like a stray file (false FAILs for R13/R22/R23); the comment in `run` and SPEC section 7 both say so.
- **Not covered by the script** (SPEC section 7 lists them as a manual checklist): copies out of the clone, atomic `mv` of every output, no stdin reads under `--yes`, no self-installer, a real systemd session, root on a real machine, other branches.

## Using it

```sh
sh tests/spec-check.sh                    # self-test of the template
sh tests/spec-check.sh /path/to/repo go   # a program repo, hiding `go` for the exit-3 test
```

Needs `git`, `od`, `find`, `sort`, `mktemp`; `timeout` is optional. `install.sh` must be committed or at least `git add`ed (R1). On failure the temp dir is kept and its path printed (`logs kept in ...`; the self-test prints `fixtures kept in ...`); on success it is removed. The FAIL text shortens temp paths to `~/` and `CLONE`.

## Related links

- [program-spec.md](program-spec.md), [program-template.md](program-template.md)
- [../tooling/cli-tests.md](../tooling/cli-tests.md) (the separate CLI suite)
- [../../SPEC.md](../../SPEC.md) section 7
