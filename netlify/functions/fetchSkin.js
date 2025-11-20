exports.handler = async (event) => {
    const url = event.queryStringParameters.url;
    if (!url) return { statusCode: 400, body: "No URL provided" };
  
    try {
      const res = await fetch(url);
      const text = await res.text();
      return {
        statusCode: 200,
        headers: {
          "Content-Type": "text/html; charset=utf-8",
          "Access-Control-Allow-Origin": "*"
        },
        body: text
      };
  
    } catch (err) {
      return { statusCode: 500, body: "Failed to fetch skin: " + err };
    }
  };
  