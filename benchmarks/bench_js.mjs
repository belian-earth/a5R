#!/usr/bin/env node
/**
 * A5 JavaScript benchmarks — outputs JSON for cross-language comparison.
 */
import {
  lonLatToCell, cellToLonLat, cellToBoundary,
  getResolution, cellToParent, cellToChildren,
  compact, uncompact, cellArea, u64ToHex
} from 'a5-js';
import { writeFileSync } from 'fs';

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
  return { operation: name, median_ms: Math.round(median * 1000) / 1000, mem_alloc_kb: 0 };
}

// -- Pre-compute data --------------------------------------------------------
const cells = lons.map((lon, i) => lonLatToCell([lon, lats[i]], RES));
const singleCell = cells[0];
const parentCell = cellToParent(singleCell, 3);
const children = cellToChildren(parentCell, 5);

// -- Benchmarks --------------------------------------------------------------
const results = [];

results.push(bench("lonlat_to_cell", () => {
  for (let i = 0; i < N; i++) lonLatToCell([lons[i], lats[i]], RES);
}));

results.push(bench("cell_to_lonlat", () => {
  for (const c of cells) cellToLonLat(c);
}));

results.push(bench("cell_to_boundary", () => {
  for (const c of cells) cellToBoundary(c);
}));

results.push(bench("get_resolution", () => {
  for (const c of cells) getResolution(c);
}));

results.push(bench("cell_to_parent", () => {
  for (const c of cells) cellToParent(c);
}));

results.push(bench("cell_to_children", () => {
  cellToChildren(singleCell, RES + 2);
}));

results.push(bench("compact", () => {
  compact(children);
}));

results.push(bench("uncompact", () => {
  uncompact(compact(children), 5);
}));

results.push(bench("cell_area", () => {
  for (let r = 0; r <= 30; r++) cellArea(r);
}));

// -- Correctness reference values --------------------------------------------
const refCell = lonLatToCell([-3.19, 55.95], 5);
const refLonLat = cellToLonLat(refCell);
const refParent = cellToParent(refCell);
const refChildren = cellToChildren(refCell);
const refArea = cellArea(5);

const ref = {
  cell: u64ToHex(refCell),
  lon: refLonLat[0],
  lat: refLonLat[1],
  parent: u64ToHex(refParent),
  children: refChildren.map(c => u64ToHex(c)).sort(),
  area_m2: refArea,
  resolution: getResolution(refCell),
};

// -- Output ------------------------------------------------------------------
console.log("=== BENCHMARK RESULTS (JavaScript / a5-js) ===");
for (const r of results) {
  console.log(`  ${r.operation.padEnd(20)}  ${r.median_ms.toFixed(3).padStart(10)} ms`);
}
console.log("\n=== REFERENCE VALUES ===");
console.log(JSON.stringify(ref, null, 2));

writeFileSync(
  "/home/hugh/belian/a5R/benchmarks/results_js.json",
  JSON.stringify({ lang: "JavaScript", results, reference: ref }, null, 2)
);
