// netlify/functions/printful-order.js
// Env vars needed: PRINTFUL_API_KEY, SUPABASE_URL, SUPABASE_SERVICE_KEY

const PRINTFUL_BASE = 'https://api.printful.com';

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type',
};

// Keys must match option value="" in pattern-generator-v2.html exactly.
// Fill in variant_id from: Printful dashboard → Stores → [your store] → Products → [product] → Edit
// variant_id is the number in the URL when you open a product variant, or visible in the API response.
const PRODUCT_VARIANTS = {
  // ── All-Over Print Basic Pillow (Printful product 83) ──
  '4532:18x18:58': { product_id: 83, variant_id: 4532  }, // 18"×18"
  '4532:20x12:52': { product_id: 83, variant_id: 9513  }, // 20"×12" lumbar
  '4532:22x22:65': { product_id: 83, variant_id: 11075 }, // 22"×22"

  // ── Canvas Prints (Printful product 3) ──
  'canvas:8x10:48':  { product_id: 3, variant_id: 19293 }, // 8"×10"
  'canvas:11x14:52': { product_id: 3, variant_id: 19298 }, // 11"×14"
  'canvas:16x20:58': { product_id: 3, variant_id: 6     }, // 16"×20"
  'canvas:24x36:78': { product_id: 3, variant_id: 825   }, // 24"×36"

  // ── Sublimation Throw Blanket (Printful product 395) ──
  'blanket:50x60:72':  { product_id: 395, variant_id: 10986 }, // 50"×60"
  'blanket:60x80:85':  { product_id: 395, variant_id: 13222 }, // 60"×80"

  // ── Sublimated Sherpa Blanket (Printful product 711) ──
  'blanket:sherpa:95': { product_id: 711, variant_id: 17482 }, // 50"×60"

  // ── All-Over Print Tote Bags ──
  'tote:15x15:38': { product_id: 84,  variant_id: 4533 }, // AOP Tote 15"×15" (product 84)
  'tote:16x20:48': { product_id: 274, variant_id: 9039 }, // Large Tote w/ Pocket (product 274)
};

