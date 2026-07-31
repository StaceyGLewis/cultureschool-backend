-- ============================================================================
--  10-atlas-content-seed.sql
--
--  Seeds hook, color_symbolism, key_term, and key_term_def for publishable
--  Atlas entries. Requires 09-atlas-content-enrichment.sql to have been run.
--
--  Skipped entries (require separate editorial review before seeding):
--    · Hawaiian Quilt      — tradition's own protocol prohibits copying
--    · Navajo / Diné       — active trademark + Indian Arts and Crafts Act
--    · Otomi (Tenango)     — Mexico 2022 indigenous IP law, legal review needed
--    · T'nalak             — sacred dream-derived cloth, community consultation needed
--    · Runes               — active extremist appropriation of specific symbols
--    · Asante (Akan)       — structural: people/place node, not a textile tradition
--    · East Asian Geometric — continent, not a tradition; needs splitting
--    · Mehndi, Mizrahi, Hamsa — category errors; body art, identity, symbol
--    · Heritage Pattern, Art Print — placeholders; no cultural content
--
--  All rows updated with source_status='draft' and is_public=false unchanged.
--  Publishing is a separate step — do NOT auto-publish from this script.
--
--  Safe to re-run. Updates are idempotent.
-- ============================================================================


-- ── WEST AFRICA ──────────────────────────────────────────────────────────────

update public.cs_atlas_entries set
  hook            = 'Every Adinkra symbol is a proverb compressed into a shape — worn to carry a message without speaking a word.',
  color_symbolism = 'Black and russet-red for mourning and funerary occasions; white for joy and purification; blue for love and peace. The color of the cloth signals the occasion before the symbols are even read.',
  key_term        = 'Adinkra',
  key_term_def    = 'Symbols stamped or woven onto cloth by the Akan people of Ghana and Côte d''Ivoire, each encoding a proverb or concept — wisdom, resilience, or the passage of time. The word adinkra means "farewell" in Twi.'
where slug = 'adinkra';

update public.cs_atlas_entries set
  hook            = 'Adire is indigo made slow — Yoruba women fold, tie, and stitch cloth so the dye cannot reach, creating maps of negative space in deep blue.',
  color_symbolism = 'Deep indigo is the tradition''s signature. The darker the blue, the more valuable the cloth. Resist areas appear white or pale blue — the pattern lives in what the dye was denied.',
  key_term        = 'Adire eleko',
  key_term_def    = 'One of the two main adire techniques: cassava-paste resist is painted onto cloth before dyeing, letting the artist draw intricate patterns freehand. The other, adire oniko, uses tie-and-stitch resist.'
where slug = 'adire';

update public.cs_atlas_entries set
  hook            = 'Kente speaks before its wearer does — every color, every named pattern is a sentence in a visual language that predates colonialism by centuries.',
  color_symbolism = 'Gold for royalty, wealth, and high status. Green for growth and renewal. Red for political passion and blood. Black for maturity and spiritual energy. Blue for harmony and peace. Color combinations in named patterns amplify and complicate these individual meanings.',
  key_term        = 'Kente',
  key_term_def    = 'Strip-woven cloth of the Akan and Ewe peoples of Ghana and Togo, assembled from narrow silk or cotton strips into a large patterned textile. Each named pattern encodes a proverb. Asante kente and Ewe kente are distinct traditions that are often — incorrectly — collapsed into one.'
where slug = 'kente';

update public.cs_atlas_entries set
  hook            = 'Kuba cloth is geometry pushed to its limit — interlocking shapes cut from raffia fiber by artisans of the Kuba Kingdom, where a pattern held as much meaning as a written record.',
  color_symbolism = 'Natural raffia cream and deep black dominate, with occasional russet from camwood dye. The high contrast between light and dark is structural, not decorative — it encodes status and occasion.',
  key_term        = 'Raffia',
  key_term_def    = 'Fiber from the raffia palm, used by Kuba artisans as both base cloth and embroidery thread. Raffia textiles were so valuable in the Kuba Kingdom that they functioned as currency and were central to funerary and royal ceremony.'
