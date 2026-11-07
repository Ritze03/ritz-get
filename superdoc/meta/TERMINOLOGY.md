# Terminology

Project-specific vocabulary. When the user uses a term defined here, use the same
meaning.

**If the user uses a non-standard term that is not defined here, ask what they mean by
it before acting on it.** Once its meaning is clear, add it to this file. Keep this
file up to date automatically: whenever the user introduces or clarifies a term, add or
amend the entry here.

**Keep every entry short: what the term is, and where to read more.** One or two
sentences, about 200 characters. Details, behaviour, option names, history and rationale
belong on the linked doc page. If that page doesn't exist and there is more to say, write
the page; don't grow the entry. When you amend an entry, trim it to this form instead of
appending. This file stays in context for the whole session.

## Terms

- **program** — a git repo with an executable `install.sh` that ritz-get clones and builds; installed means its clone exists. See `superdoc/spec/program-spec.md`.
- **website** — a manifest entry whose source is an http(s) URL; it is opened, never cloned or built, and can get a shortcut. See `superdoc/features/manifest.md`.
- **manifest** — the `programs` file at the repo root: sections, programs, websites and their indented lines. See `superdoc/features/manifest.md`.
- **section** — a `[Name]` header in the manifest that groups entries; entries before the first one are `Software`, unknown clones show under `Unlisted`. See `superdoc/features/manifest.md`.
- **clone / clone folder** — a program's git checkout, the only state ritz-get keeps; all clones sit in one folder (config `dir=`). See `superdoc/commands/dir-and-config.md`.
- **spec / spec version** — SPEC.md, the rules for a program's `install.sh`; the version (`SPEC=1` in `ritz-get`, marker `# ritz-get-spec: N`) gates newer programs. See `superdoc/spec/program-spec.md`.
- **porcelain** — the stable tab-separated output of `list --porcelain` plus `#start`/`#progress` lines, for frontends. See `superdoc/features/porcelain.md`.
- **frontend** — a GUI or script that consumes the porcelain output; the GUI is a separate repo. See `superdoc/features/porcelain.md`.
- **hold** — git config `ritz-get.hold` in a clone; a plain `update` skips a held program. See `superdoc/commands/hold.md`.
- **branch-gone** — list state of a clone whose checked-out branch was deleted on the remote; `update` skips it. See `superdoc/commands/branches-switch-reset.md`.
- **data line** — an indented `data: ~/PATH` manifest line naming a folder a program creates; `delete-data` removes it. See `superdoc/commands/remove-and-delete-data.md`.
- **setup line** — an indented `setup: TEXT` manifest line, a manual step printed after install ("Additional steps required"). See `superdoc/features/manifest.md`.
- **port** — converting an existing program repo's installer to the spec (SPEC.md section 8, "Delivering the port"). See `superdoc/spec/program-spec.md`.
