const express = require('express');
const cors = require('cors');
const axios = require('axios');
const http = require('http');
const setupWebSocket = require('./websocket');
require('dotenv').config();

// ✅ ENV Check
console.log("🔍 Checking .env values:");
console.log("🔑 BASE:", process.env.AIRTABLE_BASE_ID);
console.log("📁 TABLE:", process.env.AIRTABLE_TABLE_ID);
console.log("🔒 TOKEN:", process.env.AIRTABLE_API_TOKEN?.slice(0, 6) + "...");

const app = express();
app.use(express.json());

const allowedOrigins = [
  'https://www.cultureschool.org',
  'http://localhost:5055',
  'http://localhost:3000',
  'http://127.0.0.1:3000'
];

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

app.options('*', cors());

// ✅ Airtable Save Profile Route
app.post("/api/save-to-airtable", async (req, res) => {
  const { email, username, profilePic, inviteCode, invitedBy, circleID, mediaUploads } = req.body;

  if (!email || !username) {
    return res.status(400).json({ success: false, error: "Missing email or username." });
  }

  try {
    const airtableRes = await axios.post(
      `https://api.airtable.com/v0/${process.env.AIRTABLE_BASE_ID}/${encodeURIComponent(process.env.AIRTABLE_TABLE_ID)}`,
      {
        fields: {
          email,
          username,
          profilePic,
          inviteCode,
          invitedBy,
          circleID,
          mediaUploads: mediaUploads || []
        }
      },
      {
        headers: {
          Authorization: `Bearer ${process.env.AIRTABLE_API_TOKEN}`,
          "Content-Type": "application/json"
        }
      }
    );

    res.status(200).json({ success: true, data: airtableRes.data });
  } catch (error) {
    console.error("❌ Airtable save error:", error.response?.data || error.message);
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

const server = http.createServer(app);
setupWebSocket(server);

server.listen(5055, () => {
  console.log("🚀 Server running on http://localhost:5055");
});
