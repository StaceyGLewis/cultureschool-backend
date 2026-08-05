/* Can this palette actually be a room?
   A palette lifted from a photograph can be beautiful and still be unusable on
   surfaces. These are the checks a designer runs in their head — made explicit
   so nobody has to. All computable from Lab. */
const { lab } = require('./color.js');

function analyse(colors) {
  const c = (colors || []).filter(h => /^#[0-9a-fA-F]{6}$/.test(h)).map(h => ({ hex: h, ...lab(h) }));
  if (c.length < 3) return { ok:false, fatal:true, issues:['Fewer than three usable colours.'], c };

  const Ls = c.map(x => x.L), Cs = c.map(x => x.C);
  const spread   = Math.max(...Ls) - Math.min(...Ls);
  const light    = c.filter(x => x.L >= 72);          // walls, ceilings, sheers
  const dark     = c.filter(x => x.L <= 40);          // grounding, joinery
  const loud     = c.filter(x => x.C > 45);           // can't all be the accent
  const midMuddy = c.filter(x => x.L > 40 && x.L < 72 && x.C < 20);

  const issues = [];
  if (!light.length)
    issues.push('No light anchor — nothing light enough for walls or ceilings (needs one at L*≥72).');
  if (!dark.length)
    issues.push('No dark anchor — nothing to ground the scheme (needs one at L*≤40).');
  if (spread < 40)
    issues.push(`Value spread only ${spread.toFixed(0)} — the colours sit in one band and the room reads flat.`);
  if (loud.length > 3)
    issues.push(`${loud.length} of ${c.length} colours are highly saturated — nothing recedes, so nothing reads as background.`);

  /* 60/30/10. The three roles must be three DIFFERENT colours — on a flag
     palette the lightest colour is often also the most saturated, which made
     dominant and accent collapse onto the same swatch. Assign in order and
     remove each from the pool. */
  const pool      = [...c];
  const take      = (arr, cmp) => { const w = [...arr].sort(cmp)[0];
                                    pool.splice(pool.indexOf(w), 1); return w; };
  const dominant  = take(pool, (a,b) => (b.L - b.C*0.45) - (a.L - a.C*0.45));
  const accent    = take(pool, (a,b) => b.C - a.C);
  const ground    = take(pool, (a,b) => a.L - b.L);                    // darkest left
  const secondary = pool.length
    ? [...pool].sort((a,b) => Math.abs(55-a.L) - Math.abs(55-b.L))[0]
    : ground;

  return {
    ok: issues.length === 0,
    issues, c, spread,
    counts: { light: light.length, dark: dark.length, loud: loud.length, muddy: midMuddy.length },
    scheme: { dominant: dominant.hex, secondary: secondary.hex,
              accent: accent.hex, ground: ground.hex },
  };
}

module.exports = { analyse };
