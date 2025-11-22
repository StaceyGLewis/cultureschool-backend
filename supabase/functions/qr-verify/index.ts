// ---------------------------------------------------------
// QR VERIFY — UNIVERSAL VERIFIER v2
// Pairs with qr-resolve v2
// ---------------------------------------------------------

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// ===== ENV =====
const SB_URL = Deno.env.get("SB_URL");
const SERVICE_KEY = Deno.env.get("SB_SERVICE_ROLE_KEY");

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
// Accept API keys in:
// 1) Authorization Bearer
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
function nowIso() {
  return new Date().toISOString();
}

// ---------------------------------------------------------
// MAIN HANDLER
// ---------------------------------------------------------
Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: cors(req) });
  }

  // 🔐 Extract API key
  const apiKey = extractApiKey(req);
  if (!apiKey) {
    return json(req, { ok: false, error: "missing_api_key" }, 401);
  }

  const supabase = createClient(SB_URL, apiKey);

  try {
    // Accept GET or POST
    let slug = null;
    let token = null;

    if (req.method === "GET") {
      const u = new URL(req.url);
      slug = (u.searchParams.get("slug") || "").trim();
      token = (u.searchParams.get("token") || "").trim();
    } else if (req.method === "POST") {
      const body = await req.json().catch(() => ({}));
      slug = (body.slug || "").trim();
      token = (body.token || "").trim();
    } else {
      return json(req, { ok: false, error: "method_not_allowed" }, 405);
    }

    if (!slug || !token) {
      return json(req, { ok: false, error: "missing_slug_or_token" }, 400);
    }

    // ---------------------------------------------------------
    // 1) Lookup token
    // ---------------------------------------------------------
    const { data: chk, error: chkErr } = await supabase
      .from("qr_checkins")
      .select("*")
      .eq("slug", slug)
      .eq("token", token)
      .order("created_at", { ascending: false })
      .maybeSingle();

    if (chkErr) {
      return json(req, {
        ok: false,
        error: "lookup_error",
        details: chkErr.message,
      }, 500);
    }

    if (!chk) {
      return json(req, {
        ok: false,
        error: "invalid_token",
        reason: "no token match",
      }, 404);
    }

    const now = nowIso();

    // ---------------------------------------------------------
    // 2) EXPIRED?
    // ---------------------------------------------------------
    const expiresAt = chk.expires ?? chk.token_expires_at;
    if (expiresAt && now > expiresAt) {
      // mark expired
      await supabase
        .from("qr_checkins")
        .update({ status: "expired" })
        .eq("id", chk.id);

      return json(req, {
        ok: false,
        error: "expired",
        expired_at: expiresAt,
      }, 410);
    }

    // ---------------------------------------------------------
    // 3) VALID TOKEN → verify
    // ---------------------------------------------------------
    await supabase
      .from("qr_checkins")
      .update({
        status: "verified",
        verified_at: now,
      })
      .eq("id", chk.id);

    // ---------------------------------------------------------
    // 4) Load payloads (OPTIONAL return)
    // ---------------------------------------------------------
    const { data: payloads } = await supabase
      .from("qr_payloads")
      .select("*")
      .eq("slug", slug)
      .or(`user_id.eq.${chk.user_id}`);

    return json(req, {
      ok: true,
      result: "verified",
      slug,
      token,
      payloads: payloads ?? [],
      checkin_id: chk.id,
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
