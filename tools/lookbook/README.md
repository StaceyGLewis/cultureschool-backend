# CoCo lookbook builder

Turns palettes from the live database into a print-ready 8.5 × 11 lookbook —
two palettes to a sheet, each shown as cloth and as an interior.

No build step, no dependencies. Node 18+ (uses the built-in `fetch`).

## Pick your palettes

```
node tools/lookbook/build.js --list
```

Prints every public palette with its origin, what it can be specified for, and
what — if anything — is missing. A `✓` means it is ready to print; a `·` means
it has a gap, named on the line.

Copy the names you want into a text file, one per line:

```
# autumn-2026.txt
Winfred's Hohoe Rust and Russet
Accra Kente Weaver's Gold
Vineyard Wampanoag Clay
```

Names are matched loosely — case, curly apostrophes and stray whitespace are all
forgiven. A palette id works too. Blank lines and `#` comments are ignored.

## Build it

```
node tools/lookbook/build.js \
  --picks tools/lookbook/autumn-2026.txt \
  --edition "Autumn 2026" \
  --out autumn-2026.html
```

Then open the HTML and **⌘P → Save as PDF**. `@page` is already set to US Letter
with zero margins, so the PDF trims exactly to 8.5 × 11 with no scaling. That
file goes straight to Staples for coil binding.

Flags:

| | |
|---|---|
| `--list` | show every palette and its readiness |
| `--picks <file>` | the list to build from (required) |
| `--edition <name>` | printed in the header of every sheet. Default `Autumn 2026` |
| `--out <file>` | output path. Default `lookbook.html` |
| `--force` | build without warning about gaps |

A name that doesn't match anything stops the build and tells you which — it will
never silently drop a palette from your edition.

## What ends up on the sheet

**Left — as cloth.** A warp-faced weave in the palette's own colours, folded,
with a cushion turned 90° so the warp reads as weft. These are the colours
exactly as they are, nothing altered.

**Right — as an interior.** For a palette that can hold architecture, the same
colours placed by their 60/30/10 roles: dominant on walls, secondary on
upholstery, accent on cushions and art, ground on the floor.

For a palette that cannot — no light anchor, no ground, or too little value
spread — the panel shows a **constructed interior colourway** instead, and says
so. The signature colours are kept and the missing structure is derived from
their hues. Nothing is invented and nothing is imported.

Under each render: the colour strip, then hex and CMYK per colour. A `△` marks a
colour that falls outside the CMYK gamut and will shift on press.

## The checks that run first

| check | what it catches |
|---|---|
| **gamut** | colours that cannot be reproduced in CMYK. Calibrated to the six SWOP-coated ink vertices and validated against them. |
| **textile** | whether the motif reads — ΔE between every colour pair. A palette whose colours all sit within ΔE 12 will mud in print. |
| **interior** | light anchor (L\*≥72), dark anchor (L\*≤40), value spread ≥40, no more than three saturated colours. |
| **identity** | Pride and national flags earn every cloth badge but never `Interior`. A flag belongs on things that declare, not on the surfaces you live inside. |
| **documentation** | a missing story or `cultural_origin` is reported before the build, not discovered in print. |

## Files

```
build.js              the CLI
lib/color.js          Lab, CMYK, and the SWOP gamut boundary
lib/viable.js         interior rules + 60/30/10 role assignment
lib/textile.js        ΔE pair analysis + application classes
lib/room.js           the interior render
lib/cloth.js          the woven render
lib/construct.js      builds an interior colourway from a textile palette
lib/*.woff2           Cormorant Garamond + DM Sans, inlined at build time
```

Fonts are embedded as base64 in the output, so the PDF renders identically on
any machine and never depends on the network.

## Notes

- Every SVG namespaces its element ids by palette content. Two sheets in one
  document defining the same `id` would make every `url(#…)` resolve to the
  first — which silently prints the wrong cloth on every page after page one.
- Construction is deterministic: same palette in, same colourway out, every
  time, and each derived colour is a stated transform of a source hue. That
  lineage is what makes a colourway defensible in a licensing conversation.
- All constructed colours are held inside the CMYK boundary, so nothing the
  builder generates can fail on press.
