// supabase/functions/school-upload/index.ts
//
// The only way a student's print reaches storage.
//
// A student has no account and no JWT, so a storage RLS policy has
// nothing to check them against. This function is the substitute: it
// validates the session token against the database, asks the database
// where that student's file is ALLOWED to go, and writes to exactly
// that path with the service role. The client never supplies a path,
// so it cannot aim a file at another class or another student.
//
// POST { session_token, brief_id, image (data URL or base64), credits? }
//   -> { path, signed_url }
//
// POST { session_token, note_id, image }          a field-note photograph
// POST { session_token, brief_id, mode:"read" }   re-sign a student's own print
// POST { session_token, note_id,  mode:"read" }   re-sign a note photograph
//
// POST { handoff, image }   Print Studio sending a finished print straight
//   back to the assignment. The handoff token replaces the session token
//   entirely: it can attach one image to one brief, once, within four
//   hours, and can read nothing. That is what makes it safe to put in a
//   URL when the session token never could be.
//
// GET-style read is handled by the "class-works teacher read" policy in
// docs/school-mode-storage.sql; students get the signed URL returned here.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "content-type, authorization, apikey",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, "content-type": "application/json" },
  });

// 8 MB ceiling matches the bucket's file_size_limit. Checked before the
// base64 is decoded so a hostile payload cannot make us allocate first.
const MAX_BYTES = 8 * 1024 * 1024;
const ALLOWED = new Set(["image/jpeg", "image/png", "image/webp"]);

/* One decoder for every path, so a size or type rule can never be
   enforced on one route and forgotten on another. */
