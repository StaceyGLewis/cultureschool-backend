// /netlify/functions/generateVoice.js

const fetch = require("node-fetch");

exports.handler = async (event, context) => {
  try {
    const { text } = JSON.parse(event.body);

    if (!text || text.length === 0) {
      return {
        statusCode: 400,
        body: JSON.stringify({ error: "No text provided." })
      };
    }

    const response = await fetch("https://api.elevenlabs.io/v1/text-to-speech/2qfp6zPuviqeCOZIE9RZ", {
      method: "POST",
      headers: {
        "xi-api-key": process.env.ELEVENLABS_API_KEY,
        "Content-Type": "application/json"
      },
      body: JSON.stringify({
        text,
        voice_settings: { stability: 0.5, similarity_boost: 0.75 }
      })
    });

    const audioBuffer = await response.buffer();

    return {
      statusCode: 200,
      headers: { "Content-Type": "audio/mpeg" },
      body: audioBuffer.toString("base64"),
      isBase64Encoded: true
    };

  } catch (error) {
    console.error("Voice generation error:", error);
    return {
      statusCode: 500,
      body: JSON.stringify({ error: "Internal Server Error." })
    };
  }
};


// Example frontend code snippet (add to your CoCo Speak page)

/*
async function speakCoCo(text) {
  const res = await fetch("/.netlify/functions/generateVoice", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ text })
  });

  const audioData = await res.arrayBuffer();
  const blob = new Blob([audioData], { type: "audio/mpeg" });
  const url = URL.createObjectURL(blob);

  const audio = new Audio(url);
  audio.play();
}

// Example button usage
// document.getElementById("cocoSpeakBtn").addEventListener("click", () => {
//   speakCoCo("Hello from your favorite creative sidekick!");
// });
*/
