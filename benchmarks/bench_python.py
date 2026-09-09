#!/usr/bin/env python3
"""A5 Python benchmarks: pya5, a5_fast and h3-py.

Outputs results_python.json (pya5 bulk + per-call for all three) and
results_python_a5fast.json (a5_fast bulk) for cross-language comparison.
"""

import importlib.metadata as meta
import json

import a5
import a5_fast
import h3

from bench_common import (A5_RES, BENCH_DIR, COORD, H3_RES, K, LATS, LONS, N,
                          POLYGON, RES, bench, percall, print_percall)

PYA5_V = f"pya5 {meta.version('pya5')}"
FAST_V = f"a5_fast {meta.version('a5-fast')}"
H3_V = f"h3-py {meta.version('h3')}"

# -- Pre-compute data for bulk benchmarks -------------------------------------
cells = [a5.lonlat_to_cell((LONS[i], LATS[i]), RES) for i in range(N)]
single_cell = cells[0]
parent_cell = a5.cell_to_parent(single_cell, 3)
children = a5.cell_to_children(parent_cell, 5)


def bulk_suite(m, parent_res_arg):
    """Bulk operations against module m (pya5 or a5_fast, same API shape)."""
    if m is a5:
        to_cell = lambda i: m.lonlat_to_cell((LONS[i], LATS[i]), RES)
    else:
        to_cell = lambda i: m.lonlat_to_cell(LONS[i], LATS[i], RES)
    return [
        bench("lonlat_to_cell", lambda: [to_cell(i) for i in range(N)]),
        bench("cell_to_lonlat", lambda: [m.cell_to_lonlat(c) for c in cells]),
        bench("cell_to_boundary", lambda: [m.cell_to_boundary(c) for c in cells]),
        bench("get_resolution", lambda: [m.get_resolution(c) for c in cells]),
        bench("cell_to_parent", lambda: [m.cell_to_parent(c, *parent_res_arg) for c in cells]),
        bench("cell_to_children", lambda: m.cell_to_children(single_cell, RES + 2)),
        bench("compact", lambda: m.compact(children)),
        bench("uncompact", lambda: m.uncompact(m.compact(children), 5)),
        bench("cell_area", lambda: [m.cell_area(r) for r in range(31)]),
    ]


def reference(m, parent_res_arg):
    ref_cell = m.lonlat_to_cell((-3.19, 55.95), 5) if m is a5 else m.lonlat_to_cell(-3.19, 55.95, 5)
    ref_lonlat = m.cell_to_lonlat(ref_cell)
    return {
        "cell": m.u64_to_hex(ref_cell),
        "lon": ref_lonlat[0],
        "lat": ref_lonlat[1],
        "parent": m.u64_to_hex(m.cell_to_parent(ref_cell, *parent_res_arg)),
        "children": sorted(m.u64_to_hex(c) for c in m.cell_to_children(ref_cell, 6)),
        "area_m2": m.cell_area(5),
        "resolution": m.get_resolution(ref_cell),
    }


# -- Bulk: pya5 (pure Python) and a5_fast (Rust) ------------------------------
# a5_fast requires an explicit parent resolution; pya5 defaults to res - 1.
results_pya5 = bulk_suite(a5, ())
ref_pya5 = reference(a5, ())
results_fast = bulk_suite(a5_fast, (RES - 1,))
ref_fast = reference(a5_fast, (4,))

# -- Per-call: Takashi's micro-benchmark -------------------------------------
pc = []

cell = a5.lonlat_to_cell(COORD, A5_RES)
disk_n = len(a5.grid_disk(cell, K))
poly_n = len(a5.polygon_to_cells(POLYGON, A5_RES))
pc.append(percall(PYA5_V, "Python", "lonlat_to_cell", lambda: a5.lonlat_to_cell(COORD, A5_RES), 1))
pc.append(percall(PYA5_V, "Python", "grid_disk", lambda: a5.grid_disk(cell, K), disk_n))
pc.append(percall(PYA5_V, "Python", "polygon_to_cells", lambda: a5.polygon_to_cells(POLYGON, A5_RES), poly_n))

fcell = a5_fast.lonlat_to_cell(COORD[0], COORD[1], A5_RES)
fdisk_n = len(a5_fast.grid_disk(fcell, K))
pc.append(percall(FAST_V, "Python", "lonlat_to_cell", lambda: a5_fast.lonlat_to_cell(COORD[0], COORD[1], A5_RES), 1))
pc.append(percall(FAST_V, "Python", "grid_disk", lambda: a5_fast.grid_disk(fcell, K), fdisk_n))
# a5_fast has no polygon_to_cells.

# h3-py: LatLngPoly takes (lat, lng) pairs, so the polygon is swapped.
h3cell = h3.latlng_to_cell(COORD[1], COORD[0], H3_RES)
h3poly = h3.LatLngPoly([(lat, lon) for lon, lat in POLYGON])
h3disk_n = len(h3.grid_disk(h3cell, K))
h3poly_n = len(h3.polygon_to_cells(h3poly, H3_RES))
pc.append(percall(H3_V, "Python", "lonlat_to_cell", lambda: h3.latlng_to_cell(COORD[1], COORD[0], H3_RES), 1))
pc.append(percall(H3_V, "Python", "grid_disk", lambda: h3.grid_disk(h3cell, K), h3disk_n))
pc.append(percall(H3_V, "Python", "polygon_to_cells", lambda: h3.polygon_to_cells(h3poly, H3_RES), h3poly_n))

percall_ref = {
    PYA5_V: {"cell": a5.u64_to_hex(cell), "grid_disk_n": disk_n, "polygon_n": poly_n},
    FAST_V: {"cell": a5_fast.u64_to_hex(fcell), "grid_disk_n": fdisk_n, "polygon_n": None},
}

# -- Output -------------------------------------------------------------------
for label, rows in [(PYA5_V, results_pya5), (FAST_V, results_fast)]:
    print(f"=== BULK RESULTS ({label}) ===")
    for r in rows:
        print(f"  {r['operation']:20s}  {r['median_ms']:10.3f} ms")
print_percall(pc)
print("\n=== REFERENCE VALUES (pya5) ===")
print(json.dumps(ref_pya5, indent=2))

with open(f"{BENCH_DIR}/results_python.json", "w") as f:
    json.dump({"lang": "Python", "impl": PYA5_V, "results": results_pya5,
               "reference": ref_pya5, "percall": pc, "percall_ref": percall_ref}, f, indent=2)
with open(f"{BENCH_DIR}/results_python_a5fast.json", "w") as f:
    json.dump({"lang": "Python (a5_fast)", "impl": FAST_V, "results": results_fast,
               "reference": ref_fast}, f, indent=2)
