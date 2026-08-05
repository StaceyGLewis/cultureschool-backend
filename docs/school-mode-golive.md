# School Mode — what stands between the prototype and a real classroom

Written 2026-08-05. Everything below is either done, or a discrete piece
of work with a named owner-decision inside it. Nothing here has been run
against production.

## Done

| | |
|---|---|
| The prototype | `dist/school.html` — teacher + student, three briefs, live archive, process receipts. Works today on localStorage. |
| Tables | `docs/school-mode.sql` — six tables, RLS on, no permissive policy |
| Access layer | `docs/school-mode-rpc.sql` — session tokens, teacher scoping, server-side turn-in floor. **42 assertions pass** |
| Storage | `docs/school-mode-storage.sql` — private `class-works` bucket, teacher-read policy. **20 assertions pass** |
| Upload path | `supabase/functions/school-upload/index.ts` — the only way a print reaches the bucket |

All SQL was validated by executing it against a throwaway Postgres 15,
not by reading it. Test files and run instructions are beside each.

## Step 1 — apply the SQL, in this order

```
docs/school-mode.sql          tables
docs/school-mode-rpc.sql      functions + grants
docs/school-mode-storage.sql  bucket + policy
```

Each is additive and idempotent. **Answering your question directly: yes,
add the bucket — but `school-mode-storage.sql` creates it for you with
the right settings.** Creating it by hand in the dashboard risks a public
bucket, which is the single thing that would sink a district review.

Verify blocks are at the bottom of each file. The one that matters:

```sql
select id, public from storage.buckets where id = 'class-works';
-- public MUST be false
```

## Step 2 — deploy the upload function

```
supabase functions deploy school-upload
```

It needs `SUPABASE_URL`, `SUPABASE_ANON_KEY` and
`SUPABASE_SERVICE_ROLE_KEY` in the function environment. It follows the
same shape as the existing `host-image` function.

Why a function at all: a student has no account and no JWT, so a storage
policy has nothing to check them against. The function validates the
session token, asks the database where that student's file is *allowed*
to go, and writes to exactly that path with the service role. The client
never supplies a path.

## Step 3 — teacher sign-in must become real  ← the blocking one

`dist/school.html` currently takes a teacher's word for who they are: an
email box, no password. Every teacher RPC keys off `auth.jwt()->>'email'`,
so **until this is magic-link, the teacher surface will refuse every
call.** This is the one item that cannot be deferred — the prototype's
weakest part is load-bearing in production.

Supabase magic-link, the same pattern `my-world.html` already uses:

```js
await sb.auth.signInWithOtp({ email, options:{ emailRedirectTo: location.href }});
```

**Decision needed:** should any email be able to create a class, or only
addresses on a school domain you have licensed? A pilot can accept any;
a paid tier probably cannot. `school_orgs.license_status` exists for
this and is currently unused.

## Step 4 — swap the client's Store for RPC calls

`dist/school.html` isolates all persistence in one `Store` object
(~40 lines). The mapping is one-to-one:

| Store method | RPC |
|---|---|
| `addMember` / join flow | `school_join` |
| `classById` + `works` (student) | `school_state` |
| `updWork` (draft) | `school_save_work` |
| submit | `school_submit` |
| `log` | `school_log` |
| attach | `school-upload` function |
| `classes(teacher)` | `school_teacher_classes` |
| `addClass` | `school_create_class` |
| `updClass({assigned})` | `school_set_assigned` |
| `members` | `school_roster` |
| gallery | `school_gallery` |
| `openWork` detail | `school_work_detail` |
| `resetMember` | `school_reset_member` |

Keep the localStorage path behind a flag. A showroom laptop with no wifi
should still demo.

## Step 5 — put it on a domain

`netlify.toml` already routes the other surfaces. School Mode wants its
own entry point rather than a path on the consumer site — the brief's
mode-isolation call, and it also keeps a classroom URL out of a
teenager's browser history alongside the shop.

```toml
[[redirects]]
  from = "https://coco-school.cultureschool.org/*"
  to   = "/school"
  status = 200
```

## Still open, in priority order

1. **Teacher domain policy** (step 3) — who may create a class.
2. **Retention.** Nothing purges works, receipts or objects. A district
   will ask. A defensible default is end-of-school-year deletion unless
   the teacher exports first; the sketch is at the foot of
   `school-mode-storage.sql`. **This belongs in the licence agreement in
   words before it belongs in SQL.**
3. **Brief 03 has no archive backing.** No improvisational-quilt style
   exists — `gee` only matches *Muscogee*. It ships as compose-freely and
   says so, which is honest, but a Gee's Bend-adjacent style would make
   the set complete.
4. **VA.912 benchmarks are placeholders.** Brief 02 cites "VA.912
   organizational-structure equivalents" and Brief 03 cites a strand, not
   a benchmark. Middle-school VA.68.* codes are real and specific. The
   pitch is middle **and** high school, so this gap is visible to any
   curriculum reviewer.
5. **Atlas.** Briefs reference "the CultureSchool Atlas" as the citable
   source. No `atlas_*` table exists. For a Spring 2027 prototype the
   inline tradition text carries it; for release it needs the real thing.
6. **No teacher export.** A class gallery cannot be saved as a PDF yet.
   `tools/lookbook/build.js` already renders print-ready sheets from
   data — the same approach would work here.

## What a teacher sees today, honestly

**Shows well:** the whole loop — code on the board, students in within
seconds with no accounts, the brief with real archive patterns and their
credits, the turn-in gate that will not accept an unfinished statement,
and the gallery with process receipts beside each piece.

**Does not show yet:** work syncing between devices, teacher sign-in that
means anything, or a PDF at the end. Say so plainly in the room — the
demo is strong enough that overclaiming would be the only way to lose it.
