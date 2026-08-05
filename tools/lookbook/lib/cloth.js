/* Cloth render — for palettes that belong on textiles rather than walls.
   A woven stripe is the honest form: warp-faced bands of varying width, which
   is what these colours would actually become on a loom. Deterministic from
   the palette, so the same palette always yields the same cloth. */
const { lab } = require('./color.js');

const rgba = (h,a) => { const r=parseInt(h.slice(1,3),16),g=parseInt(h.slice(3,5),16),b=parseInt(h.slice(5,7),16);
                        return `rgba(${r},${g},${b},${a})`; };
const mix = (h1,h2,t) => { const p=h=>[parseInt(h.slice(1,3),16),parseInt(h.slice(3,5),16),parseInt(h.slice(5,7),16)];
  const [a,b]=[p(h1),p(h2)];
  return '#'+a.map((v,i)=>Math.round(v+(b[i]-v)*t).toString(16).padStart(2,'0')).join(''); };

function cloth(colors) {
  /* Ids must be unique per instance: two cloths on one page both defining
     id="wv" makes every url(#wv) resolve to the first, so every sheet after
     the first prints the wrong palette. Namespace them by content. */
  const uid = "c" + colors.join("").replace(/[^0-9a-f]/gi,"").slice(0,10);
  const c = colors.filter(h=>/^#[0-9a-fA-F]{6}$/.test(h));
  const byL = [...c].sort((a,b)=>lab(b).L-lab(a).L);
  const lightest = byL[0], darkest = byL[byL.length-1];
  const ground = '#ddd7cc';                       // undyed linen the cloth sits on

  /* Warp bands — widths derived from position so the sequence is fixed but
     not mechanical. Total repeat width 60. */
  const widths = c.map((_,i) => 4 + ((i*7) % 9));
  const total  = widths.reduce((a,b)=>a+b,0);
  let x = 0;
  const warp = c.map((col,i) => {
    const w = widths[i] / total * 60;
    const r = `<rect x="${x.toFixed(2)}" y="0" width="${w.toFixed(2)}" height="60" fill="${col}"/>`;
    x += w; return r;
  }).join('');
  // A weft cross-band every repeat, in the lightest — this is what makes it
  // read as woven rather than as a printed stripe.
  const weft = `<rect x="0" y="26" width="60" height="3" fill="${rgba(lightest,.55)}"/>
                <rect x="0" y="47" width="60" height="1.4" fill="${rgba(darkest,.4)}"/>`;

  return `<svg viewBox="0 0 300 200" xmlns="http://www.w3.org/2000/svg" preserveAspectRatio="xMidYMid slice">
  <defs>
    <pattern id="${uid}-wv" width="60" height="60" patternUnits="userSpaceOnUse">${warp}${weft}</pattern>
    <linearGradient id="${uid}-fold" x1="0" y1="0" x2="1" y2="0">
      <stop offset="0%" stop-color="#000" stop-opacity=".22"/>
      <stop offset="18%" stop-color="#000" stop-opacity="0"/>
      <stop offset="82%" stop-color="#000" stop-opacity="0"/>
      <stop offset="100%" stop-color="#000" stop-opacity=".16"/>
    </linearGradient>
    <linearGradient id="${uid}-drape" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#fff" stop-opacity=".14"/>
      <stop offset="60%" stop-color="#000" stop-opacity="0"/>
      <stop offset="100%" stop-color="#000" stop-opacity=".2"/>
    </linearGradient>
  </defs>

  <rect width="300" height="200" fill="${ground}"/>
  <g stroke="${rgba('#8a8071',.16)}" stroke-width=".6">
    ${Array.from({length:14},(_,i)=>`<line x1="0" y1="${i*15}" x2="300" y2="${i*15}"/>`).join('')}
  </g>

  <!-- a length of cloth, folded back on itself -->
  <g>
    <rect x="26" y="30" width="150" height="150" fill="url(#${uid}-wv)"/>
    <rect x="26" y="30" width="150" height="150" fill="url(#${uid}-drape)"/>
    <rect x="26" y="30" width="150" height="150" fill="url(#${uid}-fold)"/>
    <path d="M176 30 L212 50 L212 200 L176 180 Z" fill="url(#${uid}-wv)"/>
    <path d="M176 30 L212 50 L212 200 L176 180 Z" fill="#000" opacity=".2"/>
    <rect x="26" y="30" width="150" height="4" fill="${rgba(darkest,.35)}"/>
  </g>

  <!-- a cushion in front, same cloth, turned 90° so warp reads as weft -->
  <g transform="translate(196,100)">
    <rect x="0" y="0" width="76" height="76" rx="5" fill="${mix(ground,'#000000',.14)}" opacity=".5"
          transform="translate(3,4)"/>
    <g transform="rotate(90 38 38)"><rect x="0" y="0" width="76" height="76" rx="5" fill="url(#${uid}-wv)"/></g>
    <rect x="0" y="0" width="76" height="76" rx="5" fill="url(#${uid}-drape)"/>
    <rect x="0" y="0" width="76" height="76" rx="5" fill="none"
          stroke="${rgba(darkest,.28)}" stroke-width="1.4"/>
  </g>
</svg>`;
}

module.exports = { cloth };
