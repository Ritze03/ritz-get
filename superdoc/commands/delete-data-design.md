# delete-data — Design Spec

**Date:** 2026-10-25 (typed confirmation added 2026-10-29)
**Status:** Implemented
**Feature:** `delete-data` is its own command, separate from `remove`, deleting only manifest-declared data after path safety checks and a typed-name confirmation.

---

## Goal & motivation

`remove` uninstalls a program but keeps its config and data (README: "keep its data"). Users still need a way to get rid of that data. `delete-data` does that, only for data the manifest explicitly declares, and only once the program is uninstalled (see [remove-and-delete-data](remove-and-delete-data.md) for the mechanics).

## Non-goals

- Not part of `remove`: `remove` keeps the data and prints where it is (`ritz-get:data_hint`).
- No guessing: ritz-get does not search for a program's data. Only `data:` lines in the manifest entry count ([manifest](../features/manifest.md)).
- No root: it never uses `sudo` and never touches anything outside `$HOME`.
- Websites have no data and installed programs are refused (`uninstall first`).

## Key decisions & rationale

- **Separate command, uninstalled only.** Commit "delete-data: separate from remove" introduced the split; `remove` only hints at it. The README states `delete-data` works "only after the program is uninstalled and only the folders its entry in `programs` lists (`data:` lines)".
- **Declared paths, not discovered.** `data:` paths must be `~/...`, contain no `..`, never be `$HOME` or a bare base directory (`~/.config`, `~/.local`, ...), and are mapped through `XDG_*` variables only when those resolve below `$HOME` (an XDG dir outside `$HOME` is ignored). The commit titled "XDG only below $HOME" records the last rule; the others are enforced in `ritz-get:load_mf` and `ritz-get:xdg_below_home`.
- **Resolved-path checks at use time.** The commit "check resolved paths against ritz-get's folders and $HOME" made `ritz-get:data_ok` compare real paths, so a symlink or a `..` cannot lead deletion into `$HOME` itself, outside it, or into ritz-get's own folders (`ritz-get:prot_raw`). A follow-up commit protects the shortcuts directory, normalises `rreal`, and deletes through the resolved parent: `rm` runs in the directory `data_ok` resolved after re-verifying it, so a parent swapped for a symlink in between deletes nothing.
- **A symlink is removed, never followed.** `data_ok` keeps the last path component unresolved; its target is checked as well and a link leading into ritz-get's folders is refused.
- **Typed confirmation instead of `[y/N]`.** The commit "confirm by typing the repository name instead of [y/N]" replaced the yes/no prompt. The warning says the data is deleted "for good"; the user must type the repository name (the last part of the manifest source, `SRC`, not the display title). `--yes` skips it, a missing terminal or the GUI never prompts (the GUI asks itself, then passes `--yes`). The commit records the change but no longer rationale.

## Related links

[remove-and-delete-data](remove-and-delete-data.md) · [manifest](../features/manifest.md) · [PORCELAIN.md](../../PORCELAIN.md) (user-facing; its `delete-data` paragraph still describes the old `[y/N]` prompt)
