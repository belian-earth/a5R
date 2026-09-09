#!/usr/bin/env python3
"""A5 DuckDB benchmarks (a5 and h3 community extensions).

Uses the Python duckdb bindings for precise timing. Per-call figures include
SQL parse, plan and execute overhead for a one-row query.
"""

import json

import duckdb

from bench_common import (A5_RES, BENCH_DIR, COORD, H3_RES, K, POLYGON_WKT,
                          bench, percall, print_percall)

con = duckdb.connect()
con.execute("INSTALL a5 FROM community; LOAD a5;")
con.execute("INSTALL h3 FROM community; LOAD h3;")

ext = dict(con.execute(
    "SELECT extension_name, extension_version FROM duckdb_extensions() WHERE extension_name IN ('a5', 'h3')"
).fetchall())
A5_V = f"duckdb-a5 {ext['a5']}"
H3_V = f"duckdb-h3 {ext['h3']}"

# -- Test data ----------------------------------------------------------------
con.execute("SELECT setseed(0.42)")
con.execute("""
    CREATE TABLE test_points AS
    SELECT
        (random() * 360 - 180)::DOUBLE AS lon,
        (random() * 170 - 85)::DOUBLE AS lat
    FROM generate_series(1, 10000)
""")
con.execute("CREATE TABLE test_cells AS SELECT *, a5_lonlat_to_cell(lon, lat, 10) AS cell_id FROM test_points")
con.execute("CREATE TABLE single_cell AS SELECT cell_id FROM test_cells LIMIT 1")
con.execute("""
    CREATE TABLE children AS
    SELECT unnest(a5_cell_to_children(
        a5_cell_to_parent((SELECT cell_id FROM single_cell), 3), 5
    )) AS cell_id
""")


def q(sql):
    return lambda: con.execute(sql).fetchall()


# -- Bulk benchmarks ----------------------------------------------------------
results = [
    bench("lonlat_to_cell", q("SELECT a5_lonlat_to_cell(lon, lat, 10) FROM test_points")),
    bench("cell_to_lonlat", q("SELECT a5_cell_to_lonlat(cell_id) FROM test_cells")),
    bench("cell_to_boundary", q("SELECT a5_cell_to_boundary(cell_id) FROM test_cells")),
    bench("get_resolution", q("SELECT a5_get_resolution(cell_id) FROM test_cells")),
    bench("cell_to_parent", q("SELECT a5_cell_to_parent(cell_id, 9) FROM test_cells")),
    bench("cell_to_children", q("SELECT a5_cell_to_children((SELECT cell_id FROM single_cell), 12)")),
    bench("compact", q("SELECT a5_compact(list(cell_id)) FROM children")),
    bench("uncompact", q("SELECT a5_uncompact(a5_compact(list(cell_id)), 5) FROM children")),
    bench("cell_area", q("SELECT a5_cell_area(r::INTEGER) FROM generate_series(0, 30) t(r)")),
]

# -- Per-call benchmarks ------------------------------------------------------
lon, lat = COORD
a5_pt = f"SELECT a5_lonlat_to_cell({lon!r}, {lat!r}, {A5_RES})"
a5_disk = f"SELECT a5_grid_disk(a5_lonlat_to_cell({lon!r}, {lat!r}, {A5_RES}), {K})"
a5_poly = f"SELECT a5_geometry_to_cells('{POLYGON_WKT}'::GEOMETRY, {A5_RES})"
h3_pt = f"SELECT h3_latlng_to_cell({lat!r}, {lon!r}, {H3_RES})"
h3_disk = f"SELECT h3_grid_disk(h3_latlng_to_cell({lat!r}, {lon!r}, {H3_RES}), {K})"
h3_poly = f"SELECT h3_polygon_wkt_to_cells('{POLYGON_WKT}', {H3_RES})"

a5_cell_hex = con.execute(f"SELECT printf('%016llx', a5_lonlat_to_cell({lon!r}, {lat!r}, {A5_RES}))").fetchone()[0]
a5_disk_n = len(con.execute(a5_disk).fetchone()[0])
a5_poly_n = len(con.execute(a5_poly).fetchone()[0])
h3_disk_n = len(con.execute(h3_disk).fetchone()[0])
h3_poly_n = len(con.execute(h3_poly).fetchone()[0])

pc = [
    percall(A5_V, "DuckDB", "lonlat_to_cell", q(a5_pt), 1),
    percall(A5_V, "DuckDB", "grid_disk", q(a5_disk), a5_disk_n),
    percall(A5_V, "DuckDB", "polygon_to_cells", q(a5_poly), a5_poly_n),
    percall(H3_V, "DuckDB", "lonlat_to_cell", q(h3_pt), 1),
    percall(H3_V, "DuckDB", "grid_disk", q(h3_disk), h3_disk_n),
    percall(H3_V, "DuckDB", "polygon_to_cells", q(h3_poly), h3_poly_n),
]
percall_ref = {A5_V: {"cell": a5_cell_hex, "grid_disk_n": a5_disk_n, "polygon_n": a5_poly_n}}

# -- Reference values ---------------------------------------------------------
row = con.execute("""
    SELECT
        printf('%016llx', a5_lonlat_to_cell(-3.19, 55.95, 5)) AS cell,
        a5_cell_to_lonlat(a5_lonlat_to_cell(-3.19, 55.95, 5)) AS lonlat,
        printf('%016llx', a5_cell_to_parent(a5_lonlat_to_cell(-3.19, 55.95, 5), 4)) AS parent,
        a5_cell_area(5) AS area_m2,
        a5_get_resolution(a5_lonlat_to_cell(-3.19, 55.95, 5)) AS resolution
""").fetchone()
children_row = con.execute("""
    SELECT list_sort(list_transform(a5_cell_to_children(a5_lonlat_to_cell(-3.19, 55.95, 5)),
                                    x -> printf('%016llx', x)))
""").fetchone()
ref = {"cell": row[0], "lon": row[1][0], "lat": row[1][1], "parent": row[2],
       "children": children_row[0], "area_m2": row[3], "resolution": row[4]}

# -- Output -------------------------------------------------------------------
print(f"=== BULK RESULTS ({A5_V}, duckdb {duckdb.__version__}) ===")
for r in results:
    print(f"  {r['operation']:20s}  {r['median_ms']:10.3f} ms")
print_percall(pc)
print("\n=== REFERENCE VALUES ===")
print(json.dumps(ref, indent=2))

with open(f"{BENCH_DIR}/results_duckdb.json", "w") as f:
    json.dump({"lang": "DuckDB", "impl": f"{A5_V} (duckdb {duckdb.__version__})",
               "results": results, "reference": ref,
               "percall": pc, "percall_ref": percall_ref}, f, indent=2)
con.close()
