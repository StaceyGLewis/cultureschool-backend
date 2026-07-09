// supabase/functions/coco-art-download/index.ts
//
// Membership-gated download for coco_art print-ready originals.
// Matches your EXISTING public.entitlements table by EMAIL via has_art_access().
// Current rule: an active `membership` grants download of ANY design.
//
// Deploy (the --no-verify-jwt flag lets the browser CORS preflight through;
// this function still verifies the user's JWT itself, so nothing is weakened):
//   supabase functions deploy coco-art-download --no-verify-jwt
//
// The service role key is auto-injected and never leaves the server; the
// browser only ever receives a short-lived signed URL, and only if the caller
// has access.

import { createClient } from "jsr:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const BUCKET = "assets";
const TTL = 60; // signed-URL lifetime, seconds

// Any of your own origins may call this. Add more here if you serve the page
// from another host later.
const ALLOWED_ORIGINS = new Set<string>([
  "https://coco-textile-library.cultureschool.org",
  "https://patch-studio.cultureschool.org",
  "https://cultureschool.org",
  "https://www.cultureschool.org",
]);
const DEFAULT_ORIGIN = "https://coco-textile-library.cultureschool.org";
const PATCH_STUDIO_ORIGIN = "https://patch-studio.cultureschool.org";

function corsHeaders(req: Request): Record<string, string> {
  const origin = req.headers.get("Origin") ?? "";
  return {
    "Access-Control-Allow-Origin": ALLOWED_ORIGINS.has(origin) ? origin : DEFAULT_ORIGIN,
    "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Vary": "Origin", // so caches don't serve one origin's header to another
  };
}
const json = (status: number, body: unknown, cors: Record<string, string>) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });

Deno.serve(async (req) => {
  const cors = corsHeaders(req);
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json(405, { error: "Method not allowed" }, cors);

  try {
    // --- 1) identify the caller (and their email) from the JWT ---
    const jwt = (req.headers.get("Authorization") ?? "").replace("Bearer ", "");
    if (!jwt) return json(401, { error: "Not signed in" }, cors);

    const userClient = createClient(SUPABASE_URL, ANON_KEY, {
      global: { headers: { Authorization: `Bearer ${jwt}` } },
    });
    const { data: { user }, error: userErr } = await userClient.auth.getUser();
    if (userErr || !user?.email) return json(401, { error: "Invalid session" }, cors);

    const { art_id } = await req.json().catch(() => ({}));
    if (!art_id) return json(400, { error: "Missing art_id" }, cors);

    // --- 2) service-role client for the gated checks (bypasses RLS) ---
    const admin = createClient(SUPABASE_URL, SERVICE_KEY);

    // Gate: patch studio allows membership OR a valid 48h patch pass;
    // textile library requires a membership (has_art_access).
    const origin = req.headers.get("Origin") ?? "";
    let allowed: boolean;
    if (origin === PATCH_STUDIO_ORIGIN) {
      const { data, error: accErr } = await admin.rpc("can_use_patch_studio", { p_email: user.email });
      if (accErr) throw accErr;
      allowed = !!data;
    } else {
      const { data, error: accErr } = await admin.rpc("has_art_access", { p_email: user.email, p_art_id: art_id });
      if (accErr) throw accErr;
      allowed = !!data;
    }
    if (!allowed) return json(403, { error: "No active membership" }, cors);

    // --- 3) resolve the private path and sign it ---
    const { data: art, error: artErr } = await admin
      .from("coco_art").select("print_path, title").eq("id", art_id).single();
    if (artErr) throw artErr;
    if (!art?.print_path) return json(404, { error: "No print file for this design" }, cors);

    const { data: signed, error: signErr } = await admin
      .storage.from(BUCKET).createSignedUrl(art.print_path, TTL, { download: true });
    if (signErr) throw signErr;

    return json(200, { url: signed.signedUrl, title: art.title }, cors);
  } catch (err) {
    return json(500, { error: (err as Error)?.message ?? "Unexpected error" }, cors);
  }
});
