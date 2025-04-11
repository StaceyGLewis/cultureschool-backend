// inspirationCollectorBackend.js (Node.js + Supabase)

// Load environment variables from .env filenpm 
import dotenv from 'dotenv';
dotenv.config();

// Import dependencies
import express from 'express';
import cors from 'cors';
import { createClient } from '@supabase/supabase-js';

// Initialize Express and middleware
const app = express();
app.use(cors());
app.use(express.json());

// Supabase setup
const supabaseUrl = process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
const supabase = createClient(supabaseUrl, supabaseKey);

// [Your routes here...]


// POST route to save a pinned item
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

// GET route to fetch all pinned items for a user or a specific board
app.get('/api/get-pins', async (req, res) => {
  const { email, boardId } = req.query;
  let query = supabase.from('pins').select('*').order('created_at', { ascending: false });

  if (email) query = query.eq('email', email);
  if (boardId) query = query.eq('board_id', boardId);

  const { data, error } = await query;
  if (error) return res.status(500).json({ success: false, error });
  res.json({ success: true, data });
});
// POST route to react to a pin
app.post('/api/react-to-pin', async (req, res) => {
    const { email, pinId, reactionType } = req.body;
  
    const { data, error } = await supabase
      .from('pin_reactions')
      .upsert([{
        pin_id: pinId,
        email,
        reaction_type: reactionType,
        reacted_at: new Date().toISOString()
      }], {
        onConflict: ['pin_id', 'email'] // ensures only one reaction per pin per user
      });
  
    if (error) return res.status(500).json({ success: false, error });
    res.json({ success: true, data });
  });
// Example boards table creation schema (in Supabase UI):
// boards: [id, email, name, created_at]

// Example pins table schema:
// pins: [id, email, title, image_url, source_url, description, tags (array), mood, board_id, created_at]

const PORT = process.env.PORT || 5055;
app.listen(PORT, () => console.log(`📌 Inspiration Collector API running on port ${PORT}`));
