-- ============================================================
-- 011_kg_seed_pattern_dictionary.sql
-- Seeds cs_kg_entries and cs_kg_places from Pattern Dictionary content.
-- Idempotent: ON CONFLICT ... DO UPDATE / DO NOTHING throughout.
-- Run in Supabase SQL editor after 001_textile_knowledge_graph.sql.
--
-- AFTER RUNNING:
--   Search 'Batik' or 'Kente' in Intelligence Platform > Textile Atlas.
--   Review each entry and publish via the platform — do not bulk-publish.
--   Runes is intentionally excluded (see purge-runes.sql).
-- ============================================================

BEGIN;

-- ── 1. PLACES ───────────────────────────────────────────────────────────────

INSERT INTO cs_kg_places (slug, name, place_type, iso_code)
VALUES
  ('ghana',          'Ghana',           'country',         'GH'),
  ('nigeria',        'Nigeria',         'country',         'NG'),
  ('mali',           'Mali',            'country',         'ML'),
  ('dr-congo',       'DR Congo',        'country',         'CD'),
  ('kenya',          'Kenya',           'country',         'KE'),
  ('tanzania',       'Tanzania',        'country',         'TZ'),
  ('morocco',        'Morocco',         'country',         'MA'),
  ('indonesia',      'Indonesia',       'country',         'ID'),
  ('japan',          'Japan',           'country',         'JP'),
  ('india',          'India',           'country',         'IN'),
  ('uzbekistan',     'Uzbekistan',      'country',         'UZ'),
  ('scotland',       'Scotland',        'country',         'GB-SCT'),
  ('france',         'France',          'country',         'FR'),
  ('peru',           'Peru',            'country',         'PE'),
  ('hawaii',         'Hawaii',          'state_province',  'US-HI'),
  ('west-africa',    'West Africa',     'cultural_region', NULL),
  ('east-africa',    'East Africa',     'cultural_region', NULL),
  ('central-africa', 'Central Africa',  'cultural_region', NULL),
  ('north-africa',   'North Africa',    'cultural_region', NULL),
  ('southeast-asia', 'Southeast Asia',  'cultural_region', NULL),
  ('central-asia',   'Central Asia',    'cultural_region', NULL),
  ('south-asia',     'South Asia',      'cultural_region', NULL),
  ('caribbean',      'Caribbean',       'cultural_region', NULL),
  ('andean',         'Andean Region',   'cultural_region', NULL),
  ('ottoman-empire', 'Ottoman Empire',  'cultural_region', NULL)
ON CONFLICT (slug) DO UPDATE SET
  name       = EXCLUDED.name,
  place_type = EXCLUDED.place_type;

-- ── 2. ENTRIES ──────────────────────────────────────────────────────────────

INSERT INTO cs_kg_entries
  (slug, name, entry_type, sensitivity_level, source_status,
   short_definition, overview, cultural_context, is_public)
VALUES

('adinkra','Adinkra','textile_tradition','context_required','researched',
 'Adinkra are visual symbols representing concepts, aphorisms, and the wisdom of the Akan people — originally stamped on cloth worn at funerals and spiritual ceremonies, each symbol carries a specific meaning.',
 'Symbols are carved into calabash gourds and stamped onto fabric using natural dye made from badie tree bark. The word adinkra means ''goodbye'' or ''farewell'' in Twi.',
 'Adinkra cloth was originally worn only by Asante royalty and spiritual leaders. Today it signals cultural pride and connection to Ghanaian identity across the diaspora.',
 true),

('adire','Adire','dye_method','context_required','researched',
 'Adire means ''tied and dyed'' in Yoruba — a resist-dyeing tradition using indigo that produces geometric and organic patterns with deep cultural meaning. Two main forms: Adire Eleko (paste resist) and Adire Oniko (tie-dye).',
 'Adire Eleko uses cassava starch paste applied by hand or through metal stencils before indigo dyeing. The deep indigo blue is extracted from Lonchocarpus cyanescens leaves.',
 'Adire was traditionally made and traded by Yoruba women and was central to their economic independence. The town of Abeokuta in Ogun State remains its spiritual home.',
 true),

