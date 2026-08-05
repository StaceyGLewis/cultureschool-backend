/* Palette CONSTRUCTION — keep the soul, derive the structure.
   Extraction samples whatever the photograph happened to contain. Construction
   keeps the colours that carry the identity and derives the missing structural
   roles from their own hues, so the result belongs to the same world instead of
   having neutrals imported into it.

   Nothing here is generative. Every output colour is a stated transform of a
   source hue, so the derivation can be written down and audited. */
const { lab, gamut, cmyk } = require('./color.js');

/* Lab -> sRGB hex, reducing chroma until the colour is representable.
   `printable` additionally holds it inside the CMYK boundary, so a constructed
   palette can never contain a colour the press cannot hit. */
function lch2hex(L, C, h, printable = true) {
  const rad = h * Math.PI / 180;
  for (let c = C; c >= 0; c -= 0.5) {
    const a = c * Math.cos(rad), b = c * Math.sin(rad);
    const fy = (L + 16) / 116, fx = fy + a / 500, fz = fy - b / 200;
    const inv = t => t*t*t > 0.008856 ? t*t*t : (t - 16/116) / 7.787;
    const X = 0.95047 * inv(fx), Y = 1.0 * inv(fy), Z = 1.08883 * inv(fz);
    let R =  3.2404542*X - 1.5371385*Y - 0.4985314*Z;
    let G = -0.9692660*X + 1.8760108*Y + 0.0415560*Z;
    let B =  0.0556434*X - 0.2040259*Y + 1.0572252*Z;
    const enc = v => v <= 0.0031308 ? 12.92*v : 1.055*Math.pow(v, 1/2.4) - 0.055;
    R = enc(R); G = enc(G); B = enc(B);
    if (R < -0.001 || G < -0.001 || B < -0.001 || R > 1.001 || G > 1.001 || B > 1.001) continue;
    const hex = '#' + [R,G,B].map(v =>
      Math.round(Math.min(1, Math.max(0, v)) * 255).toString(16).padStart(2,'0')).join('');
    if (printable && !gamut(hex).inGamut) continue;
    return hex;
  }
  return '#808080';
}

const hueGap = (a, b) => { const d = Math.abs(a - b) % 360; return d > 180 ? 360 - d : d; };

/* Pull the signature colours back inside the printable boundary without
   moving their hue — the identity is the hue, not the excess saturation. */
function makePrintable(hex) {
  const g = gamut(hex);
  if (g.inGamut) return { hex, adjusted: false };
  const l = lab(hex);
  return { hex: lch2hex(l.L, g.maxC, l.h), adjusted: true };
}

function construct(colors) {
  const c = colors
    .filter(h => /^#[0-9a-fA-F]{6}$/.test(h))
    .map(h => ({ hex: h, ...lab(h) }));

  /* Signatures must actually carry colour — on a near-achromatic source the
     "loudest" swatch can be black, which is a ground, not a signature. */
  const chromatic = c.filter(x => x.C > 12);
  const byC  = (chromatic.length ? chromatic : c).sort((a,b) => b.C - a.C);
  const sig1 = byC[0];
  const sig2 = byC.find(x => hueGap(x.h, sig1.h) > 35) || byC[1] || sig1;

  const p1 = makePrintable(sig1.hex);
  const p2 = makePrintable(sig2.hex);

  /* Structure is derived from the SOURCE's own character, not from constants.
     Fixed targets made every constructed palette share one skeleton — 56
     palettes with identical bones read as machine-made. A dark, moody source
     should stay dark and moody; a pale one should stay airy. The clamps
     guarantee viability (light ≥84, ground ≤34, so spread ≥50) while the
     position inside those bounds comes from the photograph. */
  const clamp = (v, lo, hi) => Math.min(hi, Math.max(lo, v));
  const Ls    = c.map(x => x.L).sort((a,b) => a - b);
  const Cs    = c.map(x => x.C).sort((a,b) => a - b);
  const medL  = Ls[Math.floor(Ls.length/2)];
  const medC  = Cs[Math.floor(Cs.length/2)];

  const lightL  = clamp(Math.round(Ls[Ls.length-1] + 8), 84, 95);
  const groundL = clamp(Math.round(Ls[0] - 10),          11, 34);
  const midL    = clamp(Math.round(medL),                44, 62);
  const midC    = clamp(Math.round(medC * 0.55),         14, 38);
  const lightC  = clamp(Math.round(medC * 0.12),          3, 11);
  const groundC = clamp(Math.round(medC * 0.30),          8, 26);

  const light  = lch2hex(lightL,  lightC,  sig2.h);   // plaster, warmed by sig2
  const mid    = lch2hex(midL,    midC,    sig2.h);   // the 30% — recedes
  const ground = lch2hex(groundL, groundC, sig1.h);   // depth, carrying sig1's hue

  const out = [light, p1.hex, mid, p2.hex, ground];
  return {
    colors: out,
    derivation: [
      { hex: light,  role: 'Light anchor', how: `L*${lightL} C${lightC} at ${Math.round(sig2.h)}° — lifted from this palette's own lightest tone` },
      { hex: p1.hex, role: 'Signature',    how: p1.adjusted
          ? `kept from ${sig1.hex}, chroma pulled to the CMYK boundary` : `kept from source` },
      { hex: mid,    role: 'Secondary',    how: `L*${midL} C${midC} at ${Math.round(sig2.h)}° — set at the source's median lightness so it recedes` },
      { hex: p2.hex, role: 'Signature',    how: p2.adjusted
          ? `kept from ${sig2.hex}, chroma pulled to the CMYK boundary` : `kept from source` },
      { hex: ground, role: 'Ground',       how: `L*${groundL} C${groundC} at ${Math.round(sig1.h)}° — dropped below this palette's own darkest tone` },
    ],
  };
}

module.exports = { construct, lch2hex };

if (require.main === module) {
  const { analyse } = require('./viable.js');
  const p = require('/tmp/ff.json')[0];
  const before = analyse(p.colors);
  const built  = construct(p.colors);
  const after  = analyse(built.colors);

  const show = (label, cols, v) => {
    console.log('\n' + label);
    cols.forEach(h => { const l = lab(h), g = gamut(h);
      console.log('  ' + h.padEnd(9) + 'L*' + l.L.toFixed(0).padStart(3) +
        '  C*' + l.C.toFixed(0).padStart(3) + '  h' + String(Math.round(l.h)).padStart(4) +
        '   ' + (g.inGamut ? 'printable' : 'OUT'));
    });
    console.log('  spread ' + Math.round(v.spread) +
      ' | light ' + v.counts.light + ' | dark ' + v.counts.dark + ' | loud ' + v.counts.loud +
      '  →  ' + (v.ok ? 'ROOM-VIABLE' : 'NOT VIABLE'));
    v.issues.forEach(i => console.log('    ✕ ' + i));
  };

  show('BEFORE — ' + p.name.trim(), p.colors, before);
  show('AFTER  — constructed', built.colors, after);
  console.log('\nderivation:');
  built.derivation.forEach(d => console.log('  ' + d.hex + '  ' + d.role.padEnd(13) + d.how));
}
