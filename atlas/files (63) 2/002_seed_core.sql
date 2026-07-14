-- Starter seed: four sourcing countries + initial textile/fiber/fabric concepts.
-- Idempotent by slug.

insert into public.cs_kg_places (place_type, name, slug, iso_code, summary)
values
('country','Indonesia','indonesia','ID','Archipelagic textile center associated with batik, ikat, songket and contemporary digital printing.'),
('country','Mexico','mexico','MX','Nearshore textile market with industrial cotton production and regionally distinct artisan weaving traditions.'),
('country','Thailand','thailand','TH','Textile market spanning industrial woven fabrics, natural dyeing, silk, cotton and small-run printing.'),
('country','Vietnam','vietnam','VN','Large apparel and textile manufacturing base with integrated factories and regional weaving traditions.')
on conflict (slug) do update set summary = excluded.summary;

insert into public.cs_kg_entries
(entry_type, name, slug, short_definition, overview, source_status, sensitivity_level, is_public)
values
('fiber','Cotton','cotton','A natural seed fiber widely spun and woven for apparel and home textiles.','CultureSchool tracks fiber origin, certification, yarn type and finishing separately from fabric construction.','researched','general',false),
('fiber','Linen','linen','A textile made from flax fiber.','True linen should be distinguished from linen-look fabrics and blends whose flax percentage is not disclosed.','researched','general',false),
('fabric','Cotton Poplin','cotton-poplin','A plain-weave cotton fabric with a smooth, structured surface.','Suitable for shirts, structured dresses, table linens and crisp printed products.','researched','general',false),
('fabric','Cotton-Linen Blend','cotton-linen-blend','A woven fabric combining cotton and flax linen.','Composition, GSM, weave, finishing and shrinkage should be stored for each supplier base rather than inferred from the commercial name.','researched','general',false),
('fabric','Linen-Viscose Blend','linen-viscose-blend','A blend combining linen texture with viscose drape.','Useful for fluid resortwear silhouettes; exact composition and fiber sourcing require supplier documentation.','researched','general',false),
('print_method','Reactive Digital Printing','reactive-digital-printing','Digital printing using reactive dyes that chemically bond with cellulosic fibers.','Often preferred for cotton and linen when softness, penetration and wash performance matter.','researched','general',false),
('print_method','Pigment Digital Printing','pigment-digital-printing','Digital printing that deposits pigment and binder on the textile surface.','Can support shorter runs and broad fabric compatibility; hand feel and crocking must be tested.','researched','general',false),
('textile_tradition','Batik','batik','A wax-resist textile process strongly associated with Indonesia and practiced in multiple regions.','Dictionary publication requires country- and community-specific context rather than treating batik as a generic print aesthetic.','draft','context_required',false),
('textile_tradition','Ikat','ikat','A resist-dyeing method applied to yarns before weaving.','Ikat exists in many distinct cultural traditions; entries should link to specific places and communities.','draft','context_required',false)
on conflict (slug) do update set
  short_definition = excluded.short_definition,
  overview = excluded.overview;

-- Place links
insert into public.cs_kg_entry_places (entry_id, place_id, relationship_type, is_primary)
select e.id, p.id, 'associated_with', true
from public.cs_kg_entries e cross join public.cs_kg_places p
where e.slug = 'batik' and p.slug = 'indonesia'
on conflict do nothing;

insert into public.cs_kg_entry_places (entry_id, place_id, relationship_type, is_primary)
select e.id, p.id, 'associated_with', true
from public.cs_kg_entries e cross join public.cs_kg_places p
where e.slug = 'ikat' and p.slug = 'indonesia'
on conflict do nothing;
