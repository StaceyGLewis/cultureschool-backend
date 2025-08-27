// netlify/functions/seed-board.js
import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_SERVICE_KEY = process.env.SUPABASE_SERVICE_KEY; // service role (needed for upserts)

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

// Helpers
const slugify = (s) => (s || '').toLowerCase()
  .replace(/[^\w]+/g, '-').replace(/(^-|-$)+/g, '').slice(0, 64);

export const handler = async (event) => {
  if (event.httpMethod !== 'POST') {
    return { statusCode: 405, body: 'Method Not Allowed' };
  }

  try {
    const payload = JSON.parse(event.body || '{}');
    // payload: { board_title, board_slug?, creator_email, tiles:[{title,description,image_url,buy_link,category,media_url,type}] }

    if (!payload.creator_email) {
      return { statusCode: 400, body: JSON.stringify({ ok:false, message:'creator_email required' }) };
    }

    const board_slug = slugify(payload.board_slug || payload.board_title || 'market');
    const board_title = payload.board_title || 'Market Board';
    const creator_email = payload.creator_email.trim();

    // 1) Ensure board exists (boards table: id, slug, title, owner_email, created_at)
    let { data: board, error: findErr } = await supabase
      .from('boards')
      .select('*')
      .eq('slug', board_slug)
      .maybeSingle();

    if (findErr) throw findErr;

    if (!board) {
      const { data: inserted, error: insErr } = await supabase
        .from('boards')
        .insert([{ slug: board_slug, title: board_title, owner_email: creator_email }])
        .select()
        .single();
      if (insErr) throw insErr;
      board = inserted;
    }

    const board_id = board.id;

    // 2) Normalize tiles
    const tiles = (payload.tiles || []).map((t) => ({
      board_id,
      email: creator_email,
      title: t.title || '',
      caption: t.description || t.caption || '',
      type: t.type || (t.media_url ? 'video' : (t.image_url ? 'image' : 'text')),
      image_url: t.image_url || '',
      media_url: t.media_url || '',
      buy_link: t.buy_link || '',
      category: t.category || '',
    }));

    // 3) Insert tiles (flourish_tiles table: id, board_id, email, title, caption, type, image_url, media_url, buy_link, category)
    //    Simple approach: insert all; let duplicates be handled later (or add a unique constraint if you want).
    let inserted = [];
    if (tiles.length) {
      const { data, error: tilesErr } = await supabase
        .from('flourish_tiles')
        .insert(tiles)
        .select();
      if (tilesErr) throw tilesErr;
      inserted = data || [];
    }

    // 4) Build a ready-to-use SEED object for Flourish drawer
    const SEED = {
      board: { id: board_id, slug: board_slug, title: board_title },
      tiles: (inserted.length ? inserted : tiles).map(t => ({
        title: t.title,
        caption: t.caption,
        type: t.type,
        image_url: t.image_url,
        media_url: t.media_url,
        buy_link: t.buy_link
      }))
    };

    // Encode seed for your Flourish seed link
    const seedB64 = Buffer.from(JSON.stringify(SEED), 'utf8').toString('base64');

    // Your public wall URL (adjust to your domain)
    const wallUrl = `https://seaport.cultureschool.org/?board=${encodeURIComponent(board_slug)}`;

    // Your Flourish drawer page with seed:
    const flourishDrawer = `https://cultureschool.org/pages/cococreate-flourish?seed=${encodeURIComponent(seedB64)}`;

    return {
      statusCode: 200,
      body: JSON.stringify({
        ok: true,
        board: { id: board_id, slug: board_slug, title: board_title },
        count: inserted.length || tiles.length,
        wallUrl,
        flourishDrawer,
        // for debugging:
        // seedB64
      })
    };

  } catch (err) {
    console.error('seed-board error:', err);
    return { statusCode: 500, body: JSON.stringify({ ok:false, message: err.message }) };
  }
};
