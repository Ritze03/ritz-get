# Ritze03 icon family — shared spec

**Chosen direction: D1 "Dark squircle" (this spec).** **Fixed: the ritz logo is
never redrawn** (user's call). SteamAlt is redrawn in this spec but keeps the
concept of its original `app.ico`. Its palette may be
borrowed; everything else harmonises with it, not the other way round.

Every icon in this set follows these rules so the suite reads as one family
(launcher grid, GitHub, browser tabs). Each app keeps its own accent + motif.

## Canvas
- `viewBox="0 0 512 512"`, no width/height attrs beyond `width="512" height="512"`.
- **Tile**: rounded square `x=32 y=32 w=448 h=448 rx=104` (squircle-ish). Nothing
  outside the tile — the 32px margin is transparent breathing room.
- **Tile fill**: the app's dark base color, as a subtle vertical linear gradient —
  top ~6% lighter than bottom (e.g. `#1E2129` → `#14161B`). No noise, no texture.
- **Tile edge**: 1 inner hairline highlight — same rect inset by 2px,
  `fill="none" stroke="#FFFFFF" stroke-opacity="0.08" stroke-width="4"`.

## Glyph
- One bold, centered glyph. Safe area: the central **288×288** box (x/y 112–400).
  Optical centering is fine; never touch the tile edge.
- **Stroke weight 32** for primary lines (round caps + joins); secondary details
  20. **The main container outline (keycap, bubble, box, frame) is always 32** —
  20 vanishes at 16px. Filled shapes are OK — mix is fine, but the 32/20 rhythm must hold.
- Max **3 colors** in the glyph: the app accent, a near-white `#F3F4F6`
  (or the app's text color), and optionally one secondary accent.
- Accent glow is allowed: one soft radial gradient behind the glyph at ≤25%
  opacity. No drop shadows, no bevels, no skeuomorphism.
- **No `<text>`** — fonts don't travel. Letters must be drawn as paths.
- Must still read as a distinct silhouette at **16px and 32px**. Drop fine detail
  that dies at 32px rather than keep it.

## Deliverables per app, in `/home/mo/tmp/projecticons/icons/<app>/`
- `<app>.svg` — the master, hand-written clean SVG (no editor metadata).
- `<app>-16.png`, `-32.png`, `-48.png`, `-128.png`, `-256.png`, `-512.png`:
  `rsvg-convert -w N -h N <app>.svg -o <app>-N.png`
- `favicon.ico` (16/32/48): `magick <app>-16.png <app>-32.png <app>-48.png favicon.ico`
- `preview.png` — sheet of the 6 sizes on dark + light bg for review:
  `magick \( <app>-512.png <app>-128.png <app>-48.png <app>-32.png <app>-16.png -background '#0b0c0f' +append \) \( same files -background '#f3f4f6' +append \) -append preview.png`
  (any equivalent command is fine).

## Validate
`rsvg-convert` must render without warnings; `xmllint --noout <app>.svg` passes.
