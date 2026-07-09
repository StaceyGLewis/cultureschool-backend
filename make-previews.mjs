// make-previews.mjs
// ---------------------------------------------------------------------------
// ONE-TIME migration for coco_art images:
//   1. fetch the full original from the current (Shopify CDN) image_url
//   2. upload that original into the PRIVATE `assets` bucket at print_path
//   3. build a watermarked, low-res preview
//   4. upload the preview into a PUBLIC `previews` bucket
//   5. repoint coco_art.image_url at the public preview
//
// Safe to re-run: rows already migrated (image_url no longer a Shopify CDN URL)
// are skipped, so it never overwrites a private original with a small preview.
//
// SETUP
//   Node 18+ (for global fetch)
//   npm init -y && npm i @supabase/supabase-js sharp
//   Create a PUBLIC bucket named `previews`; keep `assets` PRIVATE.
//
// RUN
//   SUPABASE_URL="https://qwulthvbwujfehgdegtn.supabase.co" \
//   SUPABASE_SERVICE_ROLE_KEY="<service_role_key>" \
//   node make-previews.mjs
//
// Your coco_art CSV export is a backup of the original image_url values if you
// ever need to roll back.
// ---------------------------------------------------------------------------

import { createClient } from '@supabase/supabase-js';
import sharp from 'sharp';

const SUPABASE_URL = process.env.SUPABASE_URL;
const SERVICE_KEY  = process.env.SUPABASE_SERVICE_ROLE_KEY;

const PRIVATE_BUCKET  = 'assets';     // private — holds print-ready originals
const PREVIEW_BUCKET  = 'previews';   // PUBLIC  — holds watermarked low-res
const PREVIEW_MAX     = 1000;         // longest edge, px
const PREVIEW_QUALITY = 72;           // webp quality
const WM_TEXT         = 'CultureSchool';
const ONLY_MIGRATE_FROM = 'cdn.shopify.com'; // guard: skip already-migrated rows

if (!SUPABASE_URL || !SERVICE_KEY) {
  console.error('Set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY env vars.');
  process.exit(1);
}
const sb = createClient(SUPABASE_URL, SERVICE_KEY, { auth: { persistSession: false } });

// tiled diagonal watermark, burned into every preview
const wmTile = Buffer.from(
`<svg xmlns="http://www.w3.org/2000/svg" width="300" height="180">
  <text x="16" y="112" transform="rotate(-24 16 112)" font-family="Georgia, serif"
    font-size="26" fill="white" fill-opacity="0.55"
    stroke="black" stroke-opacity="0.18" stroke-width="0.8">${WM_TEXT}</text>
</svg>`);

async function ensurePreviewBucket() {
  const { error } = await sb.storage.createBucket(PREVIEW_BUCKET, { public: true });
  if (error && !/exists/i.test(error.message)) throw error;
}

async function run() {
  await ensurePreviewBucket();

  const { data: rows, error } = await sb
    .from('coco_art')
    .select('id, image_url, print_path')
    .eq('is_active', true);
  if (error) throw error;

  let ok = 0, skip = 0, fail = 0;
  for (const r of rows) {
    if (!r.image_url || !r.image_url.includes(ONLY_MIGRATE_FROM)) { skip++; continue; }
    try {
      // 1) fetch full original
      const resp = await fetch(r.image_url);
      if (!resp.ok) throw new Error(`fetch ${resp.status}`);
      const buf = Buffer.from(await resp.arrayBuffer());

      // 2) upload ORIGINAL to the private bucket at print_path
      const origPath = r.print_path || `originals/${r.id}.png`;
      const up1 = await sb.storage.from(PRIVATE_BUCKET)
        .upload(origPath, buf, { upsert: true, contentType: resp.headers.get('content-type') || 'image/png' });
      if (up1.error) throw up1.error;

      // 3) watermarked low-res preview
      const { data: resizedData, info } = await sharp(buf)
        .resize({ width: PREVIEW_MAX, height: PREVIEW_MAX, fit: 'inside', withoutEnlargement: true })
        .toBuffer({ resolveWithObject: true });

      // Scale watermark tile down if image is smaller than the 300×180 SVG tile
      const tileW = Math.min(300, Math.floor(info.width  * 0.6));
      const tileH = Math.min(180, Math.floor(info.height * 0.6));
      const wmInput = (tileW < 300 || tileH < 180)
        ? await sharp(wmTile).resize(tileW, tileH, { fit: 'fill' }).toBuffer()
        : wmTile;

      const preview = await sharp(resizedData)
        .composite([{ input: wmInput, tile: true, blend: 'over' }])
        .webp({ quality: PREVIEW_QUALITY })
        .toBuffer();

      // 4) upload preview to the PUBLIC bucket
      const prevPath = `${r.id}.webp`;
      const up2 = await sb.storage.from(PREVIEW_BUCKET)
        .upload(prevPath, preview, { upsert: true, contentType: 'image/webp' });
      if (up2.error) throw up2.error;

      // 5) repoint image_url at the public preview
      const { data: pub } = sb.storage.from(PREVIEW_BUCKET).getPublicUrl(prevPath);
      const upd = await sb.from('coco_art').update({ image_url: pub.publicUrl }).eq('id', r.id);
      if (upd.error) throw upd.error;

      ok++;
      console.log(`✓ ${r.id}`);
    } catch (e) {
      fail++;
      console.warn(`✗ ${r.id}: ${e.message}`);
    }
  }
  console.log(`\nDone. ${ok} migrated · ${skip} skipped (already done / not CDN) · ${fail} failed.`);
}

run().catch(e => { console.error(e); process.exit(1); });
