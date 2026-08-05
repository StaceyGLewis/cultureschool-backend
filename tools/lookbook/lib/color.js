/* Colour maths for the palette card.
   Two jobs: give a designer the CMYK spec, and tell them honestly when a
   colour cannot be reproduced in CMYK at all. */

const hex2rgb = h => {
  h = h.replace('#', '');
  if (h.length === 3) h = h.split('').map(c => c + c).join('');
  return [parseInt(h.slice(0,2),16), parseInt(h.slice(2,4),16), parseInt(h.slice(4,6),16)];
};

/* Naive CMYK — the number a designer types into a spec field. The printer's
   RIP does the real ICC conversion; this is the reference, not the output. */
function cmyk(hex) {
  const [R,G,B] = hex2rgb(hex).map(v => v/255);
  const k = 1 - Math.max(R,G,B);
  if (k === 1) return [0,0,0,100];
  return [
    Math.round((1-R-k)/(1-k)*100),
    Math.round((1-G-k)/(1-k)*100),
    Math.round((1-B-k)/(1-k)*100),
    Math.round(k*100),
  ];
}

/* sRGB -> CIELAB (D65) */
function lab(hex) {
  let [R,G,B] = hex2rgb(hex).map(v => v/255);
  const lin = c => c <= 0.04045 ? c/12.92 : Math.pow((c+0.055)/1.055, 2.4);
  R = lin(R); G = lin(G); B = lin(B);
  let X = R*0.4124564 + G*0.3575761 + B*0.1804375;
  let Y = R*0.2126729 + G*0.7151522 + B*0.0721750;
  let Z = R*0.0193339 + G*0.1191920 + B*0.9503041;
  X /= 0.95047; Y /= 1.0; Z /= 1.08883;
  const f = t => t > 0.008856 ? Math.cbrt(t) : (7.787*t + 16/116);
  const fx = f(X), fy = f(Y), fz = f(Z);
  const L = 116*fy - 16, a = 500*(fx-fy), b = 200*(fy-fz);
  return { L, a, b, C: Math.hypot(a,b), h: (Math.atan2(b,a)*180/Math.PI + 360) % 360 };
}

/* Approximate SWOP-coated gamut: maximum achievable chroma by hue angle.
   Yellow is the widest hue in CMYK; cyan and green are the narrowest. These
   are ballpark boundary values — enough to flag a colour as unprintable, not
   a substitute for a proofed ICC conversion. */
/* Calibrated to the six vertices of the SWOP-coated solid — the three process
   inks and their two-ink overprints, in Lab:
     yellow  L89 C93 h93     red   (M+Y) L48 C83 h35
     magenta L48 C74 h358    green (C+Y) L50 C70 h157
     cyan    L55 C62 h233    blue  (C+M) L25 C50 h294
   Anything at or under these is printable; the earlier numbers were low
   enough to reject the inks themselves, which the control test caught. */
const SWOP_MAX_C = {
  0:74, 30:82, 60:88, 90:93, 120:80, 150:70,
  180:64, 210:62, 240:60, 270:54, 300:50, 330:62, 360:74,
};
/* Each hue reaches its maximum chroma at a DIFFERENT lightness — that is the
   physics of the inks, not a detail. Process yellow is most saturated when it
   is bright (L*~88); process blue is most saturated when it is dark (L*~42).
   Modelling one dome for every hue wrongly rejects yellow and wrongly passes
   light blues, which are the two colours print buyers get caught by most. */
const SWOP_PEAK_L = {
  0:48, 30:48, 60:65, 90:89, 120:75, 150:50,
  180:52, 210:54, 240:55, 270:40, 300:25, 330:36, 360:48,
};
const lerpHue = (table, h) => {
  const lo = Math.floor(h/30)*30, hi = lo + 30, t = (h - lo)/30;
  return table[lo]*(1-t) + table[hi]*t;
};
function maxChroma(h, L) {
  const base   = lerpHue(SWOP_MAX_C, h);
  const peakL  = lerpHue(SWOP_PEAK_L, h);
  // Gentle falloff — the gamut solid is a broad blob, and too steep a dome
  // wrongly rejects pale tints, which are always printable.
  const dome   = Math.max(0.18, 1 - 0.55 * Math.pow((L - peakL)/58, 2));
  return base * dome;
}

function gamut(hex) {
  const { L, C, h } = lab(hex);
  const max = maxChroma(h, L);
  const over = C - max;
  return {
    inGamut: over <= 0,
    // How far outside, as a percentage of the boundary — drives the wording.
    excess: max > 0 ? over / max : 0,
    C: +C.toFixed(1), maxC: +max.toFixed(1), L: +L.toFixed(1), h: +h.toFixed(0),
  };
}

module.exports = { cmyk, lab, gamut, hex2rgb };

if (require.main === module) {
  const tests = [
    ['#8a0f42','Joy dark'],['#FF218C','Joy pink'],['#FFD800','Joy yellow'],
    ['#21B1FF','Joy blue'],['#bce8ff','Joy pale'],
    ['#1b3a4b','TS navy'],['#73D7EE','TS light blue'],['#FFFFFF','TS white'],
    ['#FFAFC8','TS pink'],['#fce8f0','TS pale'],
    ['#8C2D2D','Persian deep'],['#C94C4C','Persian rust'],['#E6A3A3','Persian blush'],
    ['#F4D9D9','Persian pale'],['#4A1F1F','Persian dark'],
  ];
  console.log('hex      label            CMYK              L*   C*   max  verdict');
  console.log('─'.repeat(78));
  tests.forEach(([hex,label]) => {
    const c = cmyk(hex), g = gamut(hex);
    const verdict = g.inGamut ? 'ok'
      : g.excess > 0.25 ? 'OUT (far)' : 'OUT (near edge)';
    console.log(
      hex.padEnd(9) + label.padEnd(17) +
      (c.join('/')+'').padEnd(18) +
      String(g.L).padStart(4) + String(g.C).padStart(6) +
      String(g.maxC).padStart(6) + '  ' + verdict
    );
  });
}
