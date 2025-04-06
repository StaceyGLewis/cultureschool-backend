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
app.post('/api/save-to-supabase', async (req, res) => {
  try {
    const data = req.body;

    const { data: existing, error: fetchErr } = await supabase
      .from('users')
      .select('*')
      .eq('email', data.email)
      .eq('invite_code', data.invite_code)
      .single();

    if (fetchErr && fetchErr.code !== 'PGRST116') throw fetchErr;

    let response;
    if (existing) {
      response = await supabase
        .from('users')
        .update({ ...data })
        .eq('email', data.email)
        .eq('invite_code', data.invite_code);
    } else {
      response = await supabase.from('users').insert([data]);
    }

    res.json({ success: true, message: 'Saved to Supabase', response });
  } catch (err) {
    console.error('❌ Supabase Save Error:', err);
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


const PORT = process.env.PORT || 5055;
server.listen(PORT, () => {
  console.log(`🚀 Server & WebSocket live on port ${PORT}`);
});
