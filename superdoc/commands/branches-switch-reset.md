# branches, switch, reset — change which code a program runs

Three commands that move an installed program to different code: `branches` lists the remote's branches, `switch` moves to one and rebuilds, `reset` throws away local changes by re-cloning. All three keep the old install working if the rebuild fails.

## How it works

- **`ritz-get:cmd_branches NAME`** (takes no lock, exactly one argument). Installed: `git ls-remote origin refs/heads/*` inside the clone, current branch marked `* `. Not installed: looks up the manifest and does `ls-remote` on `$BASE/$SRC.git`; websites are an error. Unreachable remote: `cannot reach the remote`, exit 1.
- **`ritz-get:cmd_switch NAME BRANCH`**: needs an installed program. Steps: `fetch --prune`, `checkout BRANCH` (failure: `cannot check out 'B'; see: ritz-get branches NAME`), `merge --ff-only @{u}`, then `ritz-get:build`. If the fast-forward fails it checks the old branch back out (`your local B has diverged`). If the build fails it checks out the old ref (a detached `HEAD` is remembered by hash) and re-syncs submodules (`sync_subs`), so the installed version is unchanged. Success: `NAME: now on B HASH` plus `sc_refresh`. `install --branch` on an installed program is refused and points here ([install](install.md)).
- **`ritz-get:cmd_reset NAME [--yes]`**: needs a manifest program (not a website) that is installed. It reads `changes` and, without `--yes`, prints what is lost (`N changed files, N local commits and any hold`) before `Continue? [y/N]`. *Why the hold is listed:* the hold lives in the clone's git config, and a re-clone creates a fresh one ([hold](hold.md)). Then: clone the manifest branch (`DEFBR`) into `$SRCDIR/.NAME.new`, move the old clone to `.NAME.old`, move the new one into place, `build`. Success deletes `.old`. Failure deletes the new clone and moves `.old` back. *Why:* the code comment: "put the old clone back: same path, links still valid" because the links `install.sh` made point into that path.
- A build result of 2 ("needs a newer ritz-get") is a skip with exit 1 in both commands; other failures go through `fail` with the build's exit class (`BK`).
- Both take the lock via `main` ([locking-and-self-update](../features/locking-and-self-update.md)); `branches` does not.

## Using it

```sh
ritz-get branches NAME          # * marks the current one
ritz-get switch NAME BRANCH     # fetch, check out, fast-forward, rebuild
ritz-get reset NAME [--yes]     # discard local work: re-clone default branch, rebuild
```

Typical flow when a branch was deleted on the remote (`branch-gone` in [list](list.md), skipped by [update](update.md)): `branches NAME`, then `switch NAME BRANCH`.

## Related links

[install](install.md) · [update](update.md) · [hold](hold.md) · [list](list.md) · [build-runner](../features/build-runner.md) · [README.md](../../README.md)