('kanga','Kanga','textile_tradition','general','researched',
 'The kanga is a brightly colored cotton cloth printed with bold borders, a central design, and most distinctively, a Swahili proverb (jina) printed across the bottom — the proverb gives the kanga its meaning.',
 'Screen-printed on cotton in bold geometric and floral designs with a characteristic triple border. The Swahili proverb is integral to the design.',
 'Kangas are one of East Africa''s most important social communication tools — given at birth, marriage, and death. The right kanga proverb can express what cannot be spoken aloud.',
 true),

('kente','Kente','textile_tradition','context_required','researched',
 'Kente cloth is woven in narrow strips (roughly 4 inches wide) that are sewn together to create larger garments — each color and pattern combination carries specific meaning.',
 'Woven on a horizontal strip loom using silk or cotton. The weaver creates patterns by manipulating the heddle to create geometric designs. Strips are then sewn edge to edge.',
 'Kente was originally worn exclusively by Asante royalty. Today it is worn across the African diaspora as a symbol of pride and connection to African heritage — at graduations, ceremonies, and celebrations.',
 true),

('kuba-cloth','Kuba Cloth','textile_tradition','context_required','researched',
 'Kuba cloth is made from raffia palm fiber and features intricately cut and embroidered geometric patterns. The Kuba Kingdom was renowned for its artistic sophistication.',
 'Woven from raffia palm fiber on a fixed-heddle loom, then cut-pile embroidery (like velvet) is applied using a small blade. The geometric vocabulary is highly codified — patterns are named and specific combinations carry meaning.',
 'The Kuba King was considered divine and Kuba cloth was inseparable from royal power. Kuba geometric forms influenced early 20th-century European modern artists who encountered them in Paris ethnographic collections.',
 true),

('mudcloth-bogolan','Mudcloth / Bògòlanfini','textile_tradition','context_required','researched',
 'Bògòlanfini means ''earth cloth'' in Bambara — bògo (earth/mud), lan (with), fini (cloth). The cloth is dyed using fermented mud and the symbols carry specific meanings related to Bamana history, spirituality, and identity.',
 'Cotton is woven on a narrow strip loom. The fabric is soaked in a solution of n''gallama tree leaves, turning it yellow. Patterns are painted with river mud, then the background is bleached away.',
 'Mudcloth was traditionally worn by hunters for spiritual protection and by women after childbirth and during initiation ceremonies. In the 1970s it was adopted as a symbol of Pan-African identity.',
 true),

('zellige','Zellige','motif','general','researched',
 'Zellige (from Arabic zillij, ''small polished stone'') is the art of hand-cut ceramic mosaic tile arranged into complex geometric patterns drawn from Islamic geometric tradition.',
 'Tiles are first fired as flat slabs, then hand-cut into geometric shapes using a special pick hammer (menqach). Pieces are assembled face-down in a pattern, then grouted from behind.',
 'The great Islamic monuments of Morocco use zellige as their visual centerpiece. Master zellige craftspeople train for decades and are considered national cultural treasures; the craft is on UNESCO''s endangered heritage list.',
 true),

('batik','Batik','dye_method','general','researched',
 'Batik is a wax-resist dyeing technique that produces intricate patterns with deep cultural meaning. Different regions of Java have distinct batik traditions — Yogyakarta uses cream and brown tones; Pekalongan shows Chinese and Dutch colonial influence.',
 'Hot wax is applied to fabric using a canting (a small copper pen) for hand-drawn batik or a copper stamp (cap) for printed batik. The fabric is then dyed, wax removed, and the process repeated for each color.',
 'UNESCO recognized Indonesian batik as Intangible Cultural Heritage in 2009. In Java, specific batik patterns are worn at weddings, funerals, and ceremonies. The parang pattern was historically reserved for Javanese royalty.',
 true),

('batik-tulis','Batik Tulis','dye_method','general','researched',
 'Batik Tulis (written batik) is the most prestigious and labor-intensive form of batik — each piece is entirely hand-drawn using a canting tool. A single sarong can take six months to a year to complete.',
 'A craftsperson traces patterns freehand onto fabric using a canting — a small copper cup with a narrow spout — filled with hot wax. The finest makers work on both sides of the fabric simultaneously.',
 'Batik tulis is considered a meditation and a spiritual practice in Javanese culture. The maker''s emotional state is believed to transfer into the cloth.',
 true),

