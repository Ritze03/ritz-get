# Progress output — the bar, GUI progress lines, exit codes, last-run

How a run reports progress: a terminal progress bar, `#start`/`#progress` lines for the GUI, a worst-wins exit code, and the `last-run` summary file.

## How it works

- Counters (top of `ritz-get`): `PN` running program, `PDONE` programs finished, `PTOT` programs in this run, `PST` step (0 get the source, 1 build), `BAR` enabled, `BARV` drawn.
- `ritz-get:prog_begin NAME` (calls `prog_end` first) sets `PN`; `ritz-get:prog_end` increments `PDONE`. Under `RITZ_GET_GUI` they print `#start NAME` and `#progress NAME DONE/TOTAL` (contract: [PORCELAIN.md](../../PORCELAIN.md)). `cmd_install`, `cmd_delete_data`, `cmd_switch`, `cmd_reset` and `upd_run` call them; for `update`, `PTOT` is only the programs actually updated.
- `ritz-get:bar LABEL [STEP]` draws the bar from `BARAWK` (via `barenv`): width a quarter of the terminal, max 20; block characters in a UTF-8 locale, else `#` and `-`; the label is truncated with `...`. `unbar` clears the line; `err` and `failed` call it first so messages never land on the bar. `say` prints a transient status line only when there is no bar.
- Fill is `(PDONE*2 + PST) / (PTOT*2)`: every program has two steps. *Why:* commit "progress bar: one bar that fills by steps instead of redrawing from zero" — one bar for the whole run that never goes back. On a terminal the `cloning`/`building` lines are not printed because the bar's label says it.
- Enabled in `main` only when stdout is a terminal, `RITZ_GET_GUI` is unset, `TERM` is not `dumb` and `--verbose` is off. *Why:* commit message: `--verbose` has no bar because it would fight the stream; pipes, cron and the GUI are unchanged.
- During a quiet build `run_script`'s awk redraws the bar with a spinner (`building |`) and clears the line before it prints an allowed line. See [build-runner](build-runner.md).

### Exit codes

`ritz-get:bump KIND` keeps the worst code: 3 beats 4 beats 1 (`EXIT`). `failed` bumps (default 1); `build` supplies the class in `BK`. `finish` exits `${INTR:-$EXIT}`, so an interrupt (130/143/129) wins. Other codes: 2 usage (`usage_err`), 5 busy (see [locking-and-self-update](locking-and-self-update.md)). Table: [PORCELAIN.md](../../PORCELAIN.md).

### last-run

`ritz-get:cmd_update` ends by writing `$CACHE/last-run` (`$CACHE` = `${XDG_CACHE_HOME:-~/.cache}/ritz-get`): line 1 `ISO-TIMESTAMP N updated, N skipped, N failed`, line 2 `failed: NAME NAME` only when `FL` is non-zero. A cache, not state. See [porcelain](porcelain.md).

## Related links

- [porcelain](porcelain.md), [quiet-builds-design](quiet-builds-design.md)
- [update](../commands/update.md), [install](../commands/install.md)
