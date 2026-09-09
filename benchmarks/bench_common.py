"""Shared parameters for the Python benchmark scripts.

Per-call parameters follow the micro-benchmark written by Takashi (a5
contributor) comparing pya5, a5_fast and h3-py: a Tokyo point, a5
resolution 12 / H3 resolution 8, grid_disk k = 10, and a 7-vertex
Hiroshima polygon. Bulk parameters (10k random points at resolution 10)
are the original cross-language benchmark.
"""

import random
import time

BENCH_DIR = "/home/hugh/belian/a5R/benchmarks"

# -- Bulk ---------------------------------------------------------------------
N = 10_000
RES = 10
random.seed(42)
LONS = [random.uniform(-180, 180) for _ in range(N)]
LATS = [random.uniform(-85, 85) for _ in range(N)]

# -- Per-call -----------------------------------------------------------------
COORD = (139.70033506856208, 35.690624903733436)  # (lon, lat), Tokyo
A5_RES = 12
H3_RES = 8
K = 10
POLYGON = [  # (lon, lat)
    [132.3555094, 34.3465028],
    [132.4945511, 34.3288744],
    [132.5876105, 34.4237528],
    [132.6023905, 34.5338573],
    [132.4075132, 34.5600083],
    [132.2920101, 34.5022848],
    [132.2575233, 34.4065923],
    [132.3555094, 34.3465028],
]
POLYGON_WKT = "POLYGON ((" + ", ".join(f"{x:.7f} {y:.7f}" for x, y in POLYGON) + "))"

# Iterations per operation; slow pure-Python ops get fewer.
PERCALL_N = {"lonlat_to_cell": 1000, "grid_disk": 200, "polygon_to_cells": 200}


def bench(name, fn, iterations=10):
    """Bulk: median wall time in ms over `iterations` runs of fn()."""
    times = []
    for _ in range(iterations):
        t0 = time.perf_counter()
        fn()
        t1 = time.perf_counter()
        times.append((t1 - t0) * 1000)
    times.sort()
    return {"operation": name, "median_ms": round(times[len(times) // 2], 3)}


def percall(impl, lang, name, fn, n_cells, repeats=3):
    """Per-call: median over `repeats` of the mean µs per call across n calls."""
    n = PERCALL_N[name]
    per = []
    for _ in range(repeats):
        t0 = time.perf_counter()
        for _ in range(n):
            fn()
        per.append((time.perf_counter() - t0) / n * 1e6)
    per.sort()
    return {"impl": impl, "lang": lang, "operation": name,
            "median_us": round(per[len(per) // 2], 3), "n_cells": n_cells}


def print_percall(rows):
    print("\n=== PER-CALL RESULTS (µs per call) ===")
    for r in rows:
        print(f"  {r['impl']:16s} {r['operation']:18s} {r['median_us']:12.2f} µs  ({r['n_cells']} cells)")
