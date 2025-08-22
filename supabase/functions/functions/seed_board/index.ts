import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// 🔐 Hardcoded test credentials (replace with your real values)
const supabase = createClient(
  "https://your-project-id.supabase.co",       // replace with your project URL
  "your-service-role-key"                      // replace with your service role key
);

serve(async () => {
  const { data, error } = await supabase
    .from("creator_seed_queue")
    .select("*")
    .limit(1);

  if (error) {
    console.error("🧨 Supabase error:", error);
    return new Response(JSON.stringify({ error: error.message }), { status: 500 });
  }

  return new Response(JSON.stringify({ message: "Supabase is connected 🎉", data }), {
    status: 200,
  });
});