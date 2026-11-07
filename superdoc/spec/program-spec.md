# Program spec — the contract a program repo must meet

`SPEC.md` is the published contract that says how a program's git repo must look so ritz-get can install, update and remove it. This page is an agent's map of it: what it governs and where to look. It never restates the rules; read [SPEC.md](../../SPEC.md) for the wording. SPEC.md is user-facing and complete on its own (it is handed to agents working in other programs' repos), so do not copy it here and do not edit it from a docs task.

## How it works

- **What it governs.** Only the program side of the boundary: the shape of the repo, the two ways ritz-get calls `install.sh` (`./install.sh --install --yes`, `./install.sh --remove --yes`), the environment it runs in, exit codes, output format, and the manifest entry a port sends back. Everything ritz-get does itself (clone, update, switch, reset, hold, shortcuts, the lock, deleting the clone after remove) is listed in SPEC section 5 as "do not implement"; the CLI side is documented under [../architecture/overview.md](../architecture/overview.md).
- **Section map of SPEC.md.**

  | Section | Holds |
  | --- | --- |
  | 1 | How ritz-get calls `install.sh`: cwd, stdin, user, environment (`RITZ_GET_SPEC`, `RITZ_GET_SUDO`, `NO_COLOR`, `TERM`), 60 minute limit, rollback after a failed build |
  | 2 | The numbered rules R1 to R38 (below) |
  | 3 | The template and patterns P1 to P6 (tool check, atomic binary build, directory swap, autostart, systemd user service, root link) |
  | 4 | `NAME.desktop` (R39) and the required `icon.png` |
  | 5 | What ritz-get owns |
  | 6 | The manifest entry grammar |
  | 7 | "Done when": what [spec-check](spec-check.md) covers and the checklist it cannot cover |
  | 8 | Delivering a port: one PR from `ritz-get-spec-v1`, check output pasted in full, migration notes, README change |
  | 9 | Spec versions |

- **How the rules are organised.** Rules are numbered R1.. so that the check script, reviews and PRs can cite them. Section 2 groups them: 2.1 files in the repo (R1 to R8), 2.2 arguments (R9 to R11), 2.3 symlinks only (R12 to R16), 2.4 install, update, idempotency (R17 to R21), 2.5 remove (R22 to R24), 2.6 exit codes and output (R25 to R28), 2.7 background parts (R29 to R31), 2.8 root (R32 to R36), 2.9 never (R37, R38). R39 sits in section 4. MUST, MUST NOT, SHOULD and MAY follow RFC 2119. *Why:* the numbers are the shared handle: [spec-check](spec-check.md) prints them on every PASS/FAIL line, so a failure points straight at the rule.
- **Wins over the template.** SPEC.md says that if `template/install.sh` and the spec disagree, the spec wins ([program-template](program-template.md)).
- **The marker.** One of the first five lines of a program's `install.sh` must be exactly `# ritz-get-spec: 1` (R3). The same line is in `template/install.sh` and in ritz-get's own root `install.sh`. ritz-get tells the script which version it speaks in `RITZ_GET_SPEC` (currently 1). A ritz-get older than a program's marker skips the program with "needs a newer ritz-get"; a program without a marker still runs, but the check fails it (SPEC section 9).
- **The manifest entry a port sends back.** A port never edits `programs`; it sends its entry in the final reply (SPEC section 6, delivered per section 8): the section (`[Software]`, `[Helpers]` or `[Other]`), the entry line `NAME OWNER/REPO [BRANCH] "DESC"` (description at most 80 characters, mandatory), a mandatory `title:` (at most 40), `setup:` lines (at most 120 each, only for manual steps, never for build dependencies) and `data:` lines (`~/PATH`, every folder the program creates outside the clone). The grammar and how ritz-get parses it is in [../features/manifest.md](../features/manifest.md). *Why:* `data:` lives in the manifest because the manifest is still there after the clone is gone, which is when `delete-data` needs it (SPEC section 6).
- **Versioning rule.** The spec version goes up only when a change would make a conforming repo stop conforming; clarifications and new MAY/SHOULD rules keep the number (SPEC section 9). When it does go up, SPEC.md lists what to change, and `grep -L '# ritz-get-spec: 2' */install.sh` in the repo folder lists the repos still to port. *Why:* a program declares the version it was checked against, and an older ritz-get skips a program that declares a newer one, so bumping on a mere clarification would lock working programs out for no reason.
- **Icon rule inside the spec.** R5 requires a tracked, exactly 1024x1024 `icon.png` at the repo root, and agents never create, edit or re-export it: if missing, the port reports it and stops, and the PR is marked `waiting for icon.png`. See [../tooling/icons.md](../tooling/icons.md).
- **Where the spec is enforced.** [spec-check](spec-check.md) checks most rules by running `install.sh` in a throwaway HOME; ritz-get's CLI test suite ([../tooling/cli-tests.md](../tooling/cli-tests.md)) uses spec-style fixture scripts; the build-and-run side that executes `install.sh` is [../features/build-runner.md](../features/build-runner.md) and the command that triggers it is [../commands/install.md](../commands/install.md).

## Using it

- Porting a repo: read SPEC sections 1 and 2, check that `icon.png` exists, pick patterns in section 3, start from [the template](program-template.md), run [spec-check](spec-check.md) until the last line is `ALL PASS`, then deliver as section 8 says.
- Changing the rules: edit SPEC.md, keep `template/install.sh` and `tests/spec-check.sh` in step (a rule with a check names its R number in the check's FAIL line), and decide with the versioning rule above whether the marker number must change. A version bump also changes the marker in the template, the check script's `# ritz-get-spec: 1` grep, ritz-get's own `install.sh` and the fixtures in `tests/cli/run.sh`.

## Related links

- [SPEC.md](../../SPEC.md), [README.md](../../README.md), [PORCELAIN.md](../../PORCELAIN.md) (user-facing sources; do not copy or change from docs tasks)
- [spec-check](spec-check.md), [program-template](program-template.md)
- [../features/manifest.md](../features/manifest.md), [../features/build-runner.md](../features/build-runner.md), [../commands/install.md](../commands/install.md), [../architecture/overview.md](../architecture/overview.md)
