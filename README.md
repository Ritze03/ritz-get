# Ritz-Get

Installs, updates and removes Ritze03's programs on any Linux distro. Every program is built
on your machine from a git clone, into your home folder; nothing needs root unless a program
says so. It also lists a few websites, so everything of Ritze03's is in one place.

Each program is a git clone in one folder. The clone is the whole state: a program is
installed if its clone exists, the checked-out branch is the branch you run, and `HEAD` is the
version. There are no other state files.

## Install

With the one-time installer:

```sh
curl -fsSL https://github.com/Ritze03/ritz-get/releases/latest/download/install-ritz-get.sh | sh
```

It checks for `git`, asks where to keep the clones (the default is fine), installs Ritz-Get,
and offers to put `~/.local/bin` on your `PATH`. After that Ritz-Get updates itself.

Without the installer:

```sh
git clone https://github.com/Ritze03/ritz-get ~/.local/share/ritz-get/src/ritz-get && ~/.local/share/ritz-get/src/ritz-get/install.sh --install --yes
```

Make sure `~/.local/bin` is in your `PATH`. To remove Ritz-Get, run `install.sh --remove` from
its clone and delete the folder.

## Requirements

- `git` and a POSIX `sh` with the usual tools (coreutils, util-linux, `awk`). That is all Ritz-Get needs.
- Whatever a program needs to build (`go`, `cargo`, `npm`, a C++ compiler, ...). If something is
  missing, Ritz-Get prints one line to copy, like `deps: sudo pacman -S --needed gcc`
  (also for `dnf` and `apt`), and exits with code 3.

## Commands

```sh
ritz-get list [NAME...]            # programs and websites, installed or not, up to date or not
ritz-get install NAME...           # clone, build, install (on an installed program: repair)
ritz-get install NAME --branch B   # same, from another branch
ritz-get update [NAME...]          # update ritz-get, then rebuild what changed (asks first)
ritz-get remove NAME...            # uninstall and delete the clone, keep its data (alias: uninstall)
ritz-get delete-data NAME...       # delete the data of an uninstalled program (asks you to type the repository name; --yes skips that)
ritz-get branches NAME             # branches of the remote, the current one marked with *
ritz-get switch NAME BRANCH        # check out another branch and rebuild
ritz-get reset NAME                # throw away local changes: re-clone and rebuild
ritz-get hold NAME                 # leave NAME out of a plain 'update' (unhold: undo)
ritz-get open NAME                 # open a website in your browser
ritz-get shortcut NAME             # add a start-menu shortcut (--remove: take it away)
ritz-get shortcuts [PATH]          # show, or move, the folder the shortcuts live in
ritz-get dir [PATH]                # show, or move, the folder the clones live in
ritz-get help
```

Run it as yourself, not with `sudo`: it refuses to run as root and asks for root itself when a program needs it.

Options: `--yes` answers "yes" to every question, `--offline` makes `list` skip the network,
`--all` makes `list` show programs you have no access to, `--porcelain` is for frontends,
`--verbose` (`-v`) shows the whole build output.

- Builds are quiet: a program's `install.sh` output goes to `~/.cache/ritz-get/logs/NAME.log` (overwritten on
  each run). On a terminal one progress bar fills through the whole run (it replaces the `cloning` and
  `building` lines); lines you must act on (`missing:`, `deps:`,
  `note:`, `restart:`, `setup:`) still print. A failed build prints the log's path and its last lines.

- `update` first updates Ritz-Get itself and, if that changed, continues with the new version.
  It then rebuilds every installed program whose branch has new commits. A failure in one
  program doesn't stop the others; the exit code is non-zero at the end. A failed build leaves
  the installed version as it was. `update` ends with `N updated, N skipped, N failed`.
- Programs you changed yourself (edited files or local commits) are marked `modified` and
  skipped by `update`, so your work is never overwritten. `reset NAME` discards the changes.
- `list` checks what is new on the remote; `list --offline` doesn't.
- If the branch a program is on was deleted on the remote, `list` shows `branch-gone` and `update` skips it; pick another branch with `ritz-get branches NAME` and `ritz-get switch NAME BRANCH`.
- A program may print extra steps after installing ("Additional steps required"); do those by hand.
- Shortcuts are flat entries in your app menu, named `ritz-get-NAME.desktop`. Only programs that
  ship a `NAME.desktop` can have one; websites always can. `install` asks whether to add the shortcut
  (`--yes` says yes; with no terminal to ask on, none is added; `ritz-get shortcut NAME` adds one later).
  `remove NAME` takes the shortcut away by itself, a website's too.
- `remove` keeps a program's config and data and tells you where it is. `delete-data NAME` deletes
  it, but only after the program is uninstalled and only the folders its entry in `programs` lists
  (`data:` lines). `list` shows `data left` for an uninstalled program whose data is still there.

## In your update script

If you already update your system in a script, add one line next to `yay` or `flatpak update`:

```sh
ritz-get update --yes
```

Held and modified programs are skipped, and a second Ritz-Get running at the same time is
detected, so this is safe to run from cron.

## Where things live

- The clones: `~/.local/share/ritz-get/src/NAME` by default. Everything Ritz-Get puts elsewhere
  (`~/.local/bin/NAME`, shortcuts) is a symlink into that folder, or a file generated inside it
  (`.ritz-get/`).
- Settings, only if you changed them: `~/.config/ritz-get/config`, with `key=value` lines.
  - `dir=` is the folder for the clones. `ritz-get dir PATH` moves the whole folder there in one
    step and repairs every program's links. If you moved it by hand, run `ritz-get dir PATH` to
    tell Ritz-Get. The folder can be your own development folder: clones with changes are never touched.
  - `shortcuts=` is the folder for the shortcuts, `~/.local/share/applications` by default.
    `ritz-get shortcuts PATH` moves them.
- `${XDG_CACHE_HOME:-~/.cache}/ritz-get/last-run`: the summary of the last `update`.

## Programs

The list is [`programs`](programs) in this repo: sections, programs (`NAME OWNER/REPO "description"`)
and websites (`NAME URL "description"`). The file explains its own format. Adding an entry is a
commit to that file; everyone gets it with their next `ritz-get update`. Programs in private repos
can't be cloned by other people, so they stay out.

## For program repos

A program is a git repo with an executable `install.sh` that Ritz-Get runs from inside the
clone. The rules (what `install.sh` must do, exit codes, the optional shortcut and icon files)
are in [SPEC.md](SPEC.md), and [`template/install.sh`](template/install.sh) is the file to start from.
Git submodules are fine: Ritz-Get keeps them in sync on every install, update, switch and reset.

## For frontends

`ritz-get list --porcelain` is a stable, tab-separated format for GUIs and scripts. It and the
exit codes are described in [PORCELAIN.md](PORCELAIN.md), and so are the `#start` / `#progress`
lines a frontend gets (under `RITZ_GET_GUI=1`) while programs install or update. On a terminal,
install, update, switch and reset show one progress bar that fills step by step (get the source, build) for each
program; piped, cron and `--verbose` output has no bar and is unchanged.

## License

MIT, see [LICENSE](LICENSE).
