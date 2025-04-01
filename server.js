const express = require('express');
const cors = require('cors');
const axios = require('axios');
const http = require('http');
const setupWebSocket = require('./websocket');
require('dotenv').config();
console.log("🧪 ENV CHECK:", process.env.SHOPIFY_STORE_DOMAIN, process.env.ADMIN_API_TOKEN);



// 🔐 Environment check
if (!process.env.SHOPIFY_STORE_DOMAIN || !process.env.ADMIN_API_TOKEN) {
  console.error("❌ Missing SHOPIFY_STORE_DOMAIN or ADMIN_API_TOKEN in environment");
  process.exit(1); // Exit early so you don’t hit Shopify with undefined data
}

const app = express();
app.use(express.json());

// ✅ CORS SETUP: Allow both local + live origins
const allowedOrigins = ['https://www.cultureschool.org', 'http://localhost:5051', 'http://localhost:3000',
'http://127.0.0.1:3000'];

app.use(cors({
  origin: function (origin, callback) {
    if (!origin || allowedOrigins.includes(origin)) {
      callback(null, true);
    } else {
      console.warn(`⛔ CORS blocked: ${origin}`);
      callback(new Error('⛔ Not allowed by CORS'));
    }
  
  },
  credentials: true,
}));

// ✅ Preflight (OPTIONS) response handling
app.options('*', cors());


// ✅ UGC SAVE ROUTE
app.post("/api/save-ugc", async (req, res) => {
  try {
    const {
      username,
      email,
      profilePic,
      invite_code,
      invited_by
    } = req.body;

    if (!username || !email) {
      return res.status(400).json({ success: false, error: "Missing username or email." });
    }

    const finalInviteCode = invite_code || "Admin-Circle-2025";
    const key = email.toLowerCase().replace(/[@.]/g, "_");

    const profileData = {
      username,
      email,
      profilePic,
      invite_code: finalInviteCode,
      invited_by: invited_by || ""
    };

    const metafieldData = {
      metafield: {
        namespace: "customer_profile",
        key: key,
        type: "json",
        value: JSON.stringify(profileData)
      }
    };

    console.log("📦 FINAL JSON TO SHOPIFY:", JSON.stringify(metafieldData, null, 2));

    const response = await axios.post(
      `https://${process.env.SHOPIFY_STORE_DOMAIN}/admin/api/2024-01/metafields.json`,
      metafieldData,
      {
        headers: {
          "X-Shopify-Access-Token": process.env.ADMIN_API_TOKEN,
          "Content-Type": "application/json"
        }
      }
    );

    res.status(200).json({ success: true, data: response.data });
  } catch (error) {
    console.error("❌ Error saving UGC to Shopify:", error.message);
    res.status(500).json({ success: false, error: error.message });
  }
});
// ✅ TEMP MESSAGE FETCH ROUTE
let inMemoryMessages = {
  "Admin-Circle-2025": []
};

app.get("/api/get-circle-messages", (req, res) => {
  const groupId = req.query.group_id;

  if (!groupId) {
    return res.status(400).json({ success: false, error: "Missing group_id" });
  }

  const messages = inMemoryMessages[groupId] || [];
  res.status(200).json({ success: true, messages });
});

// ✅ TEMP MESSAGE UPDATE ROUTE
app.post("/api/update-circle-message", (req, res) => {
  const { group_id, new_message } = req.body;

  if (!group_id || !new_message) {
    return res.status(400).json({ success: false, error: "Missing group_id or message" });
  }

  if (!inMemoryMessages[group_id]) {
    inMemoryMessages[group_id] = [];
  }

  inMemoryMessages[group_id].push(new_message);
  res.status(200).json({ success: true, message: "Message added" });
});
// ✅ Get Tribe Members for a Circle
app.get("/api/get-circle-tribe", async (req, res) => {
  const groupId = req.query.group_id;
  if (!groupId) {
    return res.status(400).json({ success: false, error: "Missing group_id" });
  }

  try {
    // TODO: replace with real storage logic
    const fakeMembers = [
      { name: "Todd", avatar: "https://via.placeholder.com/60?text=T" },
      { name: "Stacey", avatar: "https://via.placeholder.com/60?text=S" }
    ];

    res.status(200).json({ success: true, tribe_members: fakeMembers });
  } catch (err) {
    console.error("❌ Failed to get tribe members:", err);
    res.status(500).json({ success: false, error: "Server error" });
  }
});

// ✅ HTTP + WebSocket Setup
const server = http.createServer(app);
setupWebSocket(server);


// ✅ Start the server
server.listen(5051, () => {
  console.log("🚀 Server running on http://localhost:5051");
});
