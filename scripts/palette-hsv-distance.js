#!/usr/bin/env node
// Compare the IIgs 4-bit RGB approximations in src/rom/rom_color.s with a reference NES palette by
// pairwise colour distance, using two metrics:
//
//   HSV cone   - each colour is placed in the HSV cone, (s*v*cos h, s*v*sin h, v), and the distance is
//                Euclidean there.  This treats hue as an angle and ignores it for greys and dark
//                colours, where it is meaningless.  Values run from 0 to 2 (two fully saturated, full
//                value colours of opposite hues, e.g. pure red and pure cyan); black to white is 1.
//   CIEDE2000  - the CIE perceptual colour difference (dE00) in CIELAB, with the colours taken as sRGB
//                (D65).  About 1 is a just-noticeable difference; black to white is 100.
//
// For each metric, writes three grids to an HTML page (reference distances, IIgs distances, IIgs -
// reference) and prints a summary.  The illegal entries that rom_color.s maps to black ($xD-$xF,
// except $2D/$3D) are left out.
//
// usage: node scripts/palette-hsv-distance.js [out.html]

const fs = require('fs');
const path = require('path');

// Reference: the 2C02 palette from the NESdev wiki (PPU palettes page).
const NES_REF = [
  '626262','001FB2','2404C8','5200B2','730076','800024','730B00','522800','244400','005700','005C00','005324','003C76','000000','000000','000000',
  'ABABAB','0D57FF','4B30FF','8A13FF','BC08D6','D21269','C72E00','9D5400','607B00','209800','00A300','009942','007DB4','000000','000000','000000',
  'FFFFFF','53AEFF','9085FF','D365FF','FF57FF','FF5DCF','FF7757','FA9E00','BDC700','7AE700','43F611','26EF7E','2CD5F6','4E4E4E','000000','000000',
  'FFFFFF','B6E1FF','CED1FF','E9C3FF','FFBCFF','FFBDF4','FFC6C3','FFD59A','E9E681','CEF481','B6FB9A','A9FAC3','A9F0F4','B8B8B8','000000','000000',
];

const root = path.join(__dirname, '..');
const src = fs.readFileSync(path.join(root, 'src/rom/rom_color.s'), 'utf8');
const body = src.slice(src.indexOf('NES_ColorPalette'), src.indexOf('NES_ColorToIIgs\n'));
const iigs = [...body.matchAll(/dw\s+\$([0-9A-Fa-f]{4})/g)].map(m => parseInt(m[1], 16));
if (iigs.length !== 64) throw new Error(`expected 64 palette entries, found ${iigs.length}`);

const used = [];
for (let i = 0; i < 64; i++) {
  const lo = i & 15;
  if (lo >= 14 || (lo === 13 && i !== 0x2D && i !== 0x3D)) continue;
  used.push(i);
}

// ---- HSV cone

function rgbToHsv(r, g, b) {             // r, g, b in 0..1 -> h in radians, s, v in 0..1
  const max = Math.max(r, g, b), min = Math.min(r, g, b), d = max - min;
  let h = 0;
  if (d > 0) {
    if (max === r) h = ((g - b) / d) % 6;
    else if (max === g) h = (b - r) / d + 2;
    else h = (r - g) / d + 4;
    h *= Math.PI / 3;
    if (h < 0) h += 2 * Math.PI;
  }
  return { h, s: max === 0 ? 0 : d / max, v: max };
}
const cone = rgb => { const { h, s, v } = rgbToHsv(...rgb); return [s * v * Math.cos(h), s * v * Math.sin(h), v]; };
const coneDist = (a, b) => Math.hypot(a[0] - b[0], a[1] - b[1], a[2] - b[2]);

// ---- CIEDE2000

function rgbToLab(rgb) {                 // sRGB 0..1 -> CIELAB (D65)
  const [r, g, b] = rgb.map(c => (c <= 0.04045 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4));
  const x = (0.4124564 * r + 0.3575761 * g + 0.1804375 * b) / 0.95047;
  const y = 0.2126729 * r + 0.7151522 * g + 0.0721750 * b;
  const z = (0.0193339 * r + 0.1191920 * g + 0.9503041 * b) / 1.08883;
  const f = t => (t > 216 / 24389 ? Math.cbrt(t) : (24389 / 27 * t + 16) / 116);
  const fx = f(x), fy = f(y), fz = f(z);
  return [116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz)];
}

