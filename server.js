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
const axios = require("axios");
const cheerio = require("cheerio");

// RSS-style image preview parser
app.post("/api/rss-preview", async (req, res) => {
  const { url } = req.body;
  if (!url) return res.status(400).json({ success: false, error: "Missing URL" });

  try {
    const { data } = await axios.get(url, {
      headers: { 'User-Agent': 'CultureSchoolBot/1.0' }
    });
    const $ = cheerio.load(data);
    const images = [];

    $("img").each((i, el) => {
      const src = $(el).attr("src");
      if (src && src.startsWith("http")) {
        images.push(src);
      }
    });

    if (!images.length) return res.json({ success: false, images: [] });

    res.json({ success: true, images: [...new Set(images)].slice(0, 12) }); // Max 12
  } catch (err) {
    console.error("❌ RSS Preview error:", err.message);
    res.status(500).json({ success: false, error: "Feed parsing failed" });
  }
});


app.post("/api/delete-media-item", async (req, res) => {
  const { id } = req.body;
  if (!id) return res.status(400).json({ success: false, error: "Missing ID" });

  const { data, error } = await supabase
    .from("media_uploads") // 👈 use correct table
    .delete()
    .eq("id", id);

  if (error) {
    console.error("❌ Supabase delete error:", error);
    return res.status(500).json({ success: false, error: error.message });
  }

  res.json({ success: true, data });
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
app.post("/api/save-moodboard", async (req, res) => {
  const {
    email,
    created_by = email,
    username = "Anonymous",
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

    res.json({ success: true, board: data[0] }); // ✅ Return as 'board' for frontend match
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
// Get Single Moodboard by ID
app.get("/api/get-moodboard", async (req, res) => {
  const { id } = req.query;
  if (!id) return res.status(400).json({ success: false, message: "Missing board ID" });

  try {
    const { data, error } = await supabase
      .from("user_moodboards")
      .select("*")
      .eq("id", id)
      .single();

    if (error) throw error;
    res.json({ success: true, board: data });
  } catch (err) {
    console.error("❌ Fetch single moodboard error:", err.message);
    res.status(500).json({ success: false, error: err.message });
  }
});


// Update Moodboard
app.post("/api/update-moodboard", async (req, res) => {
  const { id, title, description, is_public, cover_image, tags, theme, link, preview_image } = req.body;

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
  if (link !== undefined) updates.link = link; // ✅ Add this line
  if (preview_image !== undefined) updates.preview_image = preview_image;


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
// Delete Image from Moodboard
app.post("/api/delete-board-image", async (req, res) => {
  const { imageId, boardId } = req.body;

  if (!imageId || !boardId) {
    return res.status(400).json({ success: false, error: "Missing imageId or boardId" });
  }

  try {
    const { error } = await supabase
      .from("board_images")
      .delete()
      .eq("id", imageId)
      .eq("board_id", boardId);

    if (error) throw error;

    res.json({ success: true });
  } catch (err) {
    console.error("❌ Delete board image error:", err.message);
    res.status(500).json({ success: false, error: err.message });
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
  const { boardId, url, caption = "", buy_link = "", media_type = "image" } = req.body;

  if (!boardId || !url) {
    return res.status(400).json({ success: false, error: "Missing boardId or url" });
  }

  try {
    const { data, error } = await supabase
      .from("cocoboard_media")
      .insert([
        {
          board_id: boardId,
          url,
          caption,
          buy_link,
          media_type
        }
      ])
      .select()
      .single();

    if (error) throw error;

    res.status(200).json({ success: true, media: data });
  } catch (err) {
    console.error("❌ Failed to add image to board:", err.message);
    res.status(500).json({ success: false, error: err.message });
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
app.post("/api/save-theme", async (req, res) => {
  const { email, profileTheme, modalTheme } = req.body;

  if (!email) return res.status(400).json({ success: false, error: "Missing email" });

  try {
    const { data, error } = await supabase
      .from("settings")
      .upsert([{ email, profileTheme, modalTheme }], { onConflict: ["email"] });

    if (error) throw error;

    res.json({ success: true, data });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});
app.get("/api/get-theme", async (req, res) => {
  const { email } = req.query;

  if (!email) return res.status(400).json({ error: "Missing email" });

  try {
    const { data, error } = await supabase
      .from("settings")
      .select("profileTheme, modalTheme")
      .eq("email", email)
      .single();

    if (error) throw error;

    res.json(data);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});
// ✅ Save CoCoBoard
app.post("/api/save-cocoboard", async (req, res) => {
  const {
    email,
    created_by = email,
    username = "Anonymous",
    title = "My Board",
    description = "",
    is_public = false,
    cover_image = "",
    tags = [],
    theme = "default",
  } = req.body;

  const created_at = new Date().toISOString();
  const updated_at = created_at;

  const title_slug = title.trim().toLowerCase().replace(/\s+/g, "-").replace(/[^\w-]/g, "");

  try {
    const { data, error } = await supabase
  .from("cocoboards")
  .insert([{
    email,
    created_by,
    username,
    title,
    title_slug,
    description,
    is_public,
    cover_image,
    tags: Array.isArray(tags) ? tags : [],
    theme,
    created_at,
    updated_at
  }])
  .select()
  .single(); // ✅ returns a single board

    if (error || !data) throw error;

    res.status(200).json({
      success: true,
      board: {
        id: data.id,
        title: data.title,
        description: data.description,
        cover_image: data.cover_image,
        images: [] // just send an empty list for now
      }
    });
    
    
  } catch (err) {
    console.error("❌ Failed to save cocoboard:", err);
    res.status(500).json({ success: false, error: err.message });
  }
});
// ✅ Save CoCoBoard Media
app.post("/api/save-cocoboard-media", async (req, res) => {
  try {
    const { board_id, url, caption = "", type = "image", buy_link = null } = req.body;

    const { data, error } = await supabase
      .from("cocoboard_media")
      .insert([{ board_id, url, caption, media_type: type, buy_link }]);

    if (error) throw error;

    res.status(200).json({ success: true, media: data[0] });
  } catch (err) {
    console.error("❌ Error saving media:", err.message);
    res.status(500).json({ success: false, error: err.message });
  }
});



// ✅ BACKEND ROUTE — Express
// ✅ Get Single CoCoBoard by ID or Slug
app.get("/api/get-cocoboard", async (req, res) => {
  const { id, slug } = req.query;
  if (!id && !slug) {
    return res.status(400).json({ success: false, message: "Missing board ID or slug" });
  }

  try {
    const { data, error } = await supabase
      .from("cocoboards")
      .select("*, cocoboard_media(*)")
      .eq(id ? "id" : "title_slug", id || slug)
      .single();

    if (error || !data) throw error;

    const images = (data.cocoboard_media || []).map(item => ({
      url: item.url,
      caption: item.caption,
      buy_link: item.buy_link,
      media_type: item.media_type
    }));
    console.log("🎯 Full board data:", data); // ADD THIS
    res.json({
      success: true,
      board: {
        id: data.id,
        title: data.title,
        description: data.description,
        cover_image: data.cover_image,
        images
      }
    });
  } catch (err) {
    console.error("❌ Fetch cocoboard error:", err.message);
    res.status(500).json({ success: false, error: err.message });
  }
});
app.get("/api/cocoboard-gallery", async (req, res) => {
  try {
    const { data, error } = await supabase
      .from("cocoboards")
      .select("id, title, cover_image, title_slug")
      .eq("is_public", true)
      .order("updated_at", { ascending: false });

    if (error) throw error;

    res.json({ success: true, boards: data });
  } catch (err) {
    console.error("❌ Fetch gallery error:", err.message);
    res.status(500).json({ success: false, error: err.message });
  }
});
// POST route to save OG content to Supabase
app.post("/api/save-og-content", async (req, res) => {
  const { title, description, image, url, publisher = "Unknown", email = null } = req.body;

  if (!title || !url || !image) {
    return res.status(400).json({ success: false, message: "Missing required OG fields." });
  }

  try {
    const { data, error } = await supabase
      .from("media_uploads")
      .insert([{
        title,
        caption: description,
        image_url: image,
        external_url: url,
        publisher,
        publicwall: false, // ✅ Set private by default
        email // Optional: associate with user
      }]);

    if (error) throw error;

    res.status(200).json({ success: true, data });
  } catch (err) {
    console.error("❌ Error saving OG content:", err.message);
    res.status(500).json({ success: false, error: err.message });
  }
});
// ✅ Upload Media to Supabase Storage

const Busboy = require("busboy");

app.post("/api/upload-media", (req, res) => {
  const path = req.query.path;
  if (!path) return res.status(400).json({ success: false, error: "Missing file path" });

  const busboy = Busboy({ headers: req.headers }); 
  let fileBuffer = [];

  busboy.on("file", (fieldname, file, filename, encoding, mimetype) => {
    file.on("data", (data) => fileBuffer.push(data));

    file.on("end", async () => {
      try {
        const finalBuffer = Buffer.concat(fileBuffer);

        const { data, error } = await supabase.storage
          .from("public-uploads")
          .upload(path, finalBuffer, {
            contentType: mimetype,
            upsert: true
          });

        if (error) {
          console.error("❌ Upload error:", error.message);
          return res.status(500).json({ success: false, error: error.message });
        }

        const { publicUrl } = supabase.storage
          .from("public-uploads")
          .getPublicUrl(path);

        return res.status(200).json({ success: true, publicUrl });
      } catch (err) {
        console.error("❌ Unexpected upload error:", err);
        return res.status(500).json({ success: false, error: err.message });
      }
    });
  });

  busboy.on("error", (err) => {
    console.error("❌ Busboy error:", err);
    res.status(500).json({ success: false, error: "Busboy processing failed" });
  });

  req.pipe(busboy);
});






// WebSocket + Express listener
const PORT = process.env.PORT || 5055;
server.listen(PORT, () => {
  console.log(`🚀 Server & WebSocket live on port ${PORT}`);
});
