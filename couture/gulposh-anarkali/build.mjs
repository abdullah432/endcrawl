// Gulposh Anarkali — embroidery design generator.
// Every motif is drawn in millimetres (1 SVG unit = 1 mm) so the exported
// SVGs print at 1:1 for khaka (pounce-pattern) tracing.
// Run: node build.mjs  → writes index.html and svg/*.svg next to this file.
import { writeFileSync, mkdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const r2 = (n) => Math.round(n * 100) / 100;

// ---------------------------------------------------------------- palette
const C = {
  ground: '#F6F0E3',
  blush: '#EBC1BB', blushDeep: '#DCA39E', blushLight: '#F3D8D2',
  sage: '#B4C3A4', sageDeep: '#93A587', sageLight: '#D5DDC8',
  aqua: '#C2DAD6',
  goldDark: '#9C7A3A',
  voidFill: '#ECE5D7',
};

// ---------------------------------------------------------------- tally
let tally = { moti: 0, sitara: 0 };
const resetTally = () => { tally = { moti: 0, sitara: 0 }; };

// ---------------------------------------------------------------- affine
function T(tx = 0, ty = 0, s = 1, deg = 0, mx = 1) {
  const r = (deg * Math.PI) / 180;
  const co = Math.cos(r) * s, si = Math.sin(r) * s;
  return { a: co * mx, b: si * mx, c: -si, d: co, e: tx, f: ty, s };
}
const ap = (t, x, y) => [t.a * x + t.c * y + t.e, t.b * x + t.d * y + t.f];
const I = T();
const parse = (s) => s.match(/[MLCQZ]|-?\d*\.?\d+/g).map((v) => (/[A-Z]/.test(v) ? v : +v));
function pd(cmds, t = I) {
  let out = '', i = 0;
  while (i < cmds.length) {
    const k = cmds[i++];
    const n = { M: 1, L: 1, C: 3, Q: 2, Z: 0 }[k];
    const pts = [];
    for (let j = 0; j < n; j++) {
      const [x, y] = ap(t, cmds[i], cmds[i + 1]);
      i += 2;
      pts.push(r2(x) + ',' + r2(y));
    }
    out += k + pts.join(' ') + ' ';
  }
  return out.trim();
}
const sw = (w, s) => r2(w * Math.max(0.5, Math.sqrt(s)));

// ---------------------------------------------------------------- geometry helpers
const cub = (p0, p1, p2, p3, t) => {
  const u = 1 - t;
  return [0, 1].map((k) => u * u * u * p0[k] + 3 * u * u * t * p1[k] + 3 * u * t * t * p2[k] + t * t * t * p3[k]);
};
const sampleCubic = (p0, p1, p2, p3, n = 160) => Array.from({ length: n + 1 }, (_, i) => cub(p0, p1, p2, p3, i / n));
const dist = (a, b) => Math.hypot(a[0] - b[0], a[1] - b[1]);
function cumLen(pts) {
  const L = [0];
  for (let i = 1; i < pts.length; i++) L.push(L[i - 1] + dist(pts[i - 1], pts[i]));
  return L;
}
function atLen(pts, L, s) {
  let i = 1;
  while (i < L.length - 1 && L[i] < s) i++;
  const seg = L[i] - L[i - 1] || 1, k = (s - L[i - 1]) / seg;
  const p = [pts[i - 1][0] + (pts[i][0] - pts[i - 1][0]) * k, pts[i - 1][1] + (pts[i][1] - pts[i - 1][1]) * k];
  const ang = Math.atan2(pts[i][1] - pts[i - 1][1], pts[i][0] - pts[i - 1][0]);
  return { p, ang };
}
function evenly(pts, n) { // n+1 points including both ends
  const L = cumLen(pts), tot = L[L.length - 1];
  return Array.from({ length: n + 1 }, (_, i) => atLen(pts, L, (tot * i) / n).p);
}
function spaced(pts, gap, inset = gap / 2) {
  const L = cumLen(pts), tot = L[L.length - 1];
  const n = Math.max(1, Math.floor((tot - 2 * inset) / gap));
  const real = (tot - 2 * inset) / n;
  return Array.from({ length: n + 1 }, (_, i) => atLen(pts, L, inset + i * real).p);
}
const poly = (pts) => 'M' + pts.map((p) => r2(p[0]) + ',' + r2(p[1])).join(' L');
function cuspPath(pts, bulge = 0.62) {
  let d = `M${r2(pts[0][0])},${r2(pts[0][1])}`;
  for (let i = 1; i < pts.length; i++) {
    const r = r2(dist(pts[i - 1], pts[i]) * bulge);
    d += ` A${r} ${r} 0 0 1 ${r2(pts[i][0])},${r2(pts[i][1])}`;
  }
  return d;
}
const rectD = (x1, y1, x2, y2) => `M${x1},${y1} L${x2},${y1} L${x2},${y2} L${x1},${y2} Z`;

// seeded RNG for the raw-silk slub texture
function rng(seed) { return () => ((seed = (seed * 16807) % 2147483647) - 1) / 2147483646; }

// ---------------------------------------------------------------- stitch primitives
// Dabka: coiled metal wire couched along a line. Base stroke + coil highlights (fx).
const dabka = (d, w = 1.2) =>
  `<path d="${d}" fill="none" stroke="url(#gGold)" stroke-width="${w}" stroke-linecap="round" stroke-linejoin="round"/>` +
  `<path class="fx" d="${d}" fill="none" stroke="#FFF7DF" stroke-opacity=".75" stroke-width="${r2(w * 0.45)}" stroke-dasharray="0.3 ${r2(Math.max(0.6, w * 0.7))}" stroke-linecap="round"/>`;
// Fine gold line (salma / nakshi thread line)
const goldLine = (d, w = 0.5) => `<path d="${d}" fill="none" stroke="${C.goldDark}" stroke-width="${w}" stroke-linecap="round"/>`;
// Resham: pastel silk long-and-short fill.
const resham = (d, fill, pat = 'pThread') => `<path d="${d}" fill="${fill}"/><path class="fx" d="${d}" fill="url(#${pat})"/>`;
// Nakshi: bright coil packed as a solid metal fill.
const nakshi = (d) => `<path d="${d}" fill="url(#gGold)"/><path class="fx" d="${d}" fill="url(#pCoil)"/>`;
function pearl(x, y, r = 1.4) {
  tally.moti++;
  return `<circle cx="${r2(x)}" cy="${r2(y)}" r="${r}" fill="url(#gPearl)" stroke="#C9BBA1" stroke-width=".2"/>` +
    `<circle class="fx" cx="${r2(x - r * 0.35)}" cy="${r2(y - r * 0.35)}" r="${r2(r * 0.3)}" fill="#fff"/>`;
}
function sitara(x, y, r = 1.15) {
  tally.sitara++;
  return `<circle cx="${r2(x)}" cy="${r2(y)}" r="${r}" fill="url(#gRose)" stroke="#A47B68" stroke-width=".15"/>` +
    `<circle class="fx" cx="${r2(x)}" cy="${r2(y)}" r="${r2(r * 0.26)}" fill="#7E5E4E" fill-opacity=".55"/>`;
}

// ---------------------------------------------------------------- unit motifs
const U = {
  poppyBack: parse('M0,14 C-11,4 -10,-15 0,-22 C10,-15 11,4 0,14 Z'),
  poppyLeft: parse('M0,16 C-9,15 -21,7 -20,-6 C-19.5,-13 -14,-17 -10,-15 C-12,-6 -8,6 0,16 Z'),
  poppyCalyx: parse('M-7,13 C-6,20 -2,22 0,22 C2,22 6,20 7,13 C3,15.5 -3,15.5 -7,13 Z'),
  poppyVein: parse('M-3,12 C-8,6 -12,-2 -14,-9'),
  bud: parse('M0,-9 C5,-4 5,4 0,7 C-5,4 -5,-4 0,-9 Z'),
  budCalyx: parse('M-4,3 C-3,8.5 3,8.5 4,3 C1,5 -1,5 -4,3 Z'),
  leaf: parse('M0,0 C-9,-6 -10,-20 -2,-30 C6,-22 9,-8 0,0 Z'),
  leafRib: parse('M0,-1.5 C-1.5,-10 -2,-20 -2,-27'),
  cypress: parse('M0,0 C-13,-22 -12,-68 1,-100 C2.5,-103 7,-102 5,-97 C12,-68 13,-22 0,0 Z'),
  mound: parse('M-30,0 C-26,-6 -20,-8 -15,-6 C-12,-12 -4,-13 0,-9 C4,-13 12,-12 15,-6 C20,-8 26,-6 30,0 Z'),
  petal8: parse('M0,0 C-3,-3 -2.6,-7 0,-8 C2.6,-7 3,-3 0,0 Z'),
  petal5: parse('M0,0 C-3.8,-2 -3.6,-7 0,-8 C3.6,-7 3.8,-2 0,0 Z'),
};
const MX = { a: -1, b: 0, c: 0, d: 1, e: 0, f: 0, s: 1 };
const compose = (A, B) => ({
  a: A.a * B.a + A.c * B.b, b: A.b * B.a + A.d * B.b,
  c: A.a * B.c + A.c * B.d, d: A.b * B.c + A.d * B.d,
  e: A.a * B.e + A.c * B.f + A.e, f: A.b * B.e + A.d * B.f + A.f, s: A.s * B.s,
});

function poppy(t) {
  const s = t.s, M = compose(t, MX);
  const back = pd(U.poppyBack, t), L = pd(U.poppyLeft, t), R = pd(U.poppyLeft, M);
  let o = resham(back, C.blushDeep, 'pThreadB') + dabka(back, sw(0.9, s));
  for (const tip of [[-4, -8], [0, -13], [4, -8]]) {
    o += goldLine(pd(parse(`M0,10 L${tip[0]},${tip[1]}`), t), sw(0.4, s));
  }
  for (const tip of [[-4, -8], [0, -13], [4, -8]]) { const [x, y] = ap(t, ...tip); o += sitara(x, y, sw(0.95, s)); }
  o += resham(L, C.blush) + resham(R, C.blush, 'pThreadB');
  o += goldLine(pd(U.poppyVein, t), sw(0.35, s)) + goldLine(pd(U.poppyVein, M), sw(0.35, s));
  o += dabka(L, sw(1, s)) + dabka(R, sw(1, s));
  o += nakshi(pd(U.poppyCalyx, t));
  return o;
}
function bud(t, fill = C.blush) {
  const d = pd(U.bud, t);
  return resham(d, fill) + dabka(d, sw(0.9, t.s)) + nakshi(pd(U.budCalyx, t));
}
function leaf(t) {
  const d = pd(U.leaf, t);
  return resham(d, C.sage) + goldLine(pd(U.leafRib, t), sw(0.45, t.s)) + dabka(d, sw(0.85, t.s));
}
function rosette(cx, cy, r, fill = C.aqua) {
  let o = '';
  for (let k = 0; k < 8; k++) { const d = pd(U.petal8, T(cx, cy, r / 8, k * 45)); o += resham(d, fill) + dabka(d, sw(0.55, r / 8)); }
  return o + pearl(cx, cy, r2(Math.max(0.9, r * 0.24)));
}
function blossom(cx, cy, r, fill = C.blush) {
  let o = '';
  for (let k = 0; k < 5; k++) { const d = pd(U.petal5, T(cx, cy, r / 8, k * 72)); o += resham(d, fill) + dabka(d, sw(0.55, r / 8)); }
  return o + sitara(cx, cy, r2(Math.max(0.8, r * 0.22)));
}
function cypress(t) {
  const d = pd(U.cypress, t);
  let o = resham(d, C.sage) + goldLine(pd(parse('M0,-2 L0,-92'), t), sw(0.45, t.s));
  for (let y = -10; y > -90; y -= 8) {
    const hw = 10.5 * Math.pow(Math.sin(Math.PI * Math.min(0.98, -y / 100)), 0.8);
    o += goldLine(pd(parse(`M${-hw * 0.72},${y - 4} L0,${y} L${hw * 0.72},${y - 4}`), t), sw(0.4, t.s));
  }
  o += dabka(d, sw(1, t.s)) + dabka(pd(parse('M0,0 L0,6'), t), sw(1.1, t.s));
  return o;
}
function mound(t) {
  const d = pd(U.mound, t);
  return resham(d, C.sageLight) + dabka(d, sw(0.9, t.s));
}

// ---------------------------------------------------------------- slub ground
function ground(W, H, seed) {
  const rand = rng(seed);
  let slubs = '';
  const n = Math.round((W * H) / 260);
  for (let i = 0; i < n; i++) {
    const x = rand() * W, y = rand() * H, l = 2 + rand() * 7;
    slubs += `M${r2(x)},${r2(y)} h${r2(l)} `;
  }
  return `<rect class="ground" width="${W}" height="${H}" fill="${C.ground}"/>` +
    `<path class="fx" d="${slubs}" stroke="#E4D7BE" stroke-width=".35" stroke-linecap="round" fill="none" opacity=".8"/>`;
}
function scaleBar(W, y) {
  const x0 = W - 56;
  return `<g class="scale"><path d="M${x0},${y} h50 M${x0},${y - 1.6} v3.2 M${x0 + 25},${y - 1} v2 M${x0 + 50},${y - 1.6} v3.2" stroke="#8A7A62" stroke-width=".35" fill="none"/>` +
    `<text x="${x0 + 25}" y="${y + 5.2}" text-anchor="middle" font-size="3.4" font-family="IBM Plex Mono, monospace" fill="#8A7A62">50 mm</text></g>`;
}

// ================================================================ MOTIF A — Mehrab panel
function motifA() {
  resetTally();
  const W = 160, H = 290, HV = 304;
  let o = ground(W, HV, 11);
  const colTop = 120, colBot = 272;
  for (const side of [1, -1]) {
    const X = (x) => (side === 1 ? x : W - x);
    o += dabka(`M${X(12)},${colBot} L${X(12)},${colTop}`, 1.3) + dabka(`M${X(21)},${colBot} L${X(21)},${colTop + 2}`, 1.1);
    let k = 0;
    for (let y = colTop + 7; y < colBot - 3; y += 6, k++) o += k % 2 ? pearl(X(16.5), y, 1.3) : sitara(X(16.5), y, 1.1);
    o += nakshi(rectD(Math.min(X(8), X(25)), 115.5, Math.max(X(8), X(25)), 120.5));
    o += nakshi(rectD(Math.min(X(8), X(25)), 272, Math.max(X(8), X(25)), 280));
  }
  o += dabka('M6,284 L154,284', 1.2);
  // arch: extrados, pearl row, cusped intrados
  const ext = [...sampleCubic([12, 120], [12, 70], [46, 38], [80, 22]), ...sampleCubic([80, 22], [114, 38], [148, 70], [148, 120]).slice(1)];
  o += dabka(poly(ext), 1.4);
  const mid = [...sampleCubic([16.5, 121], [16.5, 74], [48, 43], [80, 28]), ...sampleCubic([80, 28], [112, 43], [143.5, 74], [143.5, 121]).slice(1)];
  for (const p of spaced(mid, 4.6)) o += pearl(p[0], p[1], 1.35);
  const inL = evenly(sampleCubic([21, 122], [21, 78], [50, 48], [80, 34]), 5);
  const inR = evenly(sampleCubic([80, 34], [110, 48], [139, 78], [139, 122]), 5);
  const cps = [...inL, ...inR.slice(1)];
  o += dabka(cuspPath(cps), 1.1);
  for (const p of cps.slice(1, -1)) {
    const dx = 80 - p[0], dy = 125 - p[1], l = Math.hypot(dx, dy);
    o += sitara(p[0] + (dx / l) * 2.6, p[1] + (dy / l) * 2.6, 1);
  }
  // finial
  o += leaf(T(80, 19, 0.3, -62)) + leaf(T(80, 19, 0.3, 62, -1));
  o += bud(T(80, 12, 0.9));
  o += sitara(80, 1.8, 1.1);
  // spandrel rosettes with trailing sequins
  for (const side of [1, -1]) {
    const X = (x) => (side === 1 ? x : W - x);
    o += rosette(X(22), 50, 6);
    o += sitara(X(31), 40, 0.95) + sitara(X(37), 33.5, 0.95) + sitara(X(44), 28.5, 0.95);
  }
  // the flowering poppy plant
  o += dabka('M80,262 C78,210 82,150 80,96', 1.3);
  o += dabka('M80,206 C68,197 54,183 50,150', 1.1) + dabka('M80,206 C92,197 106,183 110,150', 1.1);
  o += dabka('M80,128 C73,121 66,114 61,107', 0.9) + dabka('M80,128 C87,121 94,114 99,107', 0.9);
  o += leaf(T(80, 232, 1.05, -58)) + leaf(T(80, 232, 1.05, 58, -1));
  o += leaf(T(80, 172, 0.9, -42)) + leaf(T(80, 172, 0.9, 42, -1));
  o += bud(T(59, 103, 0.9, -40)) + bud(T(101, 103, 0.9, 40));
  o += poppy(T(46, 132, 0.8, -12)) + poppy(T(114, 132, 0.8, 12));
  o += poppy(T(80, 72, 1.15));
  for (const side of [1, -1]) {
    const X = (x) => (side === 1 ? x : W - x);
    o += dabka(`M${X(53)},257 C${X(47)},252 ${X(42)},245 ${X(39)},239`, 0.8);
    o += leaf(T(X(45), 250, 0.3, side * -55, side)) + blossom(X(38), 234, 4.6);
  }
  o += mound(T(80, 270, 1.4));
  for (const [x, y] of [[34, 192], [38, 100], [29, 160], [30, 214]]) o += sitara(x, y) + sitara(W - x, y);
  o += scaleBar(W, 296);
  return { id: 'A', file: 'A-mehrab-panel', W, H: HV, body: o, tally: { ...tally } };
}

// ================================================================ MOTIF B — Daaman (hem) border
function motifB() {
  resetTally();
  const W = 240, H = 110, HV = 122;
  let o = ground(W, HV, 23);
  o += dabka('M0,3 L240,3', 1.1) + dabka('M0,17 L240,17', 1.1);
  const wave = Array.from({ length: 241 }, (_, x) => [x, 10 - 3.5 * Math.sin((2 * Math.PI * x) / 20)]);
  o += dabka(poly(wave), 0.8);
  for (let x = 5; x < W; x += 20) o += sitara(x, 13.4, 1);
  for (let x = 15; x < W; x += 20) o += pearl(x, 6.6, 1.15);
  for (let k = 0; k < 3; k++) {
    const ox = k * 80;
    o += dabka(`M${ox + 12},91 L${ox + 12},48 C${ox + 12},36 ${ox + 26},28 ${ox + 40},24 C${ox + 54},28 ${ox + 68},36 ${ox + 68},48 L${ox + 68},91`, 1.2);
    const l = evenly(sampleCubic([ox + 17, 50], [ox + 17, 41], [ox + 28, 34], [ox + 40, 30]), 3);
    const r = evenly(sampleCubic([ox + 40, 30], [ox + 52, 34], [ox + 63, 41], [ox + 63, 50]), 3);
    o += dabka(`M${ox + 17},91 L${ox + 17},50.01 ` + cuspPath([...l, ...r.slice(1)]).replace(/^M[^A]*/, '') + ` L${ox + 63},91`, 0.95);
    for (let y = 53; y < 90; y += 5) o += sitara(ox + 14.5, y, 0.95) + sitara(ox + 65.5, y, 0.95);
    o += cypress(T(ox + 40, 88, 0.5));
    o += mound(T(ox + 40, 90.5, 0.55));
    o += dabka(`M${ox + 27},72 C${ox + 27},80 ${ox + 30},86 ${ox + 34},88`, 0.7) + dabka(`M${ox + 53},72 C${ox + 53},80 ${ox + 50},86 ${ox + 46},88`, 0.7);
    o += blossom(ox + 27, 68, 4.2) + blossom(ox + 53, 68, 4.2);
  }
  for (const gx of [0, 80, 160, 240]) {
    o += dabka(`M${gx},91 L${gx},56`, 0.9);
    o += leaf(T(gx, 80, 0.38, -42)) + leaf(T(gx, 80, 0.38, 42, -1));
    o += leaf(T(gx, 66, 0.3, -38)) + leaf(T(gx, 66, 0.3, 38, -1));
    o += bud(T(gx, 50, 0.8));
    o += rosette(gx, 32, 5.5);
  }
  o += dabka('M0,93.5 L240,93.5', 1.1) + dabka('M0,106.5 L240,106.5', 1.1);
  for (let x = 2; x <= 238; x += 4) o += pearl(x, 100, 1.4);
  o += scaleBar(W, 116);
  return { id: 'B', file: 'B-daaman-border', W, H: HV, body: o, tally: { ...tally } };
}

// ================================================================ MOTIF C — Jaal trellis (bodice)
function motifC() {
  resetTally();
  const W = 160, H = 168, HV = 180, w = 40, h = 56;
  let o = ground(W, HV, 37);
  let inner = '';
  let lattice = '';
  for (let i = -2; i <= 10; i++) for (let j = -1; j <= 7; j++) {
    if ((i + j) % 2 !== 0) continue;
    const x = i * (w / 2), y = j * (h / 2);
    for (const sgn of [-1, 1]) lattice += `M${x},${y} C${x},${y + h / 4} ${x + sgn * (w / 2)},${y + h / 4} ${x + sgn * (w / 2)},${y + h / 2} `;
  }
  inner += dabka(lattice.trim(), 1);
  for (let i = -1; i <= 9; i++) for (let j = -1; j <= 7; j++) {
    const x = i * (w / 2), y = j * (h / 2);
    if ((i + j) % 2 === 0) {
      if (x >= 0 && x <= W && y >= 0 && y <= H) inner += pearl(x, y, 1.6) + sitara(x - 3.4, y, 0.9) + sitara(x + 3.4, y, 0.9);
    } else if (x >= -10 && x <= W + 10 && y >= -14 && y <= H + 14) {
      inner += dabka(`M${x},${y + 4} L${x},${y + 13}`, 0.7);
      inner += leaf(T(x, y + 12, 0.33, -52)) + leaf(T(x, y + 12, 0.33, 52, -1));
      inner += poppy(T(x, y - 5, 0.42));
    }
  }
  o += `<clipPath id="clipC"><rect width="${W}" height="${H}"/></clipPath><g clip-path="url(#clipC)">${inner}</g>`;
  o += `<path class="trim" d="M0,${H} L${W},${H}" stroke="#B9A887" stroke-width=".3" stroke-dasharray="1.5 1"/>`;
  o += scaleBar(W, 175);
  return { id: 'C', file: 'C-jaal-trellis', W, H: HV, body: o, tally: { ...tally } };
}

// ================================================================ MOTIF D — Gul buti (scatter)
function motifD() {
  resetTally();
  const W = 74, H = 80, HV = 92;
  let o = ground(W, HV, 41);
  o += dabka('M37,43 C36,52 38,60 37,68', 1);
  o += dabka('M37,52 C44,49 50,44 53,38', 0.8);
  o += dabka('M37,57 C30,55 24,51 22,45', 0.7);
  o += sitara(21.5, 41.5, 1) + sitara(19.5, 36.5, 0.95) + sitara(21, 31.5, 0.9);
  o += leaf(T(37, 62, 0.55, -48)) + leaf(T(37, 62, 0.55, 48, -1));
  o += bud(T(54.5, 35, 0.7, 35));
  o += poppy(T(37, 28, 0.7));
  o += sitara(33, 71.5) + pearl(37, 73.5, 1.3) + sitara(41, 71.5);
  o += scaleBar(W, 87);
  return { id: 'D', file: 'D-gul-buti', W, H: HV, body: o, tally: { ...tally } };
}

// ================================================================ MOTIF E — Neckline yoke
function motifE() {
  resetTally();
  const W = 260, H = 218, HV = 230, cx = 130;
  const ell = (a, b, n = 500) => Array.from({ length: n + 1 }, (_, i) => { const t = (Math.PI * i) / n; return [cx + a * Math.cos(t), b * Math.sin(t)]; });
  let o = ground(W, HV, 53);
  const neck = ell(72, 110);
  o += `<path class="void" d="${poly(neck)} Z" fill="${C.voidFill}"/><path class="fx" d="${poly(neck)} Z" fill="url(#pVoid)"/>`;
  o += `<text class="note" x="${cx}" y="44" text-anchor="middle" font-size="4.2" letter-spacing=".6" font-family="Jost, sans-serif" fill="#9B8B72">NECK OPENING</text>`;
  o += dabka(poly(neck), 1.4);
  for (const p of spaced(ell(76, 114), 4.4)) o += pearl(p[0], p[1], 1.35);
  o += dabka(poly(ell(80.5, 118.5)), 0.9);
  // vine along the centre of the band, symmetric about centre front
  const vb = ell(92, 130, 800), L = cumLen(vb), tot = L[L.length - 1], half = tot / 2, P = 24;
  const vine = [];
  for (let s = 0; s <= tot; s += 0.8) {
    const { p, ang } = atLen(vb, L, s);
    const nx = Math.sin(ang), ny = -Math.cos(ang); // left normal of travel = outward here
    const off = 5.5 * Math.cos((2 * Math.PI * (s - half)) / P);
    vine.push([p[0] + nx * off, p[1] + ny * off]);
  }
  o += dabka(poly(vine), 0.85);
  for (let k = -12; k <= 12; k++) {
    const s = half + k * P;
    if (s < 6 || s > tot - 6) continue;
    const { p, ang } = atLen(vb, L, s);
    const nx = Math.sin(ang), ny = -Math.cos(ang);
    o += blossom(p[0] + nx * 1.2, p[1] + ny * 1.2, 4);
    const s2 = s + P / 2;
    if (s2 < tot - 6) {
      const q = atLen(vb, L, s2), mx = Math.sin(q.ang), my = -Math.cos(q.ang);
      const deg = (Math.atan2(my, mx) * 180) / Math.PI + 90;
      o += leaf(T(q.p[0] - mx * 5.5, q.p[1] - my * 5.5, 0.26, deg - 28)) + leaf(T(q.p[0] - mx * 5.5, q.p[1] - my * 5.5, 0.26, deg + 28, -1));
    }
  }
  o += dabka(poly(ell(104, 142)), 0.9);
  // cusped outer edge, symmetric points from centre front
  const ob = ell(108, 146, 800), OL = cumLen(ob), ot = OL[OL.length - 1];
  const pts = [];
  for (let s = ot / 2 - Math.floor(ot / 2 / 11) * 11; s <= ot; s += 11) pts.push(atLen(ob, OL, s).p);
  o += dabka(cuspPath(pts, 0.6), 1.1);
  for (const p of pts) {
    const s = 1;
    const dx = p[0] - cx, dy = p[1] - 0;
    const n = Math.hypot(dx / 108 ** 2, dy / 146 ** 2);
    const ux = dx / 108 ** 2 / n, uy = dy / 146 ** 2 / n;
    o += sitara(p[0], p[1], 1.05 * s);
    if (p[1] > 8) o += pearl(p[0] + ux * 4.6, p[1] + uy * 4.6, 1.2);
  }
  // centre-front drop medallion
  const med = [[130, 146], [152, 154], [156, 180], [130, 206]];
  const medL = [[130, 206], [104, 180], [108, 154], [130, 146]];
  o += `<path d="M130,146 C152,154 156,180 130,206 C104,180 108,154 130,146 Z" fill="${C.ground}"/>`;
  o += dabka('M130,146 C152,154 156,180 130,206 C104,180 108,154 130,146 Z', 1.3);
  const sc = (p) => [130 + (p[0] - 130) * 0.8, 177 + (p[1] - 177) * 0.8];
  const inner = [...sampleCubic(...med.map(sc)), ...sampleCubic(...medL.map(sc)).slice(1)];
  for (const p of spaced(inner, 4.3, 2.2)) o += pearl(p[0], p[1], 1.15);
  o += leaf(T(130, 192, 0.28, -50)) + leaf(T(130, 192, 0.28, 50, -1));
  o += poppy(T(130, 175, 0.55));
  o += sitara(130, 209.5, 1.1) + pearl(130, 213.8, 1.5);
  o += scaleBar(W, 225);
  return { id: 'E', file: 'E-neckline-yoke', W, H: HV, body: o, tally: { ...tally } };
}

// ================================================================ MOTIF F — Vine border (cuffs, waist)
function motifF() {
  resetTally();
  const W = 200, H = 44, HV = 56;
  let o = ground(W, HV, 67);
  o += dabka('M0,4 L200,4', 1) + dabka('M0,40 L200,40', 1);
  for (let x = 2; x <= 198; x += 4) o += pearl(x, 8.6, 1.2) + pearl(x, 35.4, 1.2);
  const wave = Array.from({ length: 401 }, (_, i) => { const x = i / 2; return [x, 22 - 7 * Math.sin((2 * Math.PI * x) / 40)]; });
  o += dabka(poly(wave), 0.95);
  for (let k = 0; k < 5; k++) {
    const x0 = k * 40;
    o += leaf(T(x0 + 10, 15, 0.2, -42)) + leaf(T(x0 + 10, 15, 0.2, 42, -1));
    o += leaf(T(x0 + 30, 29, 0.2, 180 + 42)) + leaf(T(x0 + 30, 29, 0.2, 180 - 42, -1));
    o += blossom(x0 + 10, 26, 4.4);
    o += rosette(x0 + 30, 18, 4.4);
    o += sitara(x0 + 20, 14.6, 0.95) + sitara(x0 + 20, 29.4, 0.95);
  }
  o += scaleBar(W, 51);
  return { id: 'F', file: 'F-vine-border', W, H: HV, body: o, tally: { ...tally } };
}

// ---------------------------------------------------------------- stitch key samples
function keySamples() {
  const W = 64, H = 24;
  const wrap = (body) => `<rect class="ground" width="${W}" height="${H}" fill="${C.ground}"/>${body}`;
  const leafD = pd(U.leaf, T(32, 21, 0.62, 90));
  return [
    { name: 'Dabka', local: 'coiled wire', use: 'All outlines, stems, the arch and lattice lines. Medium coil on A, B, E; fine (baarik) coil on C, D, F.', body: wrap(dabka(poly(Array.from({ length: 57 }, (_, i) => [4 + i, 12 - 5 * Math.sin(i / 6)])), 1.6)) },
    { name: 'Nakshi', local: 'bright coil fill', use: 'Solid metal areas: poppy calyx, bud sepals, column capitals and plinths.', body: wrap(nakshi(rectD(8, 7, 26, 17)) + nakshi(pd(U.poppyCalyx, T(44, 4, 0.9)))) },
    { name: 'Resham', local: 'silk, long-and-short', use: 'Petals in gulabi blush, leaves and cypress in pista sage, rosettes in firozi mist.', body: wrap(resham(pd(U.petal5, T(16, 20, 1.9)), C.blush) + resham(leafD, C.sage) + dabka(leafD, 0.6) + resham(pd(U.petal8, T(52, 20, 1.9)), C.aqua)) },
    { name: 'Sitara', local: 'sequin, tacked centre', use: 'Rose-gold 3 mm sequins: stamen tips, cusp points, column chains and scatter.', body: wrap([10, 20, 30, 40, 50].map((x, i) => sitara(x + 2, 12 + (i % 2 ? -3 : 3), 2.1)).join('')) },
    { name: 'Moti', local: 'pearl, 2–3 mm', use: 'Off-white pearls in rows along the arch, hem, neckline and cuffs; single moti at lattice nodes.', body: wrap(Array.from({ length: 9 }, (_, i) => pearl(8 + i * 6, 12, 2.3)).join('')) },
  ].map((k) => ({ ...k, W, H }));
}

// ---------------------------------------------------------------- garment placement map
function garmentMap() {
  const hemQ = (t) => { const u = 1 - t; return [u * u * 36 + 2 * t * u * 210 + t * t * 384, u * u * 548 + 2 * t * u * 580 + t * t * 548]; };
  const waistX = (i) => 172 + i * 9.5;
  const leftSide = sampleCubic([172, 178], [120, 300], [70, 430], [36, 548], 300);
  const xOnLeft = (y) => { for (let i = 1; i < leftSide.length; i++) if (leftSide[i][1] >= y) { const a = leftSide[i - 1], b = leftSide[i]; return a[0] + ((b[0] - a[0]) * (y - a[1])) / (b[1] - a[1]); } return 36; };
  const seamX = (i, y) => {
    if (i === 0) return xOnLeft(y);
    if (i === 8) return 420 - xOnLeft(y);
    const [hx, hy] = hemQ(i / 8), wx = waistX(i);
    return wx + ((hx - wx) * (y - 178)) / (hy - 178);
  };
  const lerp = (a, b, k) => a + (b - a) * k;
  const yUpper = (x) => 526 + 16 * (1 - ((x - 210) / 167) ** 2);
  const fabric = C.ground, line = '#A39072';
  const bodice = 'M184,40 L150,54 C156,78 160,98 162,116 L172,178 L248,178 L258,116 C260,98 264,78 270,54 L236,40 C234,72 222,92 210,94 C198,92 186,72 184,40 Z';
  const sleeveL = 'M150,54 C138,70 132,120 128,200 L122,282 L146,286 L152,200 C154,160 158,130 162,116 C160,98 156,78 150,54 Z';
  const mirror = (d) => d.replace(/(-?\d+\.?\d*),(-?\d+\.?\d*)/g, (_, x, y) => `${r2(420 - +x)},${y}`);
  const skirt = 'M172,178 L248,178 C300,300 350,430 384,548 Q210,580 36,548 C70,430 120,300 172,178 Z';
  let o = '';
  o += `<path d="${sleeveL}" fill="${fabric}" stroke="${line}" stroke-width="1"/><path d="${mirror(sleeveL)}" fill="${fabric}" stroke="${line}" stroke-width="1"/>`;
  o += `<path d="${skirt}" fill="${fabric}" stroke="${line}" stroke-width="1"/>`;
  for (let i = 1; i < 8; i++) { const [hx, hy] = hemQ(i / 8); o += `<path d="M${waistX(i)},178 L${r2(hx)},${r2(hy)}" stroke="${line}" stroke-width=".6" stroke-dasharray="3 2.5" opacity=".7"/>`; }
  o += `<path d="${bodice}" fill="${fabric}" stroke="${line}" stroke-width="1"/>`;

  const zf = 'fill="#D7B56E" fill-opacity=".38" stroke="#B48E48" stroke-width=".9"';
  // C jaal on bodice
  o += `<g class="zone" data-z="C"><clipPath id="clipBodice"><path d="${bodice}"/></clipPath><rect x="140" y="30" width="140" height="160" fill="url(#pJaalMini)" clip-path="url(#clipBodice)"/></g>`;
  // E neckline band + drop
  o += `<g class="zone" data-z="E"><path d="M184,40 C186,72 198,92 210,94 C222,92 234,72 236,40 L249,45.4 C246,88 226,108 210,108 C194,108 174,88 171,45.4 Z" ${zf}/><path d="M210,106 C217,109 218,116 210,124 C202,116 203,109 210,106 Z" ${zf}/></g>`;
  // F waist + cuffs
  const cuff = 'M123.5,262 L147.4,266 L146,286 L122,282 Z';
  o += `<g class="zone" data-z="F"><path d="M171.4,173 L248.6,173 L251.4,186 L168.6,186 Z" ${zf}/><path d="${cuff}" ${zf}/><path d="${mirror(cuff)}" ${zf}/></g>`;
  // D buti rows (half-drop)
  let dz = '';
  [250, 290, 330, 370, 410].forEach((y, r) => {
    for (let k = 0; k < 8; k++) if ((k + r) % 2 === 0) {
      const x = (seamX(k, y) + seamX(k + 1, y)) / 2;
      dz += `<circle cx="${r2(x)}" cy="${y}" r="3.2" fill="${C.blush}" stroke="#B48E48" stroke-width=".8"/><circle cx="${r2(x)}" cy="${y}" r="1" fill="#B48E48"/>`;
    }
  });
  o += `<g class="zone" data-z="D">${dz}</g>`;
  // A mehrab panels, one per kali, following the taper
  let az = '';
  for (let k = 0; k < 8; k++) {
    const xm = (seamX(k, 520) + seamX(k + 1, 520)) / 2;
    const yb = yUpper(xm) - 5, yt = yb - 72, ys = yt + 26;
    const bl = lerp(seamX(k, yb), seamX(k + 1, yb), 0.18), br = lerp(seamX(k, yb), seamX(k + 1, yb), 0.82);
    const sl = lerp(seamX(k, ys), seamX(k + 1, ys), 0.18), sr = lerp(seamX(k, ys), seamX(k + 1, ys), 0.82);
    const ax = (seamX(k, yt) + seamX(k + 1, yt)) / 2;
    az += `<path d="M${r2(bl)},${r2(yb)} L${r2(sl)},${r2(ys)} C${r2(sl)},${r2(yt + 9)} ${r2(lerp(sl, ax, 0.62))},${r2(yt + 3)} ${r2(ax)},${r2(yt)} C${r2(lerp(sr, ax, 0.62))},${r2(yt + 3)} ${r2(sr)},${r2(yt + 9)} ${r2(sr)},${r2(ys)} L${r2(br)},${r2(yb)} Z" ${zf}/>`;
    az += `<circle cx="${r2((bl + br) / 2)}" cy="${r2(ys + 4)}" r="3" fill="${C.blush}" stroke="#B48E48" stroke-width=".7"/>`;
  }
  o += `<g class="zone" data-z="A">${az}</g>`;
  // B hem border
  const xl = xOnLeft(526);
  o += `<g class="zone" data-z="B"><path d="M36,548 Q210,580 384,548 L${r2(420 - xl)},526 Q210,558 ${r2(xl)},526 Z" ${zf}/></g>`;
  // chips
  const chips = [['E', 210, 101], ['C', 210, 142], ['F', 210, 180], ['F', 134.7, 274], ['F', 285.3, 274], ['D', 210, 350], ['A', (seamX(4, 495) + seamX(5, 495)) / 2, 492], ['B', 210, 553]];
  for (const [z, x, y] of chips) o += `<g class="chip" data-z="${z}"><circle cx="${r2(x)}" cy="${r2(y)}" r="8.5"/><text x="${r2(x)}" y="${r2(y + 3.6)}" text-anchor="middle">${z}</text></g>`;
  return o;
}

// ---------------------------------------------------------------- defs
const DEFS = `<defs>
<linearGradient id="gGold" gradientUnits="userSpaceOnUse" x1="0" y1="0" x2="4.5" y2="2.6" spreadMethod="reflect"><stop offset="0" stop-color="#F3E3B6"/><stop offset=".45" stop-color="#D5B36D"/><stop offset=".72" stop-color="#B08A45"/><stop offset="1" stop-color="#EBD5A0"/></linearGradient>
<radialGradient id="gPearl" cx=".36" cy=".32" r=".75"><stop offset="0" stop-color="#FFFFFF"/><stop offset=".55" stop-color="#F5EFE3"/><stop offset="1" stop-color="#D6CAB3"/></radialGradient>
<radialGradient id="gRose" cx=".35" cy=".33" r=".8"><stop offset="0" stop-color="#F8E1D4"/><stop offset=".5" stop-color="#D7A894"/><stop offset="1" stop-color="#AF806B"/></radialGradient>
<pattern id="pThread" width="1.1" height="1.1" patternUnits="userSpaceOnUse" patternTransform="rotate(35)"><rect width="1.1" height=".34" fill="#fff" fill-opacity=".3"/></pattern>
<pattern id="pThreadB" width="1.1" height="1.1" patternUnits="userSpaceOnUse" patternTransform="rotate(-35)"><rect width="1.1" height=".34" fill="#fff" fill-opacity=".26"/></pattern>
<pattern id="pCoil" width=".8" height=".8" patternUnits="userSpaceOnUse" patternTransform="rotate(-50)"><rect width=".8" height=".22" fill="#8E6C30" fill-opacity=".45"/></pattern>
<pattern id="pVoid" width="3" height="3" patternUnits="userSpaceOnUse" patternTransform="rotate(45)"><rect width="3" height=".3" fill="#C9BBA1" fill-opacity=".6"/></pattern>
<pattern id="pJaalMini" width="10" height="14" patternUnits="userSpaceOnUse"><path d="M0,0 C0,3.5 5,3.5 5,7 C5,10.5 0,10.5 0,14 M10,0 C10,3.5 5,3.5 5,7 C5,10.5 10,10.5 10,14" fill="none" stroke="#B48E48" stroke-width=".8"/><circle cx="0" cy="7" r="1.5" fill="${C.blush}"/><circle cx="10" cy="7" r="1.5" fill="${C.blush}"/><circle cx="5" cy="0" r=".9" fill="#B48E48"/><circle cx="5" cy="14" r=".9" fill="#B48E48"/></pattern>
</defs>`;

// ---------------------------------------------------------------- build
const motifs = [motifA(), motifB(), motifC(), motifD(), motifE(), motifF()];
const M = Object.fromEntries(motifs.map((m) => [m.id, m]));
const keys = keySamples();

const KHAKA_CSS = `.fx{display:none}.ground{fill:#fff!important}path,circle,rect:not(.ground){fill:none!important;stroke:#1f1f1f!important;stroke-width:.3px!important;stroke-dasharray:none!important;stroke-opacity:1!important}text{fill:#1f1f1f!important;stroke:none!important}`;
mkdirSync(join(here, 'svg'), { recursive: true });
for (const m of motifs) {
  const head = `<svg xmlns="http://www.w3.org/2000/svg" width="${m.W}mm" height="${m.H}mm" viewBox="0 0 ${m.W} ${m.H}">`;
  writeFileSync(join(here, 'svg', `${m.file}.svg`), `${head}${DEFS}${m.body}</svg>\n`);
  writeFileSync(join(here, 'svg', `${m.file}-khaka.svg`), `${head}<style>${KHAKA_CSS}</style>${DEFS}${m.body}</svg>\n`);
}

const svgInline = (m, label) => `<svg class="motif" viewBox="0 0 ${m.W} ${m.H}" style="--w:${m.W}" role="img" aria-label="${label}">${m.body}</svg>`;

// production data
const prod = [
  { id: 'A', name: 'Mehrab panel', where: 'Every kali, 10 mm above the hem border', size: '160 × 290 mm', qty: '16 panels', mult: 16, hrs: 9 * 16, rate: '9 h each' },
  { id: 'B', name: 'Daaman border', where: 'Full hem, continuous', size: '110 mm deep · 80 mm repeat', qty: '≈ 4.2 m', mult: 4200 / 240, hrs: Math.round(4.2 * 17), rate: '17 h per metre' },
  { id: 'C', name: 'Jaal trellis', where: 'Front and back bodice, shoulder to empire waist', size: '40 × 56 mm ogee repeat', qty: '≈ 0.16 m²', mult: 0.16 / ((160 * 168) / 1e6), hrs: 44, rate: '≈ 275 h per m²' },
  { id: 'D', name: 'Gul buti', where: 'Kalis above the panels, half-drop', size: '≈ 42 × 62 mm', qty: '40 butis', mult: 40, hrs: 20, rate: '30 min each' },
  { id: 'E', name: 'Neckline yoke', where: 'Front U-neck, with centre drop', size: '40 mm band · 68 mm drop', qty: '1', mult: 1, hrs: 16, rate: '16 h' },
  { id: 'F', name: 'Vine border', where: 'Both cuffs and the empire-waist seam', size: '44 mm deep · 40 mm repeat', qty: '≈ 1.3 m', mult: 1300 / 200, hrs: 16, rate: '12 h per metre' },
];
const round50 = (n) => Math.max(50, Math.round(n / 50) * 50);
let totH = 0, totMoti = 0, totSit = 0;
const rows = prod.map((p) => {
  const m = M[p.id];
  const moti = m.tally.moti * p.mult, sit = m.tally.sitara * p.mult;
  totH += p.hrs; totMoti += moti; totSit += sit;
  return `<tr data-z="${p.id}"><td><span class="code">${p.id}</span></td><td><b>${p.name}</b><span class="sub">${p.where}</span></td><td>${p.size}</td><td class="num">${p.qty}</td><td class="num">${round50(moti).toLocaleString('en-IN')}</td><td class="num">${round50(sit).toLocaleString('en-IN')}</td><td class="num">${p.hrs} h<span class="sub">${p.rate}</span></td></tr>`;
}).join('');

const card = (m, d) => `
<article class="mcard${d.wide ? ' wide' : ''}" id="motif-${m.id}" data-z="${m.id}">
  <div class="swatch">${svgInline(m, d.name + ' embroidery motif')}</div>
  <div class="mspec">
    <div class="mhead"><span class="code">${m.id}</span><h3>${d.name}</h3><span class="hindi">${d.local}</span></div>
    <p>${d.desc}</p>
    <dl class="facts">
      <div><dt>Size</dt><dd>${d.size}</dd></div>
      <div><dt>Placement</dt><dd>${d.where}</dd></div>
      <div><dt>In this drawing</dt><dd>${m.tally.moti} moti · ${m.tally.sitara} sitara</dd></div>
    </dl>
    <p class="files">Print files: <code>svg/${m.file}.svg</code> · <code>svg/${m.file}-khaka.svg</code></p>
  </div>
</article>`;

const DESC = {
  B: { name: 'Daaman border', local: 'दामन · hem', wide: true, size: '110 mm deep, 80 mm repeat', where: 'Full hem, about 4.2 m, continuous across kali seams', desc: 'A Mughal arcade runs around the hem. Each cusped arch frames a sage cypress on a small hillock, flanked by blush blossoms. Between arches a poppy bud rises under a firozi rosette. A vine of sitara and moti runs along the top, with a double dabka rail and a pearl row at the hem edge.' },
  C: { name: 'Jaal trellis', local: 'जाल · lattice', size: '40 × 56 mm ogee repeat', where: 'Bodice front and back', desc: 'An ogee lattice in fine dabka, with a moti and two sitara at every node and a small poppy on two leaves in each cell. Start the repeat at centre front so the cells mirror at the neckline.' },
  D: { name: 'Gul buti', local: 'गुल बूटी · scatter', size: '≈ 42 × 62 mm', where: 'Kalis above the panels, half-drop, rows about 120 mm apart', desc: 'A single poppy sprig with a side bud and a sequin tendril. It lightens the upper skirt so the weight stays at the hem. Turn alternate butis 8° left and right so they read as hand-placed.' },
  E: { name: 'Neckline yoke', local: 'गला · neck', size: '40 mm band on a 144 × 110 mm U-neck, 68 mm drop', where: 'Front neck, from shoulder seam to shoulder seam', desc: 'Pearls edge the neck, then a poppy vine with blossoms and paired leaves, finished with a cusped outer edge carrying sitara and moti drops. A teardrop medallion with a poppy hangs at centre front.' },
  F: { name: 'Vine border', local: 'बेल · creeper', wide: true, size: '44 mm deep, 40 mm repeat', where: 'Both sleeve cuffs and the empire-waist seam, about 1.3 m', desc: 'A light running bel between two pearl rows, alternating blush blossoms and firozi rosettes. It is narrow and flexible enough to sit on the curved waist seam without puckering.' },
};

const A = M.A;
const html = `<title>Gulposh Anarkali</title>
<meta name="claude:viewport-fit-sides" content="cover">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Italiana&family=Jost:wght@300;400;500;600&family=IBM+Plex+Mono:wght@400;500&family=Tiro+Devanagari+Hindi&display=swap">
<style>
/* Layout: a couture tech-pack — ivory fabric swatches pinned to a pale atelier board, specs in ruled columns beside each swatch */
:root{
  --board:#ECEEE6; --panel:#F8F8F3; --ink:#2A2630; --ink-2:#5F5866; --rule:#D2D5C9;
  --gold:#86642A; --blush:#B06A66; --fabric:#F6F0E3; --fabric-edge:#DDD0B6;
  --chip:#2A2630; --chip-ink:#F6F0E3; --shadow:rgba(60,48,30,.10);
  --f-display:"Italiana","Didot","Bodoni 72",Georgia,serif;
  --f-body:"Jost","Futura","Avenir Next",system-ui,sans-serif;
  --f-mono:"IBM Plex Mono",ui-monospace,Menlo,monospace;
  --f-deva:"Tiro Devanagari Hindi","Noto Serif Devanagari",serif;
}
@media (prefers-color-scheme: dark){:root:not([data-theme="light"]){
  --board:#1C1A20; --panel:#25222A; --ink:#EEE8DC; --ink-2:#B3ABA1; --rule:#3A3640;
  --gold:#D8BD82; --blush:#E6ADA7; --fabric-edge:#5B5142; --chip:#EEE8DC; --chip-ink:#1C1A20; --shadow:rgba(0,0,0,.35); color-scheme:dark}}
:root[data-theme="dark"]{
  --board:#1C1A20; --panel:#25222A; --ink:#EEE8DC; --ink-2:#B3ABA1; --rule:#3A3640;
  --gold:#D8BD82; --blush:#E6ADA7; --fabric-edge:#5B5142; --chip:#EEE8DC; --chip-ink:#1C1A20; --shadow:rgba(0,0,0,.35); color-scheme:dark}
*{box-sizing:border-box}
body{background:var(--board);color:var(--ink);font-family:var(--f-body);font-size:16px;line-height:1.55;font-weight:400}
.wrap{max-width:1180px;margin:0 auto;padding-left:max(16px,env(safe-area-inset-left,0px));padding-right:max(16px,env(safe-area-inset-right,0px));padding-block:40px 72px}
h1,h2,h3{font-weight:400;text-wrap:balance;margin:0}
h1{font-family:var(--f-display);font-size:clamp(3rem,8vw,5.6rem);line-height:.95;letter-spacing:.01em}
h2{font-family:var(--f-display);font-size:clamp(2rem,4vw,2.7rem);line-height:1.05}
h3{font-family:var(--f-body);font-weight:500;font-size:1.15rem;letter-spacing:.01em}
p{margin:0;max-width:65ch}
.eyebrow{font-size:.75rem;letter-spacing:.18em;text-transform:uppercase;color:var(--gold);font-weight:500}
.code{display:inline-grid;place-items:center;width:1.9rem;height:1.9rem;border-radius:50%;background:var(--chip);color:var(--chip-ink);font-family:var(--f-mono);font-weight:500;font-size:.85rem;flex:none}
.hindi{font-family:var(--f-deva);color:var(--ink-2);font-size:.95rem}
code{font-family:var(--f-mono);font-size:.82em;color:var(--ink-2);overflow-wrap:anywhere}

/* hero */
.hero{display:grid;grid-template-columns:minmax(0,1fr) minmax(0,1.05fr);gap:48px;align-items:start}
.hero-text{display:flex;flex-direction:column;gap:22px;padding-top:12px}
.lede{font-size:1.12rem;font-weight:300;color:var(--ink)}
.meta{display:grid;grid-template-columns:auto 1fr;gap:8px 20px;margin:0;padding:18px 0;border-top:1px solid var(--rule);border-bottom:1px solid var(--rule);font-size:.92rem}
.meta dt{color:var(--ink-2);font-size:.75rem;letter-spacing:.12em;text-transform:uppercase;padding-top:3px}
.meta dd{margin:0}
.status{display:inline-flex;align-items:center;gap:8px}
.status::before{content:"";width:8px;height:8px;border-radius:50%;background:var(--blush)}
.viewer{display:flex;flex-direction:column;gap:8px}
.seg{display:inline-flex;border:1px solid var(--rule);border-radius:999px;padding:3px;background:var(--panel);width:max-content;max-width:100%}
.seg button{font:inherit;font-size:.88rem;border:0;background:transparent;color:var(--ink-2);padding:7px 16px;border-radius:999px;cursor:pointer}
.seg button[aria-pressed="true"]{background:var(--chip);color:var(--chip-ink)}
.seg button:focus-visible{outline:2px solid var(--gold);outline-offset:2px}
.hint{font-size:.82rem;color:var(--ink-2)}
.hero-swatch{display:flex;flex-direction:column;gap:14px}
.hero-swatch .swatch{padding:22px}
.hero-swatch .motif{max-width:min(100%,460px)}
.hero-cap{display:grid;grid-template-columns:auto 1fr;gap:4px 14px;align-items:start}
.hero-cap h3{align-self:center}
.hero-cap p{grid-column:2;color:var(--ink-2);font-size:.95rem}

/* swatches */
.swatch{background:var(--fabric);border:1px solid var(--fabric-edge);box-shadow:0 1px 0 var(--shadow),0 10px 28px -14px var(--shadow);display:grid;place-items:center;padding:18px;position:relative;min-width:0}
.swatch::before{content:"";position:absolute;top:-7px;left:50%;width:12px;height:12px;margin-left:-6px;border-radius:50%;background:radial-gradient(circle at 35% 35%,#E9D6A7,#9C7A3A);box-shadow:0 2px 3px rgba(0,0,0,.25)}
.motif{display:block;width:100%;max-width:min(100%,calc(var(--w) * 2.7px));height:auto}

/* sections */
section{margin-top:84px}
.sec-head{display:flex;flex-direction:column;gap:10px;margin-bottom:28px}
.sec-head p{color:var(--ink-2)}

/* placement */
.place{display:grid;grid-template-columns:minmax(0,.9fr) minmax(0,1.1fr);gap:40px;align-items:start;background:var(--panel);border:1px solid var(--rule);padding:28px}
.map{width:100%;max-width:420px;height:auto;margin:0 auto;display:block}
.map .zone,.map .chip{transition:opacity .2s}
.map.focus .zone:not(.on),.map.focus .chip:not(.on){opacity:.18}
.map .chip circle{fill:var(--chip)}
.map .chip text{fill:var(--chip-ink);font-family:var(--f-mono);font-size:10px;font-weight:500}
.legend{list-style:none;margin:0;padding:0;display:flex;flex-direction:column}
.legend li{display:grid;grid-template-columns:auto 1fr auto;gap:4px 14px;align-items:start;padding:14px 8px;border-top:1px solid var(--rule);cursor:default;border-radius:4px}
.legend li:last-child{border-bottom:1px solid var(--rule)}
.legend li.on{background:color-mix(in srgb,var(--gold) 10%,transparent)}
.legend li:focus-visible{outline:2px solid var(--gold);outline-offset:-2px}
.legend b{font-weight:500}
.legend .sub{display:block;color:var(--ink-2);font-size:.88rem}
.legend .size{font-family:var(--f-mono);font-size:.78rem;color:var(--ink-2);text-align:right;white-space:nowrap}
.assume{margin-top:18px;font-size:.85rem;color:var(--ink-2)}

/* motif library */
.library{display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,320px),1fr));gap:28px}
.mcard{display:flex;flex-direction:column;gap:18px;min-width:0}
.mcard.wide{grid-column:1/-1;display:grid;grid-template-columns:minmax(0,1.5fr) minmax(0,1fr);gap:28px;align-items:center}
.mcard .swatch{padding:26px 18px 18px}
.mspec{display:flex;flex-direction:column;gap:12px;min-width:0}
.mhead{display:flex;align-items:center;gap:12px;flex-wrap:wrap}
.mspec>p{font-size:.95rem}
.facts{margin:0;display:flex;flex-direction:column;gap:6px;font-size:.88rem}
.facts div{display:grid;grid-template-columns:7.5rem 1fr;gap:10px}
.facts dt{color:var(--ink-2);font-size:.72rem;letter-spacing:.12em;text-transform:uppercase;padding-top:3px}
.facts dd{margin:0}
.files{font-size:.8rem;color:var(--ink-2)}

/* khaka view */
.khaka .motif .fx{display:none}
.khaka .motif .ground{fill:#fff!important}
.khaka .motif path,.khaka .motif circle,.khaka .motif rect:not(.ground){fill:none!important;stroke:#1f1f1f!important;stroke-width:.3px!important;stroke-dasharray:none!important;stroke-opacity:1!important}
.khaka .motif text{fill:#1f1f1f!important;stroke:none!important}
.khaka .swatch{background:#fff}

/* palette */
.palette{display:grid;grid-template-columns:repeat(auto-fill,minmax(min(100%,200px),1fr));gap:20px}
.chipcol{display:flex;flex-direction:column;gap:10px}
.dot{height:76px;border:1px solid var(--fabric-edge);position:relative;overflow:hidden}
.dot.metal{background:linear-gradient(115deg,#F3E3B6 0%,#D5B36D 30%,#B08A45 52%,#EBD5A0 74%,#C9A55E 100%)}
.dot.metal::after{content:"";position:absolute;inset:0;background:repeating-linear-gradient(-55deg,rgba(255,247,223,.55) 0 1px,transparent 1px 4px)}
.dot.seq{background:radial-gradient(circle at 22% 40%,#F8E1D4 0 3px,#D7A894 6px,#AF806B 11px,transparent 12px) 0 0/28px 26px,var(--fabric)}
.dot.pearlrow{background:radial-gradient(circle at 34% 34%,#fff 0 2px,#F5EFE3 5px,#D6CAB3 9px,transparent 10px) 0 0/22px 22px,var(--fabric)}
.chipcol b{font-weight:500;display:block}
.chipcol span{font-size:.85rem;color:var(--ink-2);display:block}
.chipcol code{font-size:.75rem}

/* stitch key */
.keys{display:grid;grid-template-columns:repeat(auto-fill,minmax(min(100%,210px),1fr));gap:20px}
.key{display:flex;flex-direction:column;gap:10px}
.key .swatch{padding:10px}
.key .swatch::before{display:none}
.key .motif{max-width:100%}
.key h3{font-size:1rem}
.key h3 span{font-weight:300;color:var(--ink-2)}
.key p{font-size:.88rem;color:var(--ink-2)}

/* production */
.tablewrap{overflow-x:auto;background:var(--panel);border:1px solid var(--rule)}
table{border-collapse:collapse;width:100%;min-width:760px;font-size:.92rem}
th,td{text-align:left;padding:14px 16px;border-bottom:1px solid var(--rule);vertical-align:top}
th{font-size:.7rem;letter-spacing:.14em;text-transform:uppercase;color:var(--ink-2);font-weight:500}
td .sub{display:block;color:var(--ink-2);font-size:.82rem}
td b{font-weight:500}
.num{text-align:right;font-variant-numeric:tabular-nums;font-family:var(--f-mono);font-size:.85rem;white-space:nowrap}
th.num{font-family:var(--f-body)}
tfoot td{font-weight:500;border-bottom:0}
.totals{display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,200px),1fr));gap:20px;margin-top:24px}
.total{border-top:2px solid var(--ink);padding-top:12px}
.total .big{font-family:var(--f-display);font-size:2.6rem;line-height:1}
.total span{display:block;font-size:.85rem;color:var(--ink-2)}

/* notes */
.twocol{display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,380px),1fr));gap:40px}
.steps{margin:0;padding:0;list-style:none;counter-reset:s;display:flex;flex-direction:column;gap:16px}
.steps li{counter-increment:s;display:grid;grid-template-columns:2.2rem 1fr;gap:12px}
.steps li::before{content:counter(s);font-family:var(--f-display);font-size:1.7rem;line-height:1;color:var(--gold)}
.steps b,.asks b{font-weight:500}
.asks{margin:0;padding:0;list-style:none;display:flex;flex-direction:column}
.asks li{padding:14px 0;border-top:1px solid var(--rule)}
.asks li:last-child{border-bottom:1px solid var(--rule)}
.asks span{display:block;color:var(--ink-2);font-size:.9rem}
footer{margin-top:72px;padding-top:20px;border-top:1px solid var(--rule);font-size:.85rem;color:var(--ink-2);display:flex;flex-wrap:wrap;gap:8px 24px;justify-content:space-between}

@media (max-width:860px){
  .hero,.place{grid-template-columns:1fr}
  .mcard.wide{grid-template-columns:1fr}
  .place{padding:18px}
}
@media (max-width:480px){
  .legend li{grid-template-columns:auto 1fr}
  .legend .size{grid-column:2;text-align:left}
  .facts div{grid-template-columns:1fr;gap:0}
}
@media (prefers-reduced-motion:reduce){*{transition:none!important}}
</style>

<svg width="0" height="0" style="position:absolute" aria-hidden="true">${DEFS}</svg>

<main class="wrap" id="sheet">
  <header class="hero">
    <div class="hero-text">
      <span class="eyebrow">Mughal Garden collection · Prototype 01</span>
      <h1>Gulposh Anarkali</h1>
      <p class="lede">The embroidery for our first sample dress. Champagne-gold zardozi and dabka on ivory, with blush and sage resham filling the flowers. Every motif comes from a Mughal garden: the cusped mehrab arch, the poppy, the cypress and the jaal trellis.</p>
      <dl class="meta">
        <dt>Garment</dt><dd>Floor-length Anarkali, 16 kalis, empire waist, full sleeves</dd>
        <dt>Ground</dt><dd>Ivory raw silk bodice, ivory silk organza kalis</dd>
        <dt>Work</dt><dd>Zardozi: dabka, nakshi, sitara, moti, with pastel resham fill</dd>
        <dt>Sheet</dt><dd>Rev A · 16 Nov 2026</dd>
        <dt>Status</dt><dd><span class="status">For designer review</span></dd>
      </dl>
      <div class="viewer">
        <div class="seg" role="group" aria-label="Drawing view">
          <button type="button" id="view-render" aria-pressed="true">Embroidered</button>
          <button type="button" id="view-khaka" aria-pressed="false">Khaka line art</button>
        </div>
        <span class="hint">Khaka view shows clean outlines for tracing and pouncing. All drawings are to scale; each scale bar is 50 mm.</span>
      </div>
    </div>
    <figure class="hero-swatch" id="motif-A" style="margin:0">
      <div class="swatch">${svgInline(A, 'Mehrab panel embroidery motif')}</div>
      <figcaption class="hero-cap">
        <span class="code">A</span><h3>Mehrab panel <span class="hindi">मेहराब</span></h3>
        <p>The signature motif, worked once on every kali. A cusped Mughal arch on pearl-studded columns frames a flowering poppy plant rising from a hillock. 160 × 290 mm. This drawing has ${A.tally.moti} moti and ${A.tally.sitara} sitara. Print files: <code>svg/${A.file}.svg</code></p>
      </figcaption>
    </figure>
  </header>

  <section aria-labelledby="h-place">
    <div class="sec-head">
      <span class="eyebrow">Placement</span>
      <h2 id="h-place">Where the embroidery sits</h2>
      <p>Heaviest at the hem, lighter through the skirt, then a fine lattice on the bodice. This keeps the weight low so the kalis swing and hang straight. Hover over or tap a row to find it on the dress.</p>
    </div>
    <div class="place">
      <svg class="map" id="map" viewBox="16 24 388 552" role="img" aria-label="Front flat of the Anarkali with embroidery zones A to F">${garmentMap()}</svg>
      <div>
        <ul class="legend" id="legend">
          ${prod.map((p) => `<li tabindex="0" data-z="${p.id}"><span class="code">${p.id}</span><span><b>${p.name}</b><span class="sub">${p.where}</span></span><span class="size">${p.size.split(' · ')[0]}</span></li>`).join('')}
        </ul>
        <p class="assume">Sizes assume a 4.2 m hem, 16 kalis and 115 cm from empire waist to hem. Each kali is then about 185 mm wide at the top of the mehrab panel, which leaves a 12 mm margin each side. If the pattern changes, scale A and B by the same percentage.</p>
      </div>
    </div>
  </section>

  <section aria-labelledby="h-lib">
    <div class="sec-head">
      <span class="eyebrow">Motif library</span>
      <h2 id="h-lib">Borders, jaal and butis</h2>
      <p>Five supporting motifs share the arch, poppy and cypress of the mehrab panel, so the dress reads as one garden. They can be reused across the rest of the collection.</p>
    </div>
    <div class="library">
      ${['B', 'C', 'D', 'E', 'F'].map((id) => card(M[id], DESC[id])).join('')}
    </div>
  </section>

  <section aria-labelledby="h-pal">
    <div class="sec-head">
      <span class="eyebrow">Colours and materials</span>
      <h2 id="h-pal">Ivory, gulabi, pista and champagne gold</h2>
      <p>The pastels stay soft so the metal work leads. Hex values are for screen reference only. Match thread and metal to physical swatches under daylight.</p>
    </div>
    <div class="palette">
      <div class="chipcol"><div class="dot" style="background:${C.ground}"></div><b>Ivory raw silk</b><span>Ground fabric, bodice and kalis</span><code>${C.ground}</code></div>
      <div class="chipcol"><div class="dot" style="background:${C.blush}"></div><b>Gulabi blush</b><span>Resham: poppy side petals, blossoms, buds</span><code>${C.blush}</code></div>
      <div class="chipcol"><div class="dot" style="background:${C.blushDeep}"></div><b>Gulabi deep</b><span>Resham: poppy back petal, for depth</span><code>${C.blushDeep}</code></div>
      <div class="chipcol"><div class="dot" style="background:${C.sage}"></div><b>Pista sage</b><span>Resham: leaves and cypress</span><code>${C.sage}</code></div>
      <div class="chipcol"><div class="dot" style="background:${C.sageLight}"></div><b>Pista light</b><span>Resham: hillocks under the plants</span><code>${C.sageLight}</code></div>
      <div class="chipcol"><div class="dot" style="background:${C.aqua}"></div><b>Firozi mist</b><span>Resham: rosettes, a nod to Mughal turquoise</span><code>${C.aqua}</code></div>
      <div class="chipcol"><div class="dot metal"></div><b>Champagne gold</b><span>Dabka and nakshi. Pale champagne, not yellow gold</span><code>metal</code></div>
      <div class="chipcol"><div class="dot seq"></div><b>Rose-gold sitara</b><span>3 mm flat sequins, tacked through the centre</span><code>metal</code></div>
      <div class="chipcol"><div class="dot pearlrow"></div><b>Off-white moti</b><span>2–3 mm pearls. Off-white sits better on ivory than bright white</span><code>bead</code></div>
    </div>
  </section>

  <section aria-labelledby="h-key">
    <div class="sec-head">
      <span class="eyebrow">Stitch key</span>
      <h2 id="h-key">How to read the drawings</h2>
      <p>Each technique is drawn the same way on every motif.</p>
    </div>
    <div class="keys">
      ${keys.map((k) => `<div class="key"><div class="swatch"><svg class="motif" viewBox="0 0 ${k.W} ${k.H}" role="img" aria-label="${k.name} sample">${k.body}</svg></div><h3>${k.name} <span>· ${k.local}</span></h3><p>${k.use}</p></div>`).join('')}
    </div>
  </section>

  <section aria-labelledby="h-prod">
    <div class="sec-head">
      <span class="eyebrow">Production estimate</span>
      <h2 id="h-prod">About ${totH} karigar hours</h2>
      <p>Bead counts are taken from the drawings and multiplied out to the full garment. Hours are planning estimates for costing. Confirm them with your karigar after the sample swatch.</p>
    </div>
    <div class="tablewrap">
      <table>
        <thead><tr><th></th><th>Element</th><th>Size</th><th class="num">Quantity</th><th class="num">Moti</th><th class="num">Sitara</th><th class="num">Hours</th></tr></thead>
        <tbody>${rows}</tbody>
        <tfoot><tr><td></td><td>Whole garment</td><td></td><td></td><td class="num">${round50(totMoti).toLocaleString('en-IN')}</td><td class="num">${round50(totSit).toLocaleString('en-IN')}</td><td class="num">${totH} h</td></tr></tfoot>
      </table>
    </div>
    <div class="totals">
      <div class="total"><div class="big">${Math.ceil(totH / 24)} days</div><span>with 3 karigars on one adda, 8 hours a day</span></div>
      <div class="total"><div class="big">≈ ${(Math.round(totMoti / 100) / 10).toFixed(1)}k</div><span>pearls, plus about 10% spare</span></div>
      <div class="total"><div class="big">≈ ${(Math.round(totSit / 100) / 10).toFixed(1)}k</div><span>sequins, plus about 10% spare</span></div>
    </div>
  </section>

  <section aria-labelledby="h-next">
    <div class="twocol">
      <div>
        <div class="sec-head"><span class="eyebrow">Sampling</span><h2 id="h-next">Making the sample</h2></div>
        <ol class="steps">
          <li><span><b>Stitch a test swatch first.</b> Work panel A and 20 cm of border B on the final ivory organza before cutting the kalis.</span></li>
          <li><span><b>Transfer with the khaka.</b> Print the khaka SVGs at 100% and check the 50 mm scale bar with a ruler. Then prick the outlines and pounce with chalk or neel.</span></li>
          <li><span><b>Back the organza on the adda.</b> Tack fine cotton mulmul behind the kalis while embroidering, then trim it close afterwards. Organza alone will pucker under dabka.</span></li>
          <li><span><b>Weigh the swatch.</b> Multiply up to estimate the hem weight. If it pulls the kalis off-grain, drop the cypress fill in B to outline only.</span></li>
          <li><span><b>Approve colour in daylight.</b> Check the blush resham against the champagne dabka. The blush should look pink, not peach, next to the metal.</span></li>
        </ol>
      </div>
      <div>
        <div class="sec-head"><span class="eyebrow">Your call</span><h2>Decisions before we sample</h2></div>
        <ul class="asks">
          <li><b>Kali count and hem</b><span>16 kalis and 4.2 m are assumed. More kalis means narrower panels, so A would need resizing.</span></li>
          <li><b>Neckline shape</b><span>The drawing is a U-neck. A sweetheart or boat neck would need its own yoke drawing.</span></li>
          <li><b>Pearls</b><span>Freshwater pearls or glass pearls. This changes the cost and the weight noticeably at about ${(Math.round(totMoti / 100) / 10).toFixed(1)}k pieces.</span></li>
          <li><b>Back of the dress</b><span>Should the back bodice carry the full jaal or a lighter buti, and do we want a back neck motif?</span></li>
          <li><b>Dupatta</b><span>Border B at 60% scale with buti D scattered would match. Should it join this prototype?</span></li>
        </ul>
      </div>
    </div>
  </section>

  <footer>
    <span>Gulposh Anarkali · Embroidery design sheet Rev A</span>
    <span>Print files in <code>couture/gulposh-anarkali/svg/</code>, colour and khaka, 1:1 scale</span>
  </footer>
</main>

<script>
(function(){
  var sheet=document.getElementById('sheet'), bR=document.getElementById('view-render'), bK=document.getElementById('view-khaka');
  function setView(k){ sheet.classList.toggle('khaka',k); bR.setAttribute('aria-pressed',String(!k)); bK.setAttribute('aria-pressed',String(k)); try{localStorage.setItem('gulposh-view',k?'khaka':'render')}catch(e){} }
  bR.addEventListener('click',function(){setView(false)}); bK.addEventListener('click',function(){setView(true)});
  try{ if(localStorage.getItem('gulposh-view')==='khaka') setView(true) }catch(e){}
  var map=document.getElementById('map'), items=document.querySelectorAll('#legend li');
  function focusZone(z){
    map.classList.toggle('focus',!!z);
    map.querySelectorAll('.zone,.chip').forEach(function(el){ el.classList.toggle('on',el.getAttribute('data-z')===z) });
    items.forEach(function(li){ li.classList.toggle('on',li.getAttribute('data-z')===z) });
  }
  items.forEach(function(li){
    var z=li.getAttribute('data-z');
    li.addEventListener('mouseenter',function(){focusZone(z)});
    li.addEventListener('focus',function(){focusZone(z)});
    li.addEventListener('click',function(){focusZone(li.classList.contains('on')?null:z)});
  });
  document.getElementById('legend').addEventListener('mouseleave',function(){focusZone(null)});
  map.querySelectorAll('.chip').forEach(function(c){ c.addEventListener('click',function(){var z=c.getAttribute('data-z'); var t=document.getElementById('motif-'+z); if(t) t.scrollIntoView({behavior:'smooth',block:'center'})}); c.style.cursor='pointer' });
})();
</script>
`;
writeFileSync(join(here, 'index.html'), html);
console.log('motif tallies:', motifs.map((m) => `${m.id}: ${m.tally.moti} moti / ${m.tally.sitara} sitara`).join(' | '));
console.log('totals: hours', totH, 'moti', Math.round(totMoti), 'sitara', Math.round(totSit));
