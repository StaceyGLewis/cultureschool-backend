// supabase/functions/coco-art-approve/index.ts
//
// Approves a coco_art_submission into the live coco_art catalog, doing every
// privileged write with the SERVICE ROLE (bypasses RLS entirely). The browser
// only makes the watermarked preview and posts it here.
//
// Deploy (needs --no-verify-jwt so the browser CORS preflight isn't blocked;
// this function verifies the caller's JWT itself):
//   supabase functions deploy coco-art-approve --no-verify-jwt
//
// SUPABASE_URL / SUPABASE_ANON_KEY / SUPABASE_SERVICE_ROLE_KEY are auto-injected.

import { createClient } from "jsr:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const ANON = Deno.env.get("SUPABASE_ANON_KEY")!;
const SERVICE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const ADMIN_EMAILS = ["stacey.a.grant@gmail.com"];  // who may approve
const ASSETS = "assets";       // private originals
const PREVIEWS = "previews";   // public watermarked previews

function corsHeaders(req: Request): Record<string, string> {
  return {
    "Access-Control-Allow-Origin": req.headers.get("Origin") ?? "*",
    "Access-Control-Allow-Headers": "authorization, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Vary": "Origin",
  };
}
const json = (s: number, b: unknown, c: Record<string, string>) =>
  new Response(JSON.stringify(b), { status: s, headers: { ...c, "Content-Type": "application/json" } });

Deno.serve(async (req) => {
  const cors = corsHeaders(req);
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json(405, { error: "Method not allowed" }, cors);

  try {
    // 1) verify the caller is an admin
    const jwt = (req.headers.get("Authorization") ?? "").replace("Bearer ", "");
    if (!jwt) return json(401, { error: "Not signed in" }, cors);
    const userClient = createClient(SUPABASE_URL, ANON, { global: { headers: { Authorization: `Bearer ${jwt}` } } });
    const { data: { user }, error: uErr } = await userClient.auth.getUser();
    if (uErr || !user) return json(401, { error: "Invalid session" }, cors);
    if (!ADMIN_EMAILS.includes((user.email ?? "").toLowerCase())) return json(403, { error: "Not an admin" }, cors);

    // 2) read the multipart payload (submission id + watermarked preview)
    const form = await req.formData();
    const submissionId = String(form.get("submission_id") ?? "");
    const preview = form.get("preview") as File | null;
    if (!submissionId) return json(400, { error: "Missing submission_id" }, cors);
    if (!preview) return json(400, { error: "Missing preview file" }, cors);

    const admin = createClient(SUPABASE_URL, SERVICE);

    // 3) fetch the submission
    const { data: sub, error: sErr } = await admin
      .from("coco_art_submissions").select("*").eq("id", submissionId).single();
    if (sErr) throw sErr;
    if (!sub) return json(404, { error: "Submission not found" }, cors);

    const newId = crypto.randomUUID();
    const printPath = `originals/${newId}.png`;
    const previewPath = `${newId}.webp`;

    // 4) fetch the original bytes from the submission's public image_url
    const imgResp = await fetch(sub.image_url);
    if (!imgResp.ok) return json(400, { error: `Could not fetch original image (${imgResp.status})` }, cors);
    const originalBytes = new Uint8Array(await imgResp.arrayBuffer());
    const originalCT = imgResp.headers.get("content-type") || "image/png";

    // 5) upload original (private) + preview (public) with the service role
    let up = await admin.storage.from(ASSETS).upload(printPath, originalBytes, { contentType: originalCT, upsert: true });
    if (up.error) throw up.error;

    const previewBytes = new Uint8Array(await preview.arrayBuffer());
    up = await admin.storage.from(PREVIEWS).upload(previewPath, previewBytes, { contentType: preview.type || "image/webp", upsert: true });
    if (up.error) throw up.error;
    const { data: pub } = admin.storage.from(PREVIEWS).getPublicUrl(previewPath);

    // 6) publish into the live catalog
    const { error: iErr } = await admin.from("coco_art").insert([{
      id: newId,
      title: sub.title,
      creator_name: sub.creator_name,
      creator_email: sub.creator_email,
      image_url: pub.publicUrl,
      vibe: sub.vibe ?? null,
      payout_email: sub.payout_email ?? null,
      print_path: printPath,
      is_active: true,
      is_featured: false,
      submitted_at: sub.created_at ?? null,
    }]);
    if (iErr) throw iErr;

    // 7) mark the submission approved
    await admin.from("coco_art_submissions").update({ status: "approved" }).eq("id", submissionId);

    return json(200, { ok: true, id: newId, preview_url: pub.publicUrl }, cors);
  } catch (err) {
    return json(500, { error: (err as Error)?.message ?? "Unexpected error" }, corsHeaders(req));
  }
});
