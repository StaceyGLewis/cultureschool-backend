// supabase/functions/shopify-entitlement-webhook/index.ts
//
// PATCH-ONLY webhook. Membership is already handled by the existing
// `shopify-membership` function — this one must NOT grant membership (no double
// grants, no touching grant_membership). It grants a ONE-TIME 48h patch pass.
//
// Register as a SECOND orders/paid webhook (Shopify allows multiple per topic).
// Deploy:  supabase functions deploy shopify-entitlement-webhook --no-verify-jwt
// Secret:  supabase secrets set SHOPIFY_WEBHOOK_SECRET=<Shopify signing secret>
//
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SHOPIFY_SECRET = Deno.env.get("SHOPIFY_WEBHOOK_SECRET")!;
const SUPABASE_URL   = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE   = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const PATCH_PACK_ID  = "6b7f1d2a-3c4e-4f50-9a6b-1c2d3e4f5a6b"; // sync w/ can_use_patch_studio()
const PATCH_WINDOW_H = 48;

function isPatch(li: any): boolean {
  const t = `${li?.title ?? ""} ${li?.name ?? ""} ${li?.sku ?? ""}`.toLowerCase();
  return t.includes("iron-on patch") || t.includes("diy-iron-on-patch");
}
function safeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let r = 0; for (let i = 0; i < a.length; i++) r |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return r === 0;
}
async function verifyShopify(raw: string, hmac: string): Promise<boolean> {
  const key = await crypto.subtle.importKey("raw", new TextEncoder().encode(SHOPIFY_SECRET),
    { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  const sig = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(raw));
  return safeEqual(btoa(String.fromCharCode(...new Uint8Array(sig))), hmac);
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("method not allowed", { status: 405 });
  const raw = await req.text();
  if (!SHOPIFY_SECRET || !(await verifyShopify(raw, req.headers.get("X-Shopify-Hmac-Sha256") ?? "")))
    return new Response("invalid signature", { status: 401 });

  let order: any;
  try { order = JSON.parse(raw); } catch { return new Response("bad json", { status: 400 }); }

  const email = String(order.email || order.contact_email || order.customer?.email || "")
    .trim().toLowerCase();
  if (!email) return new Response("ok (no email)", { status: 200 });

  if (!(order.line_items ?? []).some(isPatch))
    return new Response("ok (no patch)", { status: 200 });

  // one-time 48h pass. Members already have access via has_all_access(), so an
  // extra pass row for a member is harmless.
  const sb = createClient(SUPABASE_URL, SERVICE_ROLE);
  const until = new Date(Date.now() + PATCH_WINDOW_H * 3600e3).toISOString();
  const { error } = await sb.rpc("grant_pack", { p_email: email, p_pack_id: PATCH_PACK_ID, p_expires_at: until });
  if (error) { console.error("grant_pack", error); return new Response("db error", { status: 500 }); }
  return new Response("ok", { status: 200 });
});
