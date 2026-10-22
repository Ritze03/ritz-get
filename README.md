# ritz-get

Installs, updates and removes Ritze03's programs on any Linux distro. Every program is built
on your machine from a git clone, into `$HOME`; nothing needs root unless a program's own
`install.sh` asks for it.

Each program lives as a clone in `~/.local/share/ritz-get/src/NAME`. The clone is the whole
state: a program is installed if its clone exists, the checked-out branch is the branch you
run, and `HEAD` is the version. There are no other state files. ritz-get itself is one of the
clones, and `~/.local/bin/ritz-get` is a symlink into it.

## Install

```sh
git clone https://github.com/Ritze03/ritz-get "${XDG_DATA_HOME:-$HOME/.local/share}/ritz-get/src/ritz-get" && "${XDG_DATA_HOME:-$HOME/.local/share}/ritz-get/src/ritz-get/install.sh" --install
```

Make sure `~/.local/bin` is in your `$PATH`. Remove ritz-get with `install.sh --remove` from
that clone, then delete `~/.local/share/ritz-get`.

## Requirements

- `git` and a POSIX `sh` plus coreutils. ritz-get itself needs nothing else.
- Whatever a program needs to build (`go`, `cargo`, `npm`, a C++ compiler, ...). The program's
  `install.sh` checks for it first and, if it is missing, tells you the package to install
  (`pacman -S`, `dnf install` or `apt install`).
- Go programs set `GOTOOLCHAIN=auto`: the Go version they ask for is newer than most distro
  Go packages, so any Go 1.21 or newer works and downloads the right toolchain itself.

## Usage

```sh
ritz-get list                          # programs, installed or not, branch, commit, behind or not
ritz-get install ccorral               # clone, build, install
ritz-get install ccorral --branch dev  # same, from another branch
ritz-get update                        # update ritz-get, then rebuild what changed
ritz-get update --yes ccorral          # no question; only the named programs
ritz-get branches ccorral              # branches of the remote, current one marked with *
ritz-get switch ccorral dev            # check out another branch and rebuild
ritz-get remove ccorral                # install.sh --remove, then delete the clone
ritz-get help
```

`update` first pulls ritz-get's own clone and, if that changed, restarts itself with the same
arguments. Then it fetches every installed program (or the named ones). A program whose branch
has new commits is fast-forwarded and rebuilt with `./install.sh --install --yes`; one that
hasn't moved is just reported as up to date and not rebuilt. Without `--yes` it lists what
will be rebuilt and asks once. A failure in one program doesn't stop the others and the exit
code is non-zero at the end. If the pull can't fast-forward (local changes in the clone, or a
force-pushed branch) the program is skipped and reported. If a rebuild fails, the clone goes
back to the commit it was on, so the next `update` tries again.

A failed `install` deletes the clone again and prints the tail of the build log, so a program
is never half installed. A failed `switch` goes back to the previous branch.

`list` doesn't fetch, so "behind by N" is as of the last `update`.

## In your update script

If you already update your system in a script, add one line next to `yay` or `flatpak update`:

```sh
ritz-get update --yes
```

## Programs

The list is `programs` in this repo, one per line, `#` for comments:

```
NAME  REPO  [BRANCH]
```

`REPO` is `owner/name` on GitHub, cloned from `https://github.com/REPO.git`. `BRANCH` is
optional; without it you get the remote's default branch. Adding a program is a commit to this
file; everyone gets it with their next `ritz-get update`. Programs in private repos can't be
cloned by other people, so they stay commented out.

## For program repos

Every program repo has an executable `install.sh` at its root. ritz-get runs it from inside the
clone:

```sh
./install.sh --install --yes    # build from the working tree and install into $HOME
./install.sh --remove --yes     # uninstall; never touches config or user data
```

`--install` is also what runs for an update, so it must be safe to run over an existing install.
It decides how to build and where files go; ritz-get only calls it and cares about the exit
code. A human running it without `--yes` gets the program's own questions.

Two templates to copy and edit, both with a required-tools check and distro hints:

- `template/install.sh`: generic, with `build()`, `install_files()` and `remove_files()`.
  For programs that are just files to place (binaries, AppImages, desktop files, build from source).
- `template/install-self.sh`: for programs with a built-in installer. Builds, then runs
  `./NAME install`; `--remove` runs `NAME uninstall`. That's what ccorral and ts6tray use.

## License

TODO
