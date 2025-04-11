const express = require('express');
const http = require('http');
const cors = require('cors');
const setupWebSocket = require('./websocket');
const bodyParser = require('body-parser');
require('dotenv').config();

const { createClient } = require('@supabase/supabase-js');
const app = express();
const server = http.createServer(app);
setupWebSocket(server);

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY
);

app.use(cors());
app.use(bodyParser.json({ limit: '10mb' }));
app.use(bodyParser.urlencoded({ extended: true, limit: '10mb' }));


app.get("/", (req, res) => {
  res.send("✅ CultureSchool backend is running!");
});

// 🧠 Save or Update user by email
app.post('/api/save-to-supabase', async (req, res) => {
  try {
    const data = req.body;
    if (!data.email) return res.status(400).json({ success: false, message: 'Missing email' });

    const { data: existing, error: fetchErr } = await supabase
      .from('users')
      .select('*')
      .eq('email', data.email)
      .single();

    if (fetchErr && fetchErr.code !== 'PGRST116') throw fetchErr;

    const response = existing
      ? await supabase.from('users').update(data).eq('email', data.email)
      : await supabase.from('users').insert([data]);

    res.json({ success: true, message: '✅ Saved to Supabase', response });
  } catch (err) {
    console.error('❌ Supabase Save Error:', err);
    res.status(500).json({ success: false, error: err.message });
  }
});

// 🧠 Fetch user by email
app.get('/api/get-user', async (req, res) => {
  const { email } = req.query;
  if (!email) return res.status(400).json({ success: false, message: 'Missing email' });

  try {
    const { data, error } = await supabase
      .from('users')
      .select('*')
      .eq('email', email)
      .single();

    if (error) throw error;
    res.json({ success: true, data });
  } catch (err) {
    console.error('❌ Get user error:', err);
    res.status(500).json({ success: false, error: err.message });
  }
});

// ✅ Save or update media uploads
app.post("/api/save-media-item", async (req, res) => {
  try {
    const { email, url, reactions, caption, mood } = req.body;

    const { data, error } = await supabase.from("media_uploads").upsert([
      {
        email,
        url,
        reactions,
        caption,
        mood,
        created_at: new Date().toISOString(),
      },
    ]);

    if (error) throw error;
    res.json({ success: true, data });

  } catch (err) {
    console.error("❌ Save media error:", err);
    res.status(500).json({ success: false, error: err.message });
  }
});

// ✅ Get media uploads by email
app.get('/api/get-media-items', async (req, res) => {
  const { email } = req.query;
  if (!email) return res.status(400).json({ success: false, message: 'Missing email' });

  try {
    const { data, error } = await supabase
      .from('media_uploads')
      .select('*')
      .eq('email', email)
      .order('created_at', { ascending: false });

    if (error) throw error;
    res.json({ success: true, data });
  } catch (err) {
    console.error('❌ Get media error:', err);
    res.status(500).json({ success: false, error: err.message });
  }
});

// 🔄 Get Frame Settings
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

// ✅ Test Connection
app.get("/api/test-connection", async (req, res) => {
  try {
    const { data, error } = await supabase.from("users").select("email").limit(1);
    if (error) throw error;
    res.json({ success: true, message: "Supabase connected", data });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// ✅ Get Supabase Keys (for debugging)
app.get('/api/supabase-keys', (req, res) => {
  res.json({
    url: process.env.SUPABASE_PROJECT_URL,
    anonKey: process.env.SUPABASE_ANON_KEY
  });
});

// ✅ Clean Up Circle Messages
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

// 🌐 WebSocket + Express listener
const PORT = process.env.PORT || 5055;
server.listen(PORT, () => {
  console.log(`🚀 Server & WebSocket live on port ${PORT}`);
});
