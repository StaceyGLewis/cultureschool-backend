# CoCo by CultureSchool — Locked Decisions
*Source of truth. I (Stacey) own and edit this. Paste at the start of a session so Claude anchors to what's settled instead of re-deriving it. If something here is wrong, this doc wins — flag the conflict.*

Last updated: 2026-07-31

---

## Brand & positioning (updated 2026-07-31)
- **The brand is `CoCo by CultureSchool`.** CultureSchool is the parent; CoCo is the product brand users meet.
- **The "bridal proof of concept" framing is RETIRED.** Do not describe CoCo as a wedding/bridal platform or as a bridal POC — we have evolved past it. Comp set is Canva / Adobe Express / Etsy.
- **What CoCo is:** a culturally intelligent color-and-pattern design engine — palettes, patterns, and the textile knowledge behind them — with two doors on every design (buy it made / make it yourself) and now a third (license it).
- **Ethos (unchanged, load-bearing):** *inspired by, credited, never a replacement.* Designs are reminiscent interpretations and starting points — never reproductions, never a replacement for living craft. Every tradition is named and credited.

## Strategy & IP (do not reverse without me saying so)
- **The color-intelligence ENGINE and the named palette/pattern ARCHIVE stay GATED.** The photo→palette tool, the full palette/pattern library, the recolor generator, and idea-reveal surfaces are **not** public front doors — they demonstrate the method / expose the dataset. (Decided 2026-07-04.)
- **Licensing is a PAID channel, not a public door.** Opening a licensing line does not un-gate the archive — licensees pay for access to the dataset. The engine itself is not licensed; the *output* (palettes, patterns) is. See Licensing below.
- **Promotion runs through PUBLIC-SAFE product surfaces only:** Shop by Palette, the product hub, palette-story sections, Shop by Projects, and a maker gallery. These show *finished products*, not the engine.
- **Pricing:** free to explore & shop; **$18/month membership** to create.
- **Choice overload is real:** consumer-facing pickers show **`is_featured` only**, not the whole catalog.

## Licensing — palette & pattern library (NEW, in flight 2026-07-31)
- **We are licensing the palette and pattern library.** This is a new revenue line alongside membership and product.
- Consistent with the gating decision above: licensing is B2B/paid access to the archive, not a free public surface. **Never expose the full library on a public page to support a licensing pitch** — use curated, watermarked, or `is_featured` subsets.
- **[FILL IN]** — licensing model (per-pattern / collection / annual catalog access?)
- **[FILL IN]** — who the target licensees are (brands, manufacturers, publishers, textile mills?)
- **[FILL IN]** — exclusivity posture, term length, territory, price bands
- **[FILL IN]** — attribution requirement for licensees (given the ethos above, tradition credit should travel with the license — confirm this is contractual, not optional)
- **Standing constraint:** clean/print-resolution files stay in the private `assets` bucket and are served only through a gated download path. Licensing must not become a back door around `coco-art-download`.

## Partnerships & institutions
- **Savannah College of Art and Design (SCAD) — Fellowship. PLANNED.** ([FILL IN] — fellowship structure, cohort size, start term, what CoCo provides vs. what SCAD provides, whether student work enters the archive and on what terms.)
  - **Flag for the IP decision above:** if student/fellow work enters the palette or pattern library, settle ownership and licensing rights *before* the fellowship starts, not after.
- **Columbus Fashion Academy** — comp access for the founder to test the maker tools free.
- Institution pipeline (schools, folk schools, universities, guilds, archives, museums, residencies, cooperatives) is tracked in the **Institutions** module of the Intelligence Platform — use it, don't keep a separate list.

## Business model
- Every design has two doors: **Buy it made** | **Make it yourself** (pattern · fabric · kit). Licensing is the emerging third.
- Three front doors, all converging on a design → buy/make: **Shop by Palette**, **Make it Real / Shop by Projects**, the **libraries**.
- **Fulfillment split** (capacity-constrained → POD/dropship only for now):
  - **Contrado-on-Shopify** = finished goods (Buy it made)
  - **Spoonflower** = fabric for makers (Make it → fabric)
  - **Shopify PDF products** = sewing patterns (Make it → pattern); patterns are **generic per project** ("works with any fabric") — story lives in the browse/Dictionary
  - Printful available; **DTF transfers = the next frontier** (full-color, applies to existing textiles, white-label dropship, zero inventory) — pursue after current tightening.

