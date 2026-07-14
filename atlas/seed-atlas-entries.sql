-- ============================================================

-- SEED THE ATLAS  (real cs_atlas_entries schema)

-- All entries land as draft, is_public = false. Nothing publishes.

-- Idempotent: safe to re-run.

-- ============================================================


alter table public.cs_atlas_entries
  add column if not exists entry_type text default 'textile_tradition';

insert into public.cs_atlas_entries
  (name, slug, dictionary_style, entry_type, short_definition, cultural_context,
   cultural_protocol, sensitivity_level, source_status, is_public)
values (
  'Adinkra',
  'adinkra',
  'adinkra',
  'textile_tradition',
  $$Akan people, Ghana & Côte d'Ivoire$$,
  $$Specific symbols carry funerary and royal associations. Adinkra cloth was historically worn for mourning. | STRUCTURE: SUBORDINATE TO / RELATED: Asante. Adinkra is an Akan (incl. Asante) tradition — currently listed as a peer, which is a category error. | West Africa | Pre-colonial, documented 19th c. | CANDIDATE SOURCES (UNVERIFIED): British Museum (Akan collections), Smithsonian NMAfA, Ross, 'Adinkra: The Cloth That Speaks'$$,
  $$REVIEW QUESTION: Which symbols, if any, should we decline to reproduce commercially? Is the funerary association still active?$$,
  'context_required',
  'draft',
  false
)
on conflict (slug) do nothing;

insert into public.cs_atlas_entries
  (name, slug, dictionary_style, entry_type, short_definition, cultural_context,
   cultural_protocol, sensitivity_level, source_status, is_public)
values (
  'Adire',
  'adire',
  'adire',
  'textile_tradition',
  $$Yoruba people, Southwest Nigeria (Abeokuta, Ibadan)$$,
  $$Indigo resist-dyeing, a women's craft with named patterns that carry meaning. | West Africa | Pre-colonial, flourished early 20th c. | CANDIDATE SOURCES (UNVERIFIED): British Museum, Nigerian National Museum, Byfield, 'The Bluest Hands'$$,
  $$REVIEW QUESTION: Do named adire patterns (e.g. Olokun, Ibadandun) carry restrictions we should honor?$$,
  'general',
  'draft',
  false
)
on conflict (slug) do nothing;

insert into public.cs_atlas_entries
  (name, slug, dictionary_style, entry_type, short_definition, cultural_context,
   cultural_protocol, sensitivity_level, source_status, is_public)
values (
  'Asante (Akan)',
  'asante-akan',
  'asante',
  'textile_tradition',
  $$Asante (Ashanti) kingdom, Akan people, Ghana$$,
  $$A kingdom/people, not a textile technique. Currently a peer of Adinkra and Kente, which are Akan traditions. | STRUCTURE: STRUCTURAL: likely a people/place, not a tradition. Recommend converting to a cs_kg_places or people node. | ACTION: MERGE? | West Africa | Kingdom from c. 1670 | CANDIDATE SOURCES (UNVERIFIED): British Museum, Manhyia Palace Museum$$,
  $$REVIEW QUESTION: Should 'Asante' be a PLACE/PEOPLE node rather than a textile tradition? Kente and Adinkra are the traditions, Asante is who they belong to.$$,
  'context_required',
  'draft',
  false
)
on conflict (slug) do nothing;

insert into public.cs_atlas_entries
  (name, slug, dictionary_style, entry_type, short_definition, cultural_context,
   cultural_protocol, sensitivity_level, source_status, is_public)
values (
  'Kente',
  'kente',
  'kente | kente-strip',
  'textile_tradition',
  $$Akan and Ewe people, Ghana and Togo$$,
  $$Specific cloths and patterns were historically reserved for royalty. Named patterns carry proverbs. Heavily appropriated (graduation stoles, fast fashion). | STRUCTURE: Ewe kente and Asante kente are distinct traditions often collapsed. Should they be separate entries? | West Africa | Pre-colonial, Asante & Ewe strip-weaving | CANDIDATE SOURCES (UNVERIFIED): British Museum, Smithsonian NMAfA, Ross, 'Wrapped in Pride'$$,
  $$REVIEW QUESTION: We sell graduation stoles. Is that use welcomed, tolerated, or objectionable? Which named patterns should we NOT reproduce?$$,
  'context_required',
  'draft',
  false
)
on conflict (slug) do nothing;

insert into public.cs_atlas_entries
  (name, slug, dictionary_style, entry_type, short_definition, cultural_context,
   cultural_protocol, sensitivity_level, source_status, is_public)
values (
  'Kuba Cloth',
  'kuba-cloth',
  'kuba',
  'textile_tradition',
  $$Kuba Kingdom, Democratic Republic of Congo$$,
  $$Raffia textiles tied to royal court, status, and funerary use. | Central Africa | Pre-colonial, Kuba Kingdom c. 17th c. | CANDIDATE SOURCES (UNVERIFIED): Brooklyn Museum (Kuba holdings), Royal Museum for Central Africa (Tervuren), Smithsonian NMAfA$$,
  $$REVIEW QUESTION: Are Kuba designs individually owned/attributed within the culture? Does commercial reproduction conflict with that?$$,
  'context_required',
  'draft',
  false
)
on conflict (slug) do nothing;

insert into public.cs_atlas_entries
  (name, slug, dictionary_style, entry_type, short_definition, cultural_context,
   cultural_protocol, sensitivity_level, source_status, is_public)
values (
  'Mudcloth (Bògòlanfini)',
  'mudcloth-b-g-lanfini',
  'mudcloth',
  'textile_tradition',
  $$Bamana people, Mali$$,
  $$Symbols relate to hunters, initiation, and protection. Cloth is made by named artisans, motifs carry specific meanings. | STRUCTURE: NAME: 'Mudcloth' is the English trade name. Bògòlanfini is the Bamana name. Recommend leading with the endonym. | ACTION: RENAME | West Africa | Pre-colonial, documented widely 20th c. | CANDIDATE SOURCES (UNVERIFIED): Smithsonian NMAfA, Musée du quai Branly, Rovine, 'Bogolan: Shaping Culture through Cloth in Contemporary Mali'$$,
  $$REVIEW QUESTION: Is 'Mudcloth' acceptable as a public name, or should the entry lead with Bògòlanfini? Which symbols are restricted?$$,
  'context_required',
  'draft',
  false
)
on conflict (slug) do nothing;

