const fetch = require('node-fetch');
const { createClient } = require('@supabase/supabase-js');

const SUPABASE_URL = 'https://qwulthvbwujfehgdegtn.supabase.co';
const SUPABASE_KEY = process.env.SUPABASE_SERVICE_KEY ||
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF3dWx0aHZid3VqZmVoZ2RlZ3RuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDQyMDcxODIsImV4cCI6MjA1OTc4MzE4Mn0.t9n4eZng6d0jggiPNK-J_DByvEE2L9tqy5Xh_1-TSoQ';

exports.handler = async (event) => {
  const CORS = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'Content-Type',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
  };

  if (event.httpMethod === 'OPTIONS') {
    return { statusCode: 200, headers: CORS, body: '' };
  }

  try {
    const { pattern_code, pattern_id, template_key } = JSON.parse(event.body || '{}');

    const db = createClient(SUPABASE_URL, SUPABASE_KEY);

    // Look up by code first, fall back to id (handles patterns without a code set)
    let query = db
      .from('patterns')
      .select(`
        id, name, code, palette_name, style, colors, color_descriptor, palette_story,
        tags, occasion, description,
        heritage_name, heritage_origin, heritage_region, heritage_era,
        heritage_meaning, heritage_technique, heritage_significance,
        culture_tags, aesthetic_tags, search_tags, continent, region
      `);

    if (pattern_code) {
      query = query.eq('code', pattern_code);
    } else if (pattern_id) {
      query = query.eq('id', pattern_id);
    } else {
      return { statusCode: 400, headers: CORS, body: JSON.stringify({ error: 'pattern_code or pattern_id required' }) };
    }

    const { data: pattern, error } = await query.single();

    if (error || !pattern) {
      return {
        statusCode: 404,
        headers: CORS,
        body: JSON.stringify({ error: 'Pattern not found' }),
      };
    }

    const colors = pattern.colors || [];
    const primary   = colors[0] || '#c8a050';
    const secondary = colors[1] || '#1a1208';
    const accent    = colors[2] || '#faf6ef';

    // Map colors directly — templates read --palette-1 through --palette-5
    const c = colors;
    const directPalette = {
      '--palette-1': c[0] || '#1a1208',
      '--palette-2': c[1] || '#8b6a3a',
      '--palette-3': c[2] || '#c9a96e',
      '--palette-4': c[3] || '#e8d5a8',
      '--palette-5': c[4] || '#faf6ef',
    };

    const prompt = `You are a design system for CoCo by CultureSchool — a color and pattern intelligence platform rooted in global cultural textile heritage.

Given this pattern's data, return ONLY a valid JSON object (no markdown, no explanation) with two keys: "css" and "copy".

Pattern data:
- Name: ${pattern.name}
- Code: ${pattern.code}
- Colors (hex array, in order): ${JSON.stringify(colors)}
- Color descriptor: ${pattern.color_descriptor || ''}
- Heritage origin: ${pattern.heritage_origin || ''}
- Heritage name: ${pattern.heritage_name || ''}
- Heritage meaning: ${pattern.heritage_meaning || ''}
- Heritage technique: ${pattern.heritage_technique || ''}
- Occasion: ${pattern.occasion || ''}
- Palette story: ${pattern.palette_story || ''}
- Culture tags: ${(pattern.culture_tags || []).join(', ')}
- Aesthetic tags: ${(pattern.aesthetic_tags || []).join(', ')}

The template uses these EXACT CSS variable names. Return values for all of them:
{
  "css": {
    "--accent": "<the most warm or distinctive color from the palette — used for buttons, highlights>",
    "--ink": "<darkest color in the palette — used for body text, must be readable on light bg>",
    "--ink-soft": "<mid-tone — used for secondary text, captions>",
    "--light": "<lightest color in the palette — used for backgrounds, surfaces>"
  },
  "copy": {
    "headline": "<8-10 word headline for this pattern's occasion, CoCo voice>",
    "subheader": "<one sentence, 15-20 words, cultural and warm>",
    "story": "<2 sentences grounded in the heritage meaning and technique>"
  }
}

Rules:
- All CSS values must be valid hex colors only (no rgba)
- --ink must be dark enough to read on white (#444 or darker)
- --light must be light enough for a background (#ddd or lighter)
- --accent should be the most culturally distinctive color from the palette
- Never use generic design language — be specific to this pattern's heritage`;

    const res = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': process.env.ANTHROPIC_API_KEY,
        'anthropic-version': '2023-06-01',
      },
      body: JSON.stringify({
        model: 'claude-sonnet-4-6',
        max_tokens: 800,
        messages: [{ role: 'user', content: prompt }],
      }),
    });

    const aiData = await res.json();
    const rawText = aiData?.content?.[0]?.text?.trim() || '{}';

    let result;
    try {
      const clean = rawText.replace(/```json|```/g, '').trim();
      result = JSON.parse(clean);
    } catch {
      result = { css: {}, copy: {} };
    }

    // Merge direct palette mapping (--palette-1 through --palette-5) with Claude's semantic vars
    result.css = { ...directPalette, ...(result.css || {}) };

    result.pattern = {
      name:            pattern.name,
      code:            pattern.code,
      colors:          pattern.colors,
      heritage_origin: pattern.heritage_origin,
      occasion:        pattern.occasion,
    };

    return {
      statusCode: 200,
      headers: { ...CORS, 'Content-Type': 'application/json' },
      body: JSON.stringify(result),
    };

  } catch (err) {
    return {
      statusCode: 500,
      headers: { 'Access-Control-Allow-Origin': '*' },
      body: JSON.stringify({ error: err.message }),
    };
  }
};
