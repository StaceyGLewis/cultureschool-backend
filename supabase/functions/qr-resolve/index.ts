// supabase/functions/qr-resolve/index.ts
// Route:  https://<project>.supabase.co/functions/v1/qr-resolve

import { serve } from "https://deno.fresh.dev/std/http/server.ts";

serve(async (req) => {
  try {
    const url = new URL(req.url);
    const params = url.searchParams;

    // ------------------------------------------------------
    // 1. Extract QR parameters
    // ------------------------------------------------------
    const referrer = params.get("ref") || null;          // creator email
    const creatorName = params.get("name") || null;       // creator name
    const source = params.get("source") || "qr";          // IG, flyer, viewer, storefront
    const code = params.get("code") || crypto.randomUUID();  
    const board = params.get("board") || null;            // optional: board ID
    const vendor = params.get("vendor") || null;          // optional: vendor
    const target = params.get("to") || "market";          // redirect target

    // ------------------------------------------------------
    // 2. Construct the redirect URL
    // ------------------------------------------------------
    const redirectMap: Record<string,string> = {
      "market": "https://www.cultureschool.org/pages/creator-marketplace",
      "viewer": board
        ? `https://theme-viewer.netlify.app/?board=${board}`
        : "https://theme-viewer.netlify.app",
      "creator": referrer
        ? `https://coco-public-profile.netlify.app/?email=${encodeURIComponent(referrer)}`
        : "https://coco-public-profile.netlify.app",
      "hub": "https://www.cultureschool.org/a/customerhub#account:a:dashboard"
    };

    const destination = redirectMap[target] || redirectMap.market;

    // ------------------------------------------------------
    // 3. Upsert the referral into spark_invites
    // ------------------------------------------------------
    const payload = {
      code,
      creator_email: referrer,
      creator_name: creatorName,
      referrer,
      template: {
        source,
        vendor,
        board,
        destination
      },
      status: "scanned"
    };

    const sb_url = Deno.env.get("SUPABASE_URL")!;
    const sb_key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

    const { error } = await fetch(`${sb_url}/rest/v1/spark_invites`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "apikey": sb_key,
        "Authorization": `Bearer ${sb_key}`,
        "Prefer": "resolution=merge-duplicates"
      },
      body: JSON.stringify(payload)
    }).then(r => r.json());

    if (error) {
      console.error("DB insert error:", error);
    }

    // ------------------------------------------------------
    // 4. Redirect the user to the experience
    // ------------------------------------------------------
    return new Response(null, {
      status: 302,
      headers: {
        Location: destination
      }
    });

  } catch (err) {
    console.error(err);
    return new Response("QR Resolver Error", { status: 500 });
  }
});