where slug = 'kuba-cloth';

update public.cs_atlas_entries set
  hook            = 'Bògòlanfini is literally painted with river mud — an ancient chemistry that turns iron-rich earth into the deep black marks of the Bamana tradition.',
  color_symbolism = 'Black and deep brown from fermented river mud applied over an ochre-yellow ground prepared with n''galama bark tea. Bleaching with caustic soda removes the yellow to create white. These three — black, ochre, and white — are the entire palette.',
  key_term        = 'Bògòlanfini',
  key_term_def    = 'The Bamana name: bogo (mud) + lan (by means of) + fini (cloth). Cloth decorated by painting iron-rich river mud onto yarn-dyed fabric to create the distinctive dark patterns. "Mudcloth" is the English trade name — Bògòlanfini is the name the makers use.'
where slug = 'mudcloth-b-g-lanfini';

update public.cs_atlas_entries set
  hook            = 'A kanga without its proverb is just a cloth — the Swahili text printed across the border is the heart of the garment, the message it was made to carry.',
  color_symbolism = 'Bold saturated colors — bright red, orange, green, yellow, blue — on a contrasting ground. The border (pindo) typically contrasts sharply with the central field (mji). No fixed symbolic system governs color; regional fashion and the message of the jina drive the palette.',
  key_term        = 'Jina',
  key_term_def    = 'The Swahili proverb or phrase printed on the border of a kanga — literally "name." The jina is what makes a kanga meaningful rather than merely decorative. Kangas are chosen for the message their jina sends, and gifting one to someone is a way of saying something you might not say aloud.'
where slug = 'kanga';

update public.cs_atlas_entries set
  hook            = 'Ndebele geometry is architecture made personal — bold triangles and diamonds painted on home walls and beaded onto garments that mark every stage of a woman''s life.',
  color_symbolism = 'Bright primary and secondary colors — red, yellow, green, blue — outlined in bold black on a white ground. The black outline is structural; the bright color is deliberate and joyful. Contemporary Ndebele artists have expanded the palette while keeping the geometric clarity and black outlines as signature.',
  key_term        = 'Isigolwani',
  key_term_def    = 'Beaded neck rings worn by Ndebele women that mark social status and life stage — wider rings indicate a longer marriage. The beadwork uses the same bold geometric vocabulary as Ndebele architecture and is considered inseparable from it.'
where slug = 'ndebele';


-- ── EAST AFRICA / HORN ───────────────────────────────────────────────────────

update public.cs_atlas_entries set
  hook            = 'Tibeb is the border that makes the garment — the narrow woven band of color at hem and collar that has distinguished Ethiopian handloom work for centuries.',
  color_symbolism = 'White is the ground of the habesha kemis. The tibeb border uses the full spectrum — gold, red, green, blue, and black are most common. Gold and white together signal ceremony; plain white signals everyday life.',
  key_term        = 'Tibeb',
  key_term_def    = 'The woven geometric border that edges traditional Ethiopian and Eritrean garments. Tibeb refers specifically to this woven decoration, not the garment as a whole. Patterns vary by region, and skilled weavers carry distinct regional signatures — the border is where the maker''s identity lives.'
where slug = 'ethiopian-habesha-tibeb';


-- ── SOUTHEAST ASIA ───────────────────────────────────────────────────────────

update public.cs_atlas_entries set
  hook            = 'Batik is resist-dyeing''s most sophisticated expression — hot wax drawn or stamped onto cloth so that color can only go where the wax permits.',
  color_symbolism = 'Deep indigo and soga brown from bark are the traditional Javanese palette, most often on cream cotton. The distinctive crackle lines appear when wax fractures and dye seeps through — a byproduct that became a prized characteristic.',
  key_term        = 'Larangan',
  key_term_def    = 'Forbidden patterns in Javanese batik. Certain motifs — parang, kawung, garuda — were historically reserved for the royal household and are still treated with particular care. Wearing larangan patterns without context is considered disrespectful in Java.'
