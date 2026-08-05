/* A room built from the 60/30/10 assignment, not from luminance guesswork.
   Each palette role drives a specific surface, so the render is an argument
   about how to use the palette — not decoration. */
const { lab } = require('./color.js');

const rgba = (h, a) => {
  const r = parseInt(h.slice(1,3),16), g = parseInt(h.slice(3,5),16), b = parseInt(h.slice(5,7),16);
  return `rgba(${r},${g},${b},${a})`;
};
const mix = (h1, h2, t) => {
  const p = h => [parseInt(h.slice(1,3),16),parseInt(h.slice(3,5),16),parseInt(h.slice(5,7),16)];
  const [a,b] = [p(h1),p(h2)];
  return '#' + a.map((v,i)=>Math.round(v+(b[i]-v)*t).toString(16).padStart(2,'0')).join('');
};

function room(scheme, all) {
  const uid = "r" + [scheme.dominant,scheme.accent,scheme.ground].join("").replace(/[^0-9a-f]/gi,"").slice(0,10);
  const { dominant: wall, secondary: sofa, accent, ground: floor } = scheme;
  const lightest = [...all].sort((a,b) => lab(b).L - lab(a).L)[0];
  const ceiling  = mix(wall, '#ffffff', 0.45);
  const trim     = mix(wall, '#ffffff', 0.7);
  const onWall   = lab(wall).L > 55 ? '#00000018' : '#ffffff18';

  return `<svg viewBox="0 0 300 200" xmlns="http://www.w3.org/2000/svg" preserveAspectRatio="xMidYMid slice">
  <defs>
    <linearGradient id="${uid}-lit" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0%" stop-color="#ffffff" stop-opacity=".16"/>
      <stop offset="55%" stop-color="#ffffff" stop-opacity="0"/>
    </linearGradient>
    <linearGradient id="${uid}-flr" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#000000" stop-opacity=".22"/>
      <stop offset="100%" stop-color="#000000" stop-opacity="0"/>
    </linearGradient>
  </defs>

  <rect width="300" height="200" fill="${wall}"/>
  <rect width="300" height="16" fill="${ceiling}"/>
  <rect y="16" width="300" height="3" fill="${rgba(trim,.55)}"/>

  <!-- window, and the light it throws -->
  <rect x="22" y="34" width="62" height="80" rx="1" fill="${rgba(lightest,.55)}" stroke="${rgba(trim,.9)}" stroke-width="2.5"/>
  <line x1="53" y1="34" x2="53" y2="114" stroke="${rgba(trim,.9)}" stroke-width="1.6"/>
  <line x1="22" y1="74" x2="84" y2="74" stroke="${rgba(trim,.9)}" stroke-width="1.6"/>
  <polygon points="84,36 190,86 84,114" fill="url(#${uid}-lit)"/>

  <!-- art, in the accent -->
  <rect x="188" y="30" width="74" height="54" rx="1" fill="${rgba(trim,.85)}"/>
  <rect x="193" y="35" width="64" height="44" fill="${accent}"/>
  <rect x="201" y="46" width="34" height="5" fill="${rgba(lightest,.8)}"/>
  <rect x="201" y="56" width="22" height="4" fill="${rgba(lightest,.5)}"/>

  <!-- floor -->
  <rect y="138" width="300" height="62" fill="${floor}"/>
  <rect y="138" width="300" height="20" fill="url(#${uid}-flr)"/>
  <rect y="134" width="300" height="5" fill="${rgba(trim,.35)}"/>
  <g stroke="${rgba(lightest,.10)}" stroke-width="1">
    <line x1="0" y1="152" x2="300" y2="152"/><line x1="0" y1="168" x2="300" y2="168"/>
    <line x1="0" y1="184" x2="300" y2="184"/>
  </g>
  <ellipse cx="150" cy="176" rx="118" ry="19" fill="${rgba(accent,.24)}"/>

  <!-- sofa: the secondary, carrying the 30% -->
  <rect x="46" y="100" width="208" height="20" rx="7" fill="${mix(sofa,'#000000',.12)}"/>
  <rect x="38" y="104" width="20" height="46" rx="7" fill="${mix(sofa,'#000000',.06)}"/>
  <rect x="242" y="104" width="20" height="46" rx="7" fill="${mix(sofa,'#000000',.06)}"/>
  <rect x="46" y="116" width="208" height="34" rx="4" fill="${sofa}"/>
  <rect x="46" y="116" width="208" height="6" fill="${rgba('#ffffff',.10)}"/>
  <rect x="60"  y="120" width="52" height="26" rx="5" fill="${accent}"/>
  <rect x="124" y="120" width="52" height="26" rx="5" fill="${mix(accent,lightest,.42)}"/>
  <rect x="188" y="120" width="52" height="26" rx="5" fill="${accent}"/>
  <rect x="56" y="148" width="9" height="9" rx="2" fill="${rgba(floor,.85)}"/>
  <rect x="236" y="148" width="9" height="9" rx="2" fill="${rgba(floor,.85)}"/>

  <!-- low table -->
  <rect x="104" y="152" width="94" height="11" rx="3" fill="${mix(floor,lightest,.28)}"/>
  <rect x="114" y="162" width="7" height="12" fill="${rgba(floor,.9)}"/>
  <rect x="181" y="162" width="7" height="12" fill="${rgba(floor,.9)}"/>
  <ellipse cx="134" cy="150" rx="10" ry="4" fill="${rgba(lightest,.85)}"/>
  <circle cx="168" cy="149" r="5" fill="${accent}"/>

  <!-- plant -->
  <g transform="translate(276,112)">
    <ellipse cx="0" cy="-6" rx="13" ry="16" fill="${mix(accent,'#2f5d34',.62)}"/>
    <ellipse cx="-9" cy="-14" rx="8" ry="11" fill="${mix(accent,'#2f5d34',.5)}"/>
    <ellipse cx="9" cy="-13" rx="7" ry="10" fill="${mix(accent,'#2f5d34',.72)}"/>
    <path d="M-9 8 L9 8 L7 30 L-7 30 Z" fill="${mix(sofa,floor,.4)}"/>
  </g>
  <rect width="300" height="200" fill="${onWall}" opacity="0"/>
</svg>`;
}

module.exports = { room };
