# ritz-get program spec

**Spec version: 1**

This file says how a program's git repo must look so that **ritz-get** can install, update and
remove it. It is complete on its own: you do not need ritz-get cloned, and you need nothing else
to make a repo conform. It is written to be handed to an agent that works in some other
program's repo.

The key words MUST, MUST NOT, SHOULD and MAY are used as in RFC 2119. Rules are numbered
(R1, R2, ...) so that the check script, reviews and PRs can point at them.

> **Icons: agents never create, edit or re-export icons.** Every program repo needs an
> `icon.png` (rule R5). The maintainer makes them himself. **If `icon.png` is missing, report it
> and stop at that point:** no placeholder, no generated image, no resized or converted copy,
> no merge. Whatever else you finished stays in the PR, which is then marked
> `waiting for icon.png`.

**If you are an agent porting a repo, work in this order:**

1. Read section 1 (two minutes) and section 2 (the rules).
2. Check the icon now: does `icon.png` exist at the repo root? If not, see the box above.
3. Pick your patterns in section 3, then fetch the template.
4. Write `install.sh` (plus `.gitignore` entries, and `NAME.desktop` if the program has a window).
5. Run the check script (section 7) until every line says PASS and the last line is `ALL PASS`.
6. Deliver as section 8 says: one PR, plus the manifest entry from section 6 in your reply.

---

## 1. What ritz-get is and how it calls you

ritz-get installs a small set of programs on any Linux distro by cloning each one's git repo
into a *repo folder* (default `~/.local/share/ritz-get/src/NAME`, but the user can move it
anywhere) and running that clone's `install.sh`. The clone is the program: its checked-out
branch is what the user runs and its `HEAD` is the version. Everything an install puts anywhere
else is a **symlink into the clone**, so removing the symlinks and the clone is a complete
uninstall. A CLI (`ritz-get`) and a GUI both drive the same `install.sh`; neither talks to your
program in any other way. `NAME` below always means the program's manifest name (section 6): it
is also the command name and the `NAME.desktop` file name.

ritz-get runs your script in exactly these two forms:

| When | Command |
|---|---|
| first install, every update, repair, branch switch, reset, repo-folder move | `./install.sh --install --yes` |
| remove | `./install.sh --remove --yes` |

Always with:

- **cwd** = the clone root. Do not rely on where the clone is or what its folder is called.
- **stdin** = `/dev/null`. stdout and stderr are pipes, not a terminal; they are shown live in a
  log pane. By default a terminal run of ritz-get shows only lines starting with `missing:`,
  `deps:`, `note:`, `restart:` or `setup:` and writes everything else to the build log
  (`~/.cache/ritz-get/logs/NAME.log`); the GUI and `--verbose` show the full stream, so every
  line a user must act on MUST carry one of those prefixes.
- **user** = the normal user, never root.
- **environment** = the user's own, plus:
  - `RITZ_GET_SPEC=1`: the spec version ritz-get speaks.
  - `RITZ_GET_SUDO`: `sudo` (ritz-get run in a terminal) or `pkexec` (GUI password dialog) for
    interactive commands, empty for unattended `update`. Unset and empty both mean "no root
    available".
  - `NO_COLOR=1` and `TERM=dumb`.
  - `XDG_*` variables may or may not be set.
- **time limit**: a run that takes longer than 60 minutes is killed and counts as failed.

Before `--install`, ritz-get has already cloned, fetched and checked out the commit to build, and
brought its submodules to the commits it records (`git submodule update --init --recursive` after
every clone, update, switch and reset).
If `--install` fails, ritz-get puts the clone (submodules included) back on the previous commit
and tells the user "your installed version is unchanged and still works", so a failed build MUST
leave the old install working (R18). If the *first* install fails, ritz-get runs `--remove --yes` before it
deletes the clone, so `--remove` MUST cope with a half-finished install (R23); it then says
"nothing was installed" instead, because there is no old version. After a
successful `--remove`, ritz-get deletes the clone.

A human may also run `./install.sh --install` or `--remove` by hand, without `--yes`.

---

## 2. Rules

### 2.1 Files in the repo

- **R1** The repo MUST have an executable `install.sh` at its root, committed with git mode
  `100755` (`git update-index --chmod=+x install.sh`).
- **R2** `install.sh` MUST be POSIX sh: first line exactly `#!/bin/sh`, no bashisms, and it MUST
  pass `sh -n`.
- **R3** One of the first 5 lines of `install.sh` MUST be exactly `# ritz-get-spec: 1`, the spec
  version it targets.
- **R4** `install.sh` MUST contain a line `NAME=...` with the program's manifest NAME.
- **R5** **`icon.png`** MUST exist at the repo root, be **exactly 1024x1024 pixels**, and be
  tracked in git on the branch users install (transparency is allowed). ritz-get shows it on the
  program's card before installation (fetched through GitHub's raw URL) and uses it for the
  shortcut. `icon.svg` MAY exist next to it: the original artwork the PNG was exported from; it
  is never checked or used. **Agents never create, edit or re-export icons; if `icon.png` is
  missing, report it and stop at that point.**
- **R6** After `--install`, `git status --porcelain` in the clone MUST print exactly what it
  printed before. Build output is git-ignored by a committed `.gitignore`, and nothing may
  rewrite a tracked file: `npm ci` (not `npm install`), `cargo build --locked`, no
  `go mod tidy`, no code generators that rewrite committed files. (ritz-get treats a clone with
  changed or untracked files as *locally modified* and refuses to update it.) A Rust program MUST
  also cope with a rustup that has no default toolchain (`cargo` is then a shim that exits with
  "no default is configured"): see the Rust lines in P2.
