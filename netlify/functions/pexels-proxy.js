// Serverless proxy for Pexels. Keeps your API token private.
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
    const token = process.env.PEXELS_API;
    if (!token) {
      return { statusCode: 500, headers: CORS, body: JSON.stringify({ error: "PEXELS_API not set" }) };
    }

    const qs = new URLSearchParams(event.queryStringParameters || {});
    const query = qs.get('query') || qs.get('q') || 'inspiration';
    const per   = Math.min(parseInt(qs.get('per_page') || '12', 10), 30); // sensible cap
    const thumb = qs.get('thumb');

    const url = `https://api.pexels.com/v1/search?query=${encodeURIComponent(query)}&per_page=${per}`;
    const res = await fetch(url, { headers: { Authorization: token }});
    if (!res.ok) {
      return { statusCode: res.status, headers: CORS, body: JSON.stringify({ error: `Pexels ${res.status}` }) };
    }
    const data = await res.json();

    // If ?thumb=1, redirect to a tiny image so <img src="/api/pexels-proxy?...&thumb=1"> works.
    if (thumb) {
      const p = data?.photos?.[0];
      const tiny = p?.src?.tiny || p?.src?.small || p?.src?.medium || p?.src?.large;
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
