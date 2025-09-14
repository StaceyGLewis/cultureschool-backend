// supabase/functions/host-image/index.ts
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method Not Allowed", { status: 405 });
  }
  try {
    const { url, board_id, path } = await req.json();
    if (!url) return new Response("Missing url", { status: 400 });

    // fetch remote image
    const res = await fetch(url, { redirect: "follow" });
    if (!res.ok) {
      return new Response(
        JSON.stringify({ error: `Fetch failed: ${res.status}` }),
        { status: 400, headers: { "content-type": "application/json" } }
      );
    }

    const ct = res.headers.get("content-type") || "image/jpeg";
    const buf = new Uint8Array(await res.arrayBuffer());
    const ext =
      (ct.split("/")[1] || "jpg").split(";")[0].replace(/[^a-z0-9]/gi, "") ||
      "jpg";

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    const key =
      path ||
      `boards/${board_id || "anon"}/media/${crypto.randomUUID()}.${ext}`;

    const { error } = await supabase.storage
      .from("public-uploads")
      .upload(key, buf, { contentType: ct, upsert: true });
    if (error) {
      return new Response(JSON.stringify({ error: error.message }), {
        status: 500,
        headers: { "content-type": "application/json" },
      });
    }

    const { data: pub } = supabase.storage
      .from("public-uploads")
      .getPublicUrl(key);

    return new Response(JSON.stringify({ url: pub.publicUrl, key }), {
      status: 200,
      headers: { "content-type": "application/json" },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: { "content-type": "application/json" },
    });
  }
});