where slug = 'batik';

update public.cs_atlas_entries set
  hook            = 'Batik tulis is drawn, not stamped — each line of wax applied freehand with a tjanting tool, making every cloth a unique original that cannot be exactly replicated.',
  color_symbolism = 'Same palette as batik generally: indigo, soga brown, cream. The hand-drawn quality of tulis means color edges are slightly less sharp than stamped batik cap — a mark of the maker''s hand, and a way to distinguish authentic tulis from machine copies.',
  key_term        = 'Tjanting',
  key_term_def    = 'The pen-like copper tool used to apply liquid wax in batik tulis. A small cup holds the molten wax and a narrow spout controls the flow — the craft of batik tulis is inseparable from the craft of controlling this tool.'
where slug = 'batik-tulis';

update public.cs_atlas_entries set
  hook            = 'Ikat works before the weaving begins — threads are bound and dyed in precise sequence so the pattern appears almost by itself when finally woven, with the slightly blurred edges that are the technique''s global signature.',
  color_symbolism = 'Color meaning varies by culture. Uzbek ikat uses jewel tones — deep red, emerald, sapphire — on silk that changes at every angle. Guatemalan jaspe uses earthy tones coded by village of origin. Indian patola uses rich reds and indigo on silk for bridal use. The technique is shared; the meaning is local.',
  key_term        = 'Ikat',
  key_term_def    = 'A resist-dyeing technique in which threads are bound and dyed before weaving — from the Malay/Indonesian mengikat, meaning "to bind." The same technique developed independently in Central Asia, Southeast Asia, India, Japan, and the Americas. It is a technique, not a single culture''s tradition.'
where slug = 'ikat';

update public.cs_atlas_entries set
  hook            = 'The Hmong story cloth was born in a refugee camp — Paj Ntaub became a way to stitch memory into fabric when everything else had been left behind.',
  color_symbolism = 'Bright, high-contrast colors on a dark ground: hot pink, electric blue, lime green, and red against black. The vivid palette is a marker of life and vitality. Story cloths often use more muted narrative tones — the color shifts depending on whether the cloth is decorative or documentary.',
  key_term        = 'Paj Ntaub',
  key_term_def    = 'Hmong for "flower cloth" (pronounced roughly "pa ndao"). The term covers both geometric decorative embroidery and the figurative story cloths developed in Thai refugee camps after the Vietnam-era Secret War in Laos — two distinct forms united by the hand and the thread.'
where slug = 'hmong-paj-ntaub';


-- ── EAST ASIA ────────────────────────────────────────────────────────────────

update public.cs_atlas_entries set
  hook            = 'Shibori works by refusing the dye access — folding, binding, stitching, or compressing cloth before the vat, so the marks of resistance become the pattern.',
  color_symbolism = 'Indigo is the foundational color of shibori — Japan blue. Resist technique creates patterns in white against deep blue. Contemporary shibori uses many dye colors, but the indigo-and-white pairing is the tradition''s heart.',
  key_term        = 'Kanoko',
  key_term_def    = 'One of six classical shibori techniques — small points of cloth are bound with thread before dyeing, creating circles resembling deer spots (kanoko = fawn in Japanese). The technique is a direct ancestor of tie-dye, and the finest kanoko work is considered among the most labor-intensive textiles in the world.'
where slug = 'shibori';


-- ── CENTRAL ASIA ─────────────────────────────────────────────────────────────

update public.cs_atlas_entries set
  hook            = 'A suzani was a woman''s life compressed into silk thread — months of embroidery completed before her wedding day, destined to hang in her new home as both art and autobiography.',
  color_symbolism = 'Bold saturated color on ivory or cream silk: deep red (pomegranate — fertility and abundance), cobalt blue (sky and protection), rich green (growth and the garden). The large circular motifs — often called moons — are almost always in the most saturated available hue.',
  key_term        = 'Suzani',
  key_term_def    = 'Embroidered wedding textiles from Uzbekistan, Tajikistan, and the Silk Road cities — the word means "needlework" in Persian. Each piece was traditionally made by the bride and women of her family as dowry, with protective motifs intended to bless the new household.'