exports.handler = async (event) => {
  if (event.httpMethod === 'OPTIONS') {
    return { statusCode: 204, headers: CORS };
  }

  if (event.httpMethod !== 'POST') {
    return {
      statusCode: 405,
      headers: { ...CORS, 'Content-Type': 'application/json' },
      body: JSON.stringify({ error: 'Method not allowed' }),
    };
  }

  const PRINTFUL_KEY = process.env.PRINTFUL_API_KEY;
  const SUPABASE_URL = process.env.SUPABASE_URL;
  const SUPABASE_KEY = process.env.SUPABASE_SERVICE_KEY;

  if (!PRINTFUL_KEY) {
    return {
      statusCode: 500,
      headers: { ...CORS, 'Content-Type': 'application/json' },
      body: JSON.stringify({ error: 'Printful API key not configured' }),
    };
  }

  // Reject before Netlify's 6 MB hard limit returns an HTML error page
  if (event.body && Buffer.byteLength(event.body, 'utf8') > 5 * 1024 * 1024) {
    return {
      statusCode: 413,
      headers: { ...CORS, 'Content-Type': 'application/json' },
      body: JSON.stringify({ error: 'Image too large. Please use a photo under 2000×2000 px, or reduce quality.' }),
    };
  }

  let body;
  try {
    body = JSON.parse(event.body);
  } catch {
    return {
      statusCode: 400,
      headers: { ...CORS, 'Content-Type': 'application/json' },
      body: JSON.stringify({ error: 'Invalid JSON' }),
    };
  }

  const { name, email, notes, product, palette_name, palette_colors, pattern_style, back_style, design_base64, back_base64 } = body;

  if (!name || !email || !product || !design_base64) {
    return {
      statusCode: 400,
      headers: { ...CORS, 'Content-Type': 'application/json' },
      body: JSON.stringify({ error: 'Missing required fields: name, email, product, design_base64' }),
    };
  }

  const variant = PRODUCT_VARIANTS[product];
  if (!variant) {
    return {
      statusCode: 400,
      headers: { ...CORS, 'Content-Type': 'application/json' },
      body: JSON.stringify({ error: `Unknown product key: ${product}` }),
    };
  }

  try {
    // ── STEP 1: Upload front design to Printful ──
    const slug = (palette_name || 'pattern').replace(/\s+/g, '-').toLowerCase();
    const ts = Date.now();
    const filename = `coco-${slug}-${ts}.jpg`;

    const uploadRes = await fetch(`${PRINTFUL_BASE}/files`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${PRINTFUL_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        type:     'default',
        filename: filename,
        contents: design_base64,
      }),
    });

    const uploadData = await uploadRes.json();
    if (!uploadRes.ok || !uploadData.result?.id) {
      throw new Error('File upload failed: ' + JSON.stringify(uploadData));
    }
    const fileId = uploadData.result.id;

    // ── STEP 1b: Upload back design (optional — photo-print orders only) ──
    let backFileId = null;
    if (back_base64) {
      try {
        const backRes = await fetch(`${PRINTFUL_BASE}/files`, {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${PRINTFUL_KEY}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            type:     'back',
            filename: `coco-${slug}-back-${back_style||'pattern'}-${ts}.jpg`,
            contents: back_base64,
          }),
        });
        const backData = await backRes.json();
        if (backRes.ok && backData.result?.id) backFileId = backData.result.id;
      } catch (_) { /* non-fatal — proceed without back file */ }
    }

    // ── STEP 2: Create draft order ──
    // Orders are draft by default — no status field needed. Confirm manually in
    // the Printful dashboard (Orders → Drafts) after collecting payment.
    const orderRes = await fetch(`${PRINTFUL_BASE}/orders`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${PRINTFUL_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        recipient: {
          name:         name,
          email:        email,
          // Shipping address collected at checkout. Printful requires these fields
          // even for drafts — use placeholders until the payment flow is wired up.
          address1:     'TBD',
          city:         'TBD',
          state_code:   'MA',
          country_code: 'US',
          zip:          '00000',
        },
        items: [{
          variant_id: variant.variant_id,
          quantity:   1,
          name:       `${palette_name || 'CoCo Pattern'} — ${pattern_style || 'Print'}`,
          files: [
            { type: 'default', id: fileId },
            ...(backFileId ? [{ type: 'back', id: backFileId }] : []),
          ],
        }],
      }),
    });

    const orderData = await orderRes.json();
    if (!orderRes.ok || !orderData.result?.id) {
      throw new Error('Order creation failed: ' + JSON.stringify(orderData));
    }

    const printfulOrderId = orderData.result.id;

    // ── STEP 3: Log to Supabase (non-fatal — order already created above) ──
    if (SUPABASE_URL && SUPABASE_KEY) {
      try {
        const sbRes = await fetch(`${SUPABASE_URL}/rest/v1/printful_orders`, {
          method: 'POST',
          headers: {
            'apikey':        SUPABASE_KEY,
            'Authorization': `Bearer ${SUPABASE_KEY}`,
            'Content-Type':  'application/json',
            'Prefer':        'return=minimal',
          },
          body: JSON.stringify({
            printful_order_id: String(printfulOrderId),
            customer_name:     name,
            customer_email:    email,
            palette_name:      palette_name || null,
            palette_colors:    palette_colors || null,
            pattern_style:     pattern_style || null,
            back_style:        back_style || null,
            product_key:       product,
            notes:             notes || null,
            status:            'draft',
            file_id:           String(fileId),
          }),
        });
        if (!sbRes.ok) {
          const sbErr = await sbRes.text();
          console.error('[printful-order] Supabase log failed:', sbErr);
        }
      } catch (sbErr) {
        console.error('[printful-order] Supabase error (order still created):', sbErr.message);
      }
    }

    return {
      statusCode: 200,
      headers: { ...CORS, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        success:           true,
        printful_order_id: printfulOrderId,
        file_id:           fileId,
        message:           'Draft order created. Confirm in Printful dashboard after payment.',
      }),
    };

  } catch (err) {
    console.error('[printful-order]', err);
    return {
      statusCode: 500,
      headers: { ...CORS, 'Content-Type': 'application/json' },
      body: JSON.stringify({ error: err.message || 'Order failed' }),
    };
  }
};