('east-asian-geometric','East Asian Geometric Tradition','textile_tradition','general','researched',
 'East Asian geometric textile traditions encompass cloud patterns, wave patterns, and lattice designs that carry symbolic meaning — the fret pattern represents longevity, clouds represent good fortune.',
 'Woven into silk using complex jacquard-style looms in China, brocaded into Korean hanbok silk, and stenciled or woven into Japanese kimono fabric.',
 'Specific patterns were restricted to imperial use in China and Japan. Dragon and phoenix motifs could only be worn by the emperor and empress.',
 true),

('ikat','Ikat','dye_method','general','researched',
 'Ikat (from Malay mengikat, ''to tie'') is a resist-dyeing technique where yarns are dyed before weaving. The slight misalignment of dyed yarns creates the characteristic blurred, feathered edges that distinguish ikat.',
 'Bundles of yarn are tied in specific patterns, then dyed. After dyeing, ties are removed and yarns are woven — the pattern emerges from the pre-dyed thread. Double ikat, where both warp and weft are resist-dyed, is among the most technically demanding textile arts.',
 'Uzbek ikat robes were gifts of honor from rulers to subjects. In Bali, double ikat fabric (Geringsing) is produced only in one village and is believed to have protective magical properties.',
 true),

('paisley','Paisley','motif','general','researched',
 'The paisley (boteh) is a curved teardrop shape originating in Kashmir as a woven motif representing the Zoroastrian flame or a bent cypress tree. It traveled from Kashmir to Persia to Europe via trade routes.',
 'Originally a Kashmiri kani weave motif, paisley has been adapted into every textile technique — block printing in India, jacquard weaving in Europe, screen printing globally.',
 'The paisley''s journey from sacred Kashmiri court textile to American bandana to global fashion symbol is one of the most complete stories of pattern migration in textile history.',
 true),

('shibori','Shibori','dye_method','general','researched',
 'Shibori encompasses several Japanese resist-dyeing techniques that produce organic, non-repeating patterns. The word comes from shiboru, ''to wring, squeeze, press.'' Unlike Western tie-dye, shibori is a highly refined art form with specific named techniques.',
 'The six main techniques are: itajime (clamped between resist blocks), arashi (wrapped around a pole), kumo (pleated and bound), ne-maki (bound at intervals), miura (looped with a hook), and ori nui (stitched and gathered). Indigo is the traditional dye.',
 'Shibori indigo textiles were the everyday fabric of Edo period Japan. The practice nearly died out in the 20th century before being revived by textile artists in Japan and internationally.',
 true),

('suzani','Suzani','textile_tradition','general','researched',
 'Suzani means ''needle'' in Persian (suzan). These large embroidered textiles were made by brides and their female relatives in the months and years before a wedding — a collective labor of love.',
 'Chain stitch and laid work embroidery on cotton or silk ground fabric. Bold floral and solar disc (shams) motifs are characteristic. The design is drawn by a master designer (kalamkash) and filled in by the embroiderers.',
 'Suzanis are both art objects and biographical documents — the different hands of multiple women are visible in varying stitch quality across a single piece. The solar disc motif represents the sun as a symbol of fertility and divine blessing.',
 true),

('cintamani','Çintamani','motif','general','researched',
 'The çintamani is a pattern of three circles arranged in a triangle, sometimes combined with wavy tiger stripe lines. In Buddhist tradition the three circles represent the Three Jewels of Buddhism.',
 'Woven into silk velvet and brocade in Ottoman imperial workshops in Istanbul and Bursa. The pattern was also used in Iznik ceramic tiles and architectural decoration.',
 'The çintamani was the exclusive property of the Ottoman sultan. Its journey from Buddhist sacred symbol to Ottoman imperial mark to globally recognized decorative motif is a complete story of the Silk Road as a highway of cultural exchange.',
 true),

