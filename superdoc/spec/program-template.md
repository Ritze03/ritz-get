# program-template — the starting install.sh for program repos

`template/install.sh` is the one template every program repo starts from. A port copies it to the repo root and edits only the per-program section; the plumbing below it already implements most spec rules.

## How it works

- **Layout.** The file runs top to bottom: marker lines (`# ritz-get-spec: 1` on line 2, R3), `set -eu`, derived variables, the `per-program section` (between the `# ---- per-program section` and `# ---- end per-program section` marker lines), then `ritz-get plumbing: do not edit below`. The self-test in [spec-check](spec-check.md) finds those two marker lines with `awk` and swaps in fixture sections, so do not rename them.
- **Variables for the per-program section:** `dir` (the clone, absolute, from `cd ... && pwd -P`, R15), `bin` (`$HOME/.local/bin`), `cfg` (`XDG_CONFIG_HOME`), `data` (`XDG_DATA_HOME`), `first` (non-empty on a first install: `$bin/$NAME` was not a symlink when the run started, decided before anything changes, R20), `yes` (1 under `--yes`).
- **What you fill in:** `NAME`, `TARGET`, `ROOT_LINK`, then the functions `check_tools`, `build`, `install_files`, `remove_files` (table in SPEC section 3). The default is a Go single-binary build (pattern P2) with Rust, meson and cmake variants in comments.
- **Helpers in the plumbing:**
  - `link TARGET LINK` does `mkdir -p` then `ln -sfn` (R13, R15); `unlink_ours LINK` deletes only a symlink pointing into the clone (R22).
  - `need TOOL pacman:PKG dnf:PKG apt:PKG` and `need_pc LIB ...` print `missing: TOOL (try: ...)` to stderr and set `missing`; `need_pc` adds `pkg-config` itself once (R26). `--install` runs `check_tools` first and exits 3 if `missing` is set, so all missing items are printed before the exit (R21).
  - Argument parsing (`usage` exits 2, R9) and the root refusal (R11).
  - Root: `run_root` is the single `$RITZ_GET_SUDO /bin/sh -c SCRIPT sh ARGS` call and maps exit 126 to `cancelled:` / exit 1 and 127 to `needs root: no password agent running...` / exit 4 (R33, R36). `root_check` runs before the build, exits 4 when root is needed and `RITZ_GET_SUDO` is empty, and exits 1 for a system path that is not ours (R34, R35). `root_link` and `root_unlink` do the stable link `$HOME/.local/share/ritz-get/links/NAME` and the `/usr/local/bin/NAME` link; all of it is inert unless `ROOT_LINK=yes`.
- **Order of steps.** `--install`: `check_tools`, exit 3 if missing, `root_check`, `mkdir -p build`, `build`, `install_files`, `root_link`, print `NAME installed`, then a `note:` if `~/.local/bin` is not on `PATH`. `--remove`: `root_unlink`, `remove_files`, unlink the stable link when `ROOT_LINK=yes`, print `NAME removed (config and user data left alone)`. *Why:* the root call comes after the build so a system link is never created for a build that failed (SPEC P6); `--remove` removes the system link first, before anything else (R36).
- **Atomic build.** The default `build` writes to `build/.NAME.new` and `mv -f` it onto `build/NAME`; with `set -e` a failed build never reaches the `mv`, so the previous build keeps working and a running program keeps its old file (R18).
- **Precedence.** If the template and SPEC.md disagree, SPEC.md wins (stated in the template header and SPEC section 3).

## Using it

SPEC section 3 gives the fetch commands (`curl` the raw file from the repo's `main` branch, `chmod +x`, `git update-index --add --chmod=+x`). Then pick patterns from the SPEC table (P1 and P2 for a binary, plus P3 to P6 for directory output, tray, daemon, root link) and run [spec-check](spec-check.md) until `ALL PASS`. Extras that need a window shortcut are a `NAME.desktop` file at the repo root, not code in `install.sh` (R37, R39).

## Related links

- [program-spec.md](program-spec.md), [spec-check.md](spec-check.md)
- [../../SPEC.md](../../SPEC.md), [../../template/install.sh](../../template/install.sh)