where slug = 'suzani';


-- ── SOUTH ASIA ───────────────────────────────────────────────────────────────

update public.cs_atlas_entries set
  hook            = 'Phulkari is embroidery turned inside out — worked from the back of plain cloth until the front blooms with so much silk thread that the ground nearly disappears.',
  color_symbolism = 'Vivid orange, red, and gold on a dark indigo or maroon ground — colors of celebration, fertility, and blessing in Punjabi culture. A fully covered piece (bagh) in gold thread was among the most precious objects a bride could bring to her marriage.',
  key_term        = 'Bagh',
  key_term_def    = 'A fully embroidered Phulkari — the Punjabi word for "garden." When the silk thread completely covers the ground cloth, the piece becomes a bagh, considered far more prestigious than a partly-worked phulkari. The best baghs were made over years and passed between generations.'
where slug = 'phulkari';

update public.cs_atlas_entries set
  hook            = 'Paisley is a name that records an act of theft — a Kashmiri motif so beautiful that a Scottish mill town copied it, sold it to the world, and got to keep the credit.',
  color_symbolism = 'The most prized Kashmir shawls used rich reds, saffron yellow, and deep green from natural dyes on ivory or cream wool. When Paisley mills mass-produced the motif, Victorian synthetic dyes pushed the palette toward garishness. The quality of the color often signals the origin.',
  key_term        = 'Boteh',
  key_term_def    = 'The Kashmiri and Persian name for the teardrop-curved motif the West calls "paisley" — the Persian word buta means "cluster of leaves" or "bush." The motif''s exact origin is debated, but it has been central to Persian and Kashmiri textile design for centuries. Paisley, Scotland copied and named it.'
where slug = 'paisley';

update public.cs_atlas_entries set
  hook            = 'Andean textile is among the world''s oldest living art — the same counting-thread techniques used today were recorded in cloth on bodies buried three thousand years ago in the Andes.',
  color_symbolism = 'Natural fibers (alpaca, vicuña) in cream, brown, and grey; vivid reds from cochineal (the most prized); blues from indigo; yellows from local plants. The Andean color tradition is inseparable from dye ecology — the colors available were the colors the land and altitude provided.',
  key_term        = 'Tocapu',
  key_term_def    = 'Geometric woven squares in Andean textiles that functioned as a writing system — each tocapu pattern encoded social information about rank, origin, and occasion. Reading a tocapu-covered tunic was reading a biography.'
where slug = 'andean-textile-tradition';


-- ── OTTOMAN / SILK ROAD ──────────────────────────────────────────────────────

update public.cs_atlas_entries set
  hook            = 'The Çintamani traveled the Silk Road from a Buddhist wish-granting jewel to the motif on an Ottoman Sultan''s kaftan — one of history''s most documented design migrations.',
  color_symbolism = 'In Ottoman court textiles, the pattern was most often rendered in gold or deep crimson on rich velvet — colors reserved for the imperial household. The triple-dot motif is almost always presented in maximum contrast against its ground.',
  key_term        = 'Çintamani',
  key_term_def    = 'An Ottoman court motif derived from the Buddhist cintamani (wish-fulfilling gem) — three dots arranged in a triangle, paired with wavy parallel lines. It appears throughout 15th–17th century Bursa silks and Ottoman court robes, arriving via the Silk Road trade.'
where slug = 'intamani';


-- ── NORTH AFRICA / IBERIA ────────────────────────────────────────────────────

