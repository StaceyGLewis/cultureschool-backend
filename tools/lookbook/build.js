#!/usr/bin/env node
/* CoCo lookbook builder.
 *
 *   node tools/lookbook/build.js --list
 *   node tools/lookbook/build.js --picks autumn-2026.txt --edition "Autumn 2026"
 *
 * Reads palettes straight from Supabase, checks each one, lays them two to an
 * 8.5x11 sheet, and writes a single HTML file. Open it and print to PDF —
 * @page is set to US Letter with no margins, so what you see is what trims.
 */
const fs   = require('fs');
const path = require('path');
const { cmyk, gamut }   = require('./lib/color.js');
const { analyse }       = require('./lib/viable.js');
const { textile }       = require('./lib/textile.js');
const { room }          = require('./lib/room.js');
const { cloth }         = require('./lib/cloth.js');
const { construct }     = require('./lib/construct.js');

const SUPA = 'https://qwulthvbwujfehgdegtn.supabase.co';
const ANON = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF3dWx0aHZid3VqZmVoZ2RlZ3RuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDQyMDcxODIsImV4cCI6MjA1OTc4MzE4Mn0.t9n4eZng6d0jggiPNK-J_DByvEE2L9tqy5Xh_1-TSoQ';

const arg = (flag, def) => { const i = process.argv.indexOf(flag);
  return i > -1 && process.argv[i+1] ? process.argv[i+1] : def; };
const has = flag => process.argv.includes(flag);

const esc  = s => String(s ?? '').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;');
const norm = s => String(s ?? '').trim().toLowerCase().replace(/[‘’]/g,"'").replace(/\s+/g,' ');

const isIdentity = p => p.occasion === 'Pride'
  || /\bflag\b/i.test(p.name + ' ' + (p.story||''))
  || (Array.isArray(p.tags) && p.tags.some(t =>
      /pride|lgbtq|trans|lesbian|bisexual|queer|intersex|nonbinary|pansexual/i.test(t)));