('greek-key-meander','Greek Key / Meander','motif','general','researched',
 'The Greek key or meander pattern — a continuous line that folds back on itself — represents the eternal flow of the river Meander in Turkey. In ancient Greece it symbolized infinity, unity, and the bond between people.',
 'Originally carved into pottery and stonework, then translated into woven textile borders, embroidered trim, and printed repeat patterns.',
 'The Greek key''s appearance across disconnected civilizations suggests it emerges from something fundamental in human visual perception.',
 true),

('tartan','Tartan','textile_tradition','general','researched',
 'Tartan is a pattern of intersecting horizontal and vertical bands in multiple colors, woven in a twill structure. Each Scottish clan has one or more registered tartans — there are over 7,000 today.',
 'Woven in a 2/2 twill on a four-shaft loom. The same sequence of colored threads is used in both warp and weft, creating the characteristic diagonal twill line. Traditionally woven in wool.',
 'After the Jacobite rising of 1745, the British government banned Highland dress including tartan for 35 years. The ban was lifted in 1782 and tartan became a symbol of Scottish resistance and identity.',
 true),

('toile-de-jouy','Toile de Jouy','print_method','general','researched',
 'Toile de Jouy depicts pastoral and narrative scenes — shepherds, rural idylls, classical mythology, exotic landscapes — in a single color on a cream or white ground. The scenes tell stories.',
 'Engraved copper plate printing (later roller printing). A single color (traditionally red, blue, or black) is printed on undyed cotton or linen. Fine engraving allows for detailed figurative illustration at textile scale.',
 'Toile de Jouy was the first industrially produced decorative fabric in France. At CultureSchool, the toile format is reclaimed for cultural storytelling — depicting scenes from African, Caribbean, and diaspora life.',
 true),

('wildflower-print','Wildflower Print','print_method','general','researched',
 'The wildflower print tradition draws from the English Arts & Crafts movement''s rejection of industrial production in favor of handcraft and natural forms. William Morris based designs on direct observation of English hedgerows.',
 'Originally woodblock printed by hand on cotton and linen. Later adapted to roller printing and screen printing. Uses asymmetric, naturalistic botanical forms with overlapping leaves and stems.',
 'At CultureSchool, wildflower prints are rendered through specific cultural color palettes — an English wildflower form through a Jamaican Mango palette becomes something entirely new: familiar form, specific cultural color language.',
 true),

('andean-textile-tradition','Andean Textile Tradition','textile_tradition','context_required','researched',
 'Andean textiles are among the oldest and most technically complex in the world. Geometric patterns called tocapu carried encoded information — social status, lineage, geographic origin.',
 'Woven on backstrap looms using wool from alpaca, llama, and vicuña. The warp-faced weave creates dense geometric patterns. Natural dyes from cochineal (red), indigo (blue), and native plants produce the characteristic saturated palette.',
 'Andean weaving is a living tradition. In communities across Peru and Bolivia, textile patterns identify which village a person is from, their family lineage, and their ceremonial role. The weaving itself is considered a sacred act.',
 true),

('hawaiian-quilt','Hawaiian Quilt','textile_tradition','context_required','researched',
 'Hawaiian quilts feature bold, symmetrical appliqué designs cut from a single folded piece of fabric — typically depicting native plants, flowers, and ocean forms. Each design is considered the intellectual property of its maker.',
 'A large piece of fabric is folded into eighths and a design is cut freehand, then unfolded to reveal a perfectly symmetrical eight-pointed pattern. Appliquéd onto a contrasting background and quilted with fine echo stitching.',
 'Hawaiian quilts were traditionally made as gifts for significant life events. They were believed to carry the mana (spiritual power) of the maker. Some families still have quilts made over a century ago as sacred heirlooms.',
 true),

('chevron','Chevron','motif','general','researched',
 'The chevron — a V-shape or inverted V — is one of the most universal patterns in human textile history, appearing independently across cultures. In West African kente it represents royalty and achievement.',
 'Woven diagonally into fabric structure or printed as a repeating geometric. In traditional hand weaving the chevron emerges from the warp and weft angle rather than being printed on.',
 'The chevron''s universality makes it a bridge pattern — it appears in virtually every textile tradition on earth, each giving it distinct local meaning.',
 true),

