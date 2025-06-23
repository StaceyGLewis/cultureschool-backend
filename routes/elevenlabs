const express = require('express');
const router = express.Router();
const fetch = require('node-fetch'); // Only needed if you're using Node <18

router.post('/speak', async (req, res) => {
  const { text } = req.body;

  if (!text) {
    return res.status(400).json({ error: "Missing 'text' in body" });
  }

  try {
    const elevenRes = await fetch(`https://api.elevenlabs.io/v1/text-to-speech/2qfp6zPuviqeCOZIE9RZ`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "xi-api-key": process.env.ELEVENLABS_API_KEY
      },
      body: JSON.stringify({
        text,
        model_id: "eleven_monolingual_v1",
        voice_settings: { stability: 0.7, similarity_boost: 0.75 }
      })
    });

    const audioBuffer = await elevenRes.arrayBuffer();

    res.setHeader("Content-Type", "audio/mpeg");
    res.send(Buffer.from(audioBuffer));
  } catch (err) {
    console.error("Error contacting ElevenLabs:", err);
    res.status(500).json({ error: "Voice generation failed" });
  }
});

module.exports = router;
