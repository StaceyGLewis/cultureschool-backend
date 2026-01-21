const express = require('express');
const http = require('http');
const cors = require('cors'); // ✅ Only once!
const setupWebSocket = require('./websocket');
const bodyParser = require('body-parser');
const { v4: uuidv4 } = require('uuid');
const { exec } = require('child_process');
const fs = require('fs');
const path = require('path');
const axios = require('axios');
const CryptoJS = require('crypto-js');
require('dotenv').config();
const { createClient } = require('@supabase/supabase-js');
const fetch = require('node-fetch');
// ===== imports (top of server.js) =====

const { JSDOM } = require("jsdom");
const { Readability } = require("@mozilla/readability");
const nlp = require("compromise");


// --- OpenAI (SDK) ---

const OpenAI = require('openai');
if (!process.env.OPENAI_API_KEY) {
  throw new Error('OPENAI_API_KEY is missing from .env');
}
const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });
const PEXELS_API_KEY  = process.env.PEXELS_API_KEY;
const PIXABAY_API_KEY = process.env.PIXABAY_API_KEY;
const FREESOUND_TOKEN = process.env.FREESOUND_TOKEN;

const app = express();
const server = http.createServer(app);
setupWebSocket(server);

// (optional) expose the client to other route files via app
app.set('openai', openai);
app.use(express.json({ limit: '10mb' }));  // needed for JSON body {prompt:"..."}


const OPENCAGE_API_KEY = process.env.OPENCAGE_API_KEY;
const elevenlabsRoute = require('./routes/elevenlabs');

// If you still want a variable, use this (but you don’t need both):
// const OPENAI_API_KEY = process.env.OPENAI_API_KEY;

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY
);

// ✅ Only one CORS declaration with all allowed origins
// server.js (Render)
// npm i cors if you haven't


// 1) Simple whitelist — NO trailing slashes
const ALLOWED_ORIGINS = [
  [
  'https://cultureschool.org',
  'https://www.cultureschool.org',  
  'https://cocoboard-preview-html.netlify.app',
  'https://coco-collector.netlify.app',
  'https://collector-desktop.netlify.app',
  'https://collector-mobile.netlify.app',
  'https://explore-cocospark.netlify.app',
  'https://ultimate-viewer.netlify.app',
  'https://flourish-viewer.netlify.app',
  'https://travel-luxe-viewer.netlify.app',
  'https://story-carousel-viewer.netlify.app',
  'https://event-collector.netlify.app',
  'https://coco-admin.netlify.app',
  'https://coco-popups.netlify.app',
  'https://coco-popups.cultureschool.org',
  'https://coco-course-viewer.netlify.app',
  'https://coco-flourish-ultimate.netlify.app',
  'https://cococreate-flourish.netlify.app',
  'https://creative-market-viewer.netlify.app',
  'https://flourish-ultimate.netlify.app',
  'https://mosaic-viewer.netlify.app',
  'https://magazine-viewer.netlify.app',
  'https://gallery-viewer.netlify.app',
  'https://kinetic-zine-viewer.netlify.app',
  'https://coco-speak.netlify.app',
  'https://cocoqr.netlify.app',
  'https://cococreator-assets-hub.netlify.app',
  'https://coco-insights-viewer.netlify.app',
  'https://coco-invite-template.netlify.app',
  'https://coco-assets-library.netlify.app',
  'https://farmers-market-viewer.netlify.app',
  'https://coco-admin-editor.netlify.app',
  'https://parisian-market-viewer.netlify.app/',
  'https://farmers-market-viewer-demo.netlify.app/',
  'https://coco-daily-inspo.netlify.app',
  'https://clay-arch-studio.netlify.app/',
  'https://holiday-night-shoppe.netlify.app/',
  'https://holiday-shoppe-booth-green.netlify.app/',
  'https://holiday-shoppe-purple.netlify.app/',
  'https://fancy-embossed-holiday-popup.netlify.app/',
  'https://holiday-festival-of-lights.netlify.app/',
  'https://rustic-market-viewer.netlify.app/',
  'https://holiday-notebook-shoppe.netlify.app/',
  'https://showcase-viewer.netlify.app/', 
  'https://theme-viewer.netlify.app/'
];


// 2) Simple CORS options — keep credentials FALSE (you don’t need cookies)
const corsOptions = {
  origin: ALLOWED_ORIGINS,                // <-- simple array whitelist
  methods: ['GET','POST','OPTIONS'],
  allowedHeaders: ['Content-Type','Authorization'],
  credentials: false,                     // important: matches frontend fetch(credentials:'omit')
  maxAge: 86400
};

// 3) Apply to API only (unchanged elsewhere)
app.options('/api/*', cors(corsOptions)); // preflight
app.use('/api', cors(corsOptions));
app.options("/api/creator_insights_upsert", cors(corsOptions));



// ------------------------------------------------------------
// Shared proxy headers (images + JSON)
// ------------------------------------------------------------
function setProxyHeaders(res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.setHeader(
    'Access-Control-Allow-Headers',
    'Content-Type, Authorization'
  );
  // Important for <img src> redirects across domains
  res.setHeader('Cross-Origin-Resource-Policy', 'cross-origin');
}




// 🔒 Ingest URL is disabled everywhere
app.all(['/api/ingest-url', '/api/ingest.url', '/ingest-url'], (req, res) => {
  res.status(410).json({ error: 'ingest-url disabled' }); // 410 Gone (intentional)
});

app.use(bodyParser.json({ limit: '25mb' }));
app.use(bodyParser.urlencoded({ extended: true, limit: '25mb' }));
app.use('/public', express.static(path.join(__dirname, 'public')));

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
app.get("/api/get-circle-from-supabase", async (req, res) => {
  const { group_id } = req.query;
  if (!group_id) return res.status(400).json({ success: false, message: "Missing group_id" });

  try {
    const { data, error } = await supabase
      .from("circles")
      .select("*")
      .eq("group_id", group_id)
      .single();

    if (error || !data) throw error;
    res.json({ success: true, ...data });
  } catch (err) {
    console.error("❌ Get Circle error:", err.message);
    res.status(500).json({ success: false, error: err.message });
  }
});
app.post("/api/update-circle-message", async (req, res) => {
  const { group_id, new_message } = req.body;
  if (!group_id || !new_message) return res.status(400).json({ success: false, message: "Missing data" });

  try {
    const { data: existing, error } = await supabase
      .from("circles")
      .select("messages")
      .eq("group_id", group_id)
      .single();

    if (error) throw error;

    const updatedMessages = [...(existing?.messages || []), new_message];

    const { error: updateError } = await supabase
      .from("circles")
      .update({ messages: updatedMessages })
      .eq("group_id", group_id);

    if (updateError) throw updateError;
    res.json({ success: true });
  } catch (err) {
    console.error("❌ Update Circle message error:", err.message);
    res.status(500).json({ success: false, error: err.message });
  }
});

// Clean Messages
app.post("/api/delete-circle-message", async (req, res) => {
  const { group_id, timestamp } = req.body;
  if (!group_id || !timestamp) return res.status(400).json({ success: false, message: "Missing data" });

  try {
    const { data: existing, error } = await supabase
      .from("circles")
      .select("messages")
      .eq("group_id", group_id)
      .single();

    if (error || !existing) throw error;

    const filteredMessages = existing.messages.filter(m => m.timestamp !== timestamp);

    const { error: updateError } = await supabase
      .from("circles")
      .update({ messages: filteredMessages })
      .eq("group_id", group_id);

    if (updateError) throw updateError;

    res.json({ success: true });
  } catch (err) {
    console.error("❌ Delete Circle message error:", err.message);
    res.status(500).json({ success: false, error: err.message });
  }
});
app.get("/api/get-circle-boards", async (req, res) => {
  const email = req.query.email;
  const { data, error } = await supabase
    .from("cocoboards")
    .select("title, cover_image, slug")
    .eq("created_by", email)
    .eq("is_public", true);

  if (error) return res.status(500).json({ error });
  res.json({ boards: data });
});

app.post("/api/seed-circle-table", async (req, res) => {
  const { group_id, circle_id, tribe_members = [], messages = [], pins = [], images = [] } = req.body;

  if (!group_id || !circle_id) {
    return res.status(400).json({ success: false, error: "Missing group_id or circle_id" });
  }

  try {
    const { error } = await supabase
      .from("circles")
      .upsert([{ group_id, circle_id, tribe_members, messages, pins, images }], {
        onConflict: ["group_id"]
      });

    if (error) throw error;

    res.status(200).json({ success: true });
  } catch (err) {
    console.error("❌ Seed Circle error:", err.message);
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
        }
      ]);

    if (error) throw error;

    res.json({ success: true, board: data[0] });
  } catch (err) {
    console.error("❌ Failed to save moodboard:", err);
    res.status(500).json({ success: false, error: err.message });
  }
});