('diamond-pattern','Diamond Pattern','motif','general','researched',
 'The diamond or lozenge shape is one of the most ancient geometric forms in textile history, found independently across every weaving tradition. In Kente weaving it represents the eye of God.',
 'Created through diagonal warp-weft intersections in hand weaving. In printed textiles it is constructed as a repeating geometric grid rotated 45 degrees.',
 'Like the chevron, the diamond''s universality is its power — it is simultaneously specific to dozens of cultural traditions and globally recognizable as a symbol of value and protection.',
 true),

('floral-pattern-traditions','Floral Pattern Traditions','motif','general','researched',
 'Floral textile patterns originate in the Persian concept of the garden as paradise — the word paradise itself comes from the Persian pairidaeza, meaning walled garden. Ottoman floral patterns represented the tulip as a symbol of God.',
 'Woven into Persian and Turkish carpets. Printed onto Indian cotton using woodblock printing. Embroidered onto Chinese silk using satin stitch. Each tradition produces a distinct floral aesthetic.',
 'Floral patterns are the most traded textile motif in history. The Silk Road spread Persian floral designs from China to Europe. Indian chintz florals transformed European fashion in the 17th and 18th centuries.',
 true),

('grid-checked-pattern','Grid / Checked Pattern','motif','general','researched',
 'The grid or checked pattern is the most fundamental woven structure — the direct visual expression of warp meeting weft. It appears in every textile tradition globally.',
 'Created by alternating two or more colored threads in both warp and weft on a loom. The simplest weave structure produces a plain weave check.',
 'The grid''s ubiquity makes it a canvas — at CultureSchool it is rendered in specific cultural palette colors, transforming a universal structure into a culturally specific expression.',
 true),

('heritage-pattern','Heritage Pattern','motif','general','researched',
 'Heritage patterns at CultureSchool are original compositions that draw from multiple cultural textile traditions simultaneously — honoring the way diaspora culture combines and transforms inherited visual languages into something new.',
 'Generated using CultureSchool''s pattern engine, combining geometric vocabularies from multiple traditions in response to a specific cultural palette.',
 'The heritage pattern represents the reality of diaspora experience, where cultural identity is never single-source but always a synthesis of multiple lineages.',
 true),

('tropical-frond','Tropical Frond','motif','general','researched',
 'The palm frond and tropical leaf motif appears across cultures that share tropical geography. In Caribbean tradition it represents abundance and resilience.',
 'Printed onto cotton using woodblock or screen printing. In Pacific Island traditions, designs are beaten into bark cloth using carved wooden beaters.',
 'Tropical frond patterns are deeply diaspora patterns — they connect communities whose ancestors were displaced from tropical homelands to their geographic and cultural roots.',
 true),

('tropical-print-tradition','Tropical Print Tradition','print_method','general','researched',
 'The tropical print as a genre emerged from the collision of Hawaiian shirt culture, Caribbean carnival costume traditions, and West African kanga printing in the mid-20th century.',
 'Screen or roller printed on lightweight cotton or rayon. Uses saturated colors on a solid ground, with organic botanical forms rendered in high contrast.',
 'For diaspora communities, tropical prints are not just aesthetic — they are geographic and cultural memory. A Jamaican hibiscus, a Nigerian palm, a Hawaiian ti leaf are each specific botanical references to particular landscapes and homelands.',
 true),

('mehndi','Mehndi','motif','general','researched',
 'Mehndi (henna body art) features intricate temporary designs of paisley (boteh), vines, blossoms, and dots stained onto hands and feet for weddings and festivals. The same ornamental language flows into textiles and block prints.',
 'A paste of ground henna leaves is piped in fine lines onto the skin; in cloth, the motifs are block-printed or embroidered.',
 'Mehndi marks life''s thresholds — the bride''s mehndi night, Eid, festivals — a joy-and-blessing art shared across South Asian, Arab, and North African cultures.',
 true),

('celtic-gaelic-knotwork','Celtic / Gaelic Knotwork','motif','general','researched',
 'Endless interlaced knots: a single unbroken line woven over and under itself with no beginning or end, symbolising eternity, continuity, and the interconnection of all things. It filled illuminated manuscripts and carved stone crosses.',
 'Drawn as interwoven ribbons following strict over-under rules on a grid — painstakingly by monks in manuscripts, carved in relief in stone.',
 'The unbroken line spoke of eternity and the weaving-together of life, and remains one of the most recognisable emblems of Celtic identity across the diaspora.',
 true)

