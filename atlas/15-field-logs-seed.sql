-- ============================================================================
--  15-field-logs-seed.sql
--  Test data for the Field Logs module — 3 logs with palette + signals
--  Run in Supabase SQL Editor, then hard-refresh the Atlas and click Field Logs
-- ============================================================================

insert into public.cs_field_logs (
  title, location, observed_date, source_type, technique,
  logged_by, image_count,
  master_palette,
  heritage_signals,
  atlas_matches,
  notes
) values
(
  'Accra Market — Kente & Batik',
  'Accra, Ghana',
  '2026-07-15',
  'market',
  'Kente weaving, Adinkra stamp, wax resist',
  'Stacey Grant-Lewis',
  18,
  '[
    {"hex":"#C8871A","r":200,"g":135,"b":26,"weight":0.31,"name":"Kente Gold","img_count":9},
    {"hex":"#1A3D2B","r":26,"g":61,"b":43,"weight":0.22,"name":"Forest Green","img_count":7},
    {"hex":"#8B1A1A","r":139,"g":26,"b":26,"weight":0.18,"name":"Deep Red","img_count":6},
    {"hex":"#F5E6C8","r":245,"g":230,"b":200,"weight":0.15,"name":"Cream Ground","img_count":5},
    {"hex":"#1A1A1A","r":26,"g":26,"b":26,"weight":0.14,"name":"Jet Black","img_count":4}
  ]'::jsonb,
  '{
    "feeling":"warm ceremonial",
    "occasion":"festival",
    "vibe":"bold geometric",
    "markers":["Kente","Adinkra","Ashanti"],
    "techniques":["strip weaving","stamping","wax resist"]
  }'::jsonb,
  '[
    {"id":"atlas-001","title":"Kente","heritage_group":"Akan","score":0.94},
    {"id":"atlas-002","title":"Adinkra","heritage_group":"Ashanti","score":0.87}
  ]'::jsonb,
  'Strong festival palette — gold, green, red dominate. Vendor mentioned upcoming Odwira season driving demand.'
),
(
  'Lagos Textile District — Adire & Aso-Oke',
  'Lagos, Nigeria',
  '2026-07-10',
  'supplier',
  'Adire eleko, Aso-oke hand-weaving',
  'Stacey Grant-Lewis',
  22,
  '[
    {"hex":"#2B4A8B","r":43,"g":74,"b":139,"weight":0.28,"name":"Indigo Deep","img_count":10},
    {"hex":"#C8871A","r":200,"g":135,"b":26,"weight":0.24,"name":"Kente Gold","img_count":8},
    {"hex":"#F0E8D8","r":240,"g":232,"b":216,"weight":0.21,"name":"Ecru Ground","img_count":7},
    {"hex":"#6B3A2A","r":107,"g":58,"b":42,"weight":0.16,"name":"Terracotta","img_count":6},
    {"hex":"#1C3520","r":28,"g":53,"b":32,"weight":0.11,"name":"Dark Forest","img_count":4}
  ]'::jsonb,
  '{
    "feeling":"cool indigo",
    "occasion":"everyday wear",
    "vibe":"resist pattern depth",
    "markers":["Adire","Yoruba","Aso-oke"],
    "techniques":["cassava paste resist","hand weaving","natural indigo"]
  }'::jsonb,
  '[
    {"id":"atlas-003","title":"Adire","heritage_group":"Yoruba","score":0.96},
    {"id":"atlas-004","title":"Aso-oke","heritage_group":"Yoruba","score":0.89}
  ]'::jsonb,
  'Indigo is the dominant signal — multiple suppliers working with natural indigo. Gold appears again alongside indigo, echoing the Accra corpus.'
),
(
  'Kumasi — Kente Region Deep Dive',
  'Kumasi, Ghana',
  '2026-07-20',
  'field',
  'Kente strip weaving, narrow-loom',
  'Nana Ama Twum',
  14,
  '[
    {"hex":"#CA8A12","r":202,"g":138,"b":18,"weight":0.35,"name":"Kente Gold","img_count":9},
    {"hex":"#1F3D2C","r":31,"g":61,"b":44,"weight":0.20,"name":"Forest Green","img_count":6},
    {"hex":"#8E1C1C","r":142,"g":28,"b":28,"weight":0.17,"name":"Ceremonial Red","img_count":5},
    {"hex":"#F8EDD8","r":248,"g":237,"b":216,"weight":0.16,"name":"Warm White","img_count":5},
    {"hex":"#4A2C8A","r":74,"g":44,"b":138,"weight":0.12,"name":"Royal Purple","img_count":3}
  ]'::jsonb,
  '{
    "feeling":"warm ceremonial",
    "occasion":"royalty and ceremony",
    "vibe":"bold geometric",
    "markers":["Kente","Ashanti","Bonwire"],
    "techniques":["strip weaving","narrow-loom","hand weaving"]
  }'::jsonb,
  '[
    {"id":"atlas-001","title":"Kente","heritage_group":"Akan","score":0.98},
    {"id":"atlas-005","title":"Bonwire Weaving","heritage_group":"Ashanti","score":0.82}
  ]'::jsonb,
  'Source village for Kente. Same gold/green/red triad as Accra corpus — strong cross-corpus signal. Strip widths are narrowing for export market.'
);

-- Verify
select id, title, location, image_count, created_at
from public.cs_field_logs
order by created_at desc
limit 10;
