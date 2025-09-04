export default async (req) => {
    const url = new URL(req.url);
    // /og/:board?template=story-carousel
    const [, , boardRaw] = url.pathname.split('/');
    const template = url.searchParams.get('template') || 'flourish-live-viewer';
  
    const SUPA_URL = 'https://qwulthvbwujfehgdegtn.supabase.co';
    const SUPA_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...SoQ'; // anon key
  
    const h = { 'apikey': SUPA_KEY, 'Authorization': 'Bearer ' + SUPA_KEY };
  
    // fetch board meta by id or slug
    const metaRes = await fetch(
      `${SUPA_URL}/rest/v1/cocoboards?select=id,slug,title,description,banner_url&or=(id.eq.${encodeURIComponent(boardRaw)},slug.eq.${encodeURIComponent(boardRaw)})&limit=1`,
      { headers: h }
    );
    const metaArr = await metaRes.json();
    const meta = metaArr?.[0] || {};
  
    // pick preview image: banner_url > first image tile > fallback
    let ogimg = meta.banner_url || '';
    if (!ogimg) {
      const tilesRes = await fetch(
        `${SUPA_URL}/rest/v1/cocoboard_media?select=image_url,media_url&board_id=eq.${encodeURIComponent(meta.id || boardRaw)}&order=created_at.asc&limit=12`,
        { headers: h }
      );
      const tiles = await tilesRes.json();
      ogimg = (tiles.find(t => t?.image_url)?.image_url) || 'https://your-cdn/og-default.jpg';
    }
  
    const title = meta.title || 'CoCo Stories';
    const desc  = meta.description || 'Swipeable stories from creators.';
    const target = `https://cultureschool.org/pages/${template}?board=${encodeURIComponent(meta.id || boardRaw)}`;
  
    const esc = (s='') => (s+'').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/"/g,'&quot;');
  
    const html = `<!doctype html><html><head>
  <meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
  <title>${esc(title)}</title>
  <link rel="canonical" href="${target}">
  <meta property="og:type" content="website">
  <meta property="og:site_name" content="CoCo Spark">
  <meta property="og:title" content="${esc(title)}">
  <meta property="og:description" content="${esc(desc)}">
  <meta property="og:image" content="${esc(ogimg)}">
  <meta property="og:image:width" content="1200"><meta property="og:image:height" content="630">
  <meta name="twitter:card" content="summary_large_image">
  <meta name="twitter:title" content="${esc(title)}">
  <meta name="twitter:description" content="${esc(desc)}">
  <meta name="twitter:image" content="${esc(ogimg)}">
  <meta http-equiv="refresh" content="0; url=${target}">
  </head><body>
    <a href="${target}">Open ${esc(title)}</a>
  </body></html>`;
  
    return new Response(html, { headers: { 'content-type': 'text/html; charset=utf-8' } });
  };
  
  export const config = { path: '/og/*' };
  