function ciede2000([L1, a1, b1], [L2, a2, b2]) {
  const rad = Math.PI / 180, p7 = c => c ** 7 / (c ** 7 + 25 ** 7);
  const G = 0.5 * (1 - Math.sqrt(p7((Math.hypot(a1, b1) + Math.hypot(a2, b2)) / 2)));
  const a1p = (1 + G) * a1, a2p = (1 + G) * a2;
  const C1 = Math.hypot(a1p, b1), C2 = Math.hypot(a2p, b2);
  const hue = (b, a) => { if (a === 0 && b === 0) return 0; const h = Math.atan2(b, a) / rad; return h < 0 ? h + 360 : h; };
  const h1 = hue(b1, a1p), h2 = hue(b2, a2p);
  let dh = 0;
  if (C1 * C2 !== 0) { dh = h2 - h1; if (dh > 180) dh -= 360; else if (dh < -180) dh += 360; }
  const dL = L2 - L1, dC = C2 - C1, dH = 2 * Math.sqrt(C1 * C2) * Math.sin(dh / 2 * rad);
  const Lb = (L1 + L2) / 2, Cb = (C1 + C2) / 2;
  let hb = h1 + h2;
  if (C1 * C2 !== 0) hb = Math.abs(h1 - h2) <= 180 ? hb / 2 : (hb < 360 ? (hb + 360) / 2 : (hb - 360) / 2);
  const T = 1 - 0.17 * Math.cos((hb - 30) * rad) + 0.24 * Math.cos(2 * hb * rad)
          + 0.32 * Math.cos((3 * hb + 6) * rad) - 0.20 * Math.cos((4 * hb - 63) * rad);
  const dTheta = 30 * Math.exp(-(((hb - 275) / 25) ** 2));
  const RT = -Math.sin(2 * dTheta * rad) * 2 * Math.sqrt(p7(Cb));
  const SL = 1 + 0.015 * (Lb - 50) ** 2 / Math.sqrt(20 + (Lb - 50) ** 2);
  const SC = 1 + 0.045 * Cb, SH = 1 + 0.015 * Cb * T;
  const l = dL / SL, c = dC / SC, h = dH / SH;
  return Math.sqrt(l * l + c * c + h * h + RT * c * h);
}

// Sharma, Wu & Dalal (2005) test data, pairs 1, 17 and 25
for (const [x, y, e] of [[[50, 2.6772, -79.7751], [50, 0, -82.7485], 2.0425],
                         [[50, 2.5, 0], [73, 25, -18], 27.1492],
                         [[60.2574, -34.0099, 36.2677], [60.4626, -34.1751, 39.4387], 1.2644]])
  if (Math.abs(ciede2000(x, y) - e) > 1e-4) throw new Error(`CIEDE2000 self-test failed: ${ciede2000(x, y)} != ${e}`);

// ---- distances

const refRgb = i => { const n = parseInt(NES_REF[i], 16); return [(n >> 16) / 255, ((n >> 8) & 255) / 255, (n & 255) / 255]; };
const gsRgb = i => [((iigs[i] >> 8) & 15) / 15, ((iigs[i] >> 4) & 15) / 15, (iigs[i] & 15) / 15];

const N = used.length;
const grid = f => Array.from({ length: N }, (_, a) => Array.from({ length: N }, (_, b) => f(a, b)));

