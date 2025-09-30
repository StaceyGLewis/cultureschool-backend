// Deno edge function: normalizes upstream seed into timeboxed events
const cors = {
  "access-control-allow-origin": "*",
  "access-control-allow-headers": "authorization, x-client-info, apikey, content-type",
  "access-control-allow-methods": "GET, OPTIONS",
};

type SeedIn = Record<string, unknown>;
const first = (...vals: unknown[]) => vals.find(v => v !== null && v !== undefined && v !== "") ?? null;

function toIsoOrNull(v: unknown): string | null {
  if (!v) return null;
  if (v instanceof Date && !isNaN(+v)) return v.toISOString();
  const s = String(v).trim();
  if (/[T]\d{2}:\d{2}(:\d{2})?(\.\d+)?(Z|[+\-]\d{2}:\d{2})$/.test(s)) { const d = new Date(s); return isNaN(+d) ? null : d.toISOString(); }
  if (/^\d{4}-\d{2}-\d{2} \d{2}:\d{2}(:\d{2})?$/.test(s)) { const d = new Date(s.replace(" ","T")); return isNaN(+d) ? null : d.toISOString(); }
  if (/^\d{4}-\d{2}-\d{2}$/.test(s)) { const d = new Date(s+"T00:00:00"); return isNaN(+d) ? null : d.toISOString(); }
  const d = new Date(s); return isNaN(+d) ? null : d.toISOString();
}

function normalizeOne(t: SeedIn) {
  const startIso = toIsoOrNull(first(
    (t as any).starts_at,(t as any).start_at,(t as any).next_start,(t as any).next_event_at,
    (t as any).event_start_at,(t as any).start_time,(t as any).date,(t as any).event_date
  ));
  let endIso = toIsoOrNull(first((t as any).ends_at,(t as any).end_at,(t as any).event_end_at,(t as any).end_time));
  if (!endIso && startIso) { const d = new Date(startIso); endIso = new Date(d.getTime()+3600000).toISOString(); } // +1h

  const img = first((t as any).image_url,(t as any).media_url,(t as any).cover_image,(t as any).banner_url,"https://placehold.co/800x600?text=CoCo") as string;

  return {
    id: (t as any).id ?? crypto.randomUUID(),
    slug: (t as any).slug ?? null,
    title: (t as any).title ?? "Untitled",
    description: (t as any).description ?? (t as any).caption ?? "",
    image_url: img,
    place_name: first((t as any).place_name,(t as any).city_tag,(t as any).location,"") as string,
    starts_at: startIso,
    ends_at: endIso,
    is_event: true,
    price_min: Number.isFinite((t as any).price_min) ? (t as any).price_min : null,
    price_max: Number.isFinite((t as any).price_max) ? (t as any).price_max : null,
    lat: (t as any).lat ?? null,
    lng: (t as any).lng ?? null,
    source: (t as any).source ?? null,
    creator_email: (t as any).creator_email ?? null,
  };
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: cors });
  try {
    const url = new URL(req.url);
    const upstream = url.searchParams.get("url") ?? Deno.env.get("MOTHER_SEED_URL");
    if (!upstream) {
      return new Response(JSON.stringify({ error: "Missing MOTHER_SEED_URL or ?url" }), {
        status: 400, headers: { "content-type": "application/json", ...cors },
      });
    }
    const r = await fetch(upstream, { headers: { accept: "application/json" } });
    if (!r.ok) {
      return new Response(JSON.stringify({ error: `Upstream ${r.status}` }), {
        status: 502, headers: { "content-type": "application/json", ...cors },
      });
    }
    const raw = await r.json();
    const arr: SeedIn[] = Array.isArray(raw) ? raw : [raw];
    const normalized = arr.map(normalizeOne).filter(x => !!x.starts_at);
    return new Response(JSON.stringify(normalized), { headers: { "content-type": "application/json", ...cors } });
  } catch (e) {
    return new Response(JSON.stringify({ error: "edge-func-failed", message: String(e?.message || e) }), {
      status: 500, headers: { "content-type": "application/json", ...cors },
    });
  }
});
