// server.js (Render-Ready with Express + WebSocket + Supabase)

const express = require('express');
const http = require('http');
const cors = require('cors');
const setupWebSocket = require('./websocket'); // your websocket logic from earlier
const bodyParser = require('body-parser');
require('dotenv').config();

const app = express();
const server = http.createServer(app);
setupWebSocket(server); // ✅ Attach WebSocket
app.get("/", (req, res) => {
  res.send("✅ CultureSchool backend is running!");
});

app.use(cors());
app.use(bodyParser.json());

// ✅ Supabase Client
const { createClient } = require('@supabase/supabase-js');
const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY
);

// ✅ Save Data to Supabase
// ✅ Save Data to Supabase (email-only logic)
app.post('/api/save-to-supabase', async (req, res) => {
  try {
    const data = req.body;

    if (!data.email) {
      return res.status(400).json({ success: false, message: 'Missing email' });
    }

    const { data: existing, error: fetchErr } = await supabase
      .from('users')
      .select('*')
      .eq('email', data.email)
      .single();

    if (fetchErr && fetchErr.code !== 'PGRST116') throw fetchErr;

    let response;
    if (existing) {
      response = await supabase
        .from('users')
        .update(data)
        .eq('email', data.email);
    } else {
      response = await supabase.from('users').insert([data]);
    }

    res.json({ success: true, message: '✅ Saved to Supabase', response });
  } catch (err) {
    console.error('❌ Supabase Save Error:', err);
    res.status(500).json({ success: false, error: err.message });
  }
});
// ✅ Get User by Email
app.get('/api/get-user', async (req, res) => {
  const { email } = req.query;

  if (!email) {
    return res.status(400).json({ success: false, message: 'Missing email in query' });
  }

  try {
    const { data, error } = await supabase
      .from('users')
      .select('*')
      .eq('email', email)
      .single();

    if (error) throw error;

    res.json({ success: true, data });
  } catch (err) {
    console.error('❌ Error fetching user:', err);
    res.status(500).json({ success: false, error: err.message });
  }
});


// ✅ Purge All Circle Messages by Group
app.post('/api/delete-all-circle-messages', async (req, res) => {
  try {
    const { group_id } = req.body;
    if (!group_id) return res.status(400).json({ success: false, message: 'Missing group_id' });

    const { data, error } = await supabase
      .from('users')
      .delete()
      .eq('invite_code', group_id);

    if (error) throw error;

    res.json({ success: true, data });
  } catch (err) {
    console.error('❌ Purge Error:', err);
    res.status(500).json({ success: false, error: err.message });
  }
});
// Get frame settings from Supabase
app.get("/api/get-frame-settings", async (req, res) => {
  try {
    const { data, error } = await supabase
      .from("settings")
      .select("value")
      .eq("key", "profile_frames")
      .single();

    if (error) return res.status(500).json({ success: false, error });

    return res.json({ success: true, value: data.value });
  } catch (err) {
    return res.status(500).json({ success: false, error: err.message });
  }
});
// ✅ GET Circle Data by Group ID
app.get('/api/get-circle-from-supabase', async (req, res) => {
  const group_id = req.query.group_id;

  if (!group_id) {
    return res.status(400).json({ success: false, message: 'Missing group_id' });
  }

  try {
    const { data, error } = await supabase
      .from('users')
      .select('*')
      .eq('invite_code', group_id);

    if (error) throw error;

    if (!data || data.length === 0) {
      return res.json({ success: true, tribe_members: [], messages: [], pins: [] });
    }

    // We'll just return the *first match* for now
    const userData = data[0];
    const {
      tribe_members = [],
      messages = [],
      pins = [],
      images = [],
    } = userData;

    return res.json({ success: true, tribe_members, messages, pins, images });
  } catch (err) {
    console.error('❌ Supabase fetch error:', err);
    return res.status(500).json({ success: false, error: err.message });
  }
});

// ✅ Save a pinned item
app.post('/api/pin-item', async (req, res) => {
  const { email, title, imageUrl, sourceUrl, description, tags, mood, boardId } = req.body;

  const { data, error } = await supabase
    .from('pins')
    .insert([{
      email,
      title,
      image_url: imageUrl,
      source_url: sourceUrl,
      description,
      tags,
      mood,
      board_id: boardId,
      created_at: new Date().toISOString()
    }]);

  if (error) return res.status(500).json({ success: false, error });
  res.json({ success: true, data });
});

// ✅ Save a pinned item
app.post('/api/pin-item', async (req, res) => {
  const { email, title, imageUrl, sourceUrl, description, tags, mood, boardId } = req.body;

  const { data, error } = await supabase
    .from('pins')
    .insert([{
      email,
      title,
      image_url: imageUrl,
      source_url: sourceUrl,
      description,
      tags,
      mood,
      board_id: boardId,
      created_at: new Date().toISOString()
    }]);

  if (error) return res.status(500).json({ success: false, error });
  res.json({ success: true, data });
});

// ✅ Get all pins (optionally filtered)
app.get('/api/get-pins', async (req, res) => {
  console.log("🔎 Incoming GET /api/get-pins request:", req.query);
  const { email, boardId } = req.query;
  let query = supabase.from('pins').select('*').order('created_at', { ascending: false });

  if (email) query = query.eq('email', email);
  if (boardId) query = query.eq('board_id', boardId);

  const { data, error } = await query;
  if (error) return res.status(500).json({ success: false, error });
  res.json({ success: true, data });
});

app.post("/api/save-media-item", async (req, res) => {
  const { email, url, reactions, caption, mood } = req.body;

  const { data, error } = await supabase.from("media_uploads").insert([
    {
      email,
      url,
      reactions,
      caption,
      mood,
      created_at: new Date().toISOString(),
    },
  ]);

  if (error) return res.status(500).json({ success: false, error });
  res.json({ success: true, data });
});
app.get("/api/test-connection", async (req, res) => {
  try {
    const { data, error } = await supabase.from("users").select("email").limit(1);
    if (error) throw error;
    res.json({ success: true, message: "Supabase connected", data });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});
app.get('/api/supabase-keys', (req, res) => {
  res.json({
    url: process.env.SUPABASE_PROJECT_URL,
    anonKey: process.env.SUPABASE_ANON_KEY
  });
});
app.post("/api/save-inspiration", async (req, res) => {
  const { email, url, title, mood, reactions } = req.body;

  if (!email || !url) {
    return res.status(400).json({ success: false, error: "Missing email or url" });
  }

  const { data, error } = await supabase.from("media_uploads").upsert([
    {
      email,
      url,
      title,
      mood,
      reactions,
      created_at: new Date().toISOString(),
    },
  ]);

  if (error) return res.status(500).json({ success: false, error });
  res.json({ success: true, data });
});


const PORT = process.env.PORT || 5055;
server.listen(PORT, () => {
  console.log(`🚀 Server & WebSocket live on port ${PORT}`);
});