const metrics = [
  { name: 'HSV cone distance', short: 'HSV', point: cone, dist: coneDist, scale: 100, digits: 3 },
  { name: 'CIEDE2000 (ΔE00)', short: 'dE00', point: rgbToLab, dist: ciede2000, scale: 1, digits: 1 },
].map(m => {
  const refP = used.map(i => m.point(refRgb(i))), gsP = used.map(i => m.point(gsRgb(i)));
  const dRef = grid((a, b) => m.dist(refP[a], refP[b]));
  const dGs = grid((a, b) => m.dist(gsP[a], gsP[b]));
  const dDev = grid((a, b) => dGs[a][b] - dRef[a][b]);
  const self = used.map((_, a) => m.dist(refP[a], gsP[a]));   // each colour against its own approximation
  const pairs = [];
  for (let a = 0; a < N; a++) for (let b = a + 1; b < N; b++) pairs.push([a, b, dDev[a][b]]);
  const abs = pairs.map(p => Math.abs(p[2]));
  const mean = abs.reduce((s, x) => s + x, 0) / abs.length;
  const rms = Math.sqrt(abs.reduce((s, x) => s + x * x, 0) / abs.length);
  const maxDev = Math.max(...abs);
  const maxD = Math.max(...dRef.flat(), ...dGs.flat());
  const rowDev = used.map((_, a) => dDev[a].reduce((s, x) => s + Math.abs(x), 0) / (N - 1));
  return { ...m, dRef, dGs, dDev, self, pairs, mean, rms, maxDev, maxD, rowDev };
});

// ---- summary

const hex2 = i => '$' + i.toString(16).toUpperCase().padStart(2, '0');
const gsHex = i => '$' + iigs[i].toString(16).toUpperCase().padStart(3, '0');
const f = (m, x) => x.toFixed(m.digits);
const sgn = (m, x) => (x >= 0 ? '+' : '') + f(m, x);

console.log(`Colours compared: ${N} (${N * (N - 1) / 2} pairs)`);
for (const m of metrics) {
  console.log(`\n=== ${m.name}`);
  console.log(`Deviation |IIgs - ref|: mean ${f(m, m.mean)}, rms ${f(m, m.rms)}, max ${f(m, m.maxDev)}`);
  console.log('Largest pair deviations:');
  for (const [a, b, d] of [...m.pairs].sort((p, q) => Math.abs(q[2]) - Math.abs(p[2])).slice(0, 12))
    console.log(`  ${hex2(used[a])}-${hex2(used[b])}  ref ${f(m, m.dRef[a][b])}  IIgs ${f(m, m.dGs[a][b])}  dev ${sgn(m, d)}`);
  console.log('Colours by mean |deviation| against all others (worst first), with own error:');
  for (const a of used.map((_, a) => a).sort((a, b) => m.rowDev[b] - m.rowDev[a]).slice(0, 12))
    console.log(`  ${hex2(used[a])}  ref #${NES_REF[used[a]]}  IIgs ${gsHex(used[a])}  mean dev ${f(m, m.rowDev[a])}  own error ${f(m, m.self[a])}`);
}

// How much the two metrics agree on which pairs are distorted (Pearson correlation of the deviations)
const [h, e] = metrics.map(m => m.pairs.map(p => p[2]));
const corr = (x, y) => {
  const mx = x.reduce((s, v) => s + v, 0) / x.length, my = y.reduce((s, v) => s + v, 0) / y.length;
  let sxy = 0, sxx = 0, syy = 0;
  for (let i = 0; i < x.length; i++) { sxy += (x[i] - mx) * (y[i] - my); sxx += (x[i] - mx) ** 2; syy += (y[i] - my) ** 2; }
  return sxy / Math.sqrt(sxx * syy);
};
const r = corr(h, e);
console.log(`\nCorrelation of the pair deviations, HSV vs dE00: ${r.toFixed(3)}`);

// ---- HTML

const css = rgb => `rgb(${rgb.map(c => Math.round(c * 255)).join(',')})`;
const heat = (x, max) => { const t = Math.min(1, x / max); return `hsl(${240 - 240 * t},70%,${85 - 35 * t}%)`; };
const div = (x, max) => { const t = Math.max(-1, Math.min(1, x / max));
  return t >= 0 ? `hsl(0,75%,${100 - 50 * t}%)` : `hsl(220,75%,${100 + 50 * t}%)`; };

