# Scope — splitting the pattern engine into a members-only bundle

Written 2026-07-31. Nothing here has been built. This is a decision document.

---

## The finding that changes the priority

**The pattern library is not where the engine leaks. The generator is.**

Measured today, no login, single request:

| Surface | Draw functions shipped | Auth check | Status |
|---|---|---|---|
| `coco-pattern-generator.netlify.app` | **80** | **none** (`is_subscriber` appears 0 times) | HTTP 200, 376 KB, fully public |
| `dist/pattern-library.html` | 77 | subscriber gate (added today) | live |
| `patterng.html` (local source of the generator) | 80 | — | uncommitted until today |
| `public/generate-thumbs.html` | 41 | — | internal tool |

One `curl` against the generator returns the complete engine — a **superset** of what the library ships. Extracting the engine out of `pattern-library.html` while that URL stays open accomplishes nothing measurable. The library work was still worth doing (it gates downloads, filters and generator access, and it's the conversion surface), but on IP specifically it is not the lever.

**Second finding, equally decisive:** `0 of 7,088` pattern rows have a `thumb_url`. Every pattern image on every surface is generated in the browser, right now, from `style` + `colors`. That is why the engine has to ship — and why "just serve images to non-members" is a project, not a switch.

---

## Why this is harder than it looks

Non-members are not shown nothing. They currently see:

- 6 free pattern tiles — canvas-rendered
- 8 blurred teaser tiles — canvas-rendered
- the modal's large preview — canvas-rendered
- the pillow / tote / sheet-set order mockups — canvas-rendered, composited against real Shopify product photos

All four need the engine client-side today. So withholding the engine from non-members means **replacing all four with pre-rendered images first.** That is the gating dependency for every option below.

---

## Options

### Option 1 — Gate the generator page itself
Stop serving `coco-pattern-generator` HTML to anonymous visitors (Netlify password / edge function / identity check).

- **Effort:** ~1 hour
- **Closes:** the single largest exposure, immediately
- **Does not close:** the engine is still in the HTML for anyone who gets past the door — including every member
- **Breaks:** the library modal's deep-link CTA for non-members, which is already gated as of today, so this is aligned
- **Verdict:** do this first regardless of what else you choose. Highest ratio of protection to effort in the whole thread.

### Option 2 — Members-only engine bundle (the thing you asked me to scope)
Extract the ~4,700 lines into `engine.js`, serve it from a Netlify function that checks entitlement — same shape as your existing `coco-art-download`.

- **Effort:** 2–4 days
- **Work:**
  1. Extract 77 draw functions + `DRAW_FN` map + helpers (`globalSeed`, `_monoFontStr`, `_botehBez`, `stampCanvas`, `roundRect`) into one module
  2. Build `netlify/functions/pattern-engine.js` — checks `is_subscriber` + `all-access`, returns the JS or 403
  3. Rewrite 4 consumer files to load it conditionally
  4. **Backfill 7,088 thumbnails first** (see dependency below) so non-members still see patterns
- **Closes:** anonymous access to the engine
- **Does not close:** any paying member can open DevTools and save the bundle. This raises cost; it does not prevent.
- **Watch out:** `generate-thumbs.html` implements **41** of the 77 styles. The other 36 fall through to `drawDiamond`, so a naive backfill would generate *wrong* thumbnails for roughly half the archive. Fixing that gap is part of the work, not a footnote.

### Option 3 — Server-side rendering
The engine never reaches any browser. An edge function renders PNG on demand.

- **Effort:** 1–2 weeks
- **Closes:** the engine, properly — this is the only option that actually withholds it
- **Cost:** needs `node-canvas` or equivalent; the draw functions are pure Canvas2D so they port with little change, but every surface becomes image-based and the members' interactive studio loses its live-recolor speed
- **Realistic shape:** hybrid — server-render for all browsing, keep a client engine inside the gated studio only

---

## Recommended sequence

| Phase | Work | Effort | Unblocks |
|---|---|---|---|
| **0** | Gate the generator page | ~1h | Stops the open door today |
| **1** | Fix `generate-thumbs` style coverage (41 → 77), backfill 7,088 thumbnails | 1–2 days | Everything below |
| **2** | `atlas/17` Section 3B — `patterns_public` view + RLS | ~half day | Row + column gating |
| **3** | Option 2 engine bundle, or Option 3 if you want it properly closed | 2–4 days / 1–2 weeks | — |

Phase 1 is the bottleneck for all of it. Nothing that withholds the engine can ship until non-members have something to look at.

---

## The honest caveat

**No client-side rendering engine can be protected from a paying member.** Options 1 and 2 raise the cost of extraction from "one curl" to "sign up, pay, open DevTools." Only Option 3 genuinely withholds it, and it costs you the interactive experience that makes the studio worth paying for.

Given the licensing line now opening: a **licence agreement with named attribution terms is probably stronger protection than any of the above**, because it makes commercial reuse actionable rather than merely difficult. The technical work should support that posture — watermarked previews, gated clean files, a clear free/paid boundary — rather than trying to win an arms race the architecture can't win.

That is not an argument for doing nothing. It is an argument for doing Phase 0 today, Phase 1 next, and treating Phase 3 as a business decision rather than a security one.

---

## Open questions for you

1. Should `coco-pattern-generator` be **members-only entirely**, or keep a free tier (e.g. the 6 free styles)?
2. Is `patterng.html` the source of the deployed generator? It has 80 draw functions and also **inserts** into `patterns` with the anon key — if it's an internal authoring tool it should not be publicly deployed at all.
3. For the thumbnail backfill: render at what size, and into which storage bucket?