ON CONFLICT (slug) DO UPDATE SET
  name              = EXCLUDED.name,
  entry_type        = EXCLUDED.entry_type,
  short_definition  = EXCLUDED.short_definition,
  overview          = EXCLUDED.overview,
  cultural_context  = EXCLUDED.cultural_context,
  sensitivity_level = EXCLUDED.sensitivity_level,
  is_public         = EXCLUDED.is_public,
  updated_at        = now();

-- ── 3. ENTRY → PLACE LINKS ──────────────────────────────────────────────────
-- PK is (entry_id, place_id, relationship_type) — ON CONFLICT covers all three.

INSERT INTO cs_kg_entry_places (entry_id, place_id, relationship_type, is_primary)
SELECT e.id, p.id, v.rt, v.ip
FROM (VALUES
  ('adinkra',               'ghana',         'origin',       true),
  ('adinkra',               'west-africa',   'practiced_in', true),
  ('adire',                 'nigeria',       'origin',       true),
  ('adire',                 'west-africa',   'practiced_in', true),
  ('kanga',                 'kenya',         'origin',       true),
  ('kanga',                 'tanzania',      'practiced_in', true),
  ('kanga',                 'east-africa',   'practiced_in', true),
  ('kente',                 'ghana',         'origin',       true),
  ('kente',                 'west-africa',   'practiced_in', true),
  ('kuba-cloth',            'dr-congo',      'origin',       true),
  ('kuba-cloth',            'central-africa','practiced_in', true),
  ('mudcloth-bogolan',      'mali',          'origin',       true),
  ('mudcloth-bogolan',      'west-africa',   'practiced_in', true),
  ('zellige',               'morocco',       'origin',       true),
  ('zellige',               'north-africa',  'practiced_in', true),
  ('batik',                 'indonesia',     'origin',       true),
  ('batik',                 'southeast-asia','practiced_in', true),
  ('batik-tulis',           'indonesia',     'origin',       true),
  ('ikat',                  'uzbekistan',    'origin',       true),
  ('ikat',                  'indonesia',     'practiced_in', true),
  ('ikat',                  'central-asia',  'practiced_in', true),
  ('ikat',                  'southeast-asia','practiced_in', true),
  ('paisley',               'india',         'origin',       true),
  ('paisley',               'south-asia',    'practiced_in', true),
  ('shibori',               'japan',         'origin',       true),
  ('suzani',                'uzbekistan',    'origin',       true),
  ('suzani',                'central-asia',  'practiced_in', true),
  ('cintamani',             'ottoman-empire','origin',       true),
  ('tartan',                'scotland',      'origin',       true),
  ('toile-de-jouy',         'france',        'origin',       true),
  ('andean-textile-tradition','peru',        'origin',       true),
  ('andean-textile-tradition','andean',      'practiced_in', true),
  ('hawaiian-quilt',        'hawaii',        'origin',       true),
  ('mehndi',                'india',         'origin',       true),
  ('mehndi',                'south-asia',    'practiced_in', true),
  ('tropical-print-tradition','hawaii',      'practiced_in', true),
  ('tropical-print-tradition','caribbean',   'practiced_in', true),
  ('tropical-print-tradition','west-africa', 'practiced_in', true)
) AS v(es, ps, rt, ip)
JOIN cs_kg_entries e ON e.slug = v.es
JOIN cs_kg_places  p ON p.slug = v.ps
ON CONFLICT (entry_id, place_id, relationship_type) DO NOTHING;

COMMIT;

-- ── VERIFICATION ────────────────────────────────────────────────────────────
-- SELECT count(*) FROM cs_kg_entries;      -- expect 29
-- SELECT count(*) FROM cs_kg_places;       -- expect 25+
-- SELECT count(*) FROM cs_kg_entry_places; -- expect 37+
--
-- In Intelligence Platform > Textile Atlas, search:
--   Batik, Kente, Adinkra, Ikat, Shibori
-- Each should return a result with full cultural context.
