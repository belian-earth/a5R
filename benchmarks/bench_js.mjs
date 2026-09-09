#!/usr/bin/env node
/**
 * A5 JavaScript benchmarks (a5-js) — outputs JSON for cross-language comparison.
 */
import {
  lonLatToCell, cellToLonLat, cellToBoundary,
  getResolution, cellToParent, cellToChildren,
  compact, uncompact, cellArea, u64ToHex,
  gridDisk, polygonToCells
} from 'a5-js';
import { writeFileSync, readFileSync } from 'fs';

const IMPL = `a5-js ${JSON.parse(readFileSync(new URL('./node_modules/a5-js/package.json', import.meta.url))).version}`;

// -- Test data ---------------------------------------------------------------
// Simple seeded PRNG (mulberry32)
function mulberry32(seed) {
  return function () {
    seed |= 0; seed = seed + 0x6D2B79F5 | 0;
    let t = Math.imul(seed ^ seed >>> 15, 1 | seed);
    t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t;
    return ((t ^ t >>> 14) >>> 0) / 4294967296;
  };
}

const rand = mulberry32(42);
const N = 10_000;
const RES = 10;
const lons = Array.from({ length: N }, () => rand() * 360 - 180);
const lats = Array.from({ length: N }, () => rand() * 170 - 85);

// Per-call parameters (Takashi's micro-benchmark)
const COORD = [139.70033506856208, 35.690624903733436];
const A5_RES = 12;
const K = 10;
const POLYGON = [
  [132.3555094, 34.3465028], [132.4945511, 34.3288744], [132.5876105, 34.4237528],
  [132.6023905, 34.5338573], [132.4075132, 34.5600083], [132.2920101, 34.5022848],
  [132.2575233, 34.4065923], [132.3555094, 34.3465028]
];
const PERCALL_N = { lonlat_to_cell: 1000, grid_disk: 200, polygon_to_cells: 200 };

function bench(name, fn, iterations = 10) {
  const times = [];
  for (let i = 0; i < iterations; i++) {
    const t0 = performance.now();
    fn();
    const t1 = performance.now();
    times.push(t1 - t0);
  }
  times.sort((a, b) => a - b);
  const median = times[Math.floor(times.length / 2)];
  return { operation: name, median_ms: Math.round(median * 1000) / 1000 };
}

function percall(name, fn, nCells, repeats = 3) {
  const n = PERCALL_N[name];
  const per = [];
  for (let r = 0; r < repeats; r++) {
    const t0 = performance.now();
    for (let i = 0; i < n; i++) fn();
    per.push((performance.now() - t0) / n * 1000);
  }
  per.sort((a, b) => a - b);
  return { impl: IMPL, lang: 'JavaScript', operation: name,
           median_us: Math.round(per[Math.floor(per.length / 2)] * 1000) / 1000, n_cells: nCells };
}

// -- Pre-compute data --------------------------------------------------------
const cells = lons.map((lon, i) => lonLatToCell([lon, lats[i]], RES));
const singleCell = cells[0];
const parentCell = cellToParent(singleCell, 3);
const children = cellToChildren(parentCell, 5);

// -- Bulk benchmarks ---------------------------------------------------------
const results = [];

results.push(bench("lonlat_to_cell", () => {
  for (let i = 0; i < N; i++) lonLatToCell([lons[i], lats[i]], RES);
}));
results.push(bench("cell_to_lonlat", () => { for (const c of cells) cellToLonLat(c); }));
results.push(bench("cell_to_boundary", () => { for (const c of cells) cellToBoundary(c); }));
results.push(bench("get_resolution", () => { for (const c of cells) getResolution(c); }));
results.push(bench("cell_to_parent", () => { for (const c of cells) cellToParent(c); }));
results.push(bench("cell_to_children", () => { cellToChildren(singleCell, RES + 2); }));
results.push(bench("compact", () => { compact(children); }));
results.push(bench("uncompact", () => { uncompact(compact(children), 5); }));
results.push(bench("cell_area", () => { for (let r = 0; r <= 30; r++) cellArea(r); }));

// -- Per-call benchmarks -----------------------------------------------------
const cell = lonLatToCell(COORD, A5_RES);
const diskN = gridDisk(cell, K).length;
const polyN = polygonToCells(POLYGON, A5_RES).length;
const percallRows = [
  percall("lonlat_to_cell", () => lonLatToCell(COORD, A5_RES), 1),
  percall("grid_disk", () => gridDisk(cell, K), diskN),
  percall("polygon_to_cells", () => polygonToCells(POLYGON, A5_RES), polyN),
];
const percallRef = { [IMPL]: { cell: u64ToHex(cell), grid_disk_n: diskN, polygon_n: polyN } };

// -- Correctness reference values --------------------------------------------
const refCell = lonLatToCell([-3.19, 55.95], 5);
const refLonLat = cellToLonLat(refCell);
const ref = {
  cell: u64ToHex(refCell),
  lon: refLonLat[0],
  lat: refLonLat[1],
  parent: u64ToHex(cellToParent(refCell)),
  children: cellToChildren(refCell).map(c => u64ToHex(c)).sort(),
  area_m2: cellArea(5),
  resolution: getResolution(refCell),
};

// -- Output ------------------------------------------------------------------
console.log(`=== BULK RESULTS (${IMPL}) ===`);
for (const r of results) {
  console.log(`  ${r.operation.padEnd(20)}  ${r.median_ms.toFixed(3).padStart(10)} ms`);
}
console.log("\n=== PER-CALL RESULTS (µs per call) ===");
for (const r of percallRows) {
  console.log(`  ${r.impl.padEnd(16)} ${r.operation.padEnd(18)} ${r.median_us.toFixed(2).padStart(12)} µs  (${r.n_cells} cells)`);
}
console.log("\n=== REFERENCE VALUES ===");
console.log(JSON.stringify(ref, null, 2));

writeFileSync(
  "/home/hugh/belian/a5R/benchmarks/results_js.json",
  JSON.stringify({ lang: "JavaScript", impl: IMPL, results, reference: ref,
                   percall: percallRows, percall_ref: percallRef }, null, 2)
);
