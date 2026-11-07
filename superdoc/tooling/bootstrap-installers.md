# Bootstrap installers — getting ritz-get itself onto a machine

Two POSIX sh scripts at the repo root: `install-ritz-get.sh` is the one-time bootstrap a new user pipes into `sh`; `install.sh` is ritz-get's own program installer (it follows the [program spec](../spec/program-spec.md) like any other program, since ritz-get is in `programs` as an entry that updates itself).

## How it works

### `install-ritz-get.sh` (one-time bootstrap)

- **Entry:** `main`. Refuses to run as root (`die`). Without `git` it prints `missing: git (try: pacman:git dnf:git apt:git)` to stderr, adds a package-manager line from `git_hint` (reads `RITZ_GET_OS_RELEASE`, default `/etc/os-release`; known families only, nothing for an unknown distro) and exits 3.
- **Questions.** `ask QUESTION DEFAULT [NOTTY_DEFAULT]` sets `ANS` from file descriptor 3, which `main` opens on `RITZ_GET_TTY` (default `/dev/tty`) when it is readable. With no terminal the default is used. *Why:* piped into `sh`, stdin is the script itself, so every answer must come from the terminal device instead (script header). `RITZ_GET_TTY` is the test hook: [cli-tests](cli-tests.md) feeds answers from a file through it.
- **Clone folder.** Resolution order: `RITZ_GET_DIR`, else `dir=` in `$XDG_CONFIG_HOME/ritz-get/config` (a previous choice), else `$XDG_DATA_HOME/ritz-get/src`. When `RITZ_GET_DIR` is unset it asks "Folder for the clones?" and normalises the answer with `normdir` (expands `~`, makes it absolute, strips trailing slashes). A non-default folder is written to the config file as `dir=`; the default is not written. The clone lands in `FOLDER/ritz-get`.
- **Already installed.** If `FOLDER/ritz-get/.git` exists and `linked` says `~/.local/bin/ritz-get` points into it, it prints "already installed ... use: ritz-get update" and exits 0, before asking anything. A clone that exists but is not linked takes the repair path: it skips the clone and re-runs `install.sh`. A non-empty folder that is not a ritz-get clone is refused.
- **Clone and install.** `git clone` from `RITZ_GET_GIT_BASE` (default `https://github.com`, overridable so tests use local `file://` repos) with `GIT_TERMINAL_PROMPT=0`, then runs `FOLDER/ritz-get/install.sh --install --yes` with output captured. The `note: ... is not in your PATH` line from `install.sh` is filtered out because the bootstrap prints its own hint. *Why:* on failure it runs `--remove --yes` and deletes what this run created (the whole new folder, or just the contents of a pre-existing empty one), "so a rerun starts clean" instead of reporting a false "already installed".
- **PATH prompt.** If `$HOME/.local/bin` is not on `PATH`, it names the login file the shell reads (zsh: `~/.zprofile`; otherwise `~/.bash_profile`, `~/.bash_login`, `~/.profile` in that order of existence, because bash skips `~/.profile` when either of the first two exists) and asks `[y/N]` before appending `export PATH="$HOME/.local/bin:$PATH"`. Default is no, and with no terminal nothing is edited. It checks the line is not already there.
- **GUI offer.** It runs `ritz-get list --offline --porcelain` and, only if an entry named `ritz-get-gui` exists (porcelain row `E`, third field), asks "Also install the GUI? [Y/n]" (default yes with a terminal, no without one). `install_gui` runs `ritz-get install ritz-get-gui`, tees the output, and on exit 0 runs `ritz-get shortcut ritz-get-gui` and points to the app menu. Exit 3 (missing build tools) is not a failure: it prints the `deps:`/`missing:` lines and the command to run later. Any other code dies with a message that ritz-get itself is installed. See [../../PORCELAIN.md](../../PORCELAIN.md) for the row format.
- **Environment:** `RITZ_GET_DIR`, `RITZ_GET_GIT_BASE`, `RITZ_GET_TTY`, `RITZ_GET_OS_RELEASE`; plus the standard `XDG_*` and `SHELL`.

### Root `install.sh` (ritz-get's own program installer)

- Parses `--install` / `--remove` / `--yes` like the spec requires (exit 2 on misuse, refuses root). Marker `# ritz-get-spec: 1` is on line 2.
- **Self symlink.** `--install` makes `$HOME/.local/bin/ritz-get` a symlink to `./ritz-get` of the clone (`ln -sfn "$here/ritz-get" "$bin/$NAME"`), the same symlink-into-the-clone model as every other program. It needs only `git` (exit 3 with a `missing:` line otherwise) and prints the `note:` about `PATH`.
- **Redirect into the clone folder.** It resolves the configured clone folder the same way ritz-get does (config `dir=`, else the default) and, when run from a checkout that is not `FOLDER/ritz-get`, says so, clones the origin there if needed and `exec`s that clone's `install.sh`. *Why:* ritz-get updates itself in its clone folder, so a link into some other checkout would never be updated.
- **`RITZ_GET_INSTALL_HERE=1`** skips the redirect and links the checkout as it is. *Why:* for test harnesses; [spec-check](../spec/spec-check.md) sets it so checking ritz-get's own `install.sh` links the temp clone under test.
- `--remove` deletes the link only if it points at this checkout's or the configured folder's `ritz-get` file.

## Using it

- New user: `curl -fsSL https://github.com/<owner>/ritz-get/releases/latest/download/install-ritz-get.sh | sh` (the exact line is in [../../README.md](../../README.md)). After that, `ritz-get update` updates ritz-get itself; the bootstrap is never needed again.
- Developer in a checkout: `./install.sh --install` links that checkout when it is already the configured clone, otherwise redirects as above.
- Tests for both scripts are in the "the one-time installer" section of `tests/cli/run.sh` ([cli-tests](cli-tests.md)); they cover no-tty defaults, piped stdin, answers via `RITZ_GET_TTY`, PATH file choice, missing git hints, a failing `install.sh` and repair of an unlinked clone.

## Options

| Variable | Used by | Meaning |
| --- | --- | --- |
| `RITZ_GET_DIR` | `install-ritz-get.sh` | clone folder; skips the folder question |
| `RITZ_GET_GIT_BASE` | `install-ritz-get.sh` | git host base URL, default `https://github.com` |
| `RITZ_GET_TTY` | `install-ritz-get.sh` | file read instead of `/dev/tty` (test hook) |
| `RITZ_GET_OS_RELEASE` | `install-ritz-get.sh` | os-release file for the git hint |
| `RITZ_GET_INSTALL_HERE` | `install.sh` | `1` links this checkout instead of redirecting into the clone folder |

## Related links

- [../spec/program-spec.md](../spec/program-spec.md), [../spec/spec-check.md](../spec/spec-check.md)
- [../commands/install.md](../commands/install.md), [../architecture/overview.md](../architecture/overview.md)
- [cli-tests.md](cli-tests.md)