update public.cs_atlas_entries set
  hook            = 'The word azulejo comes from the Arabic for "small polished stone" — a reminder that Portugal''s most iconic visual tradition arrived on the Iberian Peninsula with Moorish civilization.',
  color_symbolism = 'Classic azulejo is cobalt blue on white tin-glazed earthenware — the pairing arrived from China via Dutch Delft in the 17th century. Earlier Moorish azulejos used more colors: turquoise, green, yellow, and black in interlocking geometric arrangements.',
  key_term        = 'Azulejo',
  key_term_def    = 'Hand-painted tin-glazed ceramic tiles used to cover walls, floors, and facades across Portugal, Spain, and former colonies. From the Arabic az-zulayj, meaning "polished stone." The blue-and-white style is a 17th-century innovation; the tradition itself is Moorish.'
where slug = 'azulejo';

update public.cs_atlas_entries set
  hook            = 'Zellige is geometry in the service of the infinite — Moroccan craftspeople hand-chip each tile fragment from a larger fired piece, assembling patterns that encode the Islamic understanding of unity through mathematical order.',
  color_symbolism = 'Turquoise, cobalt blue, white, green, black, and ochre are the traditional palette. Each color has its own glaze formula and firing temperature. Blue and turquoise for water and sky; white for purity; green for paradise — all carrying Islamic symbolic weight.',
  key_term        = 'Tawhid',
  key_term_def    = 'The Islamic concept of divine unity. The infinitely repeating, non-figurative geometry of zellige is one visual expression of this principle — the pattern extends without end because the divine has no limit. The mathematical precision of the geometry is theological as much as aesthetic.'
where slug = 'zellige';


-- ── EUROPE ───────────────────────────────────────────────────────────────────

update public.cs_atlas_entries set
  hook            = 'Tartan is a language made of crossed threads — each sett uniquely identifies a clan, regiment, or family, and has been legally registered since 2008.',
  color_symbolism = 'Each tartan''s colors are specific to its sett rather than carrying universal symbolic meaning — the MacGregor red signals clan identity, not blood; Black Watch dark greens and blues signal military service. Historically, plant dyes available in each region shaped local color availability.',
  key_term        = 'Sett',
  key_term_def    = 'The color sequence that defines a tartan — the precise order and number of threads in each color that, woven in both warp and weft, creates the characteristic crossed pattern. Every tartan registered with the Scottish Register of Tartans has a documented sett.'
where slug = 'tartan';

update public.cs_atlas_entries set
  hook            = 'Celtic knotwork is illumination that escaped the page — the interlacing patterns of early medieval manuscripts like the Book of Kells have become the visual shorthand for an entire family of cultures.',
  color_symbolism = 'In medieval manuscripts, knotwork used the full range of natural pigments — lapis blue, verdigris green, red lead, gold — against vellum. As a contemporary design element, it is usually rendered in a single color or gold on dark grounds. There is no fixed color symbolism; the form carries the meaning.',
  key_term        = 'Insular art',
  key_term_def    = 'The scholarly name for the art style produced in Ireland, Scotland, and northern England in the early medieval period — the style that includes Celtic knotwork, illuminated manuscripts, and metalwork. "Insular" means island-based. Using this term is more precise than "Celtic," which covers a much broader territory.'
where slug = 'celtic-gaelic-knotwork';

update public.cs_atlas_entries set
  hook            = 'Bargello is not Brazilian, not Aztec, and not "geometric" — it is Florentine needlework named for a palace, and its interlocking zigzags are one of embroidery''s oldest counting-thread traditions.',
  color_symbolism = 'Bargello is designed to showcase color gradients — the technique works in stepped horizontal bands that rise and fall, creating the perfect vehicle for moving from pale blush through deep crimson, or from sky blue to navy. The color progression IS the design; a Bargello with a single color loses its point.',
  key_term        = 'Flame stitch',
  key_term_def    = 'Another name for Bargello embroidery — the tall vertical stitches create a pattern that rises and falls like flames. The name predates "Bargello" in English usage and is the term most commonly used in American needlework tradition. The mislabel "Brazilian" is a widespread error in commercial textile catalogues.'
where slug = 'bargello';

