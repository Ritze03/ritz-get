# Ritz-Get

Package manager for the author's own programs and websites. One POSIX `sh` script (`ritz-get`); each program is a git clone and the clone is the only state. CLI only: the GUI is a separate repo.

- Entry points: `ritz-get` (`main`, dispatches to `cmd_<name>`), `install.sh`, `install-ritz-get.sh`, `template/install.sh`.
- Tests: `sh tests/cli/run.sh` and `sh tests/spec-check.sh`.
- User-facing sources, link to them and do not copy: `README.md`, `SPEC.md`, `PORCELAIN.md`.

<!-- superdoc:start v4 -->
## Docs: read before you touch, update after you change

Full discipline — what to read, when to update, how to record the *why* — lives in the
always-loaded `superdoc/claude-instructions/documentation.md` below; this is a pointer, not
a restatement.

Reference docs — plain links, read the one relevant to your task on demand:

- **`superdoc/architecture/overview.md`** — codebase navigation map (module map, data flow,
  "where to look for X"). **Start here to navigate the code.**
- Per-command behaviour — `superdoc/commands/`
- Cross-cutting features and designs — `superdoc/features/`
- Program spec, checker, template — `superdoc/spec/`
- Installers, icons, tests — `superdoc/tooling/`
- `superdoc/README.md` — the docs table of contents

## Always in context (force-loaded, mandatory)

`@` is reserved for the must-always-know set. Everything above is a plain link: an
optional, on-demand read.

- **Terminology** — @superdoc/meta/TERMINOLOGY.md — project vocabulary; use these meanings,
  ask before acting on an undefined term, and keep it current.
- **Documentation discipline** — @superdoc/claude-instructions/documentation.md — read
  before you touch, update after you change, record design rationale (the *why*).
- **Version policy** — @superdoc/claude-instructions/documentation-version-policy.md — how
  this project bumps doc/version markers.

Path base: `CLAUDE.md` uses repo-root-relative paths (`@superdoc/...`, `` `superdoc/...` ``);
links *inside* docs are docs-relative. Precedence: `CLAUDE.md` is authoritative for
rules, docs are the reference — reconcile to `CLAUDE.md` on conflict. `@`-budget:
force-load a file only if its absence would let the agent do the wrong thing on *any*
task.
<!-- superdoc:end -->