insert into public.cs_atlas_entries
  (name, slug, dictionary_style, entry_type, short_definition, cultural_context,
   cultural_protocol, sensitivity_level, source_status, is_public)
values (
  'Kanga',
  'kanga',
  'kanga',
  'textile_tradition',
  $$Swahili coast — Kenya, Tanzania, Zanzibar$$,
  $$Kangas carry printed Swahili proverbs (jina). The TEXT is integral — a kanga without a meaningful proverb is not a kanga. | STRUCTURE: IMPORTANT: the proverb is constitutive of the form. Pattern-only reproduction may be a category error. | East Africa | Mid-19th century onward | CANDIDATE SOURCES (UNVERIFIED): British Museum, National Museums of Kenya, Zanzibar Museum$$,
  $$REVIEW QUESTION: If we reproduce kanga-style patterns without Swahili text, is that a misrepresentation? Should we require text?$$,
  'general',
  'draft',
  false
)
on conflict (slug) do nothing;

insert into public.cs_atlas_entries
  (name, slug, dictionary_style, entry_type, short_definition, cultural_context,
   cultural_protocol, sensitivity_level, source_status, is_public)
values (
  'Ndebele',
  'ndebele',
  'ndebele | ndebele-beads',
  'textile_tradition',
  $$Ndebele people, South Africa (and parts of Zimbabwe)$$,
  $$Ndebele geometric painting is architectural and beadwork, not primarily a woven textile. Associated with named artists (e.g. Esther Mahlangu) whose work is copyrighted. | STRUCTURE: CAUTION: contemporary artist attribution risk is real here. | Southern Africa | Painted-architecture tradition, 20th c. flourish | CANDIDATE SOURCES (UNVERIFIED): Smithsonian NMAfA, Iziko South African National Gallery$$,
  $$REVIEW QUESTION: Ndebele design is strongly associated with LIVING named artists. How do we avoid infringing individual authorship while honoring the tradition?$$,
  'context_required',
  'draft',
  false
)
on conflict (slug) do nothing;

insert into public.cs_atlas_entries
  (name, slug, dictionary_style, entry_type, short_definition, cultural_context,
   cultural_protocol, sensitivity_level, source_status, is_public)
values (
  'Ethiopian (Habesha / Tibeb)',
  'ethiopian-habesha-tibeb',
  'ethiopian',
  'textile_tradition',
  $$Ethiopia and Eritrea$$,
  $$Tibeb is the woven border, habesha kemis the garment. 'Ethiopian' as a style name flattens Eritrea out. | STRUCTURE: NAME: a country is not a tradition. Recommend 'Tibeb'. | ACTION: RENAME | Horn of Africa | Ancient handweaving tradition | CANDIDATE SOURCES (UNVERIFIED): National Museum of Ethiopia, Smithsonian NMAfA$$,
  $$REVIEW QUESTION: Should this be 'Tibeb' (the actual design element)? Is 'Habesha' contested as a term?$$,
  'general',
  'draft',
  false
)
on conflict (slug) do nothing;

insert into public.cs_atlas_entries
  (name, slug, dictionary_style, entry_type, short_definition, cultural_context,
   cultural_protocol, sensitivity_level, source_status, is_public)
values (
  'Hawaiian Quilt',
  'hawaiian-quilt',
  'hawaiian',
  'textile_tradition',
  $$Native Hawaiian (Kanaka Maoli) tradition$$,
  $$Quilt patterns are traditionally considered personal, sometimes spiritually significant, copying another's design is a serious breach in Hawaiian practice. | STRUCTURE: HIGH RISK: the tradition's own protocol prohibits copying designs. | Hawaii, Pacific | Early 19th c., post-missionary contact | CANDIDATE SOURCES (UNVERIFIED): Bishop Museum, Honolulu, Honolulu Museum of Art, Root/ Hammond scholarship$$,
  $$REVIEW QUESTION: Hawaiian quilt designs are traditionally NOT copied — the design belongs to its maker. Does our reproduction violate this? This may be a decline-to-publish case.$$,
  'restricted',
  'draft',
  false
)
on conflict (slug) do nothing;

insert into public.cs_atlas_entries
  (name, slug, dictionary_style, entry_type, short_definition, cultural_context,
   cultural_protocol, sensitivity_level, source_status, is_public)
values (
  'Tapa / Siapo — Pacific Bark Cloth',
  'tapa-siapo-pacific-bark-cloth',
  'tapa | siapo',
  'textile_tradition',
  $$Oceania — Fijian masi, Tongan ngatu, Samoan siapo, Hawaiian kapa$$,
  $$These are DISTINCT traditions across different nations, collapsed into one entry. Ceremonial use is common. | STRUCTURE: SPLIT REQUIRED: multiple nations flattened into one. | ACTION: SPLIT | Pacific Islands / Polynesia | Ancient and continuing | CANDIDATE SOURCES (UNVERIFIED): Bishop Museum, Te Papa Tongarewa (NZ), Fiji Museum, Auckland Museum$$,
  $$REVIEW QUESTION: Should this be split into masi / ngatu / siapo / kapa as separate entries? Which are ceremonial-restricted?$$,
  'context_required',
  'draft',
  false
)
on conflict (slug) do nothing;

insert into public.cs_atlas_entries
  (name, slug, dictionary_style, entry_type, short_definition, cultural_context,
   cultural_protocol, sensitivity_level, source_status, is_public)
values (
  'Navajo / Diné',
  'navajo-din',
  'navajo',
  'textile_tradition',
  $$Diné (Navajo) people, U.S. Southwest$$,
  $$The Navajo Nation actively enforces its trademarks (see Navajo Nation v. Urban Outfitters, 2012–2016). 'Navajo print' is a legally contested term. Some designs have ceremonial meaning. | STRUCTURE: HIGHEST RISK ENTRY. Trademark + Indian Arts and Crafts Act exposure. | North America | Weaving developed c. 17th c. (from Pueblo) | CANDIDATE SOURCES (UNVERIFIED): Navajo Nation Museum, Heard Museum, Phoenix, Wheelwright Museum$$,
  $$REVIEW QUESTION: LEGAL: The Navajo Nation holds trademarks and has litigated. Do we have any right to use 'Navajo' as a style name? Strongly recommend legal review before publishing or selling.$$,
  'restricted',
  'draft',
  false
)
on conflict (slug) do nothing;