- **R7** Generated and built files SHOULD all go into one git-ignored directory `build/` at the
  clone root (`.gitignore` line: `/build/`). If the repo already tracks a `build/` directory, use
  `.ritz-build/` and read it wherever this file says `build/`. Output directories that cannot be
  moved (`target/`, `node_modules/`, `dist/`) MUST be ignored too.
- **R8** The program MUST be built from the checked-out working tree. Downloading the program
  itself prebuilt (release assets, AppImages of itself) is not allowed. Fetching dependencies
  through the build tool (Go modules, crates, npm packages) is fine.

### 2.2 Arguments

- **R9** `install.sh` MUST accept `--install` or `--remove`, plus an optional `--yes`, in any
  order. Anything else, or neither or both of `--install` / `--remove`, MUST print a usage line to
  stderr and exit **2**, before changing anything.
- **R10** With `--yes` it MUST NOT read stdin and MUST NOT print questions (no `[y/N]`, no menus,
  no "(--yes)" notes): it takes the default answer silently. Without `--yes` it MAY ask a human;
  on EOF it MUST abort without writing anything.
- **R11** It MUST refuse to run as root (`id -u` is 0) with a message and a non-zero exit.

### 2.3 Where files go: symlinks only

- **R12** The command MUST land at exactly `$HOME/.local/bin/NAME`, as a symlink to an
  executable inside the clone. Extra commands, if any, SHOULD be named `NAME-something`.
- **R13** Every path `install.sh` creates outside the clone MUST be a symlink pointing into the
  clone. Nothing is copied or written out of the clone: not the binary, not `.desktop` files,
  icons, autostart entries or systemd units. A file whose content depends on the machine
  (absolute paths) is generated **inside** `build/` first and then symlinked (patterns P4, P5).
  Directories that hold the links may be created.
- **R14** Paths outside the clone MUST be under `$HOME` (the root link of R32 is the one
  exception) and MUST honour `XDG_CONFIG_HOME`, `XDG_DATA_HOME`, `XDG_CACHE_HOME` and
  `XDG_STATE_HOME`, with their standard defaults (`~/.config`, `~/.local/share`, `~/.cache`,
  `~/.local/state`). `~/.local/bin` is fixed.
- **R15** Symlinks MUST be made with `ln -sfn` to absolute targets computed from the script's own
  location (`dir=$(cd "$(dirname "$0")" && pwd -P)`), on every run, never "only if missing". The
  user can move the repo folder, after which ritz-get re-runs `--install` and every link must
  follow.
- **R16** The program MUST work when started through its symlink. A program that finds its own
  files relative to its executable MUST resolve the symlink first (`readlink -f "$0"` in sh,
  `filepath.EvalSymlinks(os.Executable())` in Go, `std::fs::canonicalize(std::env::current_exe()?)`
  in Rust).

### 2.4 Install, update, idempotency

- **R17** `--install` MUST succeed on a fresh machine and again over an existing install, leaving
  the same set of paths and link targets. The same command performs updates and repairs, so it MUST
  also work over an install made by an older version of the program, including an old copy
  (not a link) at `~/.local/bin/NAME`, which `ln -sfn` replaces.
- **R18** Builds MUST be atomic: write build output to a temporary name inside the clone and `mv`
  it onto the final name (patterns P2, P3). A failed build MUST leave the previous build working.
  Never write into a file that a running program is executing.
- **R19** `--install` MUST be safe while the program is running. It MUST NOT kill, restart or
  start processes, except its own systemd user service (R29).
- **R20** "First install" means `$HOME/.local/bin/NAME` was not a symlink when the run started
  (decide this before linking anything). Optional extras that the user can switch off (an
  autostart entry, an enabled service) are set up on first install only. On later runs they are
  refreshed only if they still exist, so an update never undoes the user's opt-out.
- **R21** Before changing anything, `--install` MUST check that every build tool and library it
  needs is present, and exit 3 if not (R26). Exit 3 and exit 4 MUST leave the machine unchanged:
  nothing written outside the clone, no existing link touched.

### 2.5 Remove

