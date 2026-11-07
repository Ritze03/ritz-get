# Porcelain — how the machine contract is produced in code

The stable output a frontend reads is specified in [PORCELAIN.md](../../PORCELAIN.md); this page only says which code emits which part.

## How it works

- `ritz-get:cmd_list` builds `$TMP/rows` once, then either prints it as porcelain or feeds the same file to an `awk` renderer for the human table.
- `ritz-get:row` writes one `E` record (17 fields with the letter). `irow` fills it for an installed clone from `inst_fields` (`ST`, `HELD`, `BRN`, `VER`, `LAT`, `BEH`, `DIRTY`, `AHEAD`). Websites and not-installed programs call `row` directly with `-` for n/a fields. Column 17 comes from `sc_col` (`on`/`off`/`-`).
- `S` records: copied from the manifest's `S` records after each entry's `E`. `D` records (`--data`): from `data_have`; `kb` is `du -sk` under `--porcelain`, `-` otherwise.
- With `--porcelain` it prints `#porcelain 1`, `#online 1|0`, the rows, then `#hidden N` when N > 0 (unreachable programs not shown without `--all`). Offline is decided by probing ritz-get's own repo; a failure or an HTTP 429 means offline.
- State values come from `probe` (fetch for installed clones, `ls-remote` otherwise) and `inst_fields`: `modified` beats all, then `branch-gone` (`gone`), `current`/`behind`, `fetch-failed`, `unknown` offline.
- Other parts of the contract are emitted elsewhere: `#start`/`#progress` in `prog_begin`/`prog_end` ([progress-output](progress-output.md)); the failure trailers in `fail` (`FAILED — your installed version is unchanged and still works`) and `install_one` (`FAILED — nothing was installed` after a failed first install); `deps:` in `print_deps`; the build log in `run_script`; `last-run` in `cmd_update`.
- Compatibility: column 17 was appended after the first release without bumping the version, because a reader that takes the first 16 columns and ignores the rest keeps working (PORCELAIN.md). Readers must ignore unknown record letters and unknown `#` lines.

## Contradiction found

- PORCELAIN.md (the `delete-data` bullet) says it asks `Delete these? [y/N]`; `delete_one` asks the user to type the repository name (`Type the repository name (REPO) to confirm:`), as README says.

## Related links

- [PORCELAIN.md](../../PORCELAIN.md), [porcelain-contract-design](porcelain-contract-design.md)
- [list](../commands/list.md), [update](../commands/update.md)
