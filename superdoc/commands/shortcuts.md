# shortcuts — start-menu entries for programs and websites

Ritz-Get can put a flat `ritz-get-NAME.desktop` entry in your app menu for a program that ships a `NAME.desktop`, and for any website. `shortcut` adds or removes one, `shortcuts` shows or moves the folder, `open` opens a website.

## How it works

- **Files**: the generated entry lives in `$SRCDIR/.ritz-get/ritz-get-NAME.desktop` and is linked into `$SHORTDIR` (config `shortcuts=`, default the user's applications folder) by `ritz-get:sc_link`. `ritz-get:sc_has` tests the link, `ritz-get:sc_rm` deletes link and generated file, `ritz-get:sc_db` runs `update-desktop-database` if present, `ritz-get:sc_names` lists existing ones.
- **Link, not copy**: `sc_link` uses a symlink. *Why:* its comment says every install is symlinks, that this is unverified on GNOME/KDE, and that if a desktop ignores symlinked `.desktop` files, this one function switches to `cp -f`.
- **Capability**: `ritz-get:sc_cap` is true for an installed program whose clone has `NAME.desktop`. `ritz-get:sc_col` turns that into the porcelain column: `on`, `off`, or `-` (cannot have one); websites are `on`/`off`.
- **Generation** `ritz-get:sc_make NAME` (rc 1 with `WHY` on failure):
  - Website: `Name=` title, `Comment=` description, `Exec=xdg-open "URL"` (`%` doubled), `Icon=` the ritz-get repo's `icons/NAME.png` if present, `Categories=Network;` plus ritz-get's own `X-` category (literal in `sc_make`). A URL with whitespace, quotes, backtick, `$` or backslash is refused.
  - Program: rewrites the repo's `NAME.desktop` with awk: `Name=` becomes the manifest title, `Icon=` the clone's `icon.png`, the first word of `Exec=` becomes `~/.local/bin/NAME` (arguments kept), ritz-get's own `X-` category is added to `Categories=`, everything else stays. *Why:* SPEC R39 lists exactly these rewrites and says an `Icon=` in the program's file is ignored "so the card and the shortcut can never disagree".
- **Offer on install** `ritz-get:sc_offer`: runs after a successful install when the repo ships `NAME.desktop` and no shortcut exists. `--yes` creates it; without `--yes` it asks `Add TITLE to the start menu? [Y/n]` only on a terminal (no terminal: none); `RITZ_GET_GUI` skips it entirely. *Why:* the GUI asks itself (comment on `sc_offer`), and SPEC R39 says the shortcut is installed by ritz-get "only when the user asks for a shortcut", with `install.sh` forbidden from writing menu files.
- **Kept in step** `ritz-get:sc_refresh NAME`: regenerates an existing shortcut after install (repair), update, switch, reset and `dir`. *Why:* the generated file holds absolute paths (comment). A failure prints `shortcut not refreshed (...); needs repair: ritz-get shortcut NAME`.
- **Removed with a website**: `ritz-get remove NAME` on a website (no clone) removes its shortcut; on a program it removes the shortcut together with the clone ([remove-and-delete-data](remove-and-delete-data.md)). README: "`remove NAME` takes the shortcut away by itself, a website's too."
- **`ritz-get:cmd_shortcut NAME [--remove]`**: `--remove` works for any name (`no shortcut` if none). Otherwise a program must be installed and ship `NAME.desktop` (else exit 1); a website can always have one.
- **`ritz-get:cmd_shortcuts [PATH]`**: no argument prints `$SHORTDIR`. With a path it takes the lock, writes `shortcuts=` via `setcfg` ([dir-and-config](dir-and-config.md)), regenerates every existing shortcut in the new folder, deletes the old file (`NAME: moved`), and runs `update-desktop-database` on both folders. A failed one prints `needs repair: ritz-get shortcut NAME`.
- **`ritz-get:cmd_open NAME`**: websites only; needs `xdg-open` (else prints the URL to open yourself); launches it detached with `setsid -f`.

## Using it

```sh
ritz-get shortcut NAME           # add
ritz-get shortcut NAME --remove  # take away
ritz-get shortcuts               # print the folder
ritz-get shortcuts PATH          # move all shortcuts
ritz-get open NAME               # websites
```

## Related links

[install](install.md) · [remove-and-delete-data](remove-and-delete-data.md) · [dir-and-config](dir-and-config.md) · [list](list.md) · [porcelain](../features/porcelain.md) · [SPEC.md](../../SPEC.md) (R39) · [README.md](../../README.md)
