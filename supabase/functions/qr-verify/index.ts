// =====================================================
//  CoCoCreate QR Verification Function
//  Used by event staff to validate check-in tokens
// =====================================================

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const url = Deno.env.get("SB_URL");
const serviceKey = Deno.env.get("SB_SERVICE_ROLE_KEY");
const supabase = createClient(url, serviceKey);

const ALLOW_ORIGINS = new Set([
  "https://cocoqr.netlify.app",
  "https://www.cultureschool.org",
  "http://localhost:5173",
  "http://localhost:3000",
]);

function corsHeaders(req: Request) {
  const origin = req.headers.get("origin") ?? "";
  const allow = ALLOW_ORIGINS.has(origin) ? origin : "https://cocoqr.netlify.app";

  return {
    "Access-Control-Allow-Origin": allow,
    "Vary": "Origin",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  };
}

function json(req: Request, payload: any, status = 200) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: {
      ...corsHeaders(req),
      "Content-Type": "application/json",
    },
  });
}

// =====================================================
//  MAIN VERIFY HANDLER
// =====================================================

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders(req) });
  }

  try {
    if (req.method !== "POST") {
      return json(req, { ok: false, error: "method_not_allowed" }, 405);
    }

    const body = await req.json().catch(() => ({}));
    const token = (body.token || "").trim();
    const staff = body.staff || null;        // optional: who validated
    const partner = body.partner || null;    // optional: which vendor is validating

    if (!token) {
      return json(req, { ok: false, reason: "missing_token" }, 400);
    }

    // =====================================================
    // LOOKUP — Check token validity
    // =====================================================
    const nowIso = new Date().toISOString();

    const { data: row, error } = await supabase
      .from("qr_checkins")
      .select("*")
      .eq("token", token)
      .lte("expires", nowIso)   // not expired
      .maybeSingle();

    if (error) {
      return json(req, {
        ok: false,
        error: "lookup_error",
        details: error.message,
      }, 500);
    }

    if (!row) {
      return json(req, {
        ok: false,
        reason: "invalid_or_expired",
      }, 400);
    }

    // =====================================================
    // UPDATE STATUS — mark check-in complete
    // =====================================================
    const update = {
      status: "verified",
      verified_at: nowIso,
      staff_verified: staff,
      partner_verified: partner,
    };

    const { error: updErr } = await supabase
      .from("qr_checkins")
      .update(update)
      .eq("id", row.id);

    if (updErr) {
      return json(req, {
        ok: false,
        error: "update_failed",
        details: updErr.message,
      }, 500);
    }

    // =====================================================
    // SUCCESS
    // =====================================================
    return json(req, {
      ok: true,
      verified: true,
      slug: row.slug || row.qr_slug,
      checkin_id: row.id,
      updated: update,
    });
  } catch (err) {
    return json(req, {
      ok: false,
      error: "exception",
      details: String(err),
    }, 500);
  }
});