insert into public.cs_atlas_entries
  (name, slug, dictionary_style, entry_type, short_definition, cultural_context,
   cultural_protocol, sensitivity_level, source_status, is_public)
values (
  'Otomi (Tenango)',
  'otomi-tenango',
  'otomi',
  'textile_tradition',
  $$Otomí people, Tenango de Doria, Hidalgo, Mexico$$,
  $$Mexico has publicly challenged fashion brands (e.g. Carolina Herrera, 2019) for appropriating Tenango designs. Mexican federal law now protects indigenous collective IP (2022 Federal Law on the Protection of Cultural Heritage of Indigenous Peoples). | STRUCTURE: HIGH RISK: active legal framework + recent precedent. | Central Mexico | Embroidered 'Tenango' form: mid-20th c. | CANDIDATE SOURCES (UNVERIFIED): Museo de Arte Popular, Mexico City, Mexican Secretaría de Cultura statements$$,
  $$REVIEW QUESTION: LEGAL: Mexico's 2022 law protects indigenous collective designs. Does our use require community consent or licensing? Strongly recommend legal review.$$,
  'restricted',
  'draft',
  false
)
on conflict (slug) do nothing;

insert into public.cs_atlas_entries
  (name, slug, dictionary_style, entry_type, short_definition, cultural_context,
   cultural_protocol, sensitivity_level, source_status, is_public)
values (
  'Talavera',
  'talavera',
  'talavera',
  'textile_tradition',
  $$Puebla, Mexico (rooted in Talavera de la Reina, Spain)$$,
  $$'Talavera Poblana' has a Denominación de Origen (protected designation) in Mexico — the term is legally regulated for ceramics. | STRUCTURE: Note: protected designation exists (for ceramics). | Mexico / Iberia | Colonial period | CANDIDATE SOURCES (UNVERIFIED): Museo Amparo, Puebla, Museo Franz Mayer$$,
  $$REVIEW QUESTION: The DO applies to ceramics. Does it constrain our use of the term on textiles? Check with Mexican counsel.$$,
  'context_required',
  'draft',
  false
)
on conflict (slug) do nothing;

insert into public.cs_atlas_entries
  (name, slug, dictionary_style, entry_type, short_definition, cultural_context,
   cultural_protocol, sensitivity_level, source_status, is_public)
values (
  'Azulejo',
  'azulejo',
  'azulejo',
  'textile_tradition',
  $$Portugal and Spain (from Arabic az-zulayj)$$,
  $$Ceramic tilework, not a textile. Moorish/Islamic geometric roots often erased in 'European' framing. | STRUCTURE: CATEGORY: tilework, not textile. Fine to include as motif source if labeled honestly. | Iberia / Mediterranean | Arrived via Moorish Iberia, flourished 16th–18th c. | CANDIDATE SOURCES (UNVERIFIED): Museu Nacional do Azulejo, Lisbon$$,
  $$REVIEW QUESTION: Should the entry foreground the Arab/Moorish origin more explicitly?$$,
  'general',
  'draft',
  false
)
on conflict (slug) do nothing;

insert into public.cs_atlas_entries
  (name, slug, dictionary_style, entry_type, short_definition, cultural_context,
   cultural_protocol, sensitivity_level, source_status, is_public)
values (
  'Zellige',
  'zellige',
  'zellige',
  'textile_tradition',
  $$Morocco — Fes is the center$$,
  $$Islamic geometric tradition, the geometry carries theological meaning (tawhid — unity). | STRUCTURE: CATEGORY: tilework, not textile. | North Africa, Andalusia | 10th century CE onward | CANDIDATE SOURCES (UNVERIFIED): Musée Dar Si Said, Marrakech, Victoria & Albert Museum (Islamic Middle East gallery)$$,
  $$REVIEW QUESTION: Does the religious/theological dimension impose any use restrictions?$$,
  'context_required',
  'draft',
  false
)
on conflict (slug) do nothing;

insert into public.cs_atlas_entries
  (name, slug, dictionary_style, entry_type, short_definition, cultural_context,
   cultural_protocol, sensitivity_level, source_status, is_public)
values (
  'Batik',
  'batik',
  'batik',
  'textile_tradition',
  $$Java, Indonesia$$,
  $$UNESCO Intangible Cultural Heritage (Indonesian Batik, inscribed 2009). Certain motifs (e.g. parang, kawung) were historically reserved for Javanese royalty (larangan — forbidden patterns). | STRUCTURE: PARENT of Batik Tulis. Also relates to Adire, Shibori (resist-dye family). | Southeast Asia | Ancient roots, UNESCO ICH 2009 | CANDIDATE SOURCES (UNVERIFIED): UNESCO ICH listing (Indonesian Batik, 2009), Textile Museum Jakarta, Tropenmuseum, Amsterdam$$,
  $$REVIEW QUESTION: Which larangan (forbidden/royal) motifs must we exclude? Is the UNESCO listing the right anchor citation?$$,
  'context_required',
  'draft',
  false
)
on conflict (slug) do nothing;

insert into public.cs_atlas_entries
  (name, slug, dictionary_style, entry_type, short_definition, cultural_context,
   cultural_protocol, sensitivity_level, source_status, is_public)
values (
  'Batik Tulis',
  'batik-tulis',
  'batik-tulis',
  'textile_tradition',
  $$Java, Indonesia — hand-drawn with tjanting$$,
  $$Tulis = hand-written/drawn. This is a TECHNIQUE WITHIN batik, not a peer tradition. (Contrast: batik cap = stamped.) | STRUCTURE: STRUCTURAL: child of Batik. Currently listed as a peer — category error. | ACTION: CHILD | Southeast Asia | Refined in Javanese courts | CANDIDATE SOURCES (UNVERIFIED): Same as Batik$$,
  $$REVIEW QUESTION: Confirm: should batik-tulis be a child ('derived_from' / technique) of Batik rather than a separate tradition?$$,
  'context_required',
  'draft',
  false
)
on conflict (slug) do nothing;

