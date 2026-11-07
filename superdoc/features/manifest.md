# Manifest — the `programs` file and how it is parsed

`programs` (repo root) lists everything ritz-get knows about: programs (git repos with an `install.sh`) and websites. `load_mf` turns it into a record file once per run; every command reads that.

## How it works

- Location: `ritz-get:MF`, which is `RITZ_GET_MANIFEST` or `programs` next to the script (`MYDIR`). The file documents its own grammar in its header comment. *Why:* adding an entry is a commit to that file and everyone gets it with their next `ritz-get update` (README, "Programs").
- `ritz-get:load_mf` runs one `awk` pass and writes `$TMP/mf`, one record per line, fields joined by `$US` (unit separator, `\037`):
  - `E sec name source branch desc title` (title defaults to name)
  - `S name text` (one per `setup:` line, right after its `E`)
  - `D name ABSPATH ~/PATH` (one per valid `data:` line)
- Sections: `[Name]` opens one; entries before the first header are `Software`. A line is a comment only when `#` is its first non-blank character, so URLs may contain `#`.
- Entry line: `NAME SOURCE [BRANCH] "DESCRIPTION"`. NAME must match `[A-Za-z0-9][A-Za-z0-9._-]*`, else the line is skipped silently. The description is the first double-quoted span.
- Program vs website: `ritz-get:lookup NAME` sets `SEC SRC DEFBR DESC TITLE KIND`. `KIND=website` when SRC starts with `http://` or `https://`, else `program` (SRC is `OWNER/REPO`, cloned from `$BASE/$SRC.git`). It returns 1 when the name is unlisted. Websites are never cloned; they are opened (`cmd_open`) and can get a shortcut.
- Indented lines under an entry:
  - `title:` display name; the first one wins.
  - `setup:` a manual step. `ritz-get:setup_lines` prints `Additional steps required:` plus the indented lines after a successful install; `cmd_list` emits them as `S` records.
  - `data:` a folder the program leaves behind, used by `delete-data`. Only programs carry them: on a website entry the line is ignored.
- `data:` paths are validated in `dpath` (inside `load_mf`): must start `~/`, no `..`, never `$HOME` itself or a bare base dir (`~/.config`, `~/.local`, `~/.local/share`, ...), XDG-mapped only when the XDG variable resolves strictly below `$HOME`, and never equal to, inside or above ritz-get's own folders (`prot_raw`). A bad line is warned about on stderr and dropped; `data_ok` re-checks the resolved path when it is used.

## Length limits

| Field | Limit | Where enforced |
| --- | --- | --- |
| description | 1 to 80 chars, no double quote | documented in the `programs` header; checked by `tests/cli/run.sh`, not by `load_mf` |
| `title:` | at most 40 chars | same |
| `setup:` | at most 120 chars; a URL becomes a link | documented in the header only |

`load_mf` itself neither truncates nor rejects over-long values; the limits are held by the test suite on the real `programs` file.

## Using it

Add or change an entry in `programs`, then `ritz-get list` shows it. Private repos stay out because other people cannot clone them (header of `programs`).

## Related links

- [programs](../../programs) and [README](../../README.md#programs)
- [Program spec](../spec/program-spec.md), [list](../commands/list.md), [install](../commands/install.md)
- [Architecture overview](../architecture/overview.md)
