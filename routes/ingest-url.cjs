// routes/ingest-url.cjs
const express = require('express');
const cors = require('cors');
const crypto = require('crypto');
const sharp = require('sharp');

const router = express.Router();

// ---------- Config ----------
const BUCKET      = process.env.SUPABASE_BUCKET || 'collector';
const MAX_BYTES   = +(process.env.ASSET_MAX_BYTES || 20_000_000); // 20MB
const MAX_DIM     = +(process.env.ASSET_MAX_DIM || 2000);         // longest edge
const BASE_CDN    = (process.env.BASE_CDN_URL || '').replace(/\/+$/,''); // optional override

// Allowed content-types (we’ll also allow “octet-stream” if URL looks like an image)
const ALLOWED = new Set([
  'image/jpeg','image/png','image/webp','image/gif','image/avif','image/svg+xml'
]);

// CORS + body
router.use(cors({ origin: true }));
router.use(express.json({ limit: '250kb' })); // only receives {url}

// Lazy ESM import for @supabase/supabase-js in CommonJS:
let _sbClient = null;
async function getSupabase() {
  if (_sbClient) return _sbClient;
  const { createClient } = await import('@supabase/supabase-js'); // ESM import inside CJS
  _sbClient = createClient(
    process.env.SUPABASE_URL,
    process.env.SUPABASE_SERVICE_ROLE,          // service role (server only!)
    { auth: { persistSession: false } }
  );
  return _sbClient;
}

function bad(res, code, msg) {
  return res.status(code).json({ ok: false, error: msg });
}
function sha256hex(buf) {
  return crypto.createHash('sha256').update(buf).digest('hex');
}
function looksLikeImagePath(pathname='') {
  return /\.(jpe?g|png|gif|webp|avif|svg)(\?|#|$)/i.test(pathname);
}

// GET/POST both fine; we’ll expose POST here:
router.post('/api/ingest-url', async (req, res) => {
  try {
    const raw = (req.body?.url || '').trim();
    if (!raw) return bad(res, 400, 'Missing url');

    let u;
    try { u = new URL(raw); }
    catch { return bad(res, 400, 'Invalid URL'); }

    const ua = { 'user-agent': 'CoCoCollector/1.0' };

    // Best-effort HEAD
    let headType = '';
    let headLen = 0;
    try {
      const head = await fetch(u, { method: 'HEAD', headers: ua });
      headType = (head.headers.get('content-type') || '').split(';')[0].trim().toLowerCase();
      headLen  = +(head.headers.get('content-length') || 0);
    } catch (_) { /* some hosts block HEAD */ }

    if (headLen && headLen > MAX_BYTES) return bad(res, 413, 'Remote file is too large');

    // GET the resource
    const r = await fetch(u, { method: 'GET', headers: ua, redirect: 'follow' });
    if (!r.ok) return bad(res, 502, `Fetch failed: HTTP ${r.status}`);

    const ct = (r.headers.get('content-type') || headType || '').split(';')[0].trim().toLowerCase();
    const len = +(r.headers.get('content-length') || headLen || 0);

    if (len && len > MAX_BYTES) return bad(res, 413, 'Remote file is too large');
    if (ct && !ALLOWED.has(ct) && !looksLikeImagePath(u.pathname)) {
      return bad(res, 415, `Unsupported content-type: ${ct}`);
    }

    // Read bytes (still enforce size)
    const buf = Buffer.from(await r.arrayBuffer());
    if (buf.length > MAX_BYTES) return bad(res, 413, 'Downloaded file exceeded limit');

    // Convert/resize to webp; SVG will rasterize; GIF: first frame
    let img = sharp(buf, { animated: false, limitInputPixels: false });
    const meta = await img.metadata().catch(() => ({}));

    const w = meta.width  || MAX_DIM;
    const h = meta.height || MAX_DIM;
    const scale = Math.min(1, MAX_DIM / Math.max(w, h));
    if (scale < 1) img = img.resize(Math.round(w*scale), Math.round(h*scale), { fit: 'inside' });

    const out = await img.webp({ quality: 90 }).toBuffer();
    const hash = sha256hex(out).slice(0, 16);
    const ymd  = new Date().toISOString().slice(0,10); // YYYY-MM-DD
    const key  = `rehost/${ymd}/${hash}.webp`;

    // Upload to Supabase Storage
    const supabase = await getSupabase();
    const { error: upErr } = await supabase
      .storage
      .from(BUCKET)
      .upload(key, out, { contentType: 'image/webp', upsert: true });

    if (upErr) return bad(res, 502, `Upload failed: ${upErr.message}`);

    // Build public URL
    let cdnUrl;
    if (BASE_CDN) {
      cdnUrl = `${BASE_CDN}/${key}`;
    } else {
      const { data: pub } = supabase.storage.from(BUCKET).getPublicUrl(key);
      cdnUrl = pub?.publicUrl;
    }

    // Return payload
    const dims = await sharp(out).metadata();
    return res.status(201).json({
      ok: true,
      cdnUrl,
      hash,
      bytes: out.length,
      width:  dims.width  || null,
      height: dims.height || null,
      sourceUrl: u.toString()
    });
  } catch (e) {
    console.error('[ingest-url] error', e);
    return bad(res, 500, 'Ingest failed');
  }
});

module.exports = router;
