export async function handler(event) {
  const query = event.queryStringParameters.query || "design";
  const per_page = event.queryStringParameters.per_page || 12;
  const API_KEY = process.env.PIXABAY_API;

  try {
    const res = await fetch(
      `https://pixabay.com/api/?key=${API_KEY}&q=${encodeURIComponent(query)}&image_type=photo&per_page=${per_page}`
    );
    const data = await res.json();
    return {
      statusCode: res.status,
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(data),
    };
  } catch (err) {
    return { statusCode: 500, body: JSON.stringify({ error: err.message }) };
  }
}
