// supabase/functions/notify-creator/index.ts
//
// Fires a Brevo email to a content creator when their inspo_wall card
// reaches EXACTLY 5 saves. A "save" is a heart in collector_reactions,
// where collector_reactions.item_id === inspo_wall.row_id.
//
// Trigger: Supabase Database Webhook on collector_reactions, INSERT event.
//
// Env (Edge Function secrets):
//   SUPABASE_URL                ← auto-injected by the platform
//   SUPABASE_SERVICE_ROLE_KEY   ← auto-injected; bypasses RLS for the count
//   BREVO_API_KEY               ← set this one yourself
//
// Deploy:   supabase functions deploy notify-creator
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SAVE_THRESHOLD = 5;
const BREVO_ENDPOINT = "https://api.brevo.com/v3/smtp/email";

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method Not Allowed", { status: 405 });
  }

  try {
    const payload = await req.json();
    console.log('1. Webhook received');
    console.log('2. Payload:', JSON.stringify(payload));
    const record = payload?.record ?? {};

    // Only hearts count as saves. Ignore any other reaction types.
    if (record.reaction_type !== "heart") {
      return new Response(JSON.stringify({ skipped: "not a heart" }), {
        status: 200,
        headers: { "content-type": "application/json" },
      });
    }

    // item_id on collector_reactions is the inspo_wall.row_id.
    const rowId = record.item_id;
    console.log('3. row_id extracted:', rowId);
    if (!rowId) {
      return new Response(JSON.stringify({ skipped: "no item_id" }), {
        status: 200,
        headers: { "content-type": "application/json" },
      });
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    // Count total heart-saves for this card. Service role bypasses RLS so the
    // count reflects every reactor, not just the current one.
    const { count, error: countError } = await supabase
      .from("collector_reactions")
      .select("*", { count: "exact", head: true })
      .eq("item_id", rowId)
      .eq("reaction_type", "heart");

    if (countError) {
      console.error("[notify-creator] count error:", countError.message);
      return new Response(JSON.stringify({ error: countError.message }), {
        status: 500,
        headers: { "content-type": "application/json" },
      });
    }

    console.log('4. Save count:', count);
    console.log('5. Count check — sending?', count === SAVE_THRESHOLD);

    // Exactly 5 — not >= 5 — so the creator is emailed once, not on every
    // save after the fifth.
    if (count !== SAVE_THRESHOLD) {
      return new Response(
        JSON.stringify({ skipped: `count is ${count}, not ${SAVE_THRESHOLD}` }),
        { status: 200, headers: { "content-type": "application/json" } },
      );
    }

    // Pull the card so we know who made it.
    const { data: card, error: cardError } = await supabase
      .from("inspo_wall")
      .select("row_id, title, image, source_url, email")
      .eq("row_id", rowId)
      .single();

    if (cardError || !card) {
      console.error("[notify-creator] card lookup failed:", cardError?.message);
      return new Response(JSON.stringify({ error: "card not found" }), {
        status: 200, // not a server fault — nothing to notify about
        headers: { "content-type": "application/json" },
      });
    }

    console.log('6. inspo_wall row:', JSON.stringify(card));

    const creatorEmail = (card.email || "").trim();
    console.log('7. Creator email:', creatorEmail);
    if (!creatorEmail) {
      return new Response(JSON.stringify({ skipped: "no creator email" }), {
        status: 200,
        headers: { "content-type": "application/json" },
      });
    }

    const cardUrl =
      `https://coco-daily-inspo.cultureschool.org/?card=${encodeURIComponent(rowId)}`;

    const textContent =
      `Hi there,\n\n` +
      `We found your work, and it stopped us. It's now on CoCo Daily Inspo, the ` +
      `discovery portal on CultureSchool, a color and pattern intelligence ` +
      `platform that centers cultural celebration. This week, 5 people saved it.\n\n` +
      `See it on CoCo → ${cardUrl}\n\n` +
      `If you'd like to be credited, remove it, or explore a free creator profile ` +
      `on CultureSchool, just reply. We'd love to have you in the community.\n\n` +
      `— The CoCo Team`;

    const safeTitle = (card.title || "your work")
      .replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");

    const htmlContent = `
      <div style="font-family:Georgia,'Times New Roman',serif;color:#1e1810;line-height:1.7;max-width:520px;margin:0 auto;padding:8px 4px;">
        <p>Hi there,</p>
        <p>We found your work, and it stopped us. It's now on <strong>CoCo Daily Inspo</strong>,
        the discovery portal on CultureSchool — a color and pattern intelligence platform
        that centers cultural celebration. This week, <strong>5 people saved it</strong>.</p>
        ${card.image ? `<p style="margin:18px 0;"><img src="${card.image}" alt="${safeTitle}" style="max-width:100%;border-radius:12px;display:block;"></p>` : ""}
        <p style="margin:24px 0;">
          <a href="${cardUrl}"
             style="display:inline-block;background:#c8a050;color:#fff;text-decoration:none;
                    padding:12px 26px;border-radius:999px;font-family:'Helvetica Neue',Arial,sans-serif;
                    font-weight:700;letter-spacing:.04em;">See it on CoCo →</a>
        </p>
        <p>If you'd like to be credited, remove it, or explore a free creator profile on
        CultureSchool, just reply. We'd love to have you in the community.</p>
        <p style="color:#5a4a38;">— The CoCo Team</p>
      </div>`;

    const brevoKey = Deno.env.get("BREVO_API_KEY");
    if (!brevoKey) {
      console.error("[notify-creator] BREVO_API_KEY not set");
      return new Response(JSON.stringify({ error: "missing BREVO_API_KEY" }), {
        status: 500,
        headers: { "content-type": "application/json" },
      });
    }

    console.log('8. Calling Brevo...');
    const brevoRes = await fetch(BREVO_ENDPOINT, {
      method: "POST",
      headers: {
        "api-key": brevoKey,
        "content-type": "application/json",
        "accept": "application/json",
      },
      body: JSON.stringify({
        sender: { email: "info@cultureschool.org", name: "CoCo" },
        to: [{ email: creatorEmail }],
        subject: "✦ Your work is resonating on CoCo",
        textContent,
        htmlContent,
      }),
    });

    // Read the body once — a Response stream can only be consumed a single time.
    const brevoBody = await brevoRes.text();
    console.log('9. Brevo status:', brevoRes.status);
    console.log('10. Brevo body:', brevoBody);

    if (!brevoRes.ok) {
      console.error("[notify-creator] Brevo error:", brevoRes.status, brevoBody);
      return new Response(
        JSON.stringify({ error: `Brevo ${brevoRes.status}`, detail: brevoBody }),
        { status: 502, headers: { "content-type": "application/json" } },
      );
    }

    console.log(`[notify-creator] emailed ${creatorEmail} for card ${rowId}`);
    return new Response(
      JSON.stringify({ notified: creatorEmail, row_id: rowId, saves: count }),
      { status: 200, headers: { "content-type": "application/json" } },
    );
  } catch (e) {
    console.error("[notify-creator] threw:", e);
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: { "content-type": "application/json" },
    });
  }
});