insert into public.cs_atlas_entries
  (name, slug, dictionary_style, entry_type, short_definition, cultural_context,
   cultural_protocol, sensitivity_level, source_status, is_public)
values (
  'Ikat',
  'ikat',
  'ikat | ikat_diamond',
  'textile_tradition',
  $$Many distinct traditions: Uzbek, Indonesian, Indian (patola), Japanese (kasuri), Guatemalan (jaspe)$$,
  $$'Ikat' is a TECHNIQUE (resist-dyeing yarn before weaving), not one culture's tradition. Collapsing them violates our own governance rule. | STRUCTURE: SPLIT REQUIRED: technique, not a single tradition. | ACTION: SPLIT | Global | Ancient | CANDIDATE SOURCES (UNVERIFIED): V&A, Textile Museum, Washington DC, Bühler, 'Ikat Batik Plangi'$$,
  $$REVIEW QUESTION: Should ikat be a print_method/technique node with links to per-culture traditions, rather than a single entry?$$,
  'context_required',
  'draft',
  false
)
on conflict (slug) do nothing;

insert into public.cs_atlas_entries
  (name, slug, dictionary_style, entry_type, short_definition, cultural_context,
   cultural_protocol, sensitivity_level, source_status, is_public)
values (
  'Shibori',
  'shibori',
  'shibori',
  'textile_tradition',
  $$Japan$$,
  $$Resist-dyeing technique with named sub-methods (kanoko, arashi, itajime). | STRUCTURE: Related to Batik, Adire (resist-dye family). | East Asia | 8th century CE onward | CANDIDATE SOURCES (UNVERIFIED): Arimatsu Shibori Museum, Nagoya, V&A, Wada/Rice/Barton, 'Shibori: The Inventive Art of Japanese Shaped Resist Dyeing'$$,
  $$REVIEW QUESTION: Which named shibori techniques should be documented as distinct?$$,
  'general',
  'draft',
  false
)
on conflict (slug) do nothing;

insert into public.cs_atlas_entries
  (name, slug, dictionary_style, entry_type, short_definition, cultural_context,
   cultural_protocol, sensitivity_level, source_status, is_public)
values (
  'Suzani',
  'suzani',
  'suzani',
  'textile_tradition',
  $$Uzbekistan, Tajikistan, Kazakhstan — Silk Road cities$$,
  $$Embroidered dowry textiles, motifs carry protective/fertility meanings. | Central Asia | Pre-Islamic roots, 18th–19th c. flourish | CANDIDATE SOURCES (UNVERIFIED): V&A, Metropolitan Museum of Art, State Museum of Applied Arts, Tashkent$$,
  $$REVIEW QUESTION: Are suzani motifs tied to specific families/cities in ways we should attribute?$$,
  'general',
  'draft',
  false
)
on conflict (slug) do nothing;

insert into public.cs_atlas_entries
  (name, slug, dictionary_style, entry_type, short_definition, cultural_context,
   cultural_protocol, sensitivity_level, source_status, is_public)
values (
  'Phulkari',
  'phulkari',
  'phulkari',
  'textile_tradition',
  $$Punjab (present-day India and Pakistan)$$,
  $$Dowry/life-event embroidery. Bagh (fully covered) vs phulkari (scattered) are distinct. Partition split the tradition across two nations. | South Asia | Documented 19th c., Punjabi folk tradition | CANDIDATE SOURCES (UNVERIFIED): V&A, Philadelphia Museum of Art, Partition Museum, Amritsar$$,
  $$REVIEW QUESTION: Is it correct to present phulkari as a single tradition given the India/Pakistan split? Should bagh be separate?$$,
  'context_required',
  'draft',
  false
)
on conflict (slug) do nothing;

insert into public.cs_atlas_entries
  (name, slug, dictionary_style, entry_type, short_definition, cultural_context,
   cultural_protocol, sensitivity_level, source_status, is_public)
values (
  'Mehndi',
  'mehndi',
  'mehndi',
  'motif',
  $$South Asia, Middle East, North Africa$$,
  $$NOT A TRADITION - generic motif. Do not publish as provenance. | Mehndi is HENNA BODY ART, not a textile tradition. It is applied to skin, for weddings and celebrations. | STRUCTURE: CATEGORY ERROR: not a textile. Recommend entry_type='motif' or 'symbol', with explicit note. | ACTION: CATEGORY ERROR | South Asia / MENA | Ancient | CANDIDATE SOURCES (UNVERIFIED): V&A, Museum of Fine Arts Boston$$,
  $$REVIEW QUESTION: Mehndi is body art, not textile. Should it be a MOTIF SOURCE entry rather than a textile tradition? Reproducing henna designs on cloth may be a misrepresentation.$$,
  'context_required',
  'draft',
  false
)
on conflict (slug) do nothing;

insert into public.cs_atlas_entries
  (name, slug, dictionary_style, entry_type, short_definition, cultural_context,
   cultural_protocol, sensitivity_level, source_status, is_public)
values (
  'Paisley',
  'paisley',
  'paisley',
  'textile_tradition',
  $$Boteh motif — Persia/Kashmir, named for Paisley, Scotland$$,
  $$The name is COLONIAL: a Persian/Kashmiri motif (boteh/buta) renamed for the Scottish mill town that mass-copied it. The entry should say so plainly. | STRUCTURE: DISAMBIGUATION: the name itself records an act of appropriation. Excellent Atlas entry. | South Asia → global | Mughal period, industrialized in Scotland 19th c. | CANDIDATE SOURCES (UNVERIFIED): V&A, Paisley Museum, Scotland, Metropolitan Museum of Art$$,
  $$REVIEW QUESTION: Should we lead with 'Boteh' and treat 'Paisley' as the colonial trade name? This is a strong disambiguation candidate.$$,
  'context_required',
  'draft',
  false
)
on conflict (slug) do nothing;

insert into public.cs_atlas_entries
  (name, slug, dictionary_style, entry_type, short_definition, cultural_context,
   cultural_protocol, sensitivity_level, source_status, is_public)
