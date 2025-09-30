
// in qr-resolve/index.ts and qr-verify/index.ts
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
const url = Deno.env.get("SB_URL");
const serviceKey = Deno.env.get("SB_SERVICE_ROLE_KEY");
const supabase = createClient(url, serviceKey);
// --- CORS helpers ---
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
    "Access-Control-Allow-Methods": "POST, OPTIONS"
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
// Extract expiry from either column name
function getExpiryMs(row) {
  const a = row?.expires;
  const b = row?.token_expires_at;
  const iso = a ?? b ?? null;
  if (!iso) return null;
  const t = new Date(iso).getTime();
  return Number.isFinite(t) ? t : null;
}
Deno.serve(async (req)=>{
  // CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: corsHeaders(req)
    });
  }
  if (req.method !== "POST") {
    return json(req, {
      ok: false,
      error: "method_not_allowed"
    }, 405);
  }
  try {
    const { token, partner_id } = await req.json().catch(()=>({}));
    if (!token || typeof token !== "string") {
      return json(req, {
        ok: false,
        error: "missing token"
      }, 400);
    }
    // Look up token (use maybeSingle() to avoid throw on 0 rows)
    const { data: row, error } = await supabase.from("qr_checkins").select("*").eq("token", token).maybeSingle();
    if (error) {
      return json(req, {
        ok: false,
        error: "db_error",
        details: error.message
      }, 500);
    }
    if (!row) {
      return json(req, {
        ok: false,
        reason: "invalid"
      }, 404);
    }
    // Expiry check
    const expMs = getExpiryMs(row);
    if (expMs !== null && expMs < Date.now()) {
      return json(req, {
        ok: false,
        reason: "expired"
      }, 410);
    }
    // Status check (default to 'pending' if missing)
    const status = row.status ?? "pending";
    if (status !== "pending") {
      return json(req, {
        ok: false,
        reason: "already_used"
      }, 409);
    }
    // Mark confirmed
    const update = {
      status: "confirmed",
      confirmed_at: new Date().toISOString(),
      partner_id: partner_id ?? row.partner_id ?? null
    };
    const { error: updErr } = await supabase.from("qr_checkins").update(update).eq("id", row.id);
    if (updErr) {
      return json(req, {
        ok: false,
        error: "update_failed",
        details: updErr.message
      }, 500);
    }
    return json(req, {
      ok: true,
      token,
      confirmed: true
    });
  } catch (e) {
    return json(req, {
      ok: false,
      error: "exception",
      details: String(e)
    }, 500);
  }
});
