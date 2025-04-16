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
app.use(bodyParser.json({ limit: '25mb' }));
app.use(bodyParser.urlencoded({ extended: true, limit: '25mb' }));

app.get("/", (req, res) => {
  res.send("✅ CultureSchool backend is running!");
});

// Save or Update user by email
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

// Fetch user by email
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

// Save or update media
app.post("/api/save-media-item", async (req, res) => {
  try {
    const { email, url, reactions, caption, username, tags = [] } = req.body;

    const { data, error } = await supabase.from("media_uploads").upsert([
      {
        email,
        username,
        url,
        reactions,
        caption,
        tags, // ✅ new field
        publicwall: true, // ✅ ensures visibility
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


// Get media
app.get("/api/get-media-items", async (req, res) => {
  try {
    const { data, error } = await supabase
      .from("media_uploads") // 👈 FIXED: match the table used in upsert
      .select("*")
      .eq("publicwall", true)
      .order("created_at", { ascending: false }) // 👈 match your field name
      .limit(50);

    if (error) throw error;

    res.json({ success: true, data });
  } catch (err) {
    console.error("❌ Get media error:", err);
    res.status(500).json({ success: false, error: err.message });
  }
});


app.post("/api/delete-media-item", async (req, res) => {
  const { url } = req.body;
  if (!url) return res.status(400).json({ success: false, message: "Missing URL" });

  try {
    const { error } = await supabase.from("media_uploads").delete().eq("url", url);
    if (error) throw error;
    res.json({ success: true, message: "✅ Deleted" });
  } catch (err) {
    console.error("❌ Delete error:", err);
    res.status(500).json({ success: false, error: err.message });
  }
});

// Frame Settings
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

// Test
app.get("/api/test-connection", async (req, res) => {
  try {
    const { data, error } = await supabase.from("users").select("email").limit(1);
    if (error) throw error;
    res.json({ success: true, message: "Supabase connected", data });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// Debug Keys
app.get('/api/supabase-keys', (req, res) => {
  res.json({
    url: process.env.SUPABASE_PROJECT_URL,
    anonKey: process.env.SUPABASE_ANON_KEY
  });
});

// Clean Messages
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

// Save Moodboard
// Save Moodboard
app.post("/api/save-moodboard", async (req, res) => {
  const {
    email,                         // required for sync
    created_by = email,            // who made the board (same as email)
    username = "Anonymous",        // display name on the board
    title = "My Board",
    description = "",
    is_public = false,
    cover_image = "",
    tags = [],
    theme = "default",
  } = req.body;

  const created_at = new Date().toISOString();
  const updated_at = created_at;

  try {
    const { data, error } = await supabase
      .from("user_moodboards")
      .insert([
        {
          user_email: email,
          created_by,
          username,
          title,
          description,
          is_public,
          cover_image,
          tags,
          theme,
          created_at,
          updated_at,
        },
      ]);

    if (error) throw error;
    res.json({ success: true, data });
  } catch (err) {
    console.error("❌ Failed to save moodboard:", err);
    res.status(500).json({ success: false, error: err.message });
  }
});

// Get Moodboards
app.get("/api/get-moodboards", async (req, res) => {
  const { email } = req.query;
  if (!email) return res.status(400).json({ success: false, message: "Missing email" });

  try {
    const { data, error } = await supabase
      .from("user_moodboards")
      .select("*")
      .eq("user_email", email)
      .order("updated_at", { ascending: false });

    if (error) throw error;
    res.json({ success: true, boards: data });
  } catch (err) {
    console.error("❌ Fetch moodboards error:", err.message);
    res.status(500).json({ success: false, error: err.message });
  }
});

// Update Moodboard
app.post("/api/update-moodboard", async (req, res) => {
  const { id, title, description, is_public, cover_image, tags, theme } = req.body;

  if (!id) return res.status(400).json({ success: false, message: "Missing board ID" });

  const updates = {
    updated_at: new Date().toISOString()
  };
  if (title !== undefined) updates.title = title;
  if (description !== undefined) updates.description = description;
  if (is_public !== undefined) updates.is_public = is_public;
  if (cover_image !== undefined) updates.cover_image = cover_image;
  if (tags !== undefined) updates.tags = tags;
  if (theme !== undefined) updates.theme = theme;

  try {
    const { error } = await supabase
      .from("user_moodboards")
      .update(updates)
      .eq("id", id);

    if (error) throw error;
    res.json({ success: true });
  } catch (err) {
    console.error("❌ Update board error:", err.message);
    res.status(500).json({ success: false, error: err.message });
  }
});

// Reorder Images
app.post('/api/reorder-images', async (req, res) => {
  const { boardId, images } = req.body;
  if (!boardId || !Array.isArray(images)) {
    return res.status(400).json({ success: false, error: 'Invalid payload' });
  }

  try {
    for (let i = 0; i < images.length; i++) {
      await supabase
        .from('board_images')
        .update({ sort_order: i })
        .eq('id', images[i].id);
    }

    res.json({ success: true });
  } catch (err) {
    console.error('❌ Reorder error:', err);
    res.status(500).json({ success: false, error: 'Server error' });
  }
});

// Delete Moodboard
app.post("/api/delete-moodboard", async (req, res) => {
  const { id } = req.body;
  if (!id) return res.status(400).json({ success: false, message: "Missing board ID" });

  try {
    const { error } = await supabase
      .from("user_moodboards")
      .delete()
      .eq("id", id);

    if (error) throw error;
    res.json({ success: true });
  } catch (err) {
    console.error("❌ Delete board error:", err.message);
    res.status(500).json({ success: false, error: err.message });
  }
});

// Add Image to Moodboard
app.post("/api/add-image-to-board", async (req, res) => {
  const { boardId, url } = req.body;

  if (!boardId || !url) {
    return res.status(400).json({ success: false, error: "Missing boardId or url" });
  }

  try {
    const result = await supabase
      .from("board_images")
      .insert([{ board_id: boardId, url }]);

    res.json({ success: true, imageId: result.data?.[0]?.id });
  } catch (err) {
    console.error("Error saving board image", err);
    res.status(500).json({ success: false, error: "Failed to save image" });
  }
});

// Get Images from Moodboard
app.get("/api/get-board-images", async (req, res) => {
  const boardId = req.query.id;

  if (!boardId) return res.status(400).json({ success: false, error: "Missing board ID" });

  try {
    const { data, error } = await supabase
      .from("board_images")
      .select("url, sort_order, id")
      .eq("board_id", boardId)
      .order("sort_order", { ascending: true });

    if (error) throw error;

    res.json({ success: true, images: data });
  } catch (err) {
    console.error("Fetch error:", err);
    res.status(500).json({ success: false, error: "Could not fetch images" });
  }
});

// WebSocket + Express listener
const PORT = process.env.PORT || 5055;
server.listen(PORT, () => {
  console.log(`🚀 Server & WebSocket live on port ${PORT}`);
});