values (
  'Persian',
  'persian',
  'persian',
  'textile_tradition',
  $$Iran (Persia)$$,
  $$'Persian' is a nation/culture, not a technique. Carpet traditions are regionally specific (Tabriz, Kashan, Isfahan, Kerman). | STRUCTURE: NAME: too broad. A country is not a tradition. | ACTION: RENAME | West / Central Asia | Ancient — Pazyryk carpet c. 5th c. BCE | CANDIDATE SOURCES (UNVERIFIED): Carpet Museum of Iran, Tehran, V&A, Met$$,
  $$REVIEW QUESTION: Should this be split by region/city, as carpet scholarship does?$$,
  'general',
  'draft',
  false
)
on conflict (slug) do nothing;

insert into public.cs_atlas_entries
  (name, slug, dictionary_style, entry_type, short_definition, cultural_context,
   cultural_protocol, sensitivity_level, source_status, is_public)
values (
  'Armenian',
  'armenian',
  'armenian',
  'textile_tradition',
  $$Armenian Highlands and diaspora$$,
  $$Armenian textile heritage is entangled with the Genocide (1915) and with contested attribution of carpets. Sensitive. | STRUCTURE: SENSITIVE: contested attribution + genocide context. | ACTION: RENAME | Caucasus / West Asia | Ancient carpet and needlelace traditions | CANDIDATE SOURCES (UNVERIFIED): Armenian Museum of America, Metropolitan Museum of Art$$,
  $$REVIEW QUESTION: Attribution of 'Armenian' carpets is historically contested (with Azerbaijani/Turkish claims). How do we handle this responsibly?$$,
  'context_required',
  'draft',
  false
)
on conflict (slug) do nothing;

insert into public.cs_atlas_entries
  (name, slug, dictionary_style, entry_type, short_definition, cultural_context,
   cultural_protocol, sensitivity_level, source_status, is_public)
values (
  'Mizrahi',
  'mizrahi',
  'mizrahi',
  'motif',
  $$Mizrahi Jewish communities of MENA / West Asia$$,
  $$NOT A TRADITION - generic motif. Do not publish as provenance. | 'Mizrahi' is an ethno-religious identity, not a textile tradition. Any pattern claim needs to be specific (e.g. Yemenite Jewish silverwork/embroidery). | STRUCTURE: CATEGORY ERROR: an identity, not a tradition. Recommend rework or exclude. | ACTION: CATEGORY ERROR | MENA / West Asia | Centuries-old | CANDIDATE SOURCES (UNVERIFIED): Israel Museum, Jerusalem, Jewish Museum, New York$$,
  $$REVIEW QUESTION: What SPECIFIC textile tradition is meant here? As written this is not a defensible entry.$$,
  'context_required',
  'draft',
  false
)
on conflict (slug) do nothing;

insert into public.cs_atlas_entries
  (name, slug, dictionary_style, entry_type, short_definition, cultural_context,
   cultural_protocol, sensitivity_level, source_status, is_public)
values (
  'Hamsa',
  'hamsa',
  'hamsa',
  'textile_tradition',
  $$MENA / Mediterranean — shared across Jewish, Muslim, and Christian communities$$,
  $$A protective SYMBOL (hand), not a textile tradition. Shared across faiths, also called Hand of Fatima / Hand of Miriam. | STRUCTURE: CATEGORY: symbol, not textile tradition. | MENA / Mediterranean | Ancient | CANDIDATE SOURCES (UNVERIFIED): Israel Museum, Musée du quai Branly$$,
  $$REVIEW QUESTION: Should this be entry_type='symbol' rather than textile_tradition? Whose name do we lead with, given it is shared?$$,
  'context_required',
  'draft',
  false
)
on conflict (slug) do nothing;

insert into public.cs_atlas_entries
  (name, slug, dictionary_style, entry_type, short_definition, cultural_context,
   cultural_protocol, sensitivity_level, source_status, is_public)
values (
  'Çintamani',
  'intamani',
  'cintemani',
  'textile_tradition',
  $$Ottoman Empire, Buddhist origins via the Silk Road$$,
  $$Three-dot-and-wavy-line motif, a genuine cross-cultural transmission story. | STRUCTURE: Good example of a documented cross-cultural motif. | Central Asia, Ottoman | Buddhist origins, Ottoman court use 15th–17th c. | CANDIDATE SOURCES (UNVERIFIED): Topkapı Palace Museum, Istanbul, V&A, Met$$,
  $$REVIEW QUESTION: Confirm the Buddhist→Ottoman transmission claim with a specific source.$$,
  'general',
  'draft',
  false
)
on conflict (slug) do nothing;

insert into public.cs_atlas_entries
  (name, slug, dictionary_style, entry_type, short_definition, cultural_context,
   cultural_protocol, sensitivity_level, source_status, is_public)
values (
  'Toile de Jouy',
  'toile-de-jouy',
  'toile | toile-scenic',
  'textile_tradition',
  $$Jouy-en-Josas, France — technique from India$$,
  $$Some historical toiles depict colonial and enslavement scenes. The technique itself (copperplate printing on cotton) derives from Indian chintz that Europe first banned, then copied. | STRUCTURE: SENSITIVE: colonial imagery in the historical corpus. | Europe, South Asia | 18th century | CANDIDATE SOURCES (UNVERIFIED): Musée de la Toile de Jouy, France, V&A$$,
  $$REVIEW QUESTION: Two issues: (1) some antique toile imagery is racist/colonial — do we screen for this? (2) Should the entry credit the Indian chintz origin?$$,
  'restricted',
  'draft',
  false
)
on conflict (slug) do nothing;

insert into public.cs_atlas_entries
  (name, slug, dictionary_style, entry_type, short_definition, cultural_context,
   cultural_protocol, sensitivity_level, source_status, is_public)
values (
  'Tartan',
  'tartan',
  'tartan',
  'textile_tradition',
  $$Scottish Highlands$$,
  $$Clan tartans are REGISTERED (Scottish Register of Tartans, statutory since 2008). Many 'ancient clan tartans' are in fact Victorian inventions. | STRUCTURE: Registry exists — real, checkable protocol. | Northern Europe | Documented from 16th c., codified 19th c. | CANDIDATE SOURCES (UNVERIFIED): Scottish Register of Tartans, National Museums Scotland$$,
  $$REVIEW QUESTION: Do we risk claiming a registered clan tartan? Should we only use non-clan/generic setts? Also: should the entry state that clan tartans are largely a 19th-c. invention?$$,
  'context_required',
  'draft',
  false
)
on conflict (slug) do nothing;

