// netlify/functions/img-proxy.js (CJS syntax; works on Netlify Functions)
const ALLOWED_PROTOCOLS = new Set(['http:', 'https:']);

// Optional: restrict to specific hosts if you want
// const ALLOW_HOSTS = new Set(['images.unsplash.com', 'cdn.shopify.com']);

exports.handler = async (event) => {
  try {
    const url = (event.queryStringParameters && event.queryStringParameters.url) || '';
    if (!url) {
      return { statusCode: 400, body: 'Missing ?url=' };
    }

    let target;
    try {
      target = new URL(url);
    } catch {
      return { statusCode: 400, body: 'Invalid URL' };
    }

    if (!ALLOWED_PROTOCOLS.has(target.protocol)) {
      return { statusCode: 400, body: 'Only http/https supported' };
    }

    // If you want a host allowlist, uncomment:
    // if (!ALLOW_HOSTS.has(target.hostname)) {
    //   return { statusCode: 403, body: 'Host not allowed' };
    // }

    const upstream = await fetch(target.toString(), { redirect: 'follow' });
    if (!upstream.ok) {
      return { statusCode: upstream.status, body: `Upstream error: ${upstream.statusText}` };
    }

    const contentType = upstream.headers.get('content-type') || 'application/octet-stream';
    const arrayBuf = await upstream.arrayBuffer();
    const b64 = Buffer.from(arrayBuf).toString('base64');

    return {
      statusCode: 200,
      headers: {
        'Content-Type': contentType,
        'Cache-Control': 'public, max-age=31536000, immutable',
        'Access-Control-Allow-Origin': '*', // allow canvas readback
      },
      isBase64Encoded: true,
      body: b64,
    };
  } catch (err) {
    return { statusCode: 500, body: `Proxy error: ${String(err)}` };
  }
};
