// netlify/functions/get-media-items.js
import { createClient } from '@supabase/supabase-js';

const CORS = {
  'Access-Control-Allow-Origin': '*', // or your domain
  'Access-Control-Allow-Methods': 'GET, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, x-user-email'
};

export default async (req, res) => {
  if (req.method === 'OPTIONS') {
    res.writeHead(204, CORS); return res.end();
  }

  try {
    const SUPABASE_URL  = process.env.SUPABASE_URL;
    const SERVICE_ROLE  = process.env.SUPABASE_SERVICE_ROLE; // server-only!
    if (!SUPABASE_URL || !SERVICE_ROLE) {
      console.error('Missing env SUPABASE_URL or SUPABASE_SERVICE_ROLE');
      res.writeHead(500, CORS);
      return res.end(JSON.stringify({ error: 'Server misconfigured' }));
    }

    const sb = createClient(SUPABASE_URL, SERVICE_ROLE, { auth: { persistSession: false } });

    // Filters
    const email = (req.headers['x-user-email'] || '').toLowerCase();
    const limit = Math.min(parseInt(req.query.limit || '24', 10), 100);
    const since = req.query.since ? new Date(req.query.since).toISOString() : null;

    let q = sb
      .from('cocoboard_media')
      .select('id,board_id,title,caption,description,media_type,image_url,media_url,link,cta_link,source_url,text_excerpt,creator_email,collection,show_on_profile,created_at', { count: 'exact' })
      .order('created_at', { ascending: false })
      .limit(limit);

    // policy: admins can see all, otherwise only public + own items
    const isAdmin = email && ['stacey.a.grant@gmail.com'].includes(email);
    if (!isAdmin) {
      q = q.or(`show_on_profile.eq.true,creator_email.eq.${email}`);
    }
    if (since) {
      q = q.gte('created_at', since);
    }

    const { data, error } = await q;
    if (error) {
      console.error('Supabase select error:', error);
      res.writeHead(500, CORS);
      return res.end(JSON.stringify({ error: 'DB error' }));
    }

    res.writeHead(200, { ...CORS, 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ ok: true, count: data.length, items: data }));
  } catch (e) {
    console.error('Unhandled get-media-items error:', e);
    res.writeHead(500, CORS);
    res.end(JSON.stringify({ error: 'Unhandled error' }));
  }
};
