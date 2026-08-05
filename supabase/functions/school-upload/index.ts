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

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  try {
    const { session_token, brief_id, image, credits, mode } = await req.json();

    if (!session_token || typeof session_token !== "string") {
      return json({ error: "session_token required" }, 400);
    }
    if (!brief_id || typeof brief_id !== "string") {
      return json({ error: "brief_id required" }, 400);
    }

    const url_ = Deno.env.get("SUPABASE_URL")!;
    const anon_ = Deno.env.get("SUPABASE_ANON_KEY")!;
    const service_ = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

    // ── read mode ─────────────────────────────────────────────────────
    // A student is anon and cannot sign a storage URL themselves. This
    // re-issues one for their OWN work after a reload, using the same
    // derived path — so it can only ever hand back their own file.
    if (mode === "read") {
      const asStudent0 = createClient(url_, anon_);
      const { data: t0, error: e0 } = await asStudent0.rpc(
        "school_upload_target",
        { p_session: session_token, p_brief: brief_id },
      );
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
    let contentType = "image/jpeg";
    let b64 = image;
    const m = /^data:([^;,]+);base64,(.*)$/s.exec(image);
    if (m) {
      contentType = m[1].toLowerCase();
      b64 = m[2];
    }
    if (!ALLOWED.has(contentType)) {
      return json({ error: `unsupported type ${contentType}` }, 415);
    }
    // base64 is ~4/3 of the bytes it encodes; reject before decoding.
    if (b64.length * 0.75 > MAX_BYTES) {
      return json({ error: "image too large" }, 413);
    }

    let bytes: Uint8Array;
    try {
      const bin = atob(b64);
      bytes = new Uint8Array(bin.length);
      for (let i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
    } catch {
      return json({ error: "image is not valid base64" }, 400);
    }
    if (bytes.byteLength === 0) return json({ error: "image is empty" }, 400);
    if (bytes.byteLength > MAX_BYTES) return json({ error: "image too large" }, 413);

    const url = url_, anon = anon_, service = service_;

    // ── 1. Ask the database where this student may write ──────────────
    // Called with the ANON key on purpose: school_upload_target validates
    // the session token itself, and using anon here means a stolen
    // service key is not what stands between classes.
    const asStudent = createClient(url, anon);
    const { data: target, error: targetErr } = await asStudent.rpc(
      "school_upload_target",
      { p_session: session_token, p_brief: brief_id },
    );
    if (targetErr || !target?.path) {
      // Same response for a bad token and an unknown brief, so this
      // cannot be used to enumerate either.
      return json({ error: "not authorised for this brief" }, 403);
    }

    // ── 2. Write to exactly that path, service role ───────────────────
    const admin = createClient(url, service);
    const { error: upErr } = await admin.storage
      .from(target.bucket ?? "class-works")
      .upload(target.path, bytes, { contentType, upsert: true });
    if (upErr) return json({ error: upErr.message }, 500);

    // ── 3. Record it against the work ─────────────────────────────────
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

    // ── 4. Hand back a short-lived read URL for the student's own view ─
    const { data: signed } = await admin.storage
      .from(target.bucket ?? "class-works")
      .createSignedUrl(target.path, 60 * 60 * 8); // one school day

    return json({ path: target.path, signed_url: signed?.signedUrl ?? null });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