insert into public.cs_atlas_entries
  (name, slug, dictionary_style, entry_type, short_definition, cultural_context,
   cultural_protocol, sensitivity_level, source_status, is_public)
values (
  'Celtic / Gaelic Knotwork',
  'celtic-gaelic-knotwork',
  'celtic',
  'textile_tradition',
  $$Celtic peoples of Ireland, Scotland, Wales, and the wider Celtic world$$,
  $$'Celtic' knotwork is largely from Insular manuscript art (Book of Kells, Lindisfarne). Also appropriated by some white-nationalist groups — a real modern risk. | STRUCTURE: MODERN RISK: extremist appropriation. | Northern / Western Europe | Flourished in early medieval insular art | CANDIDATE SOURCES (UNVERIFIED): Trinity College Dublin (Book of Kells), National Museum of Ireland, British Library$$,
  $$REVIEW QUESTION: Is 'Celtic' too broad? Should it be 'Insular art'? And how do we address extremist appropriation of these symbols?$$,
  'context_required',
  'draft',
  false
)
on conflict (slug) do nothing;

insert into public.cs_atlas_entries
  (name, slug, dictionary_style, entry_type, short_definition, cultural_context,
   cultural_protocol, sensitivity_level, source_status, is_public)
values (
  'Runes',
  'runes',
  'runes',
  'textile_tradition',
  $$Germanic and Norse peoples of Northern Europe$$,
  $$Runes are a WRITING SYSTEM, not a textile tradition. Critically: specific runes (e.g. sig/sowilō, othala) are actively used by neo-Nazi and white-supremacist groups. | STRUCTURE: HIGHEST MODERN RISK. Not a textile tradition, extremist appropriation is active and specific. | Northern Europe / Scandinavia | Elder Futhark from c. 2nd c. CE | CANDIDATE SOURCES (UNVERIFIED): National Museum of Denmark, Swedish History Museum$$,
  $$REVIEW QUESTION: SERIOUS: Which runes are compromised by extremist use, and should we decline to print them? This entry carries real reputational risk. Strongly recommend expert review or exclusion.$$,
  'restricted',
  'draft',
  false
)
on conflict (slug) do nothing;

insert into public.cs_atlas_entries
  (name, slug, dictionary_style, entry_type, short_definition, cultural_context,
   cultural_protocol, sensitivity_level, source_status, is_public)
values (
  'Greek Key (Meander)',
  'greek-key-meander',
  'greek-key',
  'textile_tradition',
  $$Ancient Greece, similar forms in Aztec, Chinese, and African traditions$$,
  $$Convergent motif — appears independently in many cultures. Don't claim Greek exclusivity. | Mediterranean and global | Ancient — Greek pottery | CANDIDATE SOURCES (UNVERIFIED): British Museum, Met, National Archaeological Museum, Athens$$,
  $$REVIEW QUESTION: Is 'Greek Key' the right lead name given the convergent forms elsewhere?$$,
  'general',
  'draft',
  false
)
on conflict (slug) do nothing;

insert into public.cs_atlas_entries
  (name, slug, dictionary_style, entry_type, short_definition, cultural_context,
   cultural_protocol, sensitivity_level, source_status, is_public)
values (
  'Bargello',
  'bargello',
  'brazilian',
  'textile_tradition',
  $$Florence, Italy — counted-thread needlework$$,
  $$The style key 'brazilian' is FLATLY WRONG and is live on 106 patterns. Bargello is Italian/Florentine needlework, named for the Bargello Palace. | STRUCTURE: URGENT: misnomer live in production. Rename style key. | ACTION: RENAME URGENT | Europe / Mediterranean | 'Flame stitch', associated with Bargello Palace chairs | CANDIDATE SOURCES (UNVERIFIED): Museo Nazionale del Bargello, Florence, V&A$$,
  $$REVIEW QUESTION: Confirm the correction. This is a flagship disambiguation entry: 'Bargello is routinely mislabeled Brazilian.'$$,
  'general',
  'draft',
  false
)
on conflict (slug) do nothing;

insert into public.cs_atlas_entries
  (name, slug, dictionary_style, entry_type, short_definition, cultural_context,
   cultural_protocol, sensitivity_level, source_status, is_public)
values (
  'Madras',
  'madras',
  'caribbeancarnival',
  'textile_tradition',
  $$Madras (now Chennai), Tamil Nadu, India$$,
  $$The style key 'caribbeancarnival' is WRONG and live on 106 patterns. Madras is South Indian handloom cotton — though its Caribbean adoption (via indentured Indian labor) is a real and important second chapter. | STRUCTURE: URGENT: misnomer live in production. But the diaspora story is genuinely rich — a great Atlas entry. | ACTION: RENAME URGENT | South Asia → Caribbean | Handloom cotton, global trade from 17th c. | CANDIDATE SOURCES (UNVERIFIED): V&A, Met, Government Museum, Chennai$$,
  $$REVIEW QUESTION: The Caribbean connection is REAL but secondary — madras traveled with indentured Indian laborers. How do we tell both chapters without erasing the origin?$$,
  'context_required',
  'draft',
  false
)
on conflict (slug) do nothing;

insert into public.cs_atlas_entries
  (name, slug, dictionary_style, entry_type, short_definition, cultural_context,
   cultural_protocol, sensitivity_level, source_status, is_public)
values (
  $$T'nalak$$,
  't-nalak',
  'philippine',
  'textile_tradition',
  $$T'boli people, Lake Sebu, South Cotabato, Mindanao, Philippines$$,
  $$The style key 'philippine' collapses a specific indigenous tradition into a country. CRITICALLY: T'nalak designs are received in DREAMS by 'dreamweavers' (mebuwu) and are considered sacred. There are protocols around who may weave and reproduce them. | STRUCTURE: URGENT misnomer + HIGH sensitivity. Possible sacred_private candidate. | ACTION: RENAME URGENT | Southeast Asia | Ancient and living | CANDIDATE SOURCES (UNVERIFIED): National Museum of the Philippines, Lake Sebu T'boli community organizations$$,
  $$REVIEW QUESTION: SERIOUS: T'nalak is dream-derived and sacred to the T'boli. Do we have any right to reproduce it commercially? This may be a decline-to-publish / decline-to-sell case. Recommend community consultation before any use.$$,
  'restricted',
  'draft',
  false
)
on conflict (slug) do nothing;

