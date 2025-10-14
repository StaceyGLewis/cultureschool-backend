// routes/ingest-url.js
import express from 'express';
import cors from 'cors';
import crypto from 'node:crypto';
import sharp from 'sharp';
import { createClient } from '@supabase/supabase-js';
import { fetch } from 'undici';

const router = express.Router();

// --- CORS (adjust origin as needed)
router.use(cors({ origin: true, credentials: false }));
router.use(express.json({ limit: '200kb' })); // body is just {url}

// --- Supabase
const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE,
  { auth: { persistSession: false } }
);

const BUCKET = process.env.SUPABASE_BUCKET || 'collector';
const MAX_BYTES = +(process.env.ASSET_MAX_BYTES || 20_000_000); // 20MB
const MAX_DIM = +(process.env.ASSET_MAX_DIM || 2000);
const ALLOWED = new Set([
  'image/jpeg',
  'image/png',
  'image/webp',
  'image/gif',
  'image/avif',
  'image/svg+xml'
]);

function bad(res, code, msg) {
  return res.status(code).json({ ok: false, error: msg });
}

function hashHex(buf) {
  return crypto.createHash('sha256').update(buf).digest('hex');
}

// GET/POST both supported
router.post('/api/ingest-url', async (req, res) => {
  try {
    const raw = (req.body?.url || '').trim();
    if (!raw) return bad(res, 400, 'Missing url');

    // Validate URL
    let u;
    try { u = new URL(raw); } catch { return bad(res, 400, 'Invalid URL'); }

    // Fetch HEAD first (best effort)
    let contentType = '';
    let contentLength = 0;
    try {
      const head = await fetch(u, { method: 'HEAD', headers: { 'user-agent': 'CoCoCollector/1.0' } });
      contentType = (head.headers.get('content-type') || '').split(';')[0].trim().toLowerCase();
      contentLength = +(head.headers.get('content-length') || 0);
    } catch { /* some hosts block HEAD — proceed */ }

    // If not an image content-type, we’ll still try GET below (some hosts misreport)
    if (contentLength && contentLength > MAX_BYTES) {
      return bad(res, 413, 'Remote file is too large');
    }

    // GET the bytes
    const r = await fetch(u, {
      method: 'GET',
      headers: { 'user-agent': 'CoCoCollector/1.0' },
      // Don’t follow infinite redirects
      redirect: 'follow'
    });
    if (!r.ok) return bad(res, 502, `Fetch failed: HTTP ${r.status}`);

    const ct = (r.headers.get('content-type') || contentType || '').split(';')[0].trim().toLowerCase();
    const len = +(r.headers.get('content-length') || contentLength || 0);

    if (len && len > MAX_BYTES) return bad(res, 413, 'Remote file is too large');
    if (ct && !ALLOWED.has(ct)) {
      // Some shops serve images as octet-stream; allow if the URL looks like an image
      const isMaybeImage = /\.(jpg|jpeg|png|gif|webp|avif|svg)(\?|#|$)/i.test(u.pathname);
      if (!isMaybeImage) return bad(res, 415, `Unsupported content-type: ${ct}`);
    }

    // Read the body (still enforce size)
    const buf = Buffer.from(await r.arrayBuffer());
    if (buf.length > MAX_BYTES) return bad(res, 413, 'Downloaded file exceeded limit');

    // Convert/resize safely to WEBP (works well for canvas & CDN)
    // SVG: rasterize; GIF: Sharp uses first frame.
    let img = sharp(buf, { animated: false, limitInputPixels: false });
    const meta = await img.metadata();

    // clamp size
    const w = meta.width || MAX_DIM;
    const h = meta.height || MAX_DIM;
    const scale = Math.min(1, MAX_DIM / Math.max(w, h));
    if (scale < 1) img = img.resize(Math.round(w * scale), Math.round(h * scale), { fit: 'inside' });

    const out = await img.webp({ quality: 90 }).toBuffer();
    const hash = hashHex(out).slice(0, 16);
    const ymd = new Date().toISOString().slice(0, 10); // YYYY-MM-DD
    const key = `rehost/${ymd}/${hash}.webp`;

    // Upload (upsert ok)
    const { error: upErr } = await supabase.storage.from(BUCKET).upload(key, out, {
      contentType: 'image/webp',
      upsert: true
    });
    if (upErr) return bad(res, 502, `Upload failed: ${upErr.message}`);

    // Build public URL (either Supabase public URL or your CDN)
    let cdnUrl;
    if (process.env.BASE_CDN_URL) {
      const base = process.env.BASE_CDN_URL.replace(/\/+$/, '');
      cdnUrl = `${base}/${key}`;
    } else {
      const { data: pub } = supabase.storage.from(BUCKET).getPublicUrl(key);
      cdnUrl = pub?.publicUrl;
    }

    return res.status(201).json({
      ok: true,
      cdnUrl,
      hash,
      bytes: out.length,
      width: (await sharp(out).metadata()).width || null,
      height: (await sharp(out).metadata()).height || null,
      sourceUrl: u.toString()
    });
  } catch (e) {
    console.error('[ingest-url] error:', e);
    return bad(res, 500, 'Ingest failed');
  }
});

export default router;
