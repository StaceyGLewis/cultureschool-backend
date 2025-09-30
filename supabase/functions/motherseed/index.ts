// supabase/functions/motherseed/index.ts
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SUPABASE_ANON = Deno.env.get("SUPABASE_ANON_KEY");
const ALLOWED = (Deno.env.get("ALLOWED_ORIGINS") ?? "").split(",").map((s)=>s.trim()).filter(Boolean);
function corsHeaders(origin) {
  const allow = ALLOWED.length ? ALLOWED.includes(origin ?? "") ? origin : ALLOWED[0] : "*";
  return {
    "Access-Control-Allow-Origin": allow,
    "Access-Control-Allow-Methods": "GET,OPTIONS",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Vary": "Origin",
    "Content-Type": "application/json; charset=utf-8"
  };
}
function coalesce(...vals) {
  for (const v of vals)if (v !== null && v !== undefined && v !== "") return v;
  return null;
}
serve(async (req)=>{
  const headers = corsHeaders(req.headers.get("origin"));
  // Preflight
  if (req.method === "OPTIONS") return new Response(null, {
    headers
  });
  try {
    const url = new URL(req.url);
    const scope = (url.searchParams.get("scope") ?? "upcoming").toLowerCase(); // upcoming | all
    const windowDays = Number(url.searchParams.get("windowDays") ?? "14");
    const now = Date.now();
    const maxTs = now + (isFinite(windowDays) ? windowDays : 14) * 86_400_000;
    const supabase = createClient(SUPABASE_URL, SUPABASE_ANON);
    // Pull public boards. (You can also add filters here if you like.)
    const { data, error } = await supabase.from("cocoboards").select(`
        id, slug, title, description, place_name, city_tag, location,
        cover_image, banner_url, starts_at, ends_at, lat, lng, is_verified, is_public, created_at
      `).eq("is_public", true).order("created_at", {
      ascending: false
    }).limit(300);
    if (error) throw error;
    const payload = data.map((b)=>{
      // normalize required seed fields your page expects
      const starts = b.starts_at;
      const ends = b.ends_at ?? (starts ? new Date(new Date(starts).getTime() + 60 * 60 * 1000).toISOString() : null);
      return {
        id: b.slug || b.id,
        slug: b.slug,
        title: b.title ?? "Untitled",
        description: b.description ?? "",
        image_url: coalesce(b.cover_image, b.banner_url, "https://placehold.co/800x600?text=CoCo"),
        place_name: coalesce(b.place_name, b.city_tag, b.location, ""),
        starts_at: starts,
        ends_at: ends,
        lat: b.lat,
        lng: b.lng,
        is_event: true,
        is_verified: !!b.is_verified
      };
    }).filter((x)=>{
      if (scope === "all") return true;
      // Upcoming scope: hide past, and gate by windowDays
      if (x.ends_at && new Date(x.ends_at).getTime() < now) return false;
      if (!x.starts_at) return false;
      return new Date(x.starts_at).getTime() <= maxTs;
    });
    return new Response(JSON.stringify(payload), {
      status: 200,
      headers
    });
  } catch (e) {
    return new Response(JSON.stringify({
      error: String(e?.message || e)
    }), {
      status: 500,
      headers
    });
  }
});