insert into public.cs_atlas_entries
  (name, slug, dictionary_style, entry_type, short_definition, cultural_context,
   cultural_protocol, sensitivity_level, source_status, is_public)
values (
  'Hmong (Paj Ntaub)',
  'hmong-paj-ntaub',
  'hmong',
  'textile_tradition',
  $$Hmong people — southern China and SE Asia (Vietnam, Laos, Thailand)$$,
  $$'Story cloths' (paj ntaub) were developed in refugee camps after the Secret War in Laos, recording flight and trauma. Deeply tied to a living diaspora. | STRUCTURE: SENSITIVE: living diaspora, recent trauma. | East / Southeast Asia | Ancient, batik and reverse appliqué | CANDIDATE SOURCES (UNVERIFIED): Minnesota Historical Society (large Hmong collection), Smithsonian$$,
  $$REVIEW QUESTION: The story-cloth form is tied to war and refugee experience. Is decorative commercial use appropriate?$$,
  'context_required',
  'draft',
  false
)
on conflict (slug) do nothing;

insert into public.cs_atlas_entries
  (name, slug, dictionary_style, entry_type, short_definition, cultural_context,
   cultural_protocol, sensitivity_level, source_status, is_public)
values (
  'Andean Textile Tradition',
  'andean-textile-tradition',
  'andean | inca',
  'textile_tradition',
  $$Quechua, Aymara, and indigenous Andean peoples — Peru, Bolivia, Ecuador$$,
  $$'Andean' spans thousands of years and many distinct cultures. 'Inca' as a variant key is a specific empire, not a synonym. | STRUCTURE: SPLIT REQUIRED. The 'inca' variant key is misleading. | ACTION: SPLIT | South America | Pre-Columbian (Paracas, Nazca, Wari, Inca) through today | CANDIDATE SOURCES (UNVERIFIED): Museo Larco, Lima, Textile Museum, Washington DC, Amano Museum$$,
  $$REVIEW QUESTION: Should this split by culture (Paracas / Nazca / Wari / Inca / contemporary Quechua)? 'Inca' is not a synonym for 'Andean'.$$,
  'context_required',
  'draft',
  false
)
on conflict (slug) do nothing;

insert into public.cs_atlas_entries
  (name, slug, dictionary_style, entry_type, short_definition, cultural_context,
   cultural_protocol, sensitivity_level, source_status, is_public)
values (
  'Ç- East Asian Geometric Tradition',
  'east-asian-geometric-tradition',
  'asian',
  'motif',
  $$China, Japan, Korea$$,
  $$NOT A TRADITION - generic motif. Do not publish as provenance. | 'Asian' is a continent. This entry flattens three distinct national traditions into one, which our own governance doc forbids. | STRUCTURE: CATEGORY ERROR: a continent is not a tradition. Highest-priority rework. | ACTION: CATEGORY ERROR | East Asia | Ancient | CANDIDATE SOURCES (UNVERIFIED): Met, V&A, Tokyo National Museum, National Museum of Korea$$,
  $$REVIEW QUESTION: This entry is not defensible as written. Split into specific traditions (e.g. Chinese cloud/lattice, Japanese kumiko/asanoha, Korean bojagi) or exclude.$$,
  'context_required',
  'draft',
  false
)
on conflict (slug) do nothing;

insert into public.cs_atlas_entries
  (name, slug, dictionary_style, entry_type, short_definition, cultural_context,
   cultural_protocol, sensitivity_level, source_status, is_public)
values (
  'Floral Pattern Traditions',
  'floral-pattern-traditions',
  'floral',
  'motif',
  $$Persia, Ottoman, India, China, Europe$$,
  $$NOT A TRADITION - generic motif. Do not publish as provenance. | Too broad to be a tradition. Could be a motif family with links to specific traditions. | STRUCTURE: Likely motif, not tradition. | ACTION: MOTIF? | Global | Ancient | CANDIDATE SOURCES (UNVERIFIED): n/a — depends on scope$$,
  $$REVIEW QUESTION: Is this a tradition at all, or a motif category? Recommend motif.$$,
  'general',
  'draft',
  false
)
on conflict (slug) do nothing;

insert into public.cs_atlas_entries
  (name, slug, dictionary_style, entry_type, short_definition, cultural_context,
   cultural_protocol, sensitivity_level, source_status, is_public)
values (
  'Wildflower Print',
  'wildflower-print',
  'wildflower',
  'motif',
  $$European botanical illustration, Arts & Crafts$$,
  $$NOT A TRADITION - generic motif. Do not publish as provenance. | A design genre, not a cultural tradition. Morris is a named designer with a documented estate. | STRUCTURE: Likely motif/genre. | ACTION: MOTIF | Europe, global | William Morris era onward | CANDIDATE SOURCES (UNVERIFIED): V&A (William Morris collection)$$,
  $$REVIEW QUESTION: Is this a tradition or a design genre? If we invoke Morris, note his work is largely public domain but check specific patterns.$$,
  'general',
  'draft',
  false
)
on conflict (slug) do nothing;

insert into public.cs_atlas_entries
  (name, slug, dictionary_style, entry_type, short_definition, cultural_context,
   cultural_protocol, sensitivity_level, source_status, is_public)
values (
  'Tropical Frond',
  'tropical-frond',
  'frond',
  'motif',
  $$Caribbean, Pacific, West Africa$$,
  $$NOT A TRADITION - generic motif. Do not publish as provenance. | A motif, not a tradition. 'Tropical' as a category is a colonial-era construct worth naming. | STRUCTURE: Likely motif. | ACTION: MOTIF | Tropical regions globally | Pre-colonial through modern$$,
  $$REVIEW QUESTION: Recommend motif. Should we note the colonial framing of 'tropical' as an aesthetic?$$,
  'general',
  'draft',
  false
)
on conflict (slug) do nothing;

insert into public.cs_atlas_entries
  (name, slug, dictionary_style, entry_type, short_definition, cultural_context,
   cultural_protocol, sensitivity_level, source_status, is_public)