function decodeImage(image: string):
  { bytes: Uint8Array; type: string } | { error: string; status: number } {
  let contentType = "image/jpeg";
  let b64 = image;
  const m = /^data:([^;,]+);base64,(.*)$/s.exec(image);
  if (m) { contentType = m[1].toLowerCase(); b64 = m[2]; }
  if (!ALLOWED.has(contentType)) {
    return { error: `unsupported type ${contentType}`, status: 415 };
  }
  if (b64.length * 0.75 > MAX_BYTES) return { error: "image too large", status: 413 };
  let bytes: Uint8Array;
  try {
    const bin = atob(b64);
    bytes = new Uint8Array(bin.length);
    for (let i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
  } catch { return { error: "image is not valid base64", status: 400 }; }
  if (bytes.byteLength === 0) return { error: "image is empty", status: 400 };
  if (bytes.byteLength > MAX_BYTES) return { error: "image too large", status: 413 };
  return { bytes, type: contentType };
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  try {
    const { session_token, brief_id, note_id, image, credits, mode, handoff } =
      await req.json();

    const url_ = Deno.env.get("SUPABASE_URL")!;
    const anon_ = Deno.env.get("SUPABASE_ANON_KEY")!;
    const service_ = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

    // ── handoff from Print Studio ─────────────────────────────────────
    // Deliberately before the session_token check: a handoff carries its
    // own authorisation and there is no session in this request at all.
    if (typeof handoff === "string" && handoff.length > 0) {
      if (!image || typeof image !== "string") {
        return json({ error: "image required" }, 400);
      }
      const bytes0 = decodeImage(image);
      if ("error" in bytes0) return json({ error: bytes0.error }, bytes0.status);

      const asAnon = createClient(url_, anon_);
      const { data: t, error: te } = await asAnon.rpc("school_handoff_target",
        { p_token: handoff });
      if (te || !t?.path) return json({ error: "handoff not valid" }, 403);

      const admin1 = createClient(url_, service_);
      const { error: ue } = await admin1.storage
        .from(t.bucket ?? "class-works")
        .upload(t.path, bytes0.bytes, { contentType: bytes0.type, upsert: true });
      if (ue) return json({ error: ue.message }, 500);

      // Spending the token is the last step, so a failed upload can be retried.
      const { error: ce } = await asAnon.rpc("school_handoff_complete",
        { p_token: handoff, p_path: t.path });
      if (ce) return json({ error: ce.message }, 500);

      return json({ ok: true, brief_id: t.brief_id });
    }

    if (!session_token || typeof session_token !== "string") {
      return json({ error: "session_token required" }, 400);
    }
    // Exactly one target: a brief's finished print, or a note's photograph.
    const isNote = typeof note_id === "string" && note_id.length > 0;
    if (!isNote && (!brief_id || typeof brief_id !== "string")) {
      return json({ error: "brief_id or note_id required" }, 400);
    }

    // Ask the database where this student is allowed to write. Either
    // path is DERIVED from their own membership, never supplied, so a
    // file cannot be aimed at another class, member, brief or note.
    const targetFor = async (client: ReturnType<typeof createClient>) =>
      isNote
        ? client.rpc("school_note_target",
            { p_session: session_token, p_note: note_id })
        : client.rpc("school_upload_target",
            { p_session: session_token, p_brief: brief_id });

    // ── read mode ─────────────────────────────────────────────────────
    // A student is anon and cannot sign a storage URL themselves. This
    // re-issues one for their OWN file, using that same derived path.
    if (mode === "read") {
      const asStudent0 = createClient(url_, anon_);
      const { data: t0, error: e0 } = await targetFor(asStudent0);
      if (e0 || !t0?.path) return json({ error: "not authorised" }, 403);
      const admin0 = createClient(url_, service_);
      const { data: s0 } = await admin0.storage
        .from(t0.bucket ?? "class-works")
        .createSignedUrl(t0.path, 60 * 60 * 8);
      return json({ path: t0.path, signed_url: s0?.signedUrl ?? null });
    }

    if (!image || typeof image !== "string") {
      return json({ error: "image required" }, 400);
    }

    // ── decode ────────────────────────────────────────────────────────
    const dec = decodeImage(image);
    if ("error" in dec) return json({ error: dec.error }, dec.status);
    const bytes = dec.bytes, contentType = dec.type;

    const url = url_, anon = anon_, service = service_;

    // ── 1. Ask the database where this student may write ──────────────
    // Called with the ANON key on purpose: school_upload_target validates
    // the session token itself, and using anon here means a stolen
    // service key is not what stands between classes.
    const asStudent = createClient(url, anon);
    const { data: target, error: targetErr } = await targetFor(asStudent);
    if (targetErr || !target?.path) {
      // Same response for a bad token, an unknown brief and someone
      // else's note, so this cannot be used to enumerate any of them.
      return json({ error: "not authorised" }, 403);
    }

    // ── 2. Write to exactly that path, service role ───────────────────
    const admin = createClient(url, service);
    const { error: upErr } = await admin.storage
      .from(target.bucket ?? "class-works")
      .upload(target.path, bytes, { contentType, upsert: true });
    if (upErr) return json({ error: upErr.message }, 500);

    // ── 3. Record it ──────────────────────────────────────────────────
    if (isNote) {
      const { error: noteErr } = await asStudent.rpc("school_note_photo", {
        p_session: session_token, p_note: note_id, p_path: target.path,
      });
      if (noteErr) return json({ error: noteErr.message }, 500);
      // school_note_photo writes its own receipt.
    } else {
      const { error: saveErr } = await asStudent.rpc("school_save_work", {
        p_session: session_token,
        p_brief: brief_id,
        p_statement: null,
        p_image_path: target.path,
        p_credits: Array.isArray(credits) ? credits.slice(0, 12) : null,
      });
      if (saveErr) return json({ error: saveErr.message }, 500);

      await asStudent.rpc("school_log", {
        p_session: session_token,
        p_kind: "attach",
        p_detail: `${Math.round(bytes.byteLength / 1024)}KB`,
      });
    }

    // ── 4. Hand back a short-lived read URL for the student's own view ─
    const { data: signed } = await admin.storage
      .from(target.bucket ?? "class-works")
      .createSignedUrl(target.path, 60 * 60 * 8); // one school day

    return json({ path: target.path, signed_url: signed?.signedUrl ?? null });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
