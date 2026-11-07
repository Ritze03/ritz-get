# hold — keep a program out of a plain update

`ritz-get hold NAME...` marks installed programs so `ritz-get update` without a name skips them; `unhold` undoes it.

## How it works

- State is one git config key in the program's own clone: `ritz-get.hold=true`. `ritz-get:held NAME` reads it. *Why:* the README says the clone is the whole state, with no other state files.
- `ritz-get:set_hold NAME true|false`: validates the name, requires an installed clone (`NAME is not installed`, exit 1). `true` runs `git config ritz-get.hold true` and prints `NAME: held (update without a name skips it)`; `false` runs `git config --unset ritz-get.hold` and prints `NAME: not held`.
- `ritz-get:cmd_hold` and `ritz-get:cmd_unhold` need at least one name and loop `set_hold`.
- **Effect on update**: `ritz-get:upd_check` skips a held program only when no names were given (`EXPL` unset); `ritz-get update NAME` still updates it ([update](update.md)).
- **Effect on list**: `ritz-get:inst_fields` sets `HELD`, shown as `[held]` in the table and in the porcelain `held` column ([list](list.md)).
- `reset` removes the hold, because it re-clones ([branches-switch-reset](branches-switch-reset.md)).
- Hold and unhold take the lock (`main`).

## Using it

```sh
ritz-get hold NAME       # leave NAME out of 'update'
ritz-get unhold NAME
```

## Related links

[update](update.md) · [list](list.md) · [branches-switch-reset](branches-switch-reset.md) · [locking-and-self-update](../features/locking-and-self-update.md) · [README.md](../../README.md)