// ✅ Save or update media item
app.post("/api/save-media-item", async (req, res) => {
  const { url, email, caption = "", source_url = "", reactions = {}, media_type = "", created_at = new Date().toISOString() } = req.body;

  if (!url || !email) {
    return res.status(400).json({ success: false, message: "Missing required fields" });
  }

  try {
    const { data, error } = await supabase
      .from("media_uploads")
      .insert([{
        url,
        email,
        caption,
        source_url,
        reactions,
        media_type,
        created_at
      }]);

    if (error) throw error;

    res.json({ success: true, data });
  } catch (err) {
    console.error("❌ Failed to save media item:", err.message);
    res.status(500).json({ success: false, message: err.message });
  }
});


// Get media
app.get("/api/get-media-items", async (req, res) => {
  const { publicwall } = req.query;

  try {
    const query = supabase
      .from("media_uploads")
      .select("id, url, caption, email, created_at, reactions, source_url"); // ✅ added source_url

    if (publicwall === "true") {
      query.eq("publicwall", true);
    }

    const { data, error } = await query;

    if (error) throw error;

    res.json({ success: true, data });
  } catch (err) {
    console.error("❌ Failed to fetch media items:", err);
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
    const {
      board_id,
      image_url,        // ✅ Rename from 'url'
      caption = "",
      media_type = "image", // ✅ Rename from 'type'
      buy_link = null,
      collection = "Media"
    } = req.body;

    const { data, error } = await supabase
      .from("cocoboard_media")
      .insert([{
        board_id,
        image_url,        // ✅ Save in correct column
        caption,
        media_type,       // ✅ Correct column
        buy_link,
        collection,
        publicwall: true
      }])
      .select()
      .single();

    if (error) throw error;
    res.json({ success: true, media: data });
  } catch (err) {
    console.error("Save media error:", err);
    res.status(500).json({ success: false, error: err.message });
  }
});


// ✅ Get CoCoBoard Media
app.get("/api/get-cocoboard-media", async (req, res) => {
  const { board_id } = req.query;

  if (!board_id) {
    return res.status(400).json({ success: false, error: "Missing board_id" });
  }

  try {
    const { data, error } = await supabase
      .from("cocoboard_media")
      .select("*")
      .eq("board_id", board_id)
      .order("created_at", { ascending: true });

    if (error) throw error;

    res.json({ success: true, media: data });
  } catch (err) {
    console.error("❌ Fetch media error:", err.message);
    res.status(500).json({ success: false, error: err.message });
  }
});



// ✅ BACKEND ROUTE — Express
// ✅ Get Single CoCoBoard by ID or Slug
app.get("/api/get-cocoboard", async (req, res) => {
  const { id } = req.query;
  if (!id) return res.status(400).json({ success: false, message: "Missing board ID" });

  const { data: board, error: boardError } = await supabase
    .from("cocoboards")
    .select("*")
    .eq("id", id)
    .single();

  if (boardError || !board) {
    return res.status(404).json({ success: false, message: "Board not found" });
  }

  const { data: media, error: mediaError } = await supabase
    .from("cocoboard_media")
    .select("*")
    .eq("board_id", id);

  board.tiles = media || [];

  return res.status(200).json({ success: true, board });
});

