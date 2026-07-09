// supabase/functions/shopify-membership/index.ts
//
// Shopify `orders/paid` -> grant/extend a rolling membership entitlement.
// Fires on the initial subscription order AND every monthly renewal order,
// so access always tracks payment. No cancellation handler needed: when
// payments stop, the rolling window lapses and has_art_access() closes the gate.
//
// DEPLOY (note --no-verify-jwt: Shopify won't send a Supabase JWT; our HMAC
// check is the authentication):
//   supabase functions deploy shopify-membership --no-verify-jwt
//
// ENV (SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY are auto-injected):
//   supabase secrets set SHOPIFY_WEBHOOK_SECRET=<your webhook signing secret>
//
// Then in Shopify: Settings -> Notifications -> Webhooks (or a custom app),
// create an "Order payment" (orders/paid) webhook pointing at:
//   https://qwulthvbwujfehgdegtn.supabase.co/functions/v1/shopify-membership
// The signing secret shown on that page is SHOPIFY_WEBHOOK_SECRET.

import { createClient } from "jsr:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const WEBHOOK_SECRET = Deno.env.get("SHOPIFY_WEBHOOK_SECRET")!;

const MEMBERSHIP_PRODUCT_IDS = new Set<string>([
  "8822615507107",
]);
const MEMBERSHIP_SKUS = new Set<string>([]);
const MATCH_ANY_SUBSCRIPTION_LINE = false;

const MEMBERSHIP_DAYS = 35; // monthly + grace; the rolling window

const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });

async function validHmac(raw: string, header: string | null): Promise<boolean> {
  if (!header) return false;
  const key = await crypto.subtle.importKey(
    "raw", new TextEncoder().encode(WEBHOOK_SECRET),
    { name: "HMAC", hash: "SHA-256" }, false, ["sign"],
  );
  const mac = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(raw));
  const digest = btoa(String.fromCharCode(...new Uint8Array(mac)));
  if (digest.length !== header.length) return false;
  let diff = 0;
  for (let i = 0; i < digest.length; i++) diff |= digest.charCodeAt(i) ^ header.charCodeAt(i);
  return diff === 0;
}

function isMembershipOrder(order: any): boolean {
  for (const li of order.line_items ?? []) {
    if (MEMBERSHIP_PRODUCT_IDS.has(String(li.product_id))) return true;
    if (li.sku && MEMBERSHIP_SKUS.has(li.sku)) return true;
    if (MATCH_ANY_SUBSCRIPTION_LINE && (li.selling_plan_allocation || li.selling_plan)) return true;
  }
  return false;
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return json(405, { error: "Method not allowed" });

  const raw = await req.text();
  if (!(await validHmac(raw, req.headers.get("X-Shopify-Hmac-Sha256")))) {
    return json(401, { error: "Invalid HMAC" });
  }

  let order: any;
  try { order = JSON.parse(raw); } catch { return json(400, { error: "Bad JSON" }); }

  const email = (order.email || order.contact_email || order.customer?.email || "").trim().toLowerCase();
  if (!email) return json(200, { skipped: "no email on order" });
  if (!isMembershipOrder(order)) return json(200, { skipped: "not a membership order" });

  const paidAt = new Date(order.processed_at || order.created_at || Date.now());
  const expires = new Date(paidAt.getTime() + MEMBERSHIP_DAYS * 86_400_000).toISOString();

  const admin = createClient(SUPABASE_URL, SERVICE_KEY);
  const { error } = await admin.rpc("grant_membership", { p_email: email, p_expires: expires });
  if (error) return json(500, { error: error.message });

  return json(200, { ok: true, email, expires });
});