function table(title, m, g, colour, sw) {
  let h = `<h3>${title}</h3><table><tr><th></th>`;
  for (const i of used) h += `<th class="c"><div class="sw" style="background:${css(sw(i))}"></div>${hex2(i).slice(1)}</th>`;
  h += '</tr>';
  for (let a = 0; a < N; a++) {
    h += `<tr><th class="r"><span class="sw" style="background:${css(sw(used[a]))}"></span>${hex2(used[a]).slice(1)}</th>`;
    for (let b = 0; b < N; b++) {
      const v = g[a][b];
      h += `<td style="background:${colour(v)}" title="${hex2(used[a])} - ${hex2(used[b])}: ${v.toFixed(3)}">${a === b ? '' : (v * m.scale).toFixed(0)}</td>`;
    }
    h += '</tr>';
  }
  return h + '</table>';
}

function ranking(m, n) {
  const order = used.map((_, a) => a).sort((a, b) => m.rowDev[b] - m.rowDev[a]);
  let rows = '';
  for (const a of order)
    rows += `<tr><td>${hex2(used[a])}</td><td><span class="sw" style="background:${css(refRgb(used[a]))}"></span> #${NES_REF[used[a]]}</td>` +
      `<td><span class="sw" style="background:${css(gsRgb(used[a]))}"></span> ${gsHex(used[a])}</td>` +
      `<td style="background:${heat(m.rowDev[a], m.maxDev / 2)}">${f(m, m.rowDev[a])}</td>` +
      `<td style="background:${heat(m.self[a], m.maxDev)}">${f(m, m.self[a])}</td></tr>`;
  return `<h3>${n}d. Worst colours (mean |deviation| against all others)</h3>
<table class="self"><tr><th>NES</th><th>Reference</th><th>IIgs</th><th>mean |dev|</th><th>own error</th></tr>${rows}</table>`;
}

function section(m, n) {
  const unit = m.scale === 1 ? '' : ` &times; ${m.scale}`;
  return `<h2>${n}. ${m.name}</h2>
<p>Cells show the distance${unit}; hover for exact values. Deviation |IIgs &minus; ref|: mean ${f(m, m.mean)},
rms ${f(m, m.rms)}, max ${f(m, m.maxDev)}.</p>
${table(`${n}a. Reference NES palette`, m, m.dRef, v => heat(v, m.maxD), refRgb)}
${table(`${n}b. IIgs palette (rom_color.s)`, m, m.dGs, v => heat(v, m.maxD), gsRgb)}
${table(`${n}c. Deviation: IIgs distance − reference distance`, m, m.dDev, v => div(v, m.maxDev), refRgb)}
${ranking(m, n)}`;
}

const html = `<!doctype html><meta charset="utf-8"><title>NES vs IIgs palette colour distances</title>
<style>
body{font-family:sans-serif;font-size:13px;background:#fff}
table{border-collapse:collapse;margin-bottom:24px}
td{width:17px;height:17px;font-size:8px;text-align:center;padding:0;border:1px solid #fff;color:#222}
th{font-size:8px;font-weight:normal;padding:1px}
th.c{vertical-align:bottom}
.sw{display:inline-block;width:12px;height:12px;border:1px solid #888;vertical-align:middle}
th.c .sw{display:block;margin:0 auto 1px}
table.self td,table.self th{width:auto;font-size:12px;padding:2px 8px;text-align:left}
</style>
<h1>NES reference palette vs rom_color.s (IIgs 4-bit RGB)</h1>
<p>Reference: NESdev wiki 2C02 palette. ${N} colours (the illegal blacks are left out).
HSV cone: Euclidean distance in (s·v·cos h, s·v·sin h, v), 0-2. CIEDE2000: perceptual difference in CIELAB
(colours taken as sRGB, D65); ~1 is just noticeable, black-white is 100.
In the deviation grids red = the IIgs pair is farther apart than on the NES, blue = closer (less distinguishable).
Correlation of the pair deviations between the two metrics: ${r.toFixed(3)}.</p>
${metrics.map((m, i) => section(m, i + 1)).join('\n')}
`;
const out = process.argv[2] || path.join(root, 'docs/palette-hsv-distance.html');
fs.writeFileSync(out, html);
console.log(`\nWrote ${out}`);
