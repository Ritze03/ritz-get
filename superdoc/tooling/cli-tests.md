# CLI tests — `tests/cli/run.sh`

The regression suite for the `ritz-get` script and the two root installers. It runs entirely offline in a throwaway HOME, against local bare git repos reached through `file://`.

## How it works

- **Isolation.** The script makes a temp dir (`mktemp -d`, under `$TMPDIR` if set) and exports `HOME`, all four `XDG_*` variables, `XDG_RUNTIME_DIR` and `TMPDIR` into it, plus `LC_ALL=C`, `GIT_CONFIG_GLOBAL` (a test gitconfig that sets identity, `main` as the default branch and `protocol.file.allow=always`), `GIT_CONFIG_NOSYSTEM=1` and `GIT_ALLOW_PROTOCOL=file`. An `EXIT` trap deletes the dir. *Why:* no real HOME is touched and no network is needed. The test gitconfig, not ritz-get, allows the `file` protocol: ritz-get never does, real programs use https (comment in the submodules section).
- **Pointing ritz-get at fixtures.** `RITZ_GET_GIT_BASE=file://$T/remote` makes every `OWNER/REPO` resolve to a local bare repo; `RITZ_GET_MANIFEST` points at a test `programs` file; `RITZ_GET_GUI=1` is set for the whole suite and unset (`env -u`) only in the section that acts like a person at a shell. Unset on purpose: `RITZ_GET_SUDO`, `RITZ_GET_TIMEOUT`, `RITZ_GET_OS_RELEASE`, `RITZ_GET_SELF_UPDATED`.
- **Fixture programs.** `mkrepo NAME [SPEC] [MODE]` writes a spec-style `install.sh` from an inline template (marker `# ritz-get-spec: @SPEC@`) whose behaviour is chosen by a `mode` file in the repo: `ok`, `missing` (exit 3 lines), `root` (exit 4), `fail`, `tty` (reads `/dev/tty`, like sudo's prompt), `slow` (30 s sleep, for interrupt tests), `noisy`, `loud`. `newcommit NAME [MODE]` pushes a new commit, optionally switching the mode, to drive update, revert and failure paths. Other fixtures: a branch `dev`, repos shipping `NAME.desktop` and `icon.png`, a submodule repo, ritz-get itself (the real `ritz-get` and `install.sh` copied into a repo, so self-update runs the real thing), an installer remote, and an `xdg-open` stub.
- **Assertion helpers.** `rg ARGS` runs `sh ritz-get ARGS` with stdin `/dev/null` and captures `$T/out`, `$T/err`, merged into `$T/all` and the exit code in `RC`; variants `rge VAR=val`, `rgi` (stdin input), `rgn` (no `RITZ_GET_GUI`), `rgt` (a pseudo-terminal via util-linux `script`, input typed at it). Checks: `eq`, `rc`, `has`, `lacks`, `exists`, `gone`, `match`, `fld` and `row_is` for porcelain rows (see [../../PORCELAIN.md](../../PORCELAIN.md)). Each prints `PASS name` or `FAIL name: why`.
- **Sections** (comment banners in order): usage; list (manifest grammar, porcelain, offline); install, repair and failed first install; exit 3 aggregated deps line; update; refuse to run as root (a fake `id` earlier on `PATH` reports uid 0); terminal sudo (install.sh must be in the foreground group or reading `/dev/tty` hangs: `timeout --foreground`); self-update; modified (dirty, ahead, reset); branches and switch; branch deleted on the remote; remove, uninstall, unlisted; the lock (`flock`); interrupt (INT/TERM stop a running build); shortcuts; open; dir; install offers the shortcut and remove takes it away; submodules; the real `programs` file (parses, section order, name list, length limits, website URLs); the one-time installer ([bootstrap-installers](bootstrap-installers.md)); progress output and `--data`. The real-programs section hard-codes the expected entry list, so adding or removing a manifest entry means updating that assertion ([../features/manifest.md](../features/manifest.md)).
- **Result line.** Ends with `ALL PASS (N checks)` and exit 0, or `N FAILED (M passed)` and exit 1.

## Using it

```sh
sh tests/cli/run.sh
```

Required tools, checked first (`FAIL setup: TOOL not installed`): `git`, `flock`, `timeout`, `awk`, `setsid`. Some sections also use `script` (util-linux) for pseudo-terminal runs, and `mktemp`, `sed`, `readlink`, `du` and `id`. It takes a while because many checks build and update clones and some wait on timeouts, so run it under the project's launch wrapper for long jobs.

When adding a feature, add a fixture or a `mode` to `mkrepo` rather than a network call, keep every check inside `$T`, and keep the final tally lines. A program-side check of a real repo is a different tool: [spec-check](../spec/spec-check.md).

## Related links

- [../spec/spec-check.md](../spec/spec-check.md), [../spec/program-spec.md](../spec/program-spec.md)
- [bootstrap-installers.md](bootstrap-installers.md)
- [../commands/install.md](../commands/install.md), [../features/build-runner.md](../features/build-runner.md), [../features/manifest.md](../features/manifest.md)
- [../architecture/overview.md](../architecture/overview.md)
