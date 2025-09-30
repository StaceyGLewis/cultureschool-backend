// Minimal, robust mother-seeder with CORS + GET/POST support
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
};

function j(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json", ...corsHeaders },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: corsHeaders });

  // You can later load from a table or storage; for now return request body or a sample.
  let seeds: unknown;
  try {
    if (req.method === "POST") {
      seeds = await req.json();        // POST a JSON array to update seed live
    } else {
      // GET returns a tiny sample so your page always renders if seedUrl is set
      seeds = [{
        id: "seed-sample",
        slug: "seed-sample",
        title: "Sample Popup",
        description: "This is a sample so the page always paints.",
        image_url: "https://placehold.co/1200x800?text=Sample",
        place_name: "Anywhere",
        city_tag: "Sample City",
        // timing fields your page expects:
        starts_at: new Date(Date.now() + 60 * 60 * 1000).toISOString(),
        ends_at:   new Date(Date.now() + 2  * 60 * 60 * 1000).toISOString(),
        is_event: true,
        lat: 42.19, lng: -71.23
      }];
    }
  } catch {
    seeds = [];
  }

  return j(seeds);
});
