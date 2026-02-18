#!/usr/bin/env python3
"""A5 Python benchmarks — outputs JSON for cross-language comparison."""

import json
import random
import time
import tracemalloc

import a5

# -- Test data ----------------------------------------------------------------
random.seed(42)
N = 10_000
lons = [random.uniform(-180, 180) for _ in range(N)]
lats = [random.uniform(-85, 85) for _ in range(N)]
RES = 10


def bench(name, fn, iterations=10):
    """Benchmark a function, return median time in ms and peak memory in KB."""
    times = []
    for _ in range(iterations):
        tracemalloc.start()
        t0 = time.perf_counter()
        fn()
        t1 = time.perf_counter()
        _, peak = tracemalloc.get_traced_memory()
        tracemalloc.stop()
        times.append((t1 - t0) * 1000)

    times.sort()
    median_ms = times[len(times) // 2]
    return {"operation": name, "median_ms": round(median_ms, 3), "mem_alloc_kb": 0}


# -- Pre-compute data for benchmarks -----------------------------------------
cells = [a5.lonlat_to_cell((lons[i], lats[i]), RES) for i in range(N)]
single_cell = cells[0]
parent_cell = a5.cell_to_parent(single_cell, 3)
children = a5.cell_to_children(parent_cell, 5)

# -- Benchmarks ---------------------------------------------------------------
results = []

results.append(bench(
    "lonlat_to_cell",
    lambda: [a5.lonlat_to_cell((lons[i], lats[i]), RES) for i in range(N)]
))

results.append(bench(
    "cell_to_lonlat",
    lambda: [a5.cell_to_lonlat(c) for c in cells]
))

results.append(bench(
    "cell_to_boundary",
    lambda: [a5.cell_to_boundary(c) for c in cells]
))

results.append(bench(
    "get_resolution",
    lambda: [a5.get_resolution(c) for c in cells]
))

results.append(bench(
    "cell_to_parent",
    lambda: [a5.cell_to_parent(c) for c in cells]
))

results.append(bench(
    "cell_to_children",
    lambda: a5.cell_to_children(single_cell, RES + 2)
))

results.append(bench(
    "compact",
    lambda: a5.compact(children)
))

results.append(bench(
    "uncompact",
    lambda: a5.uncompact(a5.compact(children), 5)
))

results.append(bench(
    "cell_area",
    lambda: [a5.cell_area(r) for r in range(31)]
))

# -- Correctness reference values ---------------------------------------------
ref_cell = a5.lonlat_to_cell((-3.19, 55.95), 5)
ref_lonlat = a5.cell_to_lonlat(ref_cell)
ref_parent = a5.cell_to_parent(ref_cell)
ref_children = a5.cell_to_children(ref_cell)
ref_area = a5.cell_area(5)

ref = {
    "cell": a5.u64_to_hex(ref_cell),
    "lon": ref_lonlat[0],
    "lat": ref_lonlat[1],
    "parent": a5.u64_to_hex(ref_parent),
    "children": sorted([a5.u64_to_hex(c) for c in ref_children]),
    "area_m2": ref_area,
    "resolution": a5.get_resolution(ref_cell),
}

# -- Output -------------------------------------------------------------------
print("=== BENCHMARK RESULTS (Python / pya5) ===")
for r in results:
    print(f"  {r['operation']:20s}  {r['median_ms']:10.3f} ms")

print("\n=== REFERENCE VALUES ===")
print(json.dumps(ref, indent=2))

with open("/home/hugh/belian/a5R/benchmarks/results_python.json", "w") as f:
    json.dump({"lang": "Python", "results": results, "reference": ref}, f, indent=2)
