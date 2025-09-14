// /functions/mirror-image/index.ts (Deno edge function)
import { createClient } from "https://esm.sh/@supabase/supabase-js";
export async function serve(req: Request) {
  const { url } = await req.json();
  if (!url) return new Response("Missing url", { status: 400 });

  const r = await fetch(url, { redirect: "follow" });
  if (!r.ok) return new Response("Fetch failed", { status: 400 });
  const ct = r.headers.get("content-type") || "";
  if (!ct.startsWith("image/")) return new Response("Not an image", { status: 415 });
  const buf = new Uint8Array(await r.arrayBuffer());

  // hash filename for dedupe
  const hash = Array.from(new Uint8Array(await crypto.subtle.digest("SHA-256", buf)))
    .map(b => b.toString(16).padStart(2, "0")).join("");
  const ext = (ct.split("/")[1] || "jpg").split(";")[0];
  const path = `catalog/${hash}.${ext}`;

  const supabase = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  await supabase.storage.from("catalog").upload(path, buf, { contentType: ct, upsert: true });
  const { data } = supabase.storage.from("catalog").getPublicUrl(path);
  return new Response(JSON.stringify({ image_url: data.publicUrl }), { headers: { "content-type": "application/json" }});
}