## Tech / data
- Supabase project `qwulthvbwujfehgdegtn`. **Auth = magic-link; email is the identity + the join key to Shopify.**
- **Deployment: files are dropped directly into Netlify.** The git repo is the working copy and the record — it is not the deploy pipeline. A committed file is not necessarily what's live, and a live file is not necessarily committed. Check both.
- **entitlements** table (row-per-grant): `product ∈ (board|membership|pack)`, `board_id`, `pack_id` (plain uuid, no FK), `email`, `expires_at`. Partial unique index = one membership per email.
  - **Membership** = ongoing all-access (premium — **don't dilute**). Handled by existing **`shopify-membership`** function; `grant_membership` param is **`p_expires`** — **do not rename**.
  - **One-time tool pass** = a `pack` row (`pack_id` + `expires_at`, e.g. **48h**). Patch pass id = `6b7f1d2a-3c4e-4f50-9a6b-1c2d3e4f5a6b`.
  - Gate fns are **email-param** (`has_all_access(email)`, `owns_pack(email,pack_id)`, `can_use_patch_studio(email)`) because `auth.jwt()` is null in Edge Functions; locked to `service_role`.
- **coco_art** = productized textiles. `image_url` = **watermarked preview** (public use). `print_path` = **clean original** in private `assets` bucket, served **only** via gated **`coco-art-download`** (checks entitlement). `is_active=true` = public; `is_featured=true` = curated.
- **Composite mockup technique** (shop coco): design image → `multiply` → `destination-in` mask onto a real transparent product-mockup PNG. Reused across Make it Real.
- **Studio pattern** (patch studio = the template): Netlify static page → magic-link sign-in → gated `coco-art-download` for the clean file → client-side compose → PDF. Gate = members **OR** valid one-time pass.

### Supabase RLS — hard-won rules (added 2026-07-29)
- **`anon` and `authenticated` are different roles and need separate policies.** Any surface with magic-link sign-in queries as `authenticated`. A table with only `{anon}` policies returns **status 200 + empty array + no error** to a signed-in user — silent, and it looks like a code bug. This cost a full session on `cs_field_logs`.
- **Grant ≠ policy.** With RLS on, a table-level GRANT alone does nothing; a matching PERMISSIVE policy is required. Deny-by-default wins.
- **Views created in the Supabase UI are SECURITY DEFINER by default** and bypass RLS. Set `security_invoker = on`. Applied to all flagged views via `atlas/16-fix-security-definer-views.sql` (run 2026-07-29).
- Migration history lives in `atlas/*.sql`, numbered 01→16.

## Tools & surfaces that already exist (don't reinvent, don't default to a generic equivalent)
- **Intelligence Platform / Textile Atlas** (`intelligence-platform.html`) — **the internal command center. Built July 2026. Check here before proposing any new internal tool.** Modules: Dashboard (live `cs_events` telemetry), Textile Atlas (search-first knowledge traversal), Knowledge Graph (places ↔ concepts ↔ sources), Supplier CRM, Creator CRM, Museum Library, **Institutions**, Event Planner, Trend Observatory, **Maker Network**, **Field Logs**. Magic-link gated, admin-only.
- **Telemetry layer** — `cs-track.js` inlined across the CoCo surfaces, writing to `cs_events`; `cs_dash_*` views feed the Dashboard. Search terms with no Atlas entry are flagged as content gaps with one-click draft creation.
- **Field Log / Field Read** (`field-read.cultureschool.org`) — field research capture: photo corpus → palette + heritage signals + Atlas matches, saved to `cs_field_logs`. Corpus Trends panel aggregates recurring colors and signals across logs.
- **CoCo Print Studio** (`coco-print-studio`) — pattern/surface-design creation studio (Templates, Palette, Scatter, Shapes, Text) + product-scaled export (pillow/tote/napkin) + a guided **Make Mode** 8-to-88 lane. The maker tool. *(Not a place to bolt on a second "maker studio.")*
- **Flourish / CoCo** (`flourish-ultimate`) — **color-intelligent template studio.** Editable templates for **invites, signage, landing pages**; a **Color Planner** (upload image → extract palette → apply to any template); recolors via palette variables from the Supabase library. Export = **HTML / PNG** (confirm if print-PDF exists). **This is our Canva — never recommend Canva.**
- **Patch Studio** (`patch-studio`) — gated, one-time-pass printable iron-on patch tool.
- **Daily Inspo** (`coco-daily-inspo`) — maker gallery; **users can submit** their finished pieces (the share/flywheel step).
- **coco-palettes** (`coco-palettes.cultureschool.org`) — community palette library, the social layer. `?id=xxx` = single palette view.
- **The Color Journal** blog, **Shop by Projects**, **Shop by Palette**, the **Pattern Dictionary / textile library**, **color-stories** — public-safe product/discovery surfaces.
- **Community Moment Kits** — productized gatherings that *curate the above*; see the kit spec.

## Anti-abuse (done)
- Bots/card-testers removed (James Anderson ring, jaysshopifybot, storebotmail). Defenses live: CAPTCHA, Flow interceptor, require-login-at-checkout, data-erasure for order-linked accounts. **Only paid orders grant entitlement**, so bots get nothing.

## Working agreements
- **Claude checks past chats / this doc before making strategic recommendations** — no re-deriving settled calls.
- When Claude builds against my stack, it **audits what already exists first** (avoid double-builds). Same brief pattern for Claude Code.
- **Ask to see the existing working code before guessing at an implementation.** I know my own systems.
- **Never write to Supabase without showing the exact before/after first and getting explicit confirmation.** One row at a time for anything touching `viewers` or `asset_files`.
- Memory feature is **off** by my choice in claude.ai; this doc is the anchor instead. *(Note: Claude Code has project memory enabled in `cultureschool-backend` — if that should also be off, say so and it gets deleted.)*

## Open / in flight
- **Licensing the palette & pattern library** — model, targets, and terms to be settled (see Licensing above).
- **SCAD Fellowship** — planned; structure and IP terms to be settled before it starts.
- Shopify → Supabase entitlement webhook + `coco-art-download` gate (with Claude Code).
- Community Moment Kits: **production split** — invites/signage = **Flourish** templates (palette auto-themed); games/bingo/cards = **print PDF** (must print in a stack, 8.5×11 & 5×7); craft = **Patch Studio**; textiles = **Spoonflower**. (The tote/pillow/napkin "panel studio" idea was retired — CoCo Print Studio already does product-scaled export.)
- Comp access for **Columbus Fashion Academy** founder to test the maker tools free.

## Recently closed
- ✅ Field Logs module — built, RLS fixed (`authenticated` policies), delete function working, deployed. (2026-07-31)
- ✅ Security-definer views patched across the intelligence layer. (2026-07-29)
- ✅ Telemetry layer live across CoCo surfaces; Dashboard reading real events. (2026-07-15)
