/* Textile viability — a different question from interior viability.
   A room needs anchors because its surfaces are enormous and you live inside
   them. A cushion, a scarf, a yard of cloth needs none of that; it is the
   accent in somebody else's scheme. What it does need is for the MOTIF TO
   READ — adjacent colours far enough apart that the pattern survives being
   printed, woven, and looked at from across a room. */
const { lab } = require('./color.js');

// ΔE76 — Euclidean in Lab. Coarse next to ΔE2000 but the thresholds here are
// coarse too (can you see the shape, yes or no).
const dE = (a, b) => Math.hypot(a.L-b.L, a.a-b.a, a.b-b.b);

function textile(colors) {
  const c = (colors||[]).filter(h=>/^#[0-9a-fA-F]{6}$/.test(h)).map(h=>({hex:h,...lab(h)}));
  if (c.length < 2) return { ok:false, issues:['Fewer than two usable colours.'] };

  const pairs = [];
  for (let i=0;i<c.length;i++) for (let j=i+1;j<c.length;j++)
    pairs.push({ a:c[i], b:c[j], d:dE(c[i],c[j]) });
  pairs.sort((x,y)=>y.d-x.d);

  const strongest = pairs[0].d;
  const readable  = pairs.filter(p => p.d >= 30).length;   // pairs that read at distance
  const muddy     = pairs.filter(p => p.d < 12).length;    // pairs that will blur together
  const issues = [];

  if (strongest < 30)
    issues.push(`Strongest pair is only ΔE ${strongest.toFixed(0)} — every colour blurs into its neighbour and the motif disappears at arm's length.`);
  if (readable < 2 && strongest >= 30)
    issues.push(`Only one pair reads at distance — the pattern will carry on one contrast and go flat everywhere else.`);
  if (muddy > pairs.length * 0.6)
    issues.push(`${muddy} of ${pairs.length} pairs sit under ΔE 12 — most of the palette will mud together in print.`);

  // Where does it belong? Small goods forgive far more than yardage.
  const uses = [];
  if (strongest >= 45 && readable >= 3) uses.push('Yardage');
  if (strongest >= 30) uses.push('Cushions & throws', 'Scarves & squares');
  if (strongest >= 30 && readable >= 2) uses.push('Table linen');
  if (strongest >= 22) uses.push('Trim, binding & small goods');

  return { ok: issues.length === 0, issues, strongest, readable, muddy,
           pairs: pairs.length, uses };
}

module.exports = { textile, dE };