values (
  'Tropical Print Tradition',
  'tropical-print-tradition',
  'tropical',
  'motif',
  $$Hawaii, Caribbean, West Africa — converging mid-20th c.$$,
  $$NOT A TRADITION - generic motif. Do not publish as provenance. | The mid-century 'tropical print' is largely a COMMERCIAL genre (aloha shirts, resort wear), often built on appropriated motifs. | STRUCTURE: Likely motif/genre with a candid history note. | ACTION: MOTIF | Tropical regions globally | Modern form: 1930s onward | CANDIDATE SOURCES (UNVERIFIED): Honolulu Museum of Art (aloha shirt collections)$$,
  $$REVIEW QUESTION: This is a commercial genre with an appropriation history. Should we say so explicitly?$$,
  'context_required',
  'draft',
  false
)
on conflict (slug) do nothing;

insert into public.cs_atlas_entries
  (name, slug, dictionary_style, entry_type, short_definition, cultural_context,
   cultural_protocol, sensitivity_level, source_status, is_public)
values (
  'Heritage Pattern',
  'heritage-pattern',
  'heritage',
  'motif',
  $$CultureSchool original — 'drawing from multiple traditions'$$,
  $$NOT A TRADITION - generic motif. Do not publish as provenance. | This is a meaningless label. It makes a vague cultural claim while naming no culture — the exact opposite of 'named and credited'. | STRUCTURE: EXCLUDE. Vague placeholder masquerading as provenance. | ACTION: EXCLUDE | Global diaspora | Contemporary$$,
  $$REVIEW QUESTION: Recommend EXCLUDE from the Atlas entirely, and rename in the generator. A provenance dictionary cannot contain an entry called 'Heritage Pattern'.$$,
  'general',
  'draft',
  false
)
on conflict (slug) do nothing;

insert into public.cs_atlas_entries
  (name, slug, dictionary_style, entry_type, short_definition, cultural_context,
   cultural_protocol, sensitivity_level, source_status, is_public)
values (
  'Art Print',
  'art-print',
  'art-print',
  'motif',
  $$Generic motif. No single cultural origin. Makes NO cultural claim.$$,
  $$NOT A TRADITION - generic motif. Do not publish as provenance. | Not a cultural tradition. Generic label. | STRUCTURE: EXCLUDE. | ACTION: EXCLUDE | n/a | Contemporary$$,
  $$REVIEW QUESTION: Exclude from Atlas.$$,
  'general',
  'draft',
  false
)
on conflict (slug) do nothing;


-- DISAMBIGUATIONS

insert into public.cs_atlas_distinctions (atlas_entry_id, confused_with, correction, why_confused, is_public)
select
  e.id,
  'Brazilian',
  $$Florentine counted-thread needlework from Italy, named for the Bargello Palace. It is not Brazilian and never was.$$,
  $$Our own catalogue carried the label brazilian for years. The mislabel is common in commercial textile listings.$$,
  false
from public.cs_atlas_entries e
where e.name = 'Bargello'
  and not exists (select 1 from public.cs_atlas_distinctions d
                  where d.atlas_entry_id = e.id and d.confused_with = 'Brazilian');

insert into public.cs_atlas_distinctions (atlas_entry_id, confused_with, correction, why_confused, is_public)
select
  e.id,
  'Caribbean Carnival',
  $$Handloom checked cotton from Madras (now Chennai), Tamil Nadu, India.$$,
  $$Madras travelled to the Caribbean with indentured Indian labourers and was made wholly its own there - a real second chapter, but not the origin.$$,
  false
from public.cs_atlas_entries e
where e.name = 'Madras'
  and not exists (select 1 from public.cs_atlas_distinctions d
                  where d.atlas_entry_id = e.id and d.confused_with = 'Caribbean Carnival');

insert into public.cs_atlas_distinctions (atlas_entry_id, confused_with, correction, why_confused, is_public)
select
  e.id,
  'Philippine',
  $$A specific sacred cloth of the T'boli people of Lake Sebu, Mindanao. A country is not a tradition.$$,
  $$Collapsing an indigenous tradition into its nation-state erases the people who hold it.$$,
  false
from public.cs_atlas_entries e
where e.name = $$T'nalak$$
  and not exists (select 1 from public.cs_atlas_distinctions d
                  where d.atlas_entry_id = e.id and d.confused_with = 'Philippine');

insert into public.cs_atlas_distinctions (atlas_entry_id, confused_with, correction, why_confused, is_public)
select
  e.id,
  'A European pattern',
  $$The boteh or buta motif of Persia and Kashmir. Paisley is the Scottish mill town that mass-copied it.$$,
  $$The name itself records the act of appropriation.$$,
  false
from public.cs_atlas_entries e
where e.name = 'Paisley'
  and not exists (select 1 from public.cs_atlas_distinctions d
                  where d.atlas_entry_id = e.id and d.confused_with = 'A European pattern');

insert into public.cs_atlas_distinctions (atlas_entry_id, confused_with, correction, why_confused, is_public)
select
  e.id,
  'Mudcloth',
  $$Bògòlanfini is the Bamana name. Mudcloth is the English trade name.$$,
  $$Leading with the endonym is the whole point of a provenance atlas.$$,
  false
from public.cs_atlas_entries e
where e.name = 'Mudcloth (Bògòlanfini)'
  and not exists (select 1 from public.cs_atlas_distinctions d
                  where d.atlas_entry_id = e.id and d.confused_with = 'Mudcloth');

insert into public.cs_atlas_distinctions (atlas_entry_id, confused_with, correction, why_confused, is_public)
select
  e.id,
  'A neutral non-Dine term',
  $$A Chief's Blanket IS a Diné form. The name is an Anglo trade term - the Diné did not have chiefs.$$,
  $$Renaming to dodge a trademark keeps the design and drops the credit. That is the opposite of naming and crediting.$$,
  false
from public.cs_atlas_entries e
where e.name = 'Navajo / Diné'
  and not exists (select 1 from public.cs_atlas_distinctions d
                  where d.atlas_entry_id = e.id and d.confused_with = 'A neutral non-Dine term');


-- VERIFY

select count(*) as entries from public.cs_atlas_entries;

select count(*) as distinctions from public.cs_atlas_distinctions;
