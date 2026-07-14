# Brief for Claude Code — CultureSchool Atlas (textile provenance layer)

## How to use this (avoid "prompt is too long")
Put these files in the repo, then keep the prompt SHORT and point at them. Do NOT paste them into chat:
- `001_textile_knowledge_graph.sql` (the knowledge graph)
- `002_seed_core.sql` (starter places/concepts)
- `005_atlas_layer.sql` (the Atlas — the new part)
- `dictionary-review-queue.csv` (editorial work list, data only)
- `DATA_GOVERNANCE.md`, `README.md`

Start a fresh session (`/clear`). Read files by path/line-range, not whole-file pastes.

**Do NOT run `004_seed_entries_from_patterns.sql`.** It was written for a superseded architecture. Ignore/delete it.

---

## The goal
Stand up a **cited, reviewed provenance layer** ("the Atlas") that institutions can consume *and contribute to*. This is a credibility asset, not a CRUD app.

**The product is the EDGES, not the definitions.** Any LLM can define "Kente." Nobody has a traversable, cited map of tradition → place → technique → *the thing it's routinely mislabeled as* → our patterns/products. Build accordingly.

## Architecture (decided — do not redesign)
| Layer | What it is | Public? |
|---|---|---|
| **Dictionary** (exists) | every generator style, cultural *and* generic (Grid, Fluid Gradient). A catalog of what the pattern generator makes. Makes **no cultural claim** about generic motifs. | yes (existing) |
| **Atlas** (new — `005`) | only **cited, reviewed** cultural entries, promoted by hand from the Dictionary. Institutions read + contribute here. | published entries only |
| **Sourcing CRM** (`001`, supplier tables) | vendors, MOQs, samples, quotes. Operational. | **NEVER public. NEVER provenance.** |

## ⚠️ The one mistake that would destroy this
**A manufacturing vendor is NOT a tradition-bearer.** `Palm Printing Co` is a digital printer — it is *not* evidence that a wax-resist batik tradition is alive. Never link a `cs_kg_suppliers` row to an Atlas entry as provenance. Practitioners (`cs_atlas_practitioners`) and suppliers (`cs_kg_suppliers`) are separate tables on purpose. Keep the wall.

**Practitioners are ASPIRATIONAL today** — we have zero verified tradition-bearers. Build the tables, seed nothing, publish no practitioner claims. `005` enforces this with a trigger: a practitioner cannot be public without `consent_status='consent_granted'` AND community verification. Do not weaken it.

---

## Tasks

### 0. Audit first — report before changing anything
1. Print the live schema for `patterns` (esp. `heritage_name/origin/region/era`, id type), the existing dictionary table, `palettes`, `coco_art`.
2. List existing tables matching `cs_kg_*` / `cs_atlas_*` — has any of this already been applied?
3. Confirm auth/role model (`anon`, `authenticated`, `service_role`) and whether `coco_personas` roles are in play.
Report findings. **Then** proceed.

### 1. Apply to STAGING only
Run in order: `001` → `002` → `005`. Never blind on production. Back up first.
- `001` creates the knowledge graph + supplier CRM + conservative RLS.
- `005` creates the Atlas: `cs_atlas_entries`, `cs_atlas_practitioners`, `cs_atlas_practice`, `cs_atlas_distinctions`, `cs_atlas_contributions`, the `cs_atlas_public` view, RLS, and the consent trigger.

### 2. Verify the guardrails actually hold (write tests)
- Insert a practitioner with `public_profile_allowed=true` and `consent_status='not_contacted'` → **must raise an exception**.
- Insert an Atlas entry with `source_status='draft'` → **must NOT appear** in `cs_atlas_public`.
- Insert one with `sensitivity_level='sacred_private'` + published → **must NOT appear** in `cs_atlas_public`.
- As `anon`, select from `cs_atlas_practitioners` directly → **must be blocked** by RLS.

### 3. Seed the disambiguation edges (the differentiator — do this by hand, it's small)
Create three Atlas entries (draft) + their `cs_atlas_distinctions` rows. These are known-correct and are the proof of concept for the whole layer:
| Entry | confused_with | correction |
|---|---|---|
| Bargello | "Brazilian" | Florentine counted-thread needlework, Italy — not Brazilian |
| Madras | "Caribbean Carnival" | Handloom checked cotton from South India (Chennai/Madras) |
| T'nalak | "Philippine" (as a style) | T'boli people, Mindanao — a country is not a tradition |

Leave `is_public=false` until a human reviews + cites them.

### 4. Wire the Dictionary → Atlas promotion path
A Dictionary style is **promoted** into the Atlas by a human editorial act (set `dictionary_style`, `entry_id`, write `cultural_context`, attach `cs_kg_sources`, set `reviewed_by`, then `source_status='published'` + `is_public=true`).
Build a minimal internal admin view/query for the promotion queue — do NOT auto-promote anything.

### 5. Report the editorial scope
From `dictionary-review-queue.csv`: 65 traditions → **45 real traditions, 20 generic motifs**; 12 need splitting + sourcing, 33 need citations. Confirm those counts against live data and hand back a work list.

---

## Non-negotiables
- Nothing publishes automatically. `source_status='published'` + `is_public=true` is a human act with a named `reviewed_by`.
- Per `DATA_GOVERNANCE.md`: AI-generated summaries are **drafts**, never published facts.
- Never expose supplier contacts, pricing, risk notes, failed samples, or internal notes.
- Don't touch `palettes`, `patterns`, `coco_art`, `asset_packs`, `entitlements`, or the existing dictionary table. Additive only.
- Don't weaken RLS or the consent trigger.

## Definition of done
`001`+`002`+`005` applied to staging; all four guardrail tests pass; three distinction entries exist as drafts; a promotion query exists; scope report returned.