update public.cs_atlas_entries set
  hook            = 'Toile de Jouy perfected the narrative print — but the technique that made it possible was copied from Indian chintz that Europe first banned, then imitated, then forgot to credit.',
  color_symbolism = 'Classic toile is monochromatic — a single color (most often red, blue, black, or sepia) printed on unbleached cream cotton ground. The single-color convention was a technical constraint of 18th-century copperplate printing that became the tradition''s defining aesthetic.',
  key_term        = 'Toile',
  key_term_def    = 'Technically means "cloth" in French, but in design shorthand refers to the scenic copperplate-printed cotton first produced at the Oberkampf factory in Jouy-en-Josas. The technique derived from Indian block-printed chintz; the narrative scenes — pastoral, mythological, exotic — were a European invention layered on top.'
where slug = 'toile-de-jouy';

update public.cs_atlas_entries set
  hook            = 'Madras crossed an ocean twice — first as South Indian handloom cotton traded by the British, then as a second life in the Caribbean carried by indentured laborers who made it entirely their own.',
  color_symbolism = 'Bright saturated checks — red, blue, yellow, green — on lightweight cotton. Authentic hand-dyed Indian madras "bleeds" slightly when washed, softening the edges of each check; this became a mark of quality. In Tamil Nadu the checked pattern signals artisanal handloom; in the Caribbean, the same cloth became a marker of diaspora identity.',
  key_term        = 'Bleeding madras',
  key_term_def    = 'A characteristic of authentic hand-dyed Indian madras cotton — vegetable dyes run slightly when washed, softening the check and giving the cloth a lived-in quality. Mass-produced imitations do not bleed. The bleed became a mark of authenticity in the American prep fashion that adopted the cloth in the 1950s–60s.'
where slug = 'madras';

update public.cs_atlas_entries set
  hook            = 'Paisley''s parent motif — the boteh — traveled from Persia to Kashmir to Scotland, picking up a new name at every stop while the credit stayed with the copies, not the origin.',
  color_symbolism = 'The boteh appears in every color family, but the most prized historic Persian and Kashmiri shawls used madder red, saffron, and lapis-derived blues on ivory or cream. The quality of the dye and the fineness of the wool were inseparable from the color — a brilliant Persian red on pashmina was not reproducible by mill machinery.',
  key_term        = 'Kashmiri shawl',
  key_term_def    = 'The hand-woven shawls of the Kashmir Valley — among the most prized textiles in world trade from the 18th century onward, woven from fine pashmina (cashmere) with intricate tapestry-woven boteh patterns. The European demand for them drove the Paisley mills to mechanically reproduce the boteh, creating the derivative that displaced the original.'
where slug = 'persian';

update public.cs_atlas_entries set
  hook            = 'Greek Key is the world''s most traveled motif — the same interlocking meander appears on Greek pottery, Aztec architecture, Chinese cloud borders, and African kente strips, developed independently in each place.',
  color_symbolism = 'On ancient Greek ceramics, black figure on terracotta or red figure on black ground. In contemporary use, most commonly black on white or gold on cream — the motif is treated as neutral and monochromatic. The color is borrowed from context; the form itself is culture-specific.',
  key_term        = 'Meander',
  key_term_def    = 'The geometric term for the continuous interlocking right-angle spiral. Named after the Meander River (now the Büyük Menderes) in modern Turkey, whose winding path the pattern was said to resemble. The motif appears across many unrelated cultures — making it one of the clearest examples of convergent design evolution.'
where slug = 'greek-key-meander';


-- ── VERIFICATION ─────────────────────────────────────────────────────────────
--
-- Check that hooks were applied (null hook count should equal only the
-- skipped/restricted entries):
--
--   select slug, hook is not null as has_hook, color_symbolism is not null as has_color
--   from public.cs_atlas_entries
--   order by slug;
--
-- Count seeded vs. blank:
--
--   select
--     count(*) filter (where hook is not null)            as hooked,
--     count(*) filter (where hook is null)                as still_blank,
--     count(*)                                            as total
--   from public.cs_atlas_entries;
