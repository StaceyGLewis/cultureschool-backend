
// in qr-resolve/index.ts and qr-verify/index.ts
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
const url = Deno.env.get("SB_URL");
const serviceKey = Deno.env.get("SB_SERVICE_ROLE_KEY");
const supabase = createClient(url, serviceKey);
// --- CORS ---
const ALLOW_ORIGINS = new Set([
  "https://cocoqr.netlify.app",
  "https://www.cultureschool.org",
  "http://localhost:5173",
  "http://localhost:3000"
]);
function corsHeaders(req) {
  const origin = req.headers.get("origin") ?? "";
  const allow = ALLOW_ORIGINS.has(origin) ? origin : "https://cocoqr.netlify.app";
  return {
    "Access-Control-Allow-Origin": allow,
    "Vary": "Origin",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "GET, POST, OPTIONS"
  };
}
function json(req, data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      ...corsHeaders(req),
      "Content-Type": "application/json"
    }
  });
}
function nowIso() {
  return new Date().toISOString();
}
Deno.serve(async (req)=>{
  // Preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: corsHeaders(req)
    });
  }
  try {
    // Accept GET ?slug&partner=... or POST {slug, partner}
    let slug = null;
    let partner = null;
    if (req.method === "GET") {
      const u = new URL(req.url);
      slug = (u.searchParams.get("slug") || "").trim();
      partner = u.searchParams.get("partner");
    } else if (req.method === "POST") {
      const body = await req.json().catch(()=>({}));
      slug = (body.slug || "").trim();
      partner = body.partner ?? null;
    } else {
      return json(req, {
        ok: false,
        error: "method_not_allowed"
      }, 405);
    }
    if (!slug) {
      return json(req, {
        ok: false,
        reason: "missing_slug"
      }, 400);
    }
    // 1) Lookup QR owner (user id) from user_qr_codes
    const { data: qrRow, error: qrErr } = await supabase.from("user_qr_codes").select("user_id").eq("qr_slug", slug).maybeSingle();
    if (qrErr) {
      return json(req, {
        ok: false,
        error: "qr_lookup_error",
        details: qrErr.message
      }, 500);
    }
    if (!qrRow?.user_id) {
      return json(req, {
        ok: false,
        reason: "not_found"
      }, 404);
    }
    const user_id = qrRow.user_id;
    // 2) Load active payloads for this user, time-windowed
    //    active if starts_at <= now AND (ends_at is null OR ends_at >= now)
    const now = nowIso();
    const { data: payloads, error: pErr } = await supabase.from("qr_payloads").select("*").eq("user_id", user_id).lte("starts_at", now).or(`ends_at.is.null,ends_at.gte.${now}`) // order safely without requiring "priority" to exist in schema
    .order("starts_at", {
      ascending: true
    }).order("created_at", {
      ascending: false
    });
    if (pErr) {
      // Don’t fail the whole request — just return no perks
      console.warn("payloads error", pErr);
    }
    // 3) Create a short-lived check-in token (3 minutes)
    const token = crypto.randomUUID().slice(0, 8).replace(/-/g, "").toUpperCase(); // short readable
    const expiresIso = new Date(Date.now() + 3 * 60 * 1000).toISOString();
    // Insert into qr_checkins; be tolerant to schema variants:
    //  - some schemas have qr_slug (NOT NULL), some also have slug
    //  - some call expiry column "expires", others "token_expires_at"
    const insertRow = {
      qr_slug: slug,
      slug,
      token,
      status: "pending",
      partner_id: partner ?? null,
      // add both names; the one that exists will be used:
      expires: expiresIso,
      token_expires_at: expiresIso
    };
    const { error: insErr } = await supabase.from("qr_checkins").insert(insertRow);
    if (insErr) {
      // Still return perks, but warn about token generation
      console.warn("checkin insert error", insErr);
    }
    return json(req, {
      ok: true,
      slug,
      payloads: payloads ?? [],
      checkin: {
        token,
        expires: expiresIso
      }
    });
  } catch (e) {
    return json(req, {
      ok: false,
      error: "exception",
      details: String(e)
    }, 500);
  }
});
