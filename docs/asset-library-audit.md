# Print Studio Asset Libraries — Audit

**Phase 1 of `docs/print studio-florida-alignement` (the Asset Libraries brief).**
Read-only. No code was modified. Every claim cites a file and line, or a live
read-only query against the production database.

Audited: `dist/print.html` @ 9,289 lines, commit `5239e41`, 2026-08-05.

---

## 0. Corrections to the brief's premises

The brief asks that its hypotheses be validated, not assumed. Four are wrong:

| Brief says | Actually |
|---|---|
| "external open-access libraries (Smithsonian, The Met)" | **There is no Smithsonian integration.** Zero occurrences of `smithsonian` / `si-edu` / `americanart` in the file. The external sources are **Openverse**, **The Met**, and **Iconify**. |
| "~4,200 provenance-documented works" | **6,451 rows** in `patterns_public`. |
| "exports already carry a baked-in watermark" | The watermark is **user-disableable** via a checkbox — [print.html:1431](../dist/print.html#L1431), honoured at [3934](../dist/print.html#L3934) (SVG) and [4156](../dist/print.html#L4156) (PNG). Default on, not enforced. |
| "now with real thumb URLs" | True — 6,358 of 6,451 have `thumb_url`. But see §2.4: the thumb is the **only** resolution that exists. |

"Patterns already assign their palette correctly" — **confirmed**, [print.html:2483](../dist/print.html#L2483).

---

## 1. Library inventory

Five tabs in the asset picker: `gpane-search`, `gpane-met`, `gpane-icons`,
`gpane-patterns`, `gpane-collections`.

| Library | Fetched from | Where | Rights filter | Fields captured |
|---|---|---|---|---|
| **Openverse** | `api.openverse.org/v1/images/` | [2217](../dist/print.html#L2217), [4648](../dist/print.html#L4648) | `license_type=commercial,modification` **at query time only** | `url`, `thumbnail`, `title`. The response's `license` / `license_url` / `creator` fields are **discarded** — [2221](../dist/print.html#L2221) keeps only rows where `r.url` exists |
| **The Met** | `collectionapi.metmuseum.org` | search [2237](../dist/print.html#L2237), detail [2261](../dist/print.html#L2261) | `isPublicDomain=true` at search; **not re-verified** on the object fetch | `primaryImageSmall`, `primaryImage`, `title`. `artistDisplayName`, `objectDate`, `creditLine`, `objectURL` all available in the response and **not read** |
| **Iconify** | `api.iconify.design` | [2304](../dist/print.html#L2304), [2324](../dist/print.html#L2324) | **none** | `prefix:name` only |
| **CultureSchool Patterns** | `patterns_public` view via PostgREST | [2383](../dist/print.html#L2383) | n/a (ours) | 10 of 21 columns selected |
| **My Uploads** | local `FileReader` → `coco-drops` / `public-uploads` | [2587](../dist/print.html#L2587), [2603](../dist/print.html#L2603) | **none** | filename only |

### 1.1 Iconify is asserted MIT, and isn't

[print.html:2302](../dist/print.html#L2302) labels the section
`Iconify Open SVG Library · MIT Licensed`. Iconify is an aggregator: individual
icon sets carry **Apache-2.0, CC BY 4.0, CC BY-SA, OFL and MIT** licences, several
with attribution requirements. The API exposes per-set licence data at
`/collections`; the code never requests it. A blanket MIT claim over CC BY-SA
content is a licence misstatement that reaches export.

### 1.2 Uploads go to a public bucket

[2603](../dist/print.html#L2603) uploads to `coco-drops`, falling back to
`public-uploads`, then takes `getPublicUrl`. Any file a user adds becomes
world-readable at a guessable path (`studio/<timestamp>_<filename>`). Acceptable
for consumer use; **disqualifying for School Mode**, where an upload could be
student work or contain a student's face. School Mode's "no uploads in v1"
decision is therefore correct and load-bearing, not merely a moderation
convenience.

---

## 2. Pattern library integration

### 2.1 Where the records live

- **View:** `public.patterns_public` — 21 columns, 6,451 rows.
- **Base table:** `public.patterns` — 36 columns, 6,451 rows, all `is_public = true`.
- Print Studio reads the view only, never the base table — [2383](../dist/print.html#L2383). Correct per `atlas/17`.

**The 15 columns the view withholds** (the actual privilege boundary):

```
color_descriptor, description, contributed_by, contributor_email,
heritage_meaning, heritage_technique, heritage_significance, heritage_tags,
region, culture_tags, palette_story, cultural_origin, location,
source_palette_id, is_free
```

Note `heritage_meaning`, `heritage_technique` and `heritage_significance` — the
Atlas-grade narrative content — are on the **withheld** side. School Mode §30
("Atlas-lite panels … tradition card inline") needs exactly these fields, so it
cannot be built on `patterns_public` as it stands. That is a spec input, not a bug.

**Boundary verified, not assumed.** I read the base table with the anon key
(embedded in page source, so this is what any visitor holds): RLS returns
**6 rows** of 6,451, and `contributor_email` is null on all of them. The
free-sample gate works. I initially read the 200-response as a breach and was
wrong — recording that so the spec doesn't inherit a false alarm.

### 2.2 Thumb URLs

[2358](../dist/print.html#L2358):

```js
function patternThumbUrl(p) {
  return p.thumb_url || (PATTERN_THUMB_BASE + p.id + '.png');
}
```

Deterministic fallback to `<bucket>/<id>.png`, so the tab survives the backfill.
Bucket sends `Access-Control-Allow-Origin: *` (verified live), so
`urlToDataURL` [2672](../dist/print.html#L2672) resolves patterns on the direct
path and **never** falls through to the third-party CORS proxies at
[2684–2686](../dist/print.html#L2684) (`corsproxy.io`, `allorigins.win`,
`codetabs.com`). The comment at [2345](../dist/print.html#L2345) claims this;
it is true. Proprietary art is not relayed to third parties.

Anon **cannot** enumerate the bucket (list returns `[]`), but object paths are
derivable from the public view, so all 6,358 thumbs are directly fetchable by
anyone. That is intended for thumbs — it matters only because of §2.4.

### 2.3 Palette assignment — confirmed working

[2483](../dist/print.html#L2483) `usePatternPalette()` synthesises a palette
object from the row (`colors`, `palette_name`, `heritage_origin`,
`heritage_region`) rather than looking one up, because `patterns.palette_id` is
null across the archive. Comment at [2480](../dist/print.html#L2480) documents
this. Not touched, per guardrail.

### 2.4 Resolution tiers — one tier, because the recipe wasn't saved

**Storage inventory** (full enumeration, service role):

| bucket | objects | dimensions |
|---|---|---|
| `pattern-thumbs` | **11,282** | **400 × 400, every single one** — checked largest file to smallest; the 6 KB → 401 KB size spread is compression, not resolution |
| `assets/originals` | 109 | not patterns — 0 of 60 sampled IDs match a `patterns_public` row |
| `previews` | 109 | same set as `assets/originals`, `.webp` |

So the thumbnails are exactly where expected. There is no hidden larger tier —
`full_url` does not exist as a column, and no bucket holds pattern art above
400 px.

**Storage reconciliation** — three generator runs left residue:

| | |
|---|---|
| objects in `pattern-thumbs` | 11,282 |
| rows in `patterns_public` | 6,451 |
| **objects with no matching row** | **4,923 (303 MB orphaned)** |
| rows with no object | 92 |

**Why one tier, stated precisely.** The patterns are algorithmic. The generator
is *seeded* (`globalSeed`, `seededRand()` — [patterng.html:1498](../patterng.html#L1498),
[3459](../patterng.html#L3459)), uses only two `Math.random()` calls, renders at
800 / 1200 / 1400 px on demand ([patterng.html:7048](../patterng.html#L7048)),
and can already export **SVG** — infinitely scalable — at
[6927](../patterng.html#L6927) and [7644](../patterng.html#L7644).

The maths can therefore draw any pattern at any size. But the save path,
[patterng.html:7340](../patterng.html#L7340), writes only:

```js
name, palette_name, style, colors, is_public,
palette_id, cultural_origin, contributed_by, location, occasion
```

No seed. No slider parameters. No `lastSVG`. The **description** of each pattern
is persisted; the **parameters that drew it** are not. `generate-thumbs` then
renders a 400 px PNG, and that PNG becomes the only surviving copy.

This is not a missing file — it is a missing recipe. The `code` column exists to
hold it and is NULL on all 6,451 rows.

**Consequence, correctly scoped.** Nothing above 1.33 in can be produced *for the
6,451 patterns already saved* without re-deriving their parameters. It is cheap
to fix **going forward** — persisting seed + params, or the SVG itself, is a
schema addition plus a few lines in the save path. Retrofitting the existing
archive is the expensive part, and is a licensing-track question, not a
School-Mode-prototype one.

### 2.5 Watermark — where it is baked, and how it is removed

[updateWatermark(), 4373](../dist/print.html#L4373):

```js
wm.textContent = paletteName ? `${paletteName}  ·  CoCo by CultureSchool` : '';
```

Client-side, at render, into an SVG `<text>` in the live canvas
([1360](../dist/print.html#L1360)); re-stamped onto the canvas for PNG at
[4157](../dist/print.html#L4157). Two properties matter:

1. **It is optional.** [1431](../dist/print.html#L1431) is a checkbox. Unchecked → SVG path blanks the text node ([3936](../dist/print.html#L3936)); PNG path skips the stamp entirely and downloads early ([4158](../dist/print.html#L4158)).
2. **It carries the palette name, never the pattern's provenance.** A canvas built entirely from Adinkra patterns exports stamped with the *palette* it happens to be using.

---

## 3. Rights & attribution

### 3.1 Provenance is captured, then dropped

[placePattern(), 2466–2471](../dist/print.html#L2466):

```js
el.setAttribute('data-source', 'patterns');
el.setAttribute('data-pattern-id', p.id);
const credit = [p.heritage_origin, p.continent].filter(Boolean).join(' · ');
if (credit) el.setAttribute('data-attribution', credit);
```

The comment reads *"Provenance rides along on the element so an export can
credit it."*

**No export path reads it.** `grep` for `data-attribution` across the whole
repository returns exactly two hits — both the write at
[2470](../dist/print.html#L2470) and its own comment. `data-source` likewise:
written at [2467](../dist/print.html#L2467), never read.

The attribute is write-only. Provenance is dropped at the export boundary, on
the one library where CultureSchool actually owns the provenance.

### 3.2 What "attribution" means here — and does not

**The patterns are original works.** They are generated by
[patterng.html](../patterng.html) and *reference* traditions; they are not scans
or reproductions of cultural artefacts. CultureSchool owns them outright.

That materially simplifies the rights model, and the spec should not import the
museum framing onto them:

- There is **no third-party rights holder to clear** for a pattern, and no licence to comply with. The absence of `license_type` on the pattern archive is therefore not a compliance gap.
- `attribution_text` on a pattern is an **editorial credit to the tradition that inspired it** — "in the Adinkra tradition, Ghana" — not a legal notice. Its job is the cultural-integrity claim and the works-cited line in the school briefs.
- It follows that patterns are **`school_safe` by construction.** The School Mode content gate does not need per-row rights adjudication for the owned library; it needs a filter that admits patterns and excludes the three external libraries.

The rights work that *is* genuinely outstanding belongs to Openverse, the Met and
Iconify — §3.3 below — plus uploads.

### 3.3 No rights data is stored for any external library

`license_type`, `attribution_text`, `school_safe`, `atlas_entry_id`, `source`
and `full_url` — all six proposed by the spec — are **absent** from
`patterns_public` (verified live). For Openverse and the Met, rights are
enforced by *query parameter at fetch time only*; nothing is checked at ingest
and nothing is stored on our side. Consequences:

- If a Met object's public-domain status changes, our copy never learns.
- Openverse's `license` field is available in the response and thrown away, so we cannot render "CC BY — J. Smith" even where CC BY *requires* it.
- There is no field that could drive a `school_safe` filter. School Mode §28 has nothing to filter on.

### 3.4 Attribution coverage in the pattern archive itself

| | rows | share |
|---|---|---|
| `heritage_origin` NULL | 1,751 | 27.1% |
| `continent` NULL | 1,751 | 27.1% |

The credit line at [2469](../dist/print.html#L2469) is built from exactly these
two fields, so **1,751 patterns would produce an empty credit even if the export
path did read it.** Those rows are also invisible to the continent filter
([2397](../dist/print.html#L2397)), so they are unreachable by browsing — only
by text search.

---

## 4. Usage tracking

`cs-track` is inlined at [1550](../dist/print.html#L1550). The comment at
[1540](../dist/print.html#L1540) records that Print Studio called `csTrack()` in
two places without ever loading it — every event was a silent no-op until that
fix. Live counts confirm the recovery is recent: **939 events total, 71
`pattern_view`, 31 `download`.**

| Event | Site | Fires on |
|---|---|---|
| `search` | [2438](../dist/print.html#L2438) | pattern archive search |
| `pattern_view` | [2475](../dist/print.html#L2475) | **pattern placement** — one row per placement, with `context: 'studio'` and `placed_as: background\|motif` |
| `download` | [8514](../dist/print.html#L8514), [8531](../dist/print.html#L8531) | patch / patch-PDF export only |

The brief's proposed "one row per placement" logging **already exists for
patterns** and is well-shaped. Three gaps:

1. **No placement logging for Openverse, Met, Iconify or uploads.** Only patterns are counted, so cross-library comparison is impossible.
2. **The main export path is unlogged.** `doExport()` [3921](../dist/print.html#L3921) and `downloadBlob()` [4208](../dist/print.html#L4208) emit nothing. The two `download` events cover only the patch flow. We can see what was *placed*, never what was *shipped* — which is the number a licensing conversation asks for.
3. `event_type` is CHECK-constrained to nine values and there is no `surface` column ([1547](../dist/print.html#L1547)), so a new event type needs a migration.

---

## 5. Search & filter

| Library | Keyword | Other filters |
|---|---|---|
| Openverse | free text | none |
| Met | free text | none |
| Iconify | free text | none |
| Patterns | `name`, `heritage_origin`, `occasion`, `style` via `ilike` — [2392](../dist/print.html#L2392) | continent, 6 fixed values — [2352](../dist/print.html#L2352) |

Pattern search sanitises PostgREST syntax out of user input before
interpolation ([2390](../dist/print.html#L2390), strips `,()*%`). Correct.

**No colour filter exists on any library**, and **Print Studio does not share the
colour-extraction engine.** Extraction lives in `dist/field-log.html`,
`dist/field-read.html`, `dist/planner.html` and `public/collector-planner.html`;
`print.html` contains no `extractColors` / `quantize` / `medianCut` / `kmeans`.
Patterns already carry `colors` (0 nulls), so a colour filter over patterns needs
no extraction at all — only an index. Museum items would need extraction + cache.

---

## 6. Gaps & risks

Ordered by consequence.

| # | Finding | Evidence | Risk |
|---|---|---|---|
| 1 | **The generator recipe is not persisted.** Save writes the pattern's description, never its seed/params/SVG, so the 400×400 PNG is the only surviving copy. Cheap to fix forward; expensive to retrofit 6,451 rows. | §2.4, [patterng.html:7340](../patterng.html#L7340) | Caps print size at 1.33in; licensing-track blocker, **not** a School-Mode-prototype blocker |
| 2 | **Watermark is optional and provenance-free.** User unchecks a box → clean file. Watermark names the palette, not the pattern. | [1431](../dist/print.html#L1431), [3934](../dist/print.html#L3934), [4156](../dist/print.html#L4156), [4373](../dist/print.html#L4373) | Proprietary art leaves unmarked and uncredited |
| 3 | **`data-attribution` is write-only.** Captured on placement, read nowhere. | [2470](../dist/print.html#L2470) | Provenance dropped at export — the moat's whole claim |
| 4 | **Iconify asserted MIT; sets are CC BY / CC BY-SA / Apache / OFL.** Per-set licence never fetched. | [2302](../dist/print.html#L2302), [2304](../dist/print.html#L2304) | Licence misstatement reaching exported work |
| 5 | **No rights fields for the three external libraries.** Rights are a query param at fetch time, never stored. Does **not** apply to patterns, which are owned outright (§3.2). | §3.3, live schema read | CC BY attribution impossible; external libraries can't be gated for schools |
| 6 | **27% of the archive has no origin.** 1,751 rows NULL on both `heritage_origin` and `continent`. | live count | Empty credit lines; unreachable by browsing |
| 7 | **Atlas narrative fields are behind the view.** `heritage_meaning` / `_technique` / `_significance` withheld from `patterns_public`. | §2.1 | School Mode Atlas panels can't be built on the current view |
| 8 | **Uploads land in a world-readable bucket** at a guessable path. | [2603](../dist/print.html#L2603) | Disqualifying for classroom use; confirms School Mode's no-upload call |
| 9 | **Export path unlogged.** Placements counted, downloads not. | §4 | No evidence of what actually shipped |
| 10 | **4,923 orphaned storage objects (303 MB)** in `pattern-thumbs` with no matching row — residue of three generator runs. | §2.4 | Storage cost; makes any object-count audit unreliable |
| 11 | **Third-party CORS proxies in the image path.** Patterns bypass them (CORS `*` verified); Openverse/Met/Iconify do not. | [2684](../dist/print.html#L2684) | External images relayed through `corsproxy.io` / `allorigins.win` / `codetabs.com` |

### Not found in this repo

Per the guardrail on speccing blind:

- **Pattern ingest scripts.** How `patterns` rows and `pattern-thumbs` objects are created is not in this repository. The `code`-not-persisted question (#1) can only be answered there.
- **Any Atlas entries table.** The briefs reference "the CultureSchool Atlas" as the citable source; no `atlas_*` table is read by Print Studio and none was found. School Mode §30 depends on it.
- **`docs/florida-alignment-brief`.** Named as a dependency by the School Mode brief; not present. The file named `print studio-florida-alignement` is byte-identical to `print-studio:audit then spec` and contains *this* brief, not the Florida one. The sample briefs' own standards tags confirm the gap: VA.68.* codes are specific and real; high-school citations are `VA.912 organizational-structure equivalents` (a placeholder) and `VA.912 Historical & Global Connections strand` (a strand, not a benchmark).

---

## 7. What this means for Phase 2

Three items should be settled before the spec is written, because each changes
its shape:

1. **Is there a source of full-resolution pattern art anywhere** — an original file, or the generator `code` in another system? If yes, the spec is a delivery-tier design. If no, the spec's first line item is regenerating 6,451 assets, and that is the critical path for both licensing and schools.
2. **Where does Atlas content live?** Both the School Mode Atlas panels and the `attribution_text` composition depend on it.
3. **Should the watermark toggle survive?** It is a deliberate consumer affordance ("recommended for sharing"). Removing it for all users is a product decision, not a bug fix — but the licensing frame and the School Mode provenance-credit-as-works-cited design both assume an unremovable credit line.

Findings #3 (write-only attribution) and #6 (27% missing origin) are the cheapest
real wins and are independent of all three questions above.
