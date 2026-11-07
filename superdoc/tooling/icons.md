# Icons — master SVG and PNG per entry, and the one rule

Every program and website that ritz-get lists has an icon, and every icon is made by the maintainer. **Agents copy icons; they never draw, edit or resize them.**

## How it works

- **Website entries** (a URL instead of `OWNER/REPO` in `programs`): `icons/NAME.svg` (master) and `icons/NAME.png` (128 px), where `NAME` is the `programs` entry name. Current files: `cs2-alias-cycling`, `cs2-chat-keybind`, `cs2-multimap`, `simple-screensharing-web`, `ts6-themes`, `walters-knaggertreff`, each as `.svg` and `.png`. The CLI reads `icons/NAME.png` from the ritz-get clone when it builds a website shortcut (`ritz-get:sc_make`, `si=$MYDIR/icons/$sn.png`); frontends fall back to a letter tile without it (SPEC section 6).
- **Program entries** keep their own icon in their own repo: `icon.png` at the repo root, tracked, exactly 1024x1024, with an optional `icon.svg` master next to it (SPEC R5; [spec-check](../spec/spec-check.md) checks the PNG header). ritz-get shows it on the card before installation and rewrites a shortcut's `Icon=` to the clone's `icon.png` ([../../SPEC.md](../../SPEC.md) R39). `ritz` is the exception: only `icon.png`, because its logo is never redrawn.
- **ritz-get's own icon:** root `icon.svg` (master) and `icon.png` (1024x1024).
- **Style rules for new icons:** [../../icons/FAMILY.md](../../icons/FAMILY.md), the "Dark squircle" set: a 512 viewBox, rounded-square tile with a subtle vertical gradient and a hairline inner highlight, one bold glyph in the central safe area, stroke weights 32/20, at most three glyph colours, no `<text>` (letters are paths), legible at 16 and 32 px. Validation is `rsvg-convert` without warnings and `xmllint --noout`. FAMILY.md also names a maintainer working folder for deliverables; that is a local, temporary location and it is not part of the repo.
- **Exports.** PNGs come from the SVG with `rsvg-convert -w N -h N icon.svg -o icon-N.png`, which reproduces the existing exports byte for byte. *Why:* a byte-identical re-export means a regenerated PNG never shows up as a spurious diff.
- **Why agents never touch them:** SPEC states the icons are the maintainer's own work and that, if `icon.png` is missing from a program repo, the port reports it and stops: no placeholder, no generated image, no resized or converted copy, no merge; the PR is marked `waiting for icon.png` (SPEC icon box, R5, section 8). The same applies inside this repo.
- **Unused alternative:** the maintainer's "Ritz disc" icon set exists only in his working folder, not in the repo.

## Using it

- New website entry: the maintainer supplies `icons/NAME.svg` and `icons/NAME.png`; an agent copies them into `icons/` as given and, if they are missing, reports that instead of drawing one.
- A port finds `icon.png` absent: stop at that point, report it, leave the rest of the PR in place.
- Need a PNG from an existing SVG: use the `rsvg-convert` command above; do not hand-resize.

## Related links

- [../spec/program-spec.md](../spec/program-spec.md), [../spec/spec-check.md](../spec/spec-check.md)
- [../features/manifest.md](../features/manifest.md) (entry names and website entries)
- [../../SPEC.md](../../SPEC.md), [../../icons/FAMILY.md](../../icons/FAMILY.md)