app.get("/api/cocoboard-gallery", async (req, res) => {
  try {
    const { data, error } = await supabase
      .from("cocoboards")
      .select("id, title, cover_image")  // Removed title_slug
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
app.post("/api/create-link", async (req, res) => {
  const { slug, file_url, email = "", media_type = "" } = req.body;

  if (!slug || !file_url) {
    return res.status(400).json({ success: false, message: "Missing slug or file_url" });
  }

  try {
    const { data, error } = await supabase
      .from("media_links")
      .insert([{ slug, file_url, email, media_type }])
      .select()
      .single();

    if (error) throw error;

    res.status(200).json({
      success: true,
      message: "🔗 Media link created!",
      link: `https://cultureschool.org/m/${slug}`, // or whatever your share route is
      data
    });
  } catch (err) {
    console.error("❌ Error creating media link:", err.message);
    res.status(500).json({ success: false, error: err.message });
  }
});
// ✅ Return all shareable media links for a user
app.get("/api/get-media-links", async (req, res) => {
  const { email } = req.query;
  if (!email) {
    return res.status(400).json({ success: false, message: "Missing email" });
  }

  try {
    const { data, error } = await supabase
      .from("media_links")
      .select("*")
      .eq("email", email)
      .order("created_at", { ascending: false });

    if (error) throw error;

    res.status(200).json({ success: true, links: data });
  } catch (err) {
    console.error("❌ Error fetching media links:", err.message);
    res.status(500).json({ success: false, error: err.message });
  }
});

app.get("/media/:slug/stream", async (req, res) => {
  const { slug } = req.params;
  const { data, error } = await supabase
    .from("media_links")
    .select("file_url")
    .eq("slug", slug)
    .single();

  if (error || !data) return res.status(404).send("Not found");

  try {
    const response = await fetch(data.file_url);
    if (!response.ok) throw new Error("Fetch failed");

    res.setHeader("Content-Type", response.headers.get("content-type"));
    response.body.pipe(res);
  } catch (err) {
    console.error("❌ Proxy error:", err.message);
    res.status(500).send("Proxy failed");
  }
});

app.get("/m/:slug", async (req, res) => {
  const { slug } = req.params;

  try {
    const { data, error } = await supabase
      .from("media_links")
      .select("title, file_url, media_type")
      .eq("slug", slug)
      .single();

    if (error || !data) {
      return res.status(404).send("Media not found.");
    }

    const title = data.title || "Untitled Media";
    const isVideo = data.media_type === "video";

    return res.send(`
      <!DOCTYPE html>
      <html lang="en">
      <head>
        <meta charset="UTF-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1.0" />
        <title>${title}</title>

        <!-- Social Sharing Meta -->
        <meta property="og:title" content="${title}" />
        <meta property="og:type" content="${isVideo ? "video.other" : "image"}" />
        <meta property="og:url" content="https://cultureschool.org/m/${slug}" />
        <meta property="og:image" content="https://cultureschool.org/preview/${slug}.jpg" />
        <meta property="og:description" content="A shared media experience from CultureSchool." />
        <meta property="og:site_name" content="CultureSchool" />

        <!-- Twitter Card -->
        <meta name="twitter:card" content="${isVideo ? "player" : "summary_large_image"}" />
        <meta name="twitter:title" content="${title}" />
        <meta name="twitter:description" content="Check out this CultureSchool video!" />
        <meta name="twitter:image" content="https://cultureschool.org/preview/${slug}.jpg" />

        <style>
          body {
            background: #1a2238;
            color: white;
            display: flex;
            flex-direction: column;
            justify-content: center;
            align-items: center;
            min-height: 100vh;
            margin: 0;
            font-family: 'Inter', sans-serif;
            text-align: center;
          }

          video, img {
            max-width: 90%;
            max-height: 80vh;
            border-radius: 12px;
            box-shadow: 0 8px 16px rgba(0,0,0,0.5);
          }

          h1 {
            font-size: 1.5rem;
            margin-bottom: 1rem;
          }
        </style>
      </head>
      <body>
        <h1>${title}</h1>
        ${isVideo
          ? `<video src="/media/${slug}/stream" controls autoplay muted playsinline></video>`
          : `<img src="/media/${slug}/stream" alt="${title}" />`}
      </body>
      </html>
    `);
  } catch (err) {
    console.error("❌ Error serving media page:", err.message);
    return res.status(500).send("Internal server error.");
  }
});

app.post('/api/save-inspo-teaser', async (req, res) => {
  const teaser = req.body;

  if (!teaser.title || !teaser.image || !teaser.board_id) {
    return res.status(400).json({ success: false, error: "Missing required teaser data." });
  }

  try {
    const { data, error } = await supabase
      .from('inspo_wall') // Replace with your actual table name
      .insert([{
        title: teaser.title,
        image: teaser.image,
        type: teaser.type || 'drop',
        board_id: teaser.board_id, // ✅ consistent and correct
        is_public: true,
        featured_at: teaser.featured_at || new Date().toISOString()
      }]);

    if (error) throw error;

    return res.status(200).json({ success: true, data });
  } catch (err) {
    console.error("❌ Failed to save inspo teaser:", err);
    return res.status(500).json({ success: false, error: err.message });
  }
});
app.get('/api/get-inspo-teasers', async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('inspo_wall') // your table
      .select('*')
      .eq('is_public', true)
      .order('featured_at', { ascending: false })
      .limit(30); // adjust as needed

    if (error) throw error;

    return res.status(200).json({ success: true, data });
  } catch (err) {
    console.error("❌ Error fetching inspo teasers:", err);
    return res.status(500).json({ success: false, error: err.message });
  }
});
app.get("/m/:slug", async (req, res) => {
  const { slug } = req.params;
  const { data, error } = await supabase
    .from("media_links")
    .select("board_id")
    .eq("slug", slug)
    .single();

  if (error || !data?.board_id) {
    return res.status(404).send("Board not found.");
  }

  // Permanent redirect to new format
  return res.redirect(301, `/pages/cocoboard-preview-html?board=${data.board_id}`);
});
// ✅ SERVER EXPORT TIMELINE ROUTE
app.post("/api/export-timeline", async (req, res) => {
  try {
    console.log("📦 Incoming timeline payload:", req.body);

    const { timeline } = req.body;
    if (!timeline || !Array.isArray(timeline) || timeline.length === 0) {
      return res.status(400).json({ success: false, error: "Missing or invalid timeline array" });
    }

    const sessionId = uuidv4();
    const tempDir = path.join(__dirname, "temp", sessionId);
    fs.mkdirSync(tempDir, { recursive: true });

    const tsFiles = [];

    for (let i = 0; i < timeline.length; i++) {
      const { url } = timeline[i];
      const inputFile = path.join(tempDir, `input${i}.mp4`);
      const tsFile = path.join(tempDir, `input${i}.ts`);

      const writer = fs.createWriteStream(inputFile);
      const response = await axios({ method: "GET", url, responseType: "stream" });
      await new Promise((resolve, reject) => {
        response.data.pipe(writer);
        writer.on("finish", resolve);
        writer.on("error", reject);
      });

      await new Promise((resolve, reject) => {
        exec(`ffmpeg -y -i "${inputFile}" -c copy -bsf:v h264_mp4toannexb -f mpegts "${tsFile}"`, err => {
          if (err) reject(err);
          else resolve();
        });
      });

      tsFiles.push(tsFile);
    }

    const concatList = tsFiles.map(f => `file '${f}'`).join("\n");
    fs.writeFileSync(path.join(tempDir, "input.txt"), concatList);

    const outputPath = path.join(tempDir, "output.mp4");
    await new Promise((resolve, reject) => {
      exec(`ffmpeg -y -f concat -safe 0 -i "${path.join(tempDir, "input.txt")}" -c copy "${outputPath}"`, err => {
        if (err) reject(err);
        else resolve();
      });
    });

    res.download(outputPath, "MyShortFilm.mp4", () => {
      fs.rmSync(tempDir, { recursive: true, force: true });
    });

  } catch (err) {
    console.error("❌ FFmpeg export error:", err.message);
    res.status(500).json({ success: false, error: "Timeline export failed", message: err.message });
  }
});

// ✅ TEST FFMPEG INSTALLATION
app.get("/api/test-ffmpeg", (req, res) => {
  exec("ffmpeg -version", (error, stdout, stderr) => {
    if (error) {
      console.error("❌ FFmpeg error:", error.message);
      return res.status(500).json({ success: false, error: error.message });
    }
    res.json({ success: true, version: stdout });
  });
});
app.post("/api/auto-assign-media-to-board", async (req, res) => {
  const { email, mediaUrl, mediaType, caption = "", isPublic = false } = req.body;
  if (!email || !mediaUrl || !mediaType) {
    return res.status(400).json({ success: false, message: "Missing required fields." });
  }

  try {
    // Step 1: Find or create a default board for this user
    const { data: boards } = await supabase
      .from("cocoboards")
      .select("id")
      .eq("created_by", email)
      .order("created_at", { ascending: true });

    let boardId = boards?.[0]?.id;

    if (!boardId) {
      const { data: newBoard } = await supabase
        .from("cocoboards")
        .insert({
          title: "My CoCoBoard",
          description: "Auto-generated board for your uploads",
          created_by: email,
          is_public: false
        })
        .select();
      boardId = newBoard?.[0]?.id;
    }

    // Step 2: Add the media to the board
    const { error: insertError } = await supabase
      .from("cocoboard_media")
      .insert({
        board_id: boardId,
        url: mediaUrl,
        media_type: mediaType,
        caption,
        source_url: mediaUrl,
        is_public: isPublic
      });

    if (insertError) throw insertError;

    return res.status(200).json({ success: true, boardId });
  } catch (err) {
    console.error("Auto-assign error:", err.message);
    return res.status(500).json({ success: false, message: "Failed to assign media to board." });
  }
});
app.get("/api/get-reactions", async (req, res) => {
  const board_id = req.query.board_id;

  if (!board_id) {
    return res.status(400).json({ success: false, message: "Missing board_id." });
  }

  const { data, error } = await supabase
    .from("cocoboard_reactions")
    .select("text, username, created_at")
    .eq("board_id", board_id)
    .order("created_at", { ascending: false });

  if (error) {
    console.error("❌ Supabase fetch error:", error);
    return res.status(500).json({ success: false, error });
  }

  res.json({ success: true, reactions: data });
});
app.post('/api/log-event', async (req, res) => {
  try {
    const { user_email, board_id, event_type, metadata } = req.body;

    if (!event_type) {
      return res.status(400).json({ success: false, message: 'Missing event_type' });
    }

    const { data, error } = await supabase
      .from('coco_events')
      .insert([
        {
          user_email,
          board_id,
          event_type,
          metadata,
        },
      ]);

    if (error) throw error;

    res.status(200).json({ success: true, message: 'Event logged' });
  } catch (err) {
    console.error('Log event error:', err);
    res.status(500).json({ success: false, message: 'Error logging event' });
  }
});
app.get("/api/get-creators", async (req, res) => {
  try {
    const { data: userRecords } = await supabase
      .from("users")
      .select("email, username, bio, avatar_url");

    const { data: creatorRecords } = await supabase
      .from("creators")
      .select("email, username, bio, profile_pic, location");

    const combined = [...(userRecords || []), ...(creatorRecords || [])];

    // Deduplicate by email — favoring creator records if overlap
    const deduped = Object.values(
      combined.reduce((acc, user) => {
        acc[user.email] = {
          ...acc[user.email],
          ...user,
          avatar:
            user.avatar_url ||
            user.profile_pic ||
            `https://www.gravatar.com/avatar/${CryptoJS.MD5(user.email.trim().toLowerCase())}?d=identicon`
        };
        return acc;
      }, {})
    );

    // Now join each deduped user with their latest public board
    const creatorsWithBoards = await Promise.all(
      deduped.map(async (user) => {
        const { data: board } = await supabase
          .from("cocoboards")
          .select("id, cover_image")
          .eq("created_by", user.email)
          .eq("is_public", true)
          .order("updated_at", { ascending: false })
          .limit(1)
          .single();

        return {
          id: user.email,
          username: user.username || "Anonymous",
          bio: user.bio || "",
          avatar: user.avatar,
          board_id: board?.id || null,
          previewImage: board?.cover_image || null,
        };
      })
    );

    res.json({ success: true, creators: creatorsWithBoards });
  } catch (err) {
    console.error("❌ Failed to fetch creators:", err.message);
    res.status(500).json({ success: false, error: err.message });
  }
});


// Route: Trigger fake Collector run
app.post('/admin/trigger-run', async (req, res) => {
  const { error, data } = await supabase.from('collector_runs').insert({
    run_date: new Date().toISOString(),
    source: 'admin_ui_manual_trigger',
    item_count: Math.floor(Math.random() * 5) + 1,
    created_by: 'stacey.a.grant@gmail.com',
    notes: 'Triggered via dashboard button'
  });

  if (error) return res.status(500).json({ error });
  res.json({ success: true, run: data[0] });
});
process.on("uncaughtException", err => {
  console.error("Uncaught exception:", err);
});

process.on("unhandledRejection", err => {
  console.error("Unhandled rejection:", err);
});
app.post("/admin/seed-demo-items", async (req, res) => {
  if (req.body.email !== "stacey.a.grant@gmail.com") {
    return res.status(403).json({ success: false, error: "Not authorized" });
  }
  
  // Step 1: Create a new collector_runs entry
  const run = {
    run_date: new Date().toISOString(),
    source: "admin_seed_button",
    item_count: 3,
    created_by: "stacey.a.grant@gmail.com",
    notes: "Demo seed run from admin"
  };

  const { data: newRun, error: runError } = await supabase
    .from("collector_runs")
    .insert(run)
    .select()
    .single();

  if (runError) {
    console.error("❌ Failed to create run:", runError.message);
    return res.status(500).json({ success: false, error: runError.message });
  }

  const run_id = newRun.id;

  // Step 2: Seed collector_items with that run_id
  const testItems = [
    {
      title: "Boho Interior Vibes",
      creator: "stacey.a.grant@gmail.com",
      image_url: "https://images.unsplash.com/photo-1600585154340-be6161a56a0c?auto=format&fit=crop&w=800&q=80",
      product_link: "https://cultureschool.org/product/boho-vibes",
      collected_at: new Date().toISOString(),
      board_id: "seed-demo-1",
      sku: "DEMO-001",
      tags: ["boho", "interior", "style"],
      run_id,
      metadata: { source: "unsplash", type: "image" }
    },
    {
      title: "Vision Board Kit",
      creator: "stacey.a.grant@gmail.com",
      image_url: "https://images.unsplash.com/photo-1519710164239-da123dc03ef4?auto=format&fit=crop&w=800&q=80",
      product_link: "https://cultureschool.org/product/vision-kit",
      collected_at: new Date().toISOString(),
      board_id: "seed-demo-1",
      sku: "DEMO-002",
      tags: ["vision", "kit"],
      run_id,
      metadata: { source: "unsplash", type: "image" }
    },
    {
      title: "Cultural Color Palette",
      creator: "stacey.a.grant@gmail.com",
      image_url: "https://images.unsplash.com/photo-1598620615060-2b6bb763a427?auto=format&fit=crop&w=800&q=80",
      product_link: "https://cultureschool.org/product/palette",
      collected_at: new Date().toISOString(),
      board_id: "seed-demo-1",
      sku: "DEMO-003",
      tags: ["culture", "color", "palette"],
      run_id,
      metadata: { source: "unsplash", type: "image" }
    }
  ];

  const { error: itemError } = await supabase
    .from("collector_items")
    .insert(testItems);

  if (itemError) {
    console.error("❌ Failed to seed collector items:", itemError.message);
    return res.status(500).json({ success: false, error: itemError.message });
  }

  res.json({ success: true, message: "🌱 Seeded 3 demo items + run", run_id });
});
app.post("/api/saveGrab", async (req, res) => {
  const item = req.body;

  if (!item?.email || !item?.title || !item?.image_url || !item?.board_id) {
    return res.status(400).json({ success: false, message: "Missing required fields" });
  }

  const timestamp = new Date().toISOString();

  try {
    // Step 1: Insert to creator's board
    const { error: mediaError } = await supabase
      .from("cocoboard_media")
      .insert([{ ...item, created_at: timestamp }]);

    if (mediaError) throw mediaError;

    // Step 2: Shadow insert to collector_items (optional, non-blocking)
    await supabase.from("collector_items").insert([{
      title: item.title,
      creator: item.email,
      image_url: item.image_url,
      product_link: item.link,
      collected_at: timestamp,
      board_id: item.board_id,
      sku: null,
      tags: (item.tags || "").split(/[\s,#]+/).filter(Boolean),
      metadata: {
        source: "coco-collector",
        collection: item.collection || "web",
        description: item.description || null
      }
    }]);

    // Step 3: Return success
    res.json({ success: true });

  } catch (err) {
    console.error("❌ saveGrab error:", err);
    res.status(500).json({ success: false, message: err.message });
  }
});
app.get('/api/daily-board-trends', async (req, res) => {
  try {
    const { data: boards, error } = await supabase
      .from('cocoboards')
      .select('id, created_at, created_by');

    if (error) throw error;

    // Group by date
    const trends = {};
    const creatorCounts = {};

    boards.forEach(board => {
      const date = new Date(board.created_at).toISOString().split('T')[0];

      trends[date] = (trends[date] || 0) + 1;
      if (board.created_by) {
        creatorCounts[board.created_by] = (creatorCounts[board.created_by] || 0) + 1;
      }
    });

    // Convert trend object to sorted array
    const trendArray = Object.entries(trends)
      .map(([date, count]) => ({ date, count }))
      .sort((a, b) => new Date(b.date) - new Date(a.date));

    // Convert top creators to array
    const topCreators = Object.entries(creatorCounts)
      .map(([email, count]) => ({ email, count }))
      .sort((a, b) => b.count - a.count)
      .slice(0, 10);

    res.json({
      success: true,
      trends: trendArray,
      top_creators: topCreators,
    });
  } catch (err) {
    console.error("Trend fetch failed:", err);
    res.status(500).json({ success: false, message: err.message });
  }
});
app.post("/api/set-profile-cover", async (req, res) => {
  const { email, cover_image } = req.body;

  if (!email || !cover_image) {
    return res.status(400).json({ success: false, error: "Missing email or cover image" });
  }

  try {
    const { data, error } = await supabase
      .from("users")
      .update({ cover_image })
      .eq("email", email);

    if (error) throw error;

    res.json({ success: true, message: "Cover image updated", data });
  } catch (err) {
    console.error("Error setting profile cover:", err.message);
    res.status(500).json({ success: false, error: err.message });
  }
});
app.get("/api/get-public-creators", async (req, res) => {
  try {
    const { data: boards, error: boardErr } = await supabase
      .from("cocoboards")
      .select("id, created_by, cover_image, title, updated_at")
      .eq("is_public", true)
      .order("updated_at", { ascending: false });

    if (boardErr) throw boardErr;

    const latestBoardByUser = {};
    for (const board of boards) {
      if (!latestBoardByUser[board.created_by]) {
        latestBoardByUser[board.created_by] = board;
      }
    }

    const { data: userRecords } = await supabase
      .from("users")
      .select("email, username, bio, avatar_url");

    const { data: creatorRecords } = await supabase
      .from("creators")
      .select("email, username, bio, profile_pic, location");

    const combined = [...(userRecords || []), ...(creatorRecords || [])];

    const allCreators = Object.values(
      combined.reduce((acc, user) => {
        acc[user.email] = {
          ...acc[user.email],
          ...user,
          avatar:
            user.avatar_url ||
            user.profile_pic ||
            `https://www.gravatar.com/avatar/${CryptoJS.MD5(user.email.trim().toLowerCase())}?d=identicon`
        };
        return acc;
      }, {})
    );

    const publicCreators = Object.entries(latestBoardByUser).map(
      ([email, board]) => {
        const user = allCreators.find((u) => u.email === email);
        return {
          id: email,
          username: user?.username || "Anonymous",
          bio: user?.bio || "",
          avatar: user?.avatar,
          location: user?.location || "",
          previewImage: board.cover_image || null,
          board_id: board.id
        };
      }
    );

    // ✅ Region tagging logic
    function getRegionFromLocation(location = "") {
      const normalized = location.trim().toLowerCase();
      if (normalized.includes("ny") || normalized.includes("brooklyn") || normalized.includes("queens") || normalized.includes("manhattan"))
        return "New York Area";
      if (normalized.includes("ma") || normalized.includes("boston") || normalized.includes("holliston"))
        return "New England";
      if (normalized.includes("ca") || normalized.includes("los angeles") || normalized.includes("san francisco"))
        return "California";
      if (normalized.includes("tx") || normalized.includes("houston") || normalized.includes("austin"))
        return "Texas";
      if (normalized.includes("atlanta") || normalized.includes("ga"))
        return "Southeast";
      if (normalized.includes("chicago") || normalized.includes("il"))
        return "Midwest";
      if (normalized.includes("seattle") || normalized.includes("wa"))
        return "Pacific Northwest";
      if (normalized.includes("fl") || normalized.includes("miami") || normalized.includes("orlando"))
        return "Florida";
      return "Other / International";
    }

    const creatorsWithRegions = publicCreators.map(creator => ({
      ...creator,
      region: getRegionFromLocation(creator.location)
    }));

    res.json({ success: true, creators: creatorsWithRegions });
  } catch (err) {
    console.error("❌ get-public-creators error:", err.message);
    res.status(500).json({ success: false, error: err.message });
  }
});
// server.js
app.get("/api/fetch-profile-meta", async (req, res) => {
  const url = req.query.url;
  if (!url) return res.status(400).json({ error: "Missing URL" });

  const preview = await fetch(`https://api.microlink.io/?url=${encodeURIComponent(url)}`);
  const { data } = await preview.json();

  res.json({
    title: data?.title || "",
    description: data?.description || "",
    image: data?.image?.url || ""
  });
});app.get("/api/upc-lookup", async (req, res) => {
  const { upc } = req.query;
  const result = await fetch(`https://api.upcitemdb.com/prod/trial/lookup?upc=${upc}`);
  const data = await result.json();
  res.json(data);
});

app.use('/api/voice', elevenlabsRoute); // Your POST endpoint is now: /api/voice/speak

app.get("/api/get-public-locations", async (req, res) => {
  try {
    const { data, error } = await supabase
      .from("locations")
      .select("*")
      .eq("is_public", true);

    if (error) throw error;

    const enriched = data.map((loc) => ({
      id: loc.id,
      name: loc.name,
      type: loc.type,
      tags: loc.tags || [],
      lat: loc.lat,
      lng: loc.lng,
      region: loc.region || "",
      website: loc.website || "",
      description: loc.description || "",
      image: loc.image_url || "",
    }));

    res.json({ success: true, locations: enriched });
  } catch (err) {
    console.error("❌ get-public-locations error:", err.message);
    res.status(500).json({ success: false, error: err.message });
  }
});
// Save tile endpoint
app.post('/api/saveFlourishTile', async (req, res) => {
  const tile = req.body;

  if (!tile.board_id || !tile.email) {
    return res.status(400).json({ success: false, message: "Missing board_id or email" });
  }

  try {
    let result;
    if (tile.id) {
      // Update
      const { data, error } = await supabase
        .from('flourish_tiles')
        .update(tile)
        .eq('id', tile.id)
        .select();
      if (error) throw error;
      result = data;
    } else {
      // Insert
      const { data, error } = await supabase
        .from('flourish_tiles')
        .insert([tile])
        .select();
      if (error) throw error;
      result = data;
    }

    res.json({ success: true, data: result });
  } catch (err) {
    console.error("Tile save error:", err);
    res.status(500).json({ success: false, message: err.message });
  }
});

// Delete tile endpoint
app.delete('/api/deleteFlourishTile', async (req, res) => {
  const { id } = req.query;
  if (!id) return res.status(400).json({ success: false, message: "Tile ID required" });

  try {
    const { error } = await supabase
      .from('flourish_tiles')
      .delete()
      .eq('id', id);

    if (error) throw error;
    res.json({ success: true });
  } catch (err) {
    console.error("Tile delete error:", err);
    res.status(500).json({ success: false, message: err.message });
  }
});
// Add to your Express backend (or wherever your routes live)
app.get("/api/get-support-board", async (req, res) => {
  const boardId = req.query.id;
  if (!boardId) {
    return res.status(400).json({ success: false, message: "No board_id provided" });
  }

  // Fetch board metadata
  const { data: board, error: boardError } = await supabase
    .from("cocoboards")
    .select("*")
    .eq("id", boardId)
    .single();

  if (boardError || !board) {
    return res.status(404).json({ success: false, message: "Board not found" });
  }

  // Fetch tiles
  const { data: tiles, error: tileError } = await supabase
    .from("cocoboard_media")
    .select("*")
    .eq("board_id", boardId)
    .order("created_at", { ascending: false });

  if (tileError) {
    return res.status(500).json({ success: false, message: "Error fetching tiles" });
  }

  return res.json({ success: true, board, tiles });
});

app.get("/api/geocode", async (req, res) => {
  const q = req.query.q;
  if (!q) {
    return res.status(400).json({ error: "Missing query parameter 'q'" });
  }

  try {
    const geoRes = await fetch(`https://api.opencagedata.com/geocode/v1/json?q=${encodeURIComponent(q)}&key=${OPENCAGE_API_KEY}`);
    const json = await geoRes.json();
    res.json(json);
  } catch (err) {
    console.error("Geocode API error:", err);
    res.status(500).json({ error: "Failed to fetch geocode data" });
  }
});

module.exports = app;

// ✅ Get all Flourish Tiles for a board
app.get('/api/getFlourishTiles', async (req, res) => {
  const { board_id, email } = req.query;

  if (!board_id || !email) {
    return res.status(400).json({ success: false, message: "Missing board_id or email" });
  }

  try {
    const { data, error } = await supabase
      .from('flourish_tiles')
      .select('*')
      .eq('board_id', board_id)
      .eq('email', email)
      .order('sort_order', { ascending: true });

    if (error) throw error;

    res.json({ success: true, tiles: data });
  } catch (err) {
    console.error("Tile fetch error:", err.message);
    res.status(500).json({ success: false, message: err.message });
  }
});
// Health check (optional)
app.get('/api/health/env', (_req, res) => {
  res.set('Cache-Control', 'no-store');
  res.json({
    ok: true,
    ts: Date.now()
  });
});


// ✅ matches your frontend: POST https://cultureschool-backend.onrender.com/api/images
app.post('/api/images', async (req, res) => {
  const { prompt, size = '1024x1024', n = 1 } = req.body || {};
  // ...
  const out = await openai.images.generate({ model: 'gpt-image-1', prompt, size, n });
  const images = (out?.data || []).map(x => x.url ? { url: x.url } :
                                       x.b64_json ? { b64: x.b64_json } : null).filter(Boolean);
  if (!images.length) return res.status(502).json({ error: 'No image returned from OpenAI' });
  if (images.length === 1) return res.json(images[0]);  // preserves {url} or {b64}
  return res.json({ images });
});


// GET /api/pexels-proxy?query=calm&per_page=4&page=1&thumb=1
app.get('/api/pexels-proxy', async (req, res) => {
  setProxyHeaders(res);
  const PEXELS_API_KEY = process.env.PEXELS_API_KEY;
  if (!PEXELS_API_KEY) return res.status(500).json({ error: 'PEXELS_API_KEY missing' });

  const { query = 'inspiration', per_page = 10, page = 1, thumb } = req.query;
  try {
    const url = `https://api.pexels.com/v1/search?query=${encodeURIComponent(query)}&per_page=${per_page}&page=${page}`;
    const r = await fetch(url, { headers: { Authorization: PEXELS_API_KEY } });
    const data = await r.json();

    // If a thumbnail was requested, 302 redirect to the image URL so <img src=...> works
    if (String(thumb) === '1') {
      const first = data?.photos?.[0];
      const imgUrl = first?.src?.medium || first?.src?.large || first?.src?.original;
      if (imgUrl) {
        res.set('Cache-Control', 'public, max-age=600');
        return res.redirect(302, imgUrl);
      }
      return res.redirect(302, 'about:blank');
    }

    res.set('Cache-Control', 'public, max-age=60');
    return res.json(data);
  } catch (e) {
    console.error('pexels-proxy error:', e);
    res.status(500).json({ error: 'Pexels proxy failed' });
  }
});

// GET /api/pixabay-proxy?query=nature&per_page=4&page=1&thumb=1
// GET /api/pixabay-proxy?query=nature&per_page=50&page=1&thumb=1&seed=theme-key
app.get('/api/pixabay-proxy', async (req, res) => {
  setProxyHeaders(res);
  const PIXABAY_API_KEY = process.env.PIXABAY_API_KEY;
  if (!PIXABAY_API_KEY) return res.status(500).json({ error: 'PIXABAY_API_KEY missing' });

  const { query = 'inspiration', per_page = 10, page = 1, image_type = 'photo', thumb, seed } = req.query;

  try {
    const url =
      `https://pixabay.com/api/?key=${PIXABAY_API_KEY}` +
      `&q=${encodeURIComponent(query)}` +
      `&per_page=${per_page}` +
      `&page=${page}` +
      `&image_type=${image_type}` +
      `&safesearch=true`;

    const r = await fetch(url);
    const data = await r.json();

    // --- helper: deterministic hash for stable selection ---
    function hashStr(s = '') {
      let h = 2166136261; // FNV-ish
      for (let i = 0; i < s.length; i++) {
        h ^= s.charCodeAt(i);
        h = Math.imul(h, 16777619);
      }
      return (h >>> 0);
    }

    if (String(thumb) === '1') {
      const hits = Array.isArray(data?.hits) ? data.hits : [];
      if (!hits.length) return res.redirect(302, 'about:blank');

      // pick a stable index per theme (seed), otherwise 0
      const idx = seed ? (hashStr(String(seed)) % hits.length) : 0;
      const first = hits[idx];

      const imgUrl = first?.webformatURL || first?.previewURL || first?.largeImageURL;
      if (imgUrl) {
        res.set('Cache-Control', 'public, max-age=600');
        return res.redirect(302, imgUrl);
      }
      return res.redirect(302, 'about:blank');
    }

    res.set('Cache-Control', 'public, max-age=60');
    return res.json(data);
  } catch (e) {
    console.error('pixabay-proxy error:', e);
    res.status(500).json({ error: 'Pixabay proxy failed' });
  }
});

app.get('/health', (_req, res) => res.json({ ok: true }));
// GET /api/unsplash-proxy?query=calm&per_page=6&page=1&thumb=1
app.get('/api/unsplash-proxy', async (req, res) => {
  setProxyHeaders(res);
  const UNSPLASH_ACCESS_KEY = process.env.UNSPLASH_ACCESS_KEY;
  if (!UNSPLASH_ACCESS_KEY) {
    return res.status(500).json({ error: 'UNSPLASH_ACCESS_KEY missing' });
  }

  const {
    query = 'inspiration',
    per_page = 10,
    page = 1,
    thumb
  } = req.query;

  try {
    const url =
      `https://api.unsplash.com/search/photos` +
      `?query=${encodeURIComponent(query)}` +
      `&per_page=${per_page}` +
      `&page=${page}` +
      `&orientation=squarish`;

    const r = await fetch(url, {
      headers: {
        Authorization: `Client-ID ${UNSPLASH_ACCESS_KEY}`,
        'Accept-Version': 'v1'
      }
    });

    if (!r.ok) {
      const t = await r.text();
      throw new Error(`Unsplash API error ${r.status}: ${t}`);
    }

    const data = await r.json();

    // --- THUMB MODE (for <img src>) ---
    if (String(thumb) === '1') {
      const first = data?.results?.[0];

      const imgUrl =
        first?.urls?.small ||
        first?.urls?.regular ||
        first?.urls?.full;

      if (imgUrl) {
        res.set('Cache-Control', 'public, max-age=600'); // 10 min
        return res.redirect(302, imgUrl);
      }

      return res.redirect(302, 'about:blank');
    }

    // --- JSON MODE ---
    res.set('Cache-Control', 'public, max-age=60');
    return res.json(data);

  } catch (e) {
    console.error('unsplash-proxy error:', e);
    res.status(500).json({ error: 'Unsplash proxy failed' });
  }
});
app.get('/api/health/config', (_req, res) => {
  res.set('Cache-Control', 'no-store');
  res.json({
    openai: !!process.env.OPENAI_API_KEY,
    pixabay: !!process.env.PIXABAY_API_KEY,
    unsplash: !!process.env.UNSPLASH_ACCESS_KEY
  });
});




// First allowlist at top:
const INSIGHTS_ADMINS = new Set([
  "info@cultureschool.org",
  "stacey.a.grant@gmail.com",
  "stacey@cococreate.app",
]);
function buildAdvice(p) {
  const title = p.page_title || "(untitled)";
  const top = (p.actions || []).slice(0, 5).map(a => `• ${a}`).join("\n");
  const gaps = Object.entries(p.scores || {})
    .sort((a, b) => a[1] - b[1]).slice(0, 3)
    .map(([k, v]) => `• ${k}: ${v}`).join("\n");
  const intent = p.keyword ? `Intent: “${p.keyword}”\n` : "";
  const noFixes = "• No high-priority fixes found 🎯";

  return `Page: ${title}\n${intent}Top Fixes:\n${top || noFixes}\n\nScore Gaps:\n${gaps || "• None notable"}`;
}


app.post("/api/creator_insights_upsert", cors({ origin: true }), async (req, res) => {
  try {
    const adminEmail = String(req.body?.admin_email || "").toLowerCase();
    if (!INSIGHTS_ADMINS.has(adminEmail)) {
      return res.status(403).json({ error: "not_admin" });
    }

    const body = req.body || {};
    const advice = buildAdvice(body);

      const { error } = await supabase.from("creator_insights").insert([{
        url: body.url,
        page_title: body.page_title || null,
        keyword: body.keyword || null,
        scores: body.scores || {},
        highlights: body.highlights || {},
        findings: body.findings || [],
        actions: body.actions || [],
        seo_terms: body.seo_terms || {},
        tone: body.tone || {},
        look: body.look || {},
        brand_notes: body.brand_notes || null,
        advice,
        raw: body,
        creator_email: adminEmail
      }]);
      
    if (error) throw error;

    res.json({ ok: true, advice });
  } catch (e) {
    res.status(500).json({ error: String(e.message || e) });
  }
});

// GET /api/creator_insights_list
app.get("/api/creator_insights_list", cors({ origin: true }), async (req, res) => {
  try {
    const limit = Math.min(parseInt(req.query.limit || "100", 10), 500);
    const { data, error } = await supabase
      .from("creator_insights")
      .select("*")
      .order("created_at", { ascending: false })
      .limit(limit);
    if (error) throw error;
    res.set("content-type", "application/json");
    res.json({ rows: data || [] });
  } catch (e) {
    res.status(500).json({ error: String(e.message || e) });
  }
});

// POST /api/creator_insights_delete  { id, admin_email }
app.post("/api/creator_insights_delete", cors({ origin: true }), async (req, res) => {
  try {
    const id = String(req.body?.id || "").trim();
    const adminEmail = String(req.body?.admin_email || "").toLowerCase();
    if (!id) return res.status(400).json({ error: "missing_id" });
    if (!INSIGHTS_ADMINS.has(adminEmail)) return res.status(403).json({ error: "not_admin" });

    const { error } = await supabase
      .from("creator_insights")
      .delete()
      .eq("id", id); // ← removed .limit(1)

    if (error) throw error;
    res.json({ ok: true, id });
  } catch (e) {
    res.status(500).json({ error: String(e.message || e) });
  }
});


// POST /api/creator_insights_bulk_delete  { ids: string[], admin_email: string }
app.post("/api/creator_insights_bulk_delete", cors({ origin: true }), async (req, res) => {
  try {
    const ids = req.body?.ids || [];
    const adminEmail = String(req.body?.admin_email || "").toLowerCase();
    if (!Array.isArray(ids) || !ids.length) return res.status(400).json({ error: "missing_ids" });
    if (!INSIGHTS_ADMINS.has(adminEmail))   return res.status(403).json({ error: "not_admin" });

    // delete in chunks to avoid URL length/param limits
    const chunk = (arr, n) => arr.reduce((a,_,i)=> (i % n ? a : [...a, arr.slice(i, i+n)]), []);
    const batches = chunk(ids, 300);
    let total = 0;

    for (const batch of batches) {
      const { error, count } = await supabase
        .from("creator_insights")
        .delete({ count: "exact" })
        .in("id", batch);

      if (error) throw error;
      total += (count || 0);
    }

    res.json({ ok: true, deleted: total });
  } catch (e) {
    res.status(500).json({ error: String(e.message || e) });
  }
});
// ===== helpers =====
function normalizeUrl(u){ try { return new URL(u).toString(); } catch { return String(u||""); } }
function nowISO(){ return new Date().toISOString(); }

// Heuristics reused
function topKeywordsFrom(text, extraStop) {
  const stop = new Set([
    "the","a","an","and","or","but","of","to","in","on","for","is","are","was","were","it","with",
    "you","your","at","from","by","as","this","that","these","those","be","we","our","us","they",
    "i","me","my","&","–","—"
  ].concat(extraStop||[]));
  text = (text||"").toLowerCase();
  const words = (text.match(/[a-z0-9’']+/g) || []).filter(w => !stop.has(w) && w.length>2);
  const bigrams = [];
  for (let i=0;i<words.length-1;i++) bigrams.push(words[i]+" "+words[i+1]);
  const counts = new Map();
  words.concat(bigrams).forEach(w => counts.set(w, (counts.get(w)||0)+1));
  return Array.from(counts.entries())
    .sort((a,b)=>b[1]-a[1])
    .slice(0,25)
    .map(([term,freq])=>({term,freq}));
}

function inferVoice(t){
  const s = (t||"").toLowerCase();
  const f = {
    friendly: /\b(hey|hi|let’s|we|you|welcome|love|fun|enjoy|easy|simple)\b/.test(s),
    luxury:   /\b(premium|luxury|bespoke|atelier|craftsmanship|silhouette|curated)\b/.test(s),
    professional:/\b(solution|services|clients|portfolio|strategy|results|framework)\b/.test(s),
    playful: /!/.test(t) || /\b(fun|play|joy|spark|magic)\b/.test(s),
    academic:/\b(research|study|methodology|theory|evidence|peer)\b/.test(s)
  };
  const order = ["friendly","luxury","professional","playful","academic"].filter(k=>f[k]);
  return order[0] || "neutral";
}

function readabilityBandFromFlesch(score){
  return score>=70 ? "Grade 5–6"
    : score>=60 ? "Grade 7–8"
    : score>=50 ? "Grade 9–10"
    : "Grade 11+";
}

function flesch(text){
  const s = (text.match(/[\.\!\?]+/g)||[]).length || 1;
  const words = (text.match(/\b[\w’']+\b/g)||[]);
  const w = words.length || 1;
  const syl = words.reduce((a,x)=> a + ((x.toLowerCase().match(/[aeiouy]+/g)||[]).length || 1), 0);
  const raw = 206.835 - 1.015*(w/s) - 84.6*(syl/w);
  return Math.max(0, Math.min(100, Math.round(raw)));
}

// ===== queue starter (simple in-process) =====
async function runDeepReviewRow(rowId, supabase){
  // 1) Load row
  let { data: rows, error } = await supabase.from("deep_reviews").select("*").eq("id", rowId).limit(1);
  if (error) throw error;
  const row = (rows && rows[0]) || null;
  if (!row) throw new Error("review_row_not_found");

  // 2) Mark running
  await supabase.from("deep_reviews").update({ status: "running", started_at: nowISO(), error: null }).eq("id", rowId);

  try {
    const url = normalizeUrl(row.url);

    // 3) Fetch HTML (server-side, no CORS)
    const resp = await fetch(url, { headers: { "user-agent": "CoCoDeepReview/1.0 (+https://cultureschool.org)" } });
    const html = await resp.text();

    // 4) Parse with JSDOM/Readability
    const dom = new JSDOM(html, { url });
    const doc = dom.window.document;
    const reader = new Readability(doc);
    const article = reader.parse() || {};
    const readableText = (article.textContent || "").trim();

    // 5) Meta/OG
    const $ = cheerio.load(html);
    const title = $("title").text() || article.title || "";
    const metaDesc = $('meta[name="description"]').attr("content") || "";
    const ogTitle = $('meta[property="og:title"]').attr("content") || "";
    const ogDesc = $('meta[property="og:description"]').attr("content") || "";
    const ogImage = $('meta[property="og:image"]').attr("content") || "";
    const hText = ["h1","h2","h3"].map(sel => $(sel).map((i,el)=>$(el).text()).get().join(" ")).join(" ");

    // 6) Basic NLP bits
    const keywordsBody = topKeywordsFrom(readableText);
    const keywordsHead = topKeywordsFrom(hText);
    const keywordsMeta = topKeywordsFrom([title, metaDesc, ogTitle, ogDesc].filter(Boolean).join(" "));

    // sentiment-ish / tone-ish (very light)
    const docNlp = nlp(readableText);
    const sentences = docNlp.sentences().out("array") || [];
    const exclamations = (readableText.match(/!/g)||[]).length;
    const voice = inferVoice(readableText + " " + title);
    const reading = flesch(readableText);
    const band = readabilityBandFromFlesch(reading);

    // 7) Schema types
    const schemaTypes = [];
    $('script[type="application/ld+json"]').each((i,el)=>{
      try{
        const json = JSON.parse($(el).text());
        const types = Array.isArray(json) ? json.map(x=>x["@type"]).flat() : [json["@type"]];
        types.filter(Boolean).forEach(t=> schemaTypes.push(t));
      }catch{}
    });

    // 8) Build result JSON
    const result = {
      url,
      meta: { title, metaDesc, ogTitle, ogDesc, ogImage },
      headings_present: Boolean(hText.trim()),
      schema: { types: Array.from(new Set(schemaTypes)) },
      nlp: {
        sentences: sentences.length,
        exclamations
      },
      seo_terms: {
        top_keywords: keywordsBody,
        headings: keywordsHead,
        meta: keywordsMeta
      },
      tone: {
        voice,
        readability_score: reading,
        readability_band: band
      },
      // keep the full Readability output in case you need it
      readability: {
        title: article.title || "",
        byline: article.byline || "",
        length: (article.textContent||"").length
      }
    };

    // 9) Save result
    await supabase.from("deep_reviews").update({
      status: "done",
      finished_at: nowISO(),
      result
    }).eq("id", rowId);

  } catch (err) {
    await supabase.from("deep_reviews").update({
      status: "error",
      finished_at: nowISO(),
      error: String(err && err.message || err)
    }).eq("id", rowId);
  }
}

// ===== API: enqueue =====
// POST /api/deep_review_enqueue { url, admin_email, insight_id? }
app.post("/api/deep_review_enqueue", cors({ origin: true }), async (req, res) => {
  try {
    const url = normalizeUrl(req.body?.url || "");
    const adminEmail = String(req.body?.admin_email || "").toLowerCase();
    const insightId = req.body?.insight_id || null;

    if (!url) return res.status(400).json({ error: "missing_url" });
    if (!INSIGHTS_ADMINS.has(adminEmail)) return res.status(403).json({ error: "not_admin" });

    const { data, error } = await supabase
      .from("deep_reviews")
      .insert([{ url, requested_by: adminEmail, insight_id: insightId, status: "queued" }])
      .select("*")
      .limit(1);
    if (error) throw error;

    const row = data[0];
    // fire-and-forget in-process worker (simple)
    setImmediate(() => runDeepReviewRow(row.id, supabase).catch(()=>{}));

    res.json({ ok: true, id: row.id, status: "queued" });
  } catch (e) {
    res.status(500).json({ error: String(e.message || e) });
  }
});

// GET /api/deep_review_status?id=<review_id>
// or /api/deep_review_status?insight_id=<insight_id>&latest=1
app.get("/api/deep_review_status", cors({ origin: true }), async (req, res) => {
  try {
    const id = req.query.id;
    const insightId = req.query.insight_id;
    let q = supabase.from("deep_reviews").select("*");
    if (id) q = q.eq("id", id).limit(1);
    else if (insightId) q = q.eq("insight_id", insightId).order("created_at", { ascending: false }).limit(1);
    else return res.status(400).json({ error: "missing_id_or_insight_id" });

    const { data, error } = await q;
    if (error) throw error;
    res.json({ rows: data || [] });
  } catch (e) {
    res.status(500).json({ error: String(e.message || e) });
  }
});
// =====================
// Product Scraper Route
// =====================


app.get('/api/scrape-product', async (req, res) => {
  const url = req.query.url;
  if (!url) return res.status(400).json({ error: 'Missing ?url=' });

  try {
    const response = await axios.get(url, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
      }
    });

    const html = response.data;
    const $ = cheerio.load(html);

    // ---- Extract metadata (OG + fallbacks) ----
    const title =
      $('meta[property="og:title"]').attr('content') ||
      $('title').text() ||
      null;

    const image =
      $('meta[property="og:image"]').attr('content') ||
      $('meta[name="twitter:image"]').attr('content') ||
      $('img').first().attr('src') ||
      null;

    const description =
      $('meta[property="og:description"]').attr('content') ||
      $('meta[name="description"]').attr('content') ||
      null;

    const canonical =
      $('link[rel="canonical"]').attr('href') || url;

    res.json({
      title,
      image,
      description,
      canonical
    });

  } catch (err) {
    console.error('Scrape error:', err.message);
    res.status(500).json({ error: 'Scrape failed', details: err.message });
  }
});

// WebSocket + Express listener
const PORT = process.env.PORT || 5055;
server.listen(PORT, () => {
  console.log(`🚀 Server & WebSocket live on port ${PORT}`);
});
