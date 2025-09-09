// supabase/functions/explore-search/index.ts
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { serve } from 'https://deno.land/std@0.224.0/http/server.ts'

serve(async (req) => {
  const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
  const SUPABASE_ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY')!
  const client = createClient(SUPABASE_URL, SUPABASE_ANON_KEY)

  const { q } = Object.fromEntries(new URL(req.url).searchParams)
  const { data, error } = await client
    .from('cocoboards')
    .select('id, title, lat, lng, location')
    .ilike('title', `%${q||''}%`)
    .limit(50)

  if (error) return new Response(JSON.stringify({ error: error.message }), { status: 400 })
  return new Response(JSON.stringify({ results: data }), { headers: { 'content-type': 'application/json' } })
})