- **R22** `--remove` MUST delete every path that `--install` created outside the clone. It MUST
  delete a path only if it is a symlink pointing into this clone (check with `readlink`; the
  template's `unlink_ours` does). It MUST NOT delete configuration or user data, even data the
  program created at runtime. ritz-get's `delete-data` deletes the `data:` paths the manifest
  declares (section 6), after the user types the repository name (the `REPO` of `OWNER/REPO`) to confirm, or with `--yes`; program authors list there every folder their program creates outside
  the clone.
- **R23** `--remove` MUST exit 0 when the program is not installed, or only partly installed.
- **R24** `--remove` MUST NOT build anything and MUST NOT need a build tool or the network. It
  need not clean `build/`; ritz-get deletes the clone afterwards.

### 2.6 Exit codes and output

- **R25** Exit codes:

  | Code | Meaning | ritz-get shows |
  |---|---|---|
  | 0 | success | installed / removed |
  | 2 | usage error (R9) | failed |
  | 3 | a build tool or library is missing (R26) | `NEEDS <tool>`, plus one copy-paste install command |
  | 4 | a root step is needed and cannot be done (R27) | `SETUP NEEDED` |
  | anything else | failed | failed, with the log |

- **R26** For exit 3, `install.sh` MUST print **one line per missing item to stderr**, in exactly
  this form, after checking **all** items and before changing anything:

  ```
  missing: TOOL (try: pacman:PKG dnf:PKG apt:PKG)
  ```

  `TOOL` is one word: a command name (`go`) or a pkg-config name (`wayland-client`). Each hint
  is `MANAGER:PKG`, space-separated, with MANAGER one of `pacman`, `dnf`, `apt`. `PKG` is the
  package name for that manager; several packages are joined by commas with no spaces
  (`dnf:gcc,pkg-config,wayland-devel`). Leave a manager out when you do not know the package; list
  at least one. Hints MUST name **concrete packages, never package groups**: `pacman:gcc`, not
  `pacman:base-devel`; `apt:gcc,make`, not `apt:build-essential`; no dnf `@group`. Example:

  ```
  missing: go (try: pacman:go dnf:golang apt:golang-go)
  ```

  Do **not** detect the distro and do not print a `sudo ... install` command: ritz-get collects
  the lines of all missing items, reads `/etc/os-release` and turns them into one command.
- **R27** For exit 4, it MUST print one line to stderr starting with `needs root:`, for example
  `needs root: run ritz-get install NAME`.
- **R28** Output MUST be plain text lines: progress on stdout, errors on stderr. No ANSI colours,
  no `\r` progress bars, no `clear`, no `tput`. Pass a no-colour option to build tools that need
  one. Keep it to about one line per step; the user reads it in a log pane. Hints SHOULD be lines
  starting with `note: `, restart hints MUST start with `restart: `. The last line on success
  SHOULD be `NAME installed` or `NAME removed`. By default a terminal run of ritz-get shows only
  lines starting with `missing:`, `deps:`, `note:`, `restart:` or `setup:` and writes everything
  else to the build log (`~/.cache/ritz-get/logs/NAME.log`); the GUI and `--verbose` show the
  full stream, so every line a user must act on MUST carry one of those prefixes.

### 2.7 Background parts

- **R29** A program with a **systemd user service** MUST, on `--install`, generate the unit into
  `build/` and link it with a plain symlink (the template's `link`, never `systemctl --user link`) into
  `$XDG_CONFIG_HOME/systemd/user/` (pattern P5). Every call to the user manager MUST be guarded
  by `systemctl --user show-environment` and be best effort: with no reachable user manager
  (cron, a throwaway HOME) it prints a `restart:` line and still exits 0. With one, a first
  install runs `daemon-reload` and `enable --now`; later runs run `daemon-reload` and
  `try-restart`. `--remove` disables and stops the service first, then removes the links.
- **R30** A background part that is not a systemd service (a tray app started by autostart) MUST
  NOT be started or stopped by `install.sh`. On every later run (not a first install, R20) it MUST
  print one line `restart: NAME to use the new version`, **unconditionally**: whether or not the
  program is running, and without trying to find out. On a first install it SHOULD print how to
  start it.
- **R31** `install.sh` MUST NOT start the program in the foreground or leave a process running
  after it exits, apart from the systemd service.

### 2.8 Root

Most programs never need root. Root exists for a program that has to be reachable from a system
path (gamescope-ritz is the case). It is allowed **on first install only**, so that unattended
updates never wait for a password. The template does all of it when you set `ROOT_LINK=yes`.

- **R32** Root MAY only create or delete **symlinks**; it never copies a file. The system link is
  named after the program, `/usr/local/bin/NAME` (so it cannot collide with a distro file such as
  `/usr/bin/gamescope`), and points at a **stable user link**
  `$HOME/.local/share/ritz-get/links/NAME` (a fixed path, not `XDG_DATA_HOME`), which `install.sh`
  keeps pointing into the clone on every run (`ln -sfn`, no root). When the repo folder moves, the
  root link still resolves and root is never needed again. `setcap`, `chmod u+s`, `chown`,
  package installs and edits to `/etc` are out of scope: they would have to be repeated after every
  rebuild.
- **R33** All root steps of a run go into **one** call, in exactly this shape, with the values
  passed as arguments (pkexec drops the environment) and `/bin/sh` by absolute path:

  ```sh
  $RITZ_GET_SUDO /bin/sh -c 'ln -sfn "$1" "$2"' sh "$stable" "$sys"
  $RITZ_GET_SUDO /bin/sh -c 'rm -f "$1"' sh "$sys"
  ```

  The script may contain only `ln -sfn` and `rm -f`, all paths absolute. `install.sh` MUST NOT
  call `sudo`, `pkexec`, `su` or `doas` any other way. One call is one password prompt.
- **R34** A root step runs only when the system link is missing or wrong (normally on first
  install only). If one is needed and `RITZ_GET_SUDO` is empty or unset, `install.sh` MUST exit
  **4** with `needs root: run ritz-get install NAME`, **before building or writing anything**
  (R21).
- **R35** `install.sh` MUST NOT replace a system path that is a regular file, or a symlink that is
  not one of ours (a live link, or a link that does not end in `/ritz-get/links/NAME`). That is
  someone else's file, often a distro package's. It MUST exit 1 and say so. Only a dead
  `.../ritz-get/links/NAME` link, left by an older location, may be replaced.
- **R36** `--remove` removes the system link the same way (`rm -f` in a root call), before
  removing anything else. If the link exists, points at our stable link and `RITZ_GET_SUDO` is
  empty, it MUST exit 4 before removing anything (`needs root: run ritz-get remove NAME`). Results
  of the root call: exit code 126 (the password dialog was dismissed) prints `cancelled: ...` and
  exits 1 (a plain failure; ritz-get cleans up a failed first install with `--remove`); exit code 127 (not authorised, or **no password
  agent is running**) exits 4 with `needs root: no password agent running; run ritz-get install
  NAME in a terminal`; any other non-zero code exits 1.

### 2.9 Never

- **R37** `install.sh` MUST NOT:
  1. call `sudo`, `pkexec`, `su` or `doas` directly (only `$RITZ_GET_SUDO`, R33);
  2. install system packages: it reports them with exit 3;
  3. run git commands that change the clone: no `pull`, `fetch`, `checkout`, `reset`, `clean`,
     `stash`, `commit`, `submodule update`. Read-only git (`rev-parse`, `describe`) is fine, with a
     fallback for when it fails. Git submodules are allowed: ritz-get checks them out before
     `--install`, so `install.sh` may assume they are present and must not fetch them itself. Git
     LFS is not supported;
  4. modify tracked files (R6);
  5. write anywhere in the repo folder outside its own clone, or touch another program's files;
  6. write `.desktop` files into `~/.local/share/applications` (or anywhere else a menu reads),
     or any menu files: start-menu shortcuts belong to ritz-get (section 4). A tray program's
     autostart entry is not a shortcut and is allowed (P4);
  7. edit shell startup files or `PATH`: print a `note:` instead;
  8. delete or overwrite config or user data;
  9. leave temp files outside the clone.
- **R38** The program itself MUST NOT contain a self-installer: no `install` / `uninstall`
  subcommand, no code that copies itself into `~/.local/bin` or writes autostart entries,
  launchers or units. `install.sh` does all of it. If the repo has one, the port removes it, with
  its code and tests, and points the README at `install.sh` (section 8). This does not forbid the
  program from creating **its own user configuration** at run time, outside the clone: for example
  a daemon that writes a systemd slice or a config file under `~/.config` once, if it is missing,
  and never overwrites it. That is user config, so it stays on `--remove` (R22). `install.sh`
  itself never writes such files (R13).

---

## 3. Template and patterns

There is **one template**. Start from it:

```sh
curl -fsSL https://raw.githubusercontent.com/Ritze03/ritz-get/main/template/install.sh -o install.sh
chmod +x install.sh
git update-index --add --chmod=+x install.sh
```

Edit only its per-program section (between the `per-program section` marker lines). The rest
already does argument parsing (R9), refusing root (R11), the `# ritz-get-spec: 1` marker (R3), the
`first` flag (R20), `link` and `unlink_ours` (R13, R15, R22), `need` / `need_pc` with the exit-3
lines (R26), the exit-4 and root-call logic (R32 to R36, when `ROOT_LINK=yes`), and the order of
steps. If the template and this file ever disagree, **this file wins**.

What you fill in:

| In the template | You write |
|---|---|
| `NAME`, `TARGET` | the manifest name; the executable inside the clone (`build/NAME`) |
| `ROOT_LINK` | `no`, or `yes` for pattern P6 |
| `check_tools` | one `need TOOL pacman:PKG dnf:PKG apt:PKG` per tool, one `need_pc LIB ...` per pkg-config library |
| `build` | the build, writing to a temporary name in `build/` and `mv`ing it over the final one |
| `install_files` | `link "$dir/$TARGET" "$bin/$NAME"` plus the extras of P3 to P5 |
| `remove_files` | `unlink_ours` for exactly the paths `install_files` links |

Variables available there: `$dir` (the clone, absolute), `$bin` (`~/.local/bin`), `$cfg`
(`$XDG_CONFIG_HOME`), `$data` (`$XDG_DATA_HOME`), `$first` (non-empty on a first install), `$yes`.
Go programs MUST build with `GOTOOLCHAIN=auto`: their `go.mod` usually asks for a newer Go than
distros ship, and any Go 1.21 or newer then fetches the right toolchain.

Pick your patterns:

| Your program | Patterns |
|---|---|
| Go, Rust, C/C++ (meson, cmake, make): a single binary | P1, P2 |
| Script (sh, Python) run straight from the repo | P1; `TARGET=yourscript`, `build()` does nothing |
| Output is a directory (Electron, bundled runtime) | P1, P3 |
| Needs a library found by pkg-config (GTK, Wayland, Gio) | add `need_pc` lines to P1; also `need gcc` and the like |
| Tray app that starts at login | P1, P2, P4 |
| Background daemon | P1, P2, P5 |
| Must also be reachable from a system path | P1, P2, P6 |
| Has a window, wants a start-menu entry | add `NAME.desktop` (section 4); nothing in install.sh |
| Has a built-in `install` subcommand today | delete it (R38), then the rows above |

### P1. Tool and library check

```sh
check_tools() {
	need go pacman:go dnf:golang apt:golang-go
	need gcc pacman:gcc dnf:gcc apt:gcc
	need_pc wayland-client pacman:wayland dnf:wayland-devel apt:libwayland-dev
}
```

All items are checked and every missing one is printed before the script exits 3 (R21, R26).
`need_pc` adds `pkg-config` itself as a tool, once. Check what the build really needs, not what
you have installed.

### P2. Atomic single-binary build (the template's default)

Build to a temporary name in `build/`, then `mv` it over the old one. `mv` inside one directory is
an atomic rename: a running process keeps the old file, and a failed build never reaches the
`mv`, because `set -e` stops the script first.

```sh
build() {
	GOTOOLCHAIN=auto CGO_ENABLED=0 go build -o "build/.$NAME.new" .
	# Rust:   cargo build --release --locked && cp "target/release/$NAME" "build/.$NAME.new"
	#         and first, because a rustup without a default toolchain makes `cargo` die:
	#        # rustup with no default toolchain (fresh rustup): build with stable, never touch the user's default
	#        if command -v rustup >/dev/null 2>&1 && ! cargo --version >/dev/null 2>&1; then
	#        	d=$(rustup default 2>/dev/null) || d=
	#        	rustup toolchain install stable --profile minimal --no-self-update
	#        	[ -n "$d" ] || rustup default none || :     # rustup makes the first toolchain the default; undo that
	#        	export RUSTUP_TOOLCHAIN=stable
	#        fi
	# meson:  [ -d build/meson ] || meson setup build/meson --buildtype=release
	#         meson compile -C build/meson && cp "build/meson/$NAME" "build/.$NAME.new"
	# cmake:  cmake -S . -B build/cmake -DCMAKE_BUILD_TYPE=Release && cmake --build build/cmake
	#         cp "build/cmake/$NAME" "build/.$NAME.new"
	mv -f "build/.$NAME.new" "build/$NAME"
}
install_files() { link "$dir/$TARGET" "$bin/$NAME"; }
remove_files()  { unlink_ours "$bin/$NAME"; }
```

Wrong: `go build -o build/$NAME` (overwrites in place), `install -Dm755 x ~/.local/bin/x` or
`cp x ~/.local/bin/` (copies out of the clone, R13).

### P3. Directory output (Electron and similar)

A directory cannot be renamed over another one atomically, so swap a symlink instead. Keep the
previous directory, because a running instance may still be reading it. Set
`TARGET=build/current/$NAME`.

```sh
build() {
	npm ci
	npx electron-builder --linux --dir          # -> dist/linux-unpacked/ (dist/ is git-ignored)
	prev=$(readlink build/current 2>/dev/null || true)
	new=app-$(date +%s)-$$
	cp -a dist/linux-unpacked "build/$new"
	ln -sfn "$new" build/.current.new
	mv -fT build/.current.new build/current
	for d in build/app-*; do
		case ${d#build/} in "$new"|"$prev") ;; *) rm -rf "$d" ;; esac
	done
}
install_files() { link "$dir/$TARGET" "$bin/$NAME"; }
```

`mv -T` (GNU coreutils) renames the link itself instead of moving it into the directory.

Keep `ln` and `mv` on **separate lines**: in `ln ... && mv ...` a failing `ln` does not stop the
script, because `set -e` ignores failures inside an `&&` list. Always use `ln -sfn` for the
temporary link, never plain `ln -s`: if a stale `build/.current.new` link to a directory is left
over, plain `ln -s` creates the new link *inside* that old directory and the swap silently does
nothing.

### P4. Generated autostart entry (tray app)

The file needs an absolute path, so it is written into `build/` and linked out; never write it
directly to `~/.config/autostart`. Created on first install; later only refreshed if it is still
there (R20). Do not start or stop the program (R30).

```sh
install_files() {
	link "$dir/$TARGET" "$bin/$NAME"
	cat > build/.autostart.new <<EOT
[Desktop Entry]
Type=Application
Name=$NAME
Exec=$bin/$NAME --daemon
Icon=$dir/icon.png
NoDisplay=true
EOT
	mv -f build/.autostart.new build/autostart.desktop
	a=$cfg/autostart/$NAME.desktop
	if [ -n "$first" ] || [ -L "$a" ]; then link "$dir/build/autostart.desktop" "$a"; fi
	if [ -z "$first" ]; then echo "restart: $NAME to use the new version"
	else echo "note: start it with: $NAME --daemon"; fi
}
remove_files() {
	unlink_ours "$cfg/autostart/$NAME.desktop"
	unlink_ours "$bin/$NAME"
}
```

### P5. systemd user service

The unit is generated into `build/` and linked with a plain symlink (`link`), **not** with
`systemctl --user link`: the manager would write into the real home whatever `$HOME` is, so a
test in a throwaway HOME would touch the real system. The link follows `$HOME`; the manager is
only asked when it is reachable (R29). `%h` keeps the unit machine-independent.

```sh
unit=$cfg/systemd/user/$NAME.service
has_manager() { systemctl --user show-environment >/dev/null 2>&1; }

install_files() {
	link "$dir/$TARGET" "$bin/$NAME"
	cat > build/.unit.new <<EOT
[Unit]
Description=$NAME daemon

[Service]
ExecStart=%h/.local/bin/$NAME --daemon
Restart=on-failure

[Install]
WantedBy=default.target
EOT
	mv -f build/.unit.new "build/$NAME.service"
	if [ -n "$first" ] || [ -L "$unit" ]; then link "$dir/build/$NAME.service" "$unit"; fi
	if has_manager; then
		if [ -n "$first" ]; then
			systemctl --user daemon-reload && systemctl --user enable --now "$NAME.service" \
				|| echo "restart: the service did not start; run: systemctl --user enable --now $NAME.service"
		else
			systemctl --user daemon-reload && systemctl --user try-restart "$NAME.service" \
				|| echo "restart: run: systemctl --user restart $NAME.service"
		fi
	elif [ -n "$first" ]; then echo "restart: no systemd user session; later run: systemctl --user enable --now $NAME.service"
	else echo "restart: $NAME to use the new version"; fi
}
remove_files() {
	if has_manager; then systemctl --user disable --now "$NAME.service" 2>/dev/null || true; fi
	unlink_ours "$cfg/systemd/user/default.target.wants/$NAME.service"
	unlink_ours "$unit"
	if has_manager; then systemctl --user daemon-reload || true; fi
	unlink_ours "$bin/$NAME"
}
```

A program that needs both P4 and P5 puts both blocks' bodies into the same two functions and keeps
one `restart:` line. The check script cannot test the real manager (section 7); test that part on
a real session.

### P6. Root link (first install only)

Set `ROOT_LINK=yes` in the template. It then does, in this order (R32 to R36):

```
--install:  check tools -> root_check (exit 1 / 4 now, nothing written) -> build -> install_files
            -> link the stable user link ~/.local/share/ritz-get/links/NAME -> [one root call:
            ln -sfn STABLE /usr/local/bin/NAME] -> "NAME installed"
--remove:   [one root call: rm -f /usr/local/bin/NAME] -> remove_files -> remove the stable link
```

The stable link is refreshed on every run without root; only a missing or wrong
`/usr/local/bin/NAME` needs the root call. The root call comes after the build on purpose: a
system link is never created for a build that failed. If the user cancels the password dialog the
run fails (exit 1) and ritz-get cleans up with `--remove`.

---

## 4. The shortcut (`NAME.desktop`, optional) and the icon (required)

- **R39** `NAME.desktop` (file name = manifest NAME) at the repo root turns on the Shortcut
  button in ritz-get. It MUST be a standard desktop entry with `Type=Application`, `Name=` and
  `Exec=`, and MUST NOT set `NoDisplay=true`. It SHOULD pass `desktop-file-validate`. **ritz-get,
  not install.sh, installs it**, and only when the user asks for a shortcut. When it does, it
  rewrites:
  - the first word of `Exec=` to `~/.local/bin/NAME`; arguments and field codes are kept (write
    `Exec=NAME %U`);
  - `Icon=` to the clone's `icon.png`; an `Icon=` in your file is ignored, so the card and the
    shortcut can never disagree;
  - `Name=` to the manifest `title:` (section 6);
  - `X-Ritze03;` is added to `Categories=`. Set your own normal categories (`Categories=Utility;`).

  Ship `NAME.desktop` when the program has a window the user opens from a menu. Do not ship one
  for a CLI, a background service, a tray app that runs through autostart, or a compositor that
  another program starts.
- **Icon.** `icon.png` is required for every program (R5), not only those with a shortcut. It is
  exactly 1024x1024; transparency is allowed. `icon.svg` is optional. Agents never create, edit
  or re-export either; if `icon.png` is missing, report it and stop at that point. The check
  script fails without it.

Example `myprog.desktop`:

```ini
[Desktop Entry]
Type=Application
Name=My Prog
Comment=Download videos with a simple window
Exec=myprog %U
Categories=AudioVideo;Network;
```

---

## 5. What ritz-get owns (do not implement any of it)

Cloning, the repo folder and moving it, branches and switching, fetching and updating, reverting
a failed build, refusing to update over local changes, reset (re-clone), hold (skip in
auto-update), version display, hiding repos the user cannot reach, start-menu shortcuts, the
manifest, the lock that stops two runs at once, and deleting the clone after `--remove`. Your
`install.sh` never needs to know which of these triggered it: it only ever sees `--install` on
some commit, or `--remove`.

ritz-get itself refuses to run as root (`id -u` is 0): it prints `ritz-get: do not run with sudo; it
asks for root itself when needed` to stderr and exits 2 before doing anything. It is per-user and
asks for root through `$RITZ_GET_SUDO` only when an `install.sh` needs it (R33).

Users may switch to any branch, and ritz-get then runs that branch's `install.sh`. Every branch
you expect people to use MUST conform. The build MUST NOT need credentials beyond the user's
normal git setup, and MUST NOT prompt for them. Private repos work: users without access simply
do not see the program.

---

## 6. The manifest entry you send back

ritz-get lists programs in one file, `programs`, kept in the ritz-get repo by its maintainer. You
do not edit it. You **send** your entry in your final reply. It looks like this:

```
[Helpers]
ts6tray  Ritze03/ts6tray  "Tray icon and mute control for TeamSpeak 6"
  title: TS6 Tray
  setup: In TeamSpeak: Settings -> Remote Apps -> enable, port 5899
  data: ~/.config/ts6tray
```

### Grammar

The file is read line by line. Fields are separated by spaces or tabs.

| Line | Form | Notes |
|---|---|---|
| blank | only whitespace | ignored |
| comment | first non-blank character is `#` | ignored. There are no trailing comments: a `#` later in a line is text (URLs have `#`) |
| section | `[Section name]` at column 0 | starts a group; the maintainer creates sections |
| entry | `NAME OWNER/REPO [BRANCH] "DESC"` at column 0 | one program |
| title | indented `title: TEXT` | at most one, directly under its entry |
| setup | indented `setup: TEXT` | any number, directly under its entry; order is kept |
| data | indented `data: ~/PATH` | any number, one path each, directly under its entry; programs only |

- `NAME`: `[A-Za-z0-9][A-Za-z0-9._-]*`, unique in the file. It is the folder, the command
  `~/.local/bin/NAME`, `NAME.desktop` and the icon file name. SHOULD equal the GitHub repo name.
- `OWNER/REPO`: the GitHub repo.
- `BRANCH`: optional. Omit it unless the branch users should get is not the repo's default branch.
- `DESC`: double-quoted, one line, at most **80** characters, no `"` inside. It says what the
  program does for someone who has never seen it, and SHOULD match the GitHub repo description.
  **You MUST send one.**
- `title:` at most one per entry, plain text, at most **40** characters. It is the name people
  see (card, side panel, list, and the shortcut's `Name=`). `NAME` stays the technical id.
  **You MUST send one** (`TS6 Tray`, `yt-dlp-gui`; without it NAME is shown).
- `setup:` plain text, at most **120** characters per line; a URL in it becomes a link. Use it for
  manual steps `install.sh` must not automate (R37), such as "enable remote apps in TeamSpeak".
  Send none if there are none. Never use it for build dependencies; exit 3 covers those.
- `data:` one folder or file the program creates outside the clone (config, data, cache), written
  `~/PATH`. `ritz-get delete-data NAME` deletes exactly these, after the program is uninstalled, and
  `list` shows `data left` while they exist. It lives in the manifest because the manifest is still
  there after the clone is gone. Only paths below `~/` count: a line with `..`, a bare `~`, or a path
  that is, contains or lies inside ritz-get's own folders or `~/.local/bin` is ignored with a
  warning. `~/.config/`, `~/.local/share/`, `~/.cache/` and `~/.local/state/` follow
  `$XDG_CONFIG_HOME`, `$XDG_DATA_HOME`, `$XDG_CACHE_HOME` and `$XDG_STATE_HOME`, but only when that
  variable points below `$HOME`; ritz-get also checks the resolved path (symlinks followed) and refuses
  anything outside `$HOME` or touching its own folders. List every such
  folder, and nothing broader than your program's own. Send none if there are none.
- Website entries (a URL instead of `OWNER/REPO`): the icon is `icons/NAME.png` in the ritz-get repo
  (NAME = the entry name); frontends fall back to a letter tile without it.
- Section: pick `[Software]` (apps with a window you open), `[Helpers]` (background tools, tray
  apps, CLIs) or `[Other]`. Only the maintainer creates sections; if none fits, say so.

Self-check of your entry line (prints `ok`):

```sh
printf '%s\n' 'myprog  Ritze03/myprog  "Download videos with a simple window"' |
	grep -Eq '^[A-Za-z0-9][A-Za-z0-9._-]*[[:blank:]]+[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+([[:blank:]]+[^"[:blank:]]+)?[[:blank:]]+"[^"]{1,80}"[[:blank:]]*$' && echo ok
```

---

## 7. Done when

The check script does the whole routine below in a throwaway HOME, against a clone of your repo
(with its submodules, as ritz-get checks them out, plus your uncommitted changes), so it never touches your checkout or your real home. It runs
`install.sh` exactly as ritz-get does: stdin `/dev/null`, the environment of section 1, no
systemd user session.

```sh
curl -fsSL https://raw.githubusercontent.com/Ritze03/ritz-get/main/tests/spec-check.sh -o "${TMPDIR:-/tmp}/spec-check.sh"
sh "${TMPDIR:-/tmp}/spec-check.sh" /path/to/repo go
```

Everything after the repo path is a build tool to hide for the exit-3 test (`go`, `cargo`,
`npm`, `meson`, `pkg-config`, ...); name the ones your `check_tools` checks. It prints one
`PASS`/`FAIL`/`SKIP` line per check, and a FAIL names the rule it breaks. **Done means the last
line is `ALL PASS`.** `install.sh` must be committed or at least `git add`ed (R1). If the script
reports `SKIP` for a missing build tool, install the tool and run it again.
The script sets `VK_LOADER_LAYERS_DISABLE='*LS_frame_generation*'` for its runs: that implicit
Vulkan layer (lsfg-vk) writes `$XDG_CONFIG_HOME/lsfg-vk/conf.toml` whenever Vulkan loads, which
would look like a stray config file. If another host layer or library writes config files on
load, a FAIL naming such a file is not your bug; check that `install.sh` did not cause it.

What it checks:

- `sh -n install.sh`; `#!/bin/sh`; executable in git; the marker in the first 5 lines; a `NAME=`
  line (R1 to R4)
- `icon.png` exists, is tracked, and is exactly 1024x1024 (R5)
- `--install --yes` twice: both exit 0, same set of links the second time, `git status
  --porcelain` unchanged (R6, R17)
- everything created outside the clone is a symlink into the clone, none dangling;
  `~/.local/bin/NAME` works; nothing lands in `~/.config` or `~/.local/share` when `XDG_*` point
  elsewhere (R12 to R14)
- the repo folder moves, `--install` runs again, every link follows (R15)
- no question, colour or `\r` in the output with `--yes`, and no hang on a prompt (stdin is
  `/dev/null`) (R10, R28)
- an unknown argument, no argument, or both modes exit 2 (R9)
- with a build tool hidden: exit 3, well-formed `missing:` lines naming concrete packages (no
  `base-devel` / `build-essential`), nothing changed (R21, R25, R26)
- if `install.sh` uses `need_pc`: one more `--install` with `PKG_CONFIG_LIBDIR=/nonexistent
  PKG_CONFIG_PATH=` (no library is found): exit 3, well-formed `missing:` lines, nothing changed
  (R21, R25, R26)
- if the first install created an autostart link or a systemd unit: the second install prints a
  `restart:` line (R30)
- `--remove --yes`: exit 0 with the build tools hidden, config and data survive, nothing is left
  behind, exit 0 again, exit 0 on a partly installed program (R22 to R24)
- programs that use root (`ROOT_LINK=yes`): exit 4 and `needs root:` without a password helper;
  one root call of the exact shape of R33; the pkexec results of R36 (R27, R32 to R36)
- no direct `sudo`/`pkexec`, no `git pull`/`checkout`/`submodule update`/..., no `npm install`, `go mod tidy` or
  `cargo build` without `--locked`, no writes to `.../applications` (grep, R6, R37)
- `NAME.desktop`, if present, is valid (R39)

Not covered by the script. Read your `install.sh` and your diff once more:

- [ ] No `cp`, `install -D` or `cat >` writes outside the clone: every outside path comes from
      `link` (R13).
- [ ] Every build output reaches its final name only through `mv` (R18).
- [ ] With `--yes` no code path reads stdin (R10).
- [ ] The program has no `install` / `uninstall` subcommand left, and no code that copies itself
      or writes autostart files or units (R38). Its own user config written at run time is fine.
- [ ] A background part uses P5 (service) or P4 plus the restart line (tray). Nothing is started
      by hand (R29 to R31). The `restart:` line on later runs does not depend on the program
      running (R30).
- [ ] A systemd service works on a real session: the script cannot reach a real user manager.
- [ ] Root (P6 only): the link is created once, an update afterwards needs no root, `--remove`
      deletes it. Needs a real machine with `sudo`.
- [ ] Every branch you expect users to pick has the same `install.sh` behaviour (section 5).

---

## 8. Delivering the port

- One PR per repo, from branch **`ritz-get-spec-v1`**, titled **`ritz-get: install.sh to spec v1`**.
- The PR contains `install.sh`, `.gitignore` changes, `NAME.desktop` if the program has a window,
  the removal of a self-installer with its code and tests (R38), and the README change below. It
  does not contain `icon.png` unless the repo already has it on the branch you started from: icons
  come from the maintainer.
- The PR body lists what was removed and pastes the check script's **full** output: every
  `PASS` / `SKIP` line as printed, then `ALL PASS`. No abbreviation, no "all checks pass". If
  `icon.png` is missing, the body says `waiting for icon.png` and the PR stays open.
- Before opening the PR, check that it adds no stray tracked files (debug output, scratch files,
  build output): run `git diff --stat origin/<default-branch>...HEAD` and read the file list. Every
  file in it must be one of the items above.
- **Migration.** If the port removes an old self-installer that wrote regular files (a copied
  binary in `~/.local/bin`, a `.desktop` in `~/.local/share/applications`, an autostart file),
  say so in the PR body and in the README. `--remove` only deletes symlinks into the clone, so it
  cannot delete files it did not link; users upgrading from the old install may have to delete
  them by hand (name the paths). `--install` itself is fine over them: `ln -sfn` replaces an old
  copied file at the same path (R17).
- README: keep the quick start's shape and make it work after the self-installer is gone. Any
  `NAME install` / `NAME uninstall` step becomes `ritz-get install NAME` (the main way) and
  `./install.sh --install` / `./install.sh --remove` (without ritz-get). Change nothing else in the
  README.
- Merging is the maintainer's decision, unless your task says you may merge once the check passes.
- Your final reply contains the manifest entry of section 6: section, entry line, `title:`,
  `setup:` lines, and `data:` lines.

---

## 9. Spec versions

This is version 1. The version goes up only when a change would make a conforming repo stop
conforming; clarifications and new MAY/SHOULD rules keep the number. A repo declares the version
it was checked against with the marker line (R3), and ritz-get tells the script which version it
speaks in `RITZ_GET_SPEC`. A ritz-get that is older than a program's marker skips that program
with "needs a newer ritz-get"; a program without a marker still runs, but the check fails it.
When the version goes up, this file lists what to change, and
`grep -L '# ritz-get-spec: 2' */install.sh` in the repo folder lists the repos still to port.

---

## Deliberately left out

- A metadata file in the repo (name, version, category). The manifest and `install.sh` cover it.
- Version numbers and tags. ritz-get shows the commit date and the short hash.
- Prebuilt binaries and release downloads. Everything builds from source.
- Dependencies between programs. If you need another program's build, build it yourself.
- Root for anything but symlinks: `setcap`, `suid`, system packages and system services are the
  maintainer's job by hand, not a spec feature.
- Git LFS.
- A purge mode that deletes config and user data.
- Skipping a rebuild when nothing changed: ritz-get calls `--install` when something did, and the
  build tool's own cache makes a repeat cheap.
- Extra flags (`--help`, `--version`, `--prefix`) and non-Linux systems.
- Questions asked of the user in `--install --yes`. Manual steps go into `setup:` lines instead.