async function fetchAll() {
  const url = `${SUPA}/rest/v1/palettes?select=id,name,colors,story,description,cultural_origin,`
            + `location,occasion,tags,color_descriptor,contributed_by&is_public=eq.true&limit=400`;
  const r = await fetch(url, { headers: { apikey: ANON, Authorization: 'Bearer ' + ANON } });
  if (!r.ok) throw new Error(`Supabase ${r.status} — ${await r.text()}`);
  return (await r.json()).filter(p =>
    (p.colors||[]).filter(h=>/^#[0-9a-fA-F]{6}$/.test(h)).length >= 3);
}

/* Everything the sheet needs to know about one palette. */
function assess(p) {
  const t = textile(p.colors), iv = analyse(p.colors), identity = isIdentity(p);
  const direct = iv.ok && !identity;
  const built  = direct ? null : construct(p.colors);
  const uses   = [...t.uses];
  if (direct) uses.unshift('Interior');
  const problems = [];
  if (!t.ok)                problems.push('will not read as a printed motif — ' + t.issues[0]);
  if (!p.story)             problems.push('no story');
  if (!p.cultural_origin)   problems.push('no cultural origin');
  if (p.name !== p.name.trim()) problems.push('name has stray whitespace');
  return { t, iv, identity, direct, built, uses, problems,
           roomCols: direct ? p.colors : built.colors,
           roomSch:  direct ? iv.scheme : analyse(built.colors).scheme };
}

/* ── fonts, cached beside the script so the PDF never depends on the network ── */
function fontB64(file) {
  const p = path.join(__dirname, 'lib', file);
  if (!fs.existsSync(p)) throw new Error(`missing ${file} — re-run setup`);
  return fs.readFileSync(p).toString('base64');
}

const specRow = cols => cols.map(c => {
  const g = gamut(c);
  return `<div class="sp${g.inGamut?'':' spog'}"><b>${c.toUpperCase()}</b><span>${cmyk(c).join('·')}</span></div>`;
}).join('');
const stripOf = cols => cols.map(c=>`<i style="background:${c}"></i>`).join('');

function block(p) {
  const a = assess(p);
  return `<section class="blk">
    <div class="bhead">
      <div><h2>${esc(p.name.trim())}</h2>
        <div class="borigin">${esc([p.cultural_origin,p.location].filter(Boolean).join(' · ')) || '&nbsp;'}</div></div>
      <div class="badges">${a.uses.map(u=>`<span class="bg${u==='Interior'?' bgi':''}">${esc(u)}</span>`).join('')}</div>
    </div>
    <div class="duo">
      <figure>
        <div class="rn">${cloth(p.colors)}</div>
        <figcaption><b>As cloth</b> — the palette as it is</figcaption>
        <div class="strip">${stripOf(p.colors)}</div>
        <div class="specs${p.colors.length>5?' many':''}">${specRow(p.colors)}</div>
      </figure>
      <figure>
        <div class="rn">${room(a.roomSch, a.roomCols)}</div>
        <figcaption>${a.direct ? '<b>As an interior</b> — same colours'
                               : '<b>Interior colourway</b> — constructed'}</figcaption>
        <div class="strip">${stripOf(a.roomCols)}</div>
        <div class="specs${a.roomCols.length>5?' many':''}">${specRow(a.roomCols)}</div>
      </figure>
    </div>
    ${p.story ? `<p class="story">${esc(p.story)}</p>`
      : p.description ? `<p class="story">${esc(p.description)}</p>` : ''}
    ${a.direct ? '' : `<p class="deriv">Interior colourway keeps
      ${a.built.derivation.filter(d=>/Signature/.test(d.role)).map(d=>d.hex.toUpperCase()).join(' and ')}
      and derives the rest from their hues.</p>`}
  </section>`;
}

function buildHtml(picked, edition) {
  const sheets = [];
  for (let i = 0; i < picked.length; i += 2) sheets.push(picked.slice(i, i+2));
  const cg = fontB64('cg.woff2'), dm = fontB64('dm.woff2');

  const pages = sheets.map((pair, i) => `
  <div class="sheet">
    <div class="shead"><span class="smark">CoCo</span>
      <span class="sedition">${esc(edition)}</span></div>
    <div class="body">${pair.map(block).join('')}</div>
    <div class="sfoot"><span>cultureschool.org</span>
      <span><b>Sheet ${i+1}</b> of ${sheets.length}</span></div>
  </div>`).join('');

  return `<!doctype html><html lang="en"><head><meta charset="utf-8">
<title>CoCo — ${esc(edition)}</title>
<style>
@font-face{font-family:'Cormorant Garamond';font-weight:600;font-display:block;src:url(data:font/woff2;base64,${cg}) format('woff2');}
@font-face{font-family:'DM Sans';font-weight:100 1000;font-display:block;src:url(data:font/woff2;base64,${dm}) format('woff2');}
:root{--cream:#faf6ef;--ink:#1a1208;--body:#4a3c28;--muted:#8a7a62;--gold:#a9803c;--rule:#e3dccc}
*,*::before,*::after{box-sizing:border-box}
body{margin:0;background:#ddd8cc;font-family:'DM Sans',system-ui,sans-serif;-webkit-font-smoothing:antialiased}
.stack{display:flex;flex-direction:column;align-items:center;gap:26px;padding:32px 16px 60px}
.sheet{width:8.5in;height:11in;background:var(--cream);color:var(--ink);
  container-type:inline-size;display:flex;flex-direction:column;
  padding:4.4cqw 4.8cqw 3.4cqw;box-shadow:0 18px 44px rgba(0,0,0,.28)}
.shead{display:flex;justify-content:space-between;align-items:baseline;
  padding-bottom:2cqw;border-bottom:.22cqw solid var(--rule);flex:0 0 auto}
.smark{font-family:'Cormorant Garamond',Georgia,serif;font-weight:600;font-size:2.9cqw}
.sedition{font-size:1.55cqw;letter-spacing:.2em;text-transform:uppercase;color:var(--gold)}
.body{flex:1;display:flex;flex-direction:column;gap:3.2cqw;padding-top:3cqw;min-height:0}
.blk{flex:1;display:flex;flex-direction:column;min-height:0}
.bhead{display:flex;justify-content:space-between;align-items:flex-start;gap:2cqw;margin-bottom:2cqw}
h2{font-family:'Cormorant Garamond',Georgia,serif;font-weight:600;font-size:3.5cqw;margin:0;line-height:1.08}
.borigin{font-size:1.4cqw;letter-spacing:.15em;text-transform:uppercase;color:var(--gold);margin-top:.5cqw}
.badges{display:flex;flex-wrap:wrap;gap:.7cqw;justify-content:flex-end;max-width:52%}
.bg{font-size:1.22cqw;letter-spacing:.05em;padding:.55cqw 1.2cqw;border-radius:.4cqw;
  background:rgba(26,18,8,.07);color:var(--body);white-space:nowrap}
.bg.bgi{background:var(--gold);color:#fff}
.duo{display:grid;grid-template-columns:1fr 1fr;gap:2.4cqw;flex:1;min-height:0}
figure{margin:0;display:flex;flex-direction:column;min-height:0}
.rn{aspect-ratio:3/2;overflow:hidden;border-radius:.4cqw;
  box-shadow:0 0 0 .12cqw rgba(26,18,8,.14)}  /* keeps a white-walled room from dissolving into the page */
.rn svg{width:100%;height:100%;display:block}
figcaption{font-size:1.42cqw;color:var(--muted);margin:1.3cqw 0 1cqw;line-height:1.35}
figcaption b{color:var(--ink);font-weight:600}
.strip{display:flex;height:2.4cqw;border-radius:.25cqw;overflow:hidden;margin-bottom:1cqw}
.strip i{flex:1}
.specs{display:flex;gap:.6cqw}
.sp{flex:1;min-width:0;display:flex;flex-direction:column;gap:.2cqw}
.sp b{font-size:1.28cqw;font-weight:600;font-variant-numeric:tabular-nums}
.sp span{font-size:1.02cqw;color:var(--muted);font-variant-numeric:tabular-nums}
.specs.many .sp b{font-size:1.06cqw}.specs.many .sp span{font-size:.88cqw}.specs.many{gap:.35cqw}
.spog b::after{content:' △';color:#b4422f}
.story{font-size:1.55cqw;line-height:1.62;color:var(--body);margin:2cqw 0 0;
  padding-top:1.6cqw;border-top:.22cqw solid var(--rule)}
.deriv{font-size:1.32cqw;line-height:1.55;color:var(--muted);font-style:italic;margin:1.1cqw 0 0}
.sfoot{flex:0 0 auto;padding-top:2cqw;margin-top:2.4cqw;border-top:.22cqw solid var(--rule);
  display:flex;justify-content:space-between;font-size:1.24cqw;letter-spacing:.1em;
  text-transform:uppercase;color:var(--muted)}
.sfoot b{color:var(--gold);font-weight:600}

/* Print: US Letter, no margin, one sheet per page. Cmd-P -> Save as PDF. */
@page{size:8.5in 11in;margin:0}
@media print{
  body{background:#fff}
  .stack{gap:0;padding:0}
  .sheet{box-shadow:none;break-after:page;page-break-after:always}
  .sheet:last-child{break-after:auto;page-break-after:auto}
}
</style></head><body><div class="stack">${pages}</div></body></html>`;
}

(async () => {
  const all = await fetchAll();

  if (has('--list')) {
    const rows = all.map(p => ({ p, a: assess(p) }))
      .sort((x,y) => x.p.name.trim().localeCompare(y.p.name.trim()));
    const ready = rows.filter(r => !r.a.problems.length);
    console.log(`${all.length} public palettes · ${ready.length} print-ready\n`);
    console.log('  ' + 'NAME'.padEnd(38) + 'ORIGIN'.padEnd(22) + 'USES');
    console.log('  ' + '─'.repeat(86));
    rows.forEach(({p,a}) => {
      const flag = a.problems.length ? '·' : '✓';
      console.log(`${flag} ${p.name.trim().slice(0,36).padEnd(38)}` +
        `${(p.cultural_origin||'—').slice(0,20).padEnd(22)}` +
        `${a.direct ? 'interior + cloth' : 'cloth'}` +
        (a.problems.length ? `   (${a.problems.join('; ')})` : ''));
    });
    console.log('\n✓ = ready to print.  Put the names you want in a text file, one per line.');
    return;
  }

  const picksFile = arg('--picks');
  if (!picksFile) {
    console.error('Usage:\n  node tools/lookbook/build.js --list\n' +
      '  node tools/lookbook/build.js --picks picks.txt --edition "Autumn 2026" [--out lookbook.html]');
    process.exit(1);
  }
  const wanted = fs.readFileSync(picksFile,'utf8').split('\n')
    .map(l => l.replace(/#.*$/,'').trim()).filter(Boolean);

  const byName = new Map(all.map(p => [norm(p.name), p]));
  const byId   = new Map(all.map(p => [p.id, p]));
  const picked = [], missing = [];
  wanted.forEach(w => {
    const hit = byId.get(w) || byName.get(norm(w));
    hit ? picked.push(hit) : missing.push(w);
  });

  if (missing.length) {
    console.error('Not found:\n' + missing.map(m=>'  ✕ '+m).join('\n'));
    console.error('\nRun with --list to see exact names.');
    process.exit(1);
  }

  let blocked = 0;
  picked.forEach(p => {
    const a = assess(p);
    if (a.problems.length) { blocked++;
      console.warn(`  ⚠ ${p.name.trim()} — ${a.problems.join('; ')}`); }
  });
  if (blocked && !has('--force'))
    console.warn(`\n${blocked} palette(s) have gaps. Printing anyway; pass --force to silence.`);

  const edition = arg('--edition', 'Autumn 2026');
  const out     = arg('--out', 'lookbook.html');
  fs.writeFileSync(out, buildHtml(picked, edition));
  console.log(`\n✓ ${picked.length} palettes · ${Math.ceil(picked.length/2)} sheets · ${out}`);
  console.log('  Open it, Cmd-P, Save as PDF. Page size is already US Letter with no margins.');
})().catch(e => { console.error('build failed:', e.message); process.exit(1); });
