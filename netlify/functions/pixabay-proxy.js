// Serverless proxy for Pixabay. Keeps your API key private.
const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type"
};

exports.handler = async (event) => {
  if (event.httpMethod === 'OPTIONS') {
    return { statusCode: 204, headers: CORS };
  }

  try {
    const key = process.env.PIXABAY_API;
    if (!key) {
      return { statusCode: 500, headers: CORS, body: JSON.stringify({ error: "PIXABAY_API not set" }) };
    }

    const qs = new URLSearchParams(event.queryStringParameters || {});
    const query = qs.get('query') || qs.get('q') || 'inspiration';
    const per   = Math.min(parseInt(qs.get('per_page') || '12', 10), 50); // Pixabay higher cap
    const thumb = qs.get('thumb');

    const url = `https://pixabay.com/api/?key=${encodeURIComponent(key)}&q=${encodeURIComponent(query)}&image_type=photo&per_page=${per}`;
    const res = await fetch(url);
    if (!res.ok) {
      return { statusCode: res.status, headers: CORS, body: JSON.stringify({ error: `Pixabay ${res.status}` }) };
    }
    const data = await res.json();

    if (thumb) {
      const h = data?.hits?.[0];
      const tiny = h?.previewURL || h?.webformatURL || h?.largeImageURL;
      if (tiny) {
        return {
          statusCode: 302,
          headers: { ...CORS, Location: tiny, "Cache-Control": "public, max-age=600" },
          body: ""
        };
      }
      return { statusCode: 404, headers: CORS, body: "No thumb" };
    }

    return {
      statusCode: 200,
      headers: { ...CORS, "Content-Type": "application/json", "Cache-Control": "public, max-age=60" },
      body: JSON.stringify(data)
    };
  } catch (e) {
    return { statusCode: 500, headers: CORS, body: JSON.stringify({ error: e.message }) };
  }
};
