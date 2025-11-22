// ---------------------------------------------------------
// QR RESOLVE — UNIVERSAL RESOLVER v2
// Patched for:
//  • browser testing
//  • querystring auth
//  • safer CORS
//  • stable payload lookup
// ---------------------------------------------------------

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// ===== ENV =====
const SB_URL = Deno.env.get("SB_URL");
const SERVICE_ROLE = Deno.env.get("SB_SERVICE_ROLE_KEY");

// ===== CORS =====
const ALLOW_ORIGINS = new Set([
  "https://cocoqr.netlify.app",
  "https://www.cultureschool.org",
  "https://theme-viewer.netlify.app",
  "https://coco-public-profile.netlify.app",
  "http://localhost:5173",
  "http://localhost:3000"
]);

function cors(req: Request) {
  const origin = req.headers.get("origin") ?? "";
  const allow = ALLOW_ORIGINS.has(origin)
    ? origin
    : "https://cocoqr.netlify.app";

  return {
    "Access-Control-Allow-Origin": allow,
    "Vary": "Origin",
    "Access-Control-Allow-Headers":
      "authorization, apikey, content-type, x-client-info",
    "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
  };
}

function json(req: Request, data: any, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      ...cors(req),
      "Content-Type": "application/json",
    },
  });
}

// ---------------------------------------------------------
// Extract API key from:
// 1) Authorization: Bearer xxx
// 2) apikey header
// 3) ?apikey=
// ---------------------------------------------------------
function extractApiKey(req: Request) {
  const auth = req.headers.get("authorization");
  if (auth && auth.startsWith("Bearer ")) {
    return auth.replace("Bearer ", "").trim();
  }

  const headerKey = req.headers.get("apikey");
  if (headerKey) return headerKey.trim();

  const url = new URL(req.url);
  const qsKey = url.searchParams.get("apikey");
  if (qsKey) return qsKey.trim();

  return null;
}

// ---------------------------------------------------------
// Helper
// ---------------------------------------------------------
function nowIso() {
  return new Date().toISOString();
}

// ---------------------------------------------------------
// MAIN HANDLER
// ---------------------------------------------------------
Deno.serve(async (req)=>{
  // Preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: corsHeaders(req)
    });
  }

  // ----- AUTH PATCH -----
  // Ensure Supabase client ALWAYS has an Authorization header
  let auth = req.headers.get("authorization");
  if (!auth) {
    auth = `Bearer ${Deno.env.get("SB_ANON_KEY")}`;
  }

  // Initialize supabase client with this auth header
  const supabase = createClient(
    Deno.env.get("SB_URL"),
    auth.includes("service_role") 
      ? Deno.env.get("SB_SERVICE_ROLE_KEY")
      : Deno.env.get("SB_ANON_KEY"),
    {
      global: { headers: { Authorization: auth } }
    }
  );

 


  try {
    // Accept GET or POST
    let slug: string | null = null;
    let partner: string | null = null;

    if (req.method === "GET") {
      const u = new URL(req.url);
      slug = (u.searchParams.get("slug") || "").trim();
      partner = u.searchParams.get("partner");
    } else if (req.method === "POST") {
      const body = await req.json().catch(() => ({}));
      slug = (body.slug || "").trim();
      partner = body.partner ?? null;
    } else {
      return json(req, { ok: false, error: "method_not_allowed" }, 405);
    }

    if (!slug) {
      return json(req, { ok: false, error: "missing_slug" }, 400);
    }

    // ---------------------------------------------------------
    // 1) Resolve QR → user_id
    // ---------------------------------------------------------
    const { data: qrRow, error: qrErr } = await supabase
      .from("user_qr_codes")
      .select("user_id")
      .eq("qr_slug", slug)
      .maybeSingle();

    if (qrErr) {
      return json(req, {
        ok: false,
        error: "qr_lookup_error",
        details: qrErr.message,
      }, 500);
    }

    if (!qrRow?.user_id) {
      return json(req, { ok: false, error: "not_found" }, 404);
    }

    const user_id = qrRow.user_id;

    // ---------------------------------------------------------
    // 2) Active payloads
    // ---------------------------------------------------------
    const now = nowIso();

    const { data: payloads, error: pErr } = await supabase
      .from("qr_payloads")
      .select("*")
      .eq("user_id", user_id)
      .lte("starts_at", now)
      .or(`ends_at.is.null,ends_at.gte.${now}`)
      .order("priority", { ascending: false })
      .order("starts_at", { ascending: false });

    if (pErr) {
      console.warn("payload error", pErr);
    }

    // ---------------------------------------------------------
    // 3) Issue temporary check-in token (3 min)
    // ---------------------------------------------------------
    const token = crypto.randomUUID().slice(0, 8).toUpperCase();
    const expiresIso = new Date(Date.now() + 3 * 60 * 1000).toISOString();

    const insertRow = {
      slug,
      qr_slug: slug,
      token,
      partner_id: partner,
      status: "pending",
      expires: expiresIso,
      token_expires_at: expiresIso,
    };

    const { error: insErr } = await supabase
      .from("qr_checkins")
      .insert(insertRow);

    if (insErr) {
      console.warn("checkin insert error", insErr);
    }

    // ---------------------------------------------------------
    // 4) Response
    // ---------------------------------------------------------
    return json(req, {
      ok: true,
      slug,
      payloads: payloads ?? [],
      checkin: {
        token,
        expires: expiresIso,
      },
    });

  } catch (err) {
    console.error(err);
    return json(req, {
      ok: false,
      error: "exception",
      details: String(err),
    }, 500);
  }
});
