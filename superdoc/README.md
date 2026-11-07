# Ritz-Get — Documentation

Ritz-Get is a POSIX-sh package manager for the author's own programs and websites; each program is a git clone and the clone is the only state. Start with [architecture/overview.md](architecture/overview.md).

## architecture/ — how the code fits together

- [Overview](architecture/overview.md) — big picture, data flow, module map, where to look for X. **Start here.**

## commands/ — what each command does

- [list](commands/list.md) — list programs and websites, states, offline mode.
- [install](commands/install.md) — clone, build, install, repair.
- [update](commands/update.md) — self-update first, then rebuild what changed.
- [remove and delete-data](commands/remove-and-delete-data.md) — uninstall, keep data, delete data.
- [delete-data design](commands/delete-data-design.md) — why data deletion is restricted.
- [branches, switch, reset](commands/branches-switch-reset.md) — branch handling and re-cloning.
- [hold](commands/hold.md) — leave a program out of a plain update.
- [shortcuts](commands/shortcuts.md) — start-menu shortcuts.
- [dir and config](commands/dir-and-config.md) — clone folder and config file.

## features/ — cross-cutting behaviour

- [manifest](features/manifest.md) — the `programs` file format and parsing.
- [build runner](features/build-runner.md) — how a program's `install.sh` is run.
- [progress output](features/progress-output.md) — the progress bar and quiet builds.
- [porcelain](features/porcelain.md) — machine-readable output for frontends.
- [locking and self-update](features/locking-and-self-update.md) — one run at a time, update restarts itself.
- [state model design](features/state-model-design.md) — why the clone is the only state.
- [quiet builds design](features/quiet-builds-design.md) — why build output goes to a log.
- [porcelain contract design](features/porcelain-contract-design.md) — why the output contract is versioned.

## spec/ — the program contract

- [program spec](spec/program-spec.md) — what a program's `install.sh` must do.
- [spec check](spec/spec-check.md) — the checker script.
- [program template](spec/program-template.md) — the starting `install.sh`.

## tooling/

- [bootstrap installers](tooling/bootstrap-installers.md) — `install-ritz-get.sh` and `install.sh`.
- [icons](tooling/icons.md) — icon sets and rules.
- [cli tests](tooling/cli-tests.md) — `tests/cli/run.sh`.

## claude-instructions/ — mandatory rules for agents

- [Working with the Docs](claude-instructions/documentation.md) — read before, update after, record the why.
- [Version policy](claude-instructions/documentation-version-policy.md) — manual: versions and dates come from the human.

## meta/

- [Terminology](meta/TERMINOLOGY.md) — project vocabulary and the ask-before-acting rule.
