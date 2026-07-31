#!/usr/bin/env node
// Fetches xkcd color survey data, computes CIELAB for each color,
// and writes dist/xkcd-colors-lab.json as a compact array of arrays:
// [name, hex, L, a, b]   (Lab rounded to 1 decimal)
//
// Usage:  node build-xkcd-colors.js

const https = require('https');
const fs    = require('fs');
const path  = require('path');

// sRGB hex → CIELAB (D65 illuminant, CIE 1931 2°)
function hexToLab(hex) {
  const r = parseInt(hex.slice(1,3), 16) / 255;
  const g = parseInt(hex.slice(3,5), 16) / 255;
  const b = parseInt(hex.slice(5,7), 16) / 255;

  // sRGB linearise
  const lin = v => v <= 0.04045 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4);
  const rl = lin(r), gl = lin(g), bl = lin(b);

  // Linear sRGB → CIE XYZ (D65), normalised to white point
  const X = (rl*0.4124564 + gl*0.3575761 + bl*0.1804375) / 0.95047;
  const Y = (rl*0.2126729 + gl*0.7151522 + bl*0.0721750) / 1.00000;
  const Z = (rl*0.0193339 + gl*0.1191920 + bl*0.9503041) / 1.08883;

  // XYZ → Lab
  const f = t => t > 0.008856 ? Math.cbrt(t) : 7.787 * t + 16 / 116;
  const L  = +(116 * f(Y) - 16).toFixed(1);
  const a  = +(500 * (f(X) - f(Y))).toFixed(1);
  const bv = +(200 * (f(Y) - f(Z))).toFixed(1);

  return [L, a, bv];
}

const RGB_URL = 'https://xkcd.com/color/rgb.txt';

console.log(`Fetching ${RGB_URL} …`);

https.get(RGB_URL, res => {
  if (res.statusCode !== 200) {
    console.error(`HTTP ${res.statusCode}`);
    process.exit(1);
  }

  let raw = '';
  res.on('data', chunk => raw += chunk);
  res.on('end', () => {
    const lines = raw.split('\n').filter(l => l.trim() && !l.startsWith('#'));

    const colors = [];
    for (const line of lines) {
      const parts = line.split('\t');
      if (parts.length < 2) continue;
      const name = parts[0].trim();
      const hex  = parts[1].trim();
      if (!/^#[0-9a-fA-F]{6}$/.test(hex)) continue;
      const [L, a, b] = hexToLab(hex);
      colors.push([name, hex, L, a, b]);
    }

    const outPath = path.join(__dirname, 'dist', 'xkcd-colors-lab.json');
    fs.writeFileSync(outPath, JSON.stringify(colors));
    console.log(`✓ Wrote ${colors.length} colors → ${outPath}`);
    console.log(`  File size: ${(fs.statSync(outPath).size / 1024).toFixed(1)} KB`);

    // Quick spot-check
    const gold = colors.find(c => c[0] === 'gold');
    if (gold) console.log(`  Spot-check "gold": ${JSON.stringify(gold)}`);
  });
}).on('error', err => {
  console.error('Fetch error:', err.message);
  process.exit(1);
});
