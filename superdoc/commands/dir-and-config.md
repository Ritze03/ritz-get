# dir and config — where the clones live

`ritz-get dir [PATH]` shows, or moves, the folder all program clones live in. The settings behind it and the shortcuts folder are a small `key=value` config file.

## How it works

- **Config file**: `${XDG_CONFIG_HOME:-~/.config}/ritz-get/config` (`CFGF`), plain `key=value` lines. Keys: `dir=` (clone folder), `shortcuts=` (shortcut folder). `ritz-get:cfg KEY` returns the last value; `ritz-get:setcfg KEY VALUE` rewrites the file through `$CFGF.new` and `mv`, keeping the other keys. `main` resolves `SRCDIR` and `SHORTDIR` from them with `abspath`; defaults are `~/.local/share/ritz-get/src` and the user's applications folder. The file exists only if a setting was changed.
- **`ritz-get:cmd_dir`** with no argument prints `$SRCDIR`. With a path it takes the lock and, if the old folder exists, refuses when: the target is inside the current folder; it exists and is not empty (or is not a folder); it is on another filesystem (compared with `stat -c %d`; message says to move it by hand and then run `ritz-get dir PATH`). Without `--yes` it asks `Continue? [y/N]`. Then one `mv` of the whole folder, `setcfg dir`, and `SRCDIR` switches.
  - README: it "moves the whole folder there in one step"; the same-filesystem rule is what makes that a single `mv`.
  - If the old folder does not exist (you moved it by hand), only the config is written; README: "run `ritz-get dir PATH` to tell Ritz-Get".
- **Repair after the move**: `MYDIR` is re-pointed at the moved ritz-get clone (the comment: `icons/` now live there), `SUDO` is cleared so no root is asked, then every clone is rebuilt with `ritz-get:build` (`NAME: re-linking`). *Why:* the comment says re-running `install.sh` "re-points `~/.local/bin` and friends at the new path". A build failure prints `NAME: needs repair: ritz-get install NAME` and sets the exit code; nothing is rolled back (PORCELAIN.md). Finally `sc_refresh` regenerates every shortcut ([shortcuts](shortcuts.md)).
- The program folder may be your own development folder: clones with changes are never touched (README).

## Using it

```sh
ritz-get dir                 # print the folder
ritz-get dir PATH [--yes]    # move everything there, repair links
```

## Options

| Config key | Default | Meaning |
| --- | --- | --- |
| `dir` | `${XDG_DATA_HOME:-~/.local/share}/ritz-get/src` | folder the program clones live in |
| `shortcuts` | `${XDG_DATA_HOME:-~/.local/share}/applications` | folder holding `ritz-get-NAME.desktop` links |

## Related links

[shortcuts](shortcuts.md) · [build-runner](../features/build-runner.md) · [locking-and-self-update](../features/locking-and-self-update.md) · [overview](../architecture/overview.md) · [README.md](../../README.md) · [PORCELAIN.md](../../PORCELAIN.md)
