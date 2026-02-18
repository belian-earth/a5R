#!/usr/bin/env python3
"""A5 DuckDB benchmarks — uses Python duckdb bindings for precise timing."""

import json
import time
import duckdb

con = duckdb.connect()
con.execute("INSTALL a5 FROM community")
con.execute("LOAD a5")

# -- Test data ----------------------------------------------------------------
con.execute("""
    CREATE TABLE test_points AS
    SELECT
        (random() * 360 - 180)::DOUBLE AS lon,
        (random() * 170 - 85)::DOUBLE AS lat
    FROM generate_series(1, 10000)
""")
con.execute("SELECT setseed(0.42)")

con.execute("""
    CREATE TABLE test_cells AS
    SELECT *, a5_lonlat_to_cell(lon, lat, 10) AS cell_id
    FROM test_points
""")

con.execute("""
    CREATE TABLE single_cell AS
    SELECT cell_id FROM test_cells LIMIT 1
""")

con.execute("""
    CREATE TABLE children AS
    SELECT unnest(a5_cell_to_children(
        a5_cell_to_parent((SELECT cell_id FROM single_cell), 3), 5
    )) AS cell_id
""")


def bench(name, sql, iterations=10):
    times = []
    for _ in range(iterations):
        t0 = time.perf_counter()
        con.execute(sql).fetchall()
        t1 = time.perf_counter()
        times.append((t1 - t0) * 1000)
    times.sort()
    median_ms = times[len(times) // 2]
    return {"operation": name, "median_ms": round(median_ms, 3), "mem_alloc_kb": 0}


# -- Benchmarks ---------------------------------------------------------------
results = []

results.append(bench(
    "lonlat_to_cell",
    "SELECT a5_lonlat_to_cell(lon, lat, 10) FROM test_points"
))

results.append(bench(
    "cell_to_lonlat",
    "SELECT a5_cell_to_lonlat(cell_id) FROM test_cells"
))

results.append(bench(
    "cell_to_boundary",
    "SELECT a5_cell_to_boundary(cell_id) FROM test_cells"
))

results.append(bench(
    "get_resolution",
    "SELECT a5_get_resolution(cell_id) FROM test_cells"
))

results.append(bench(
    "cell_to_parent",
    "SELECT a5_cell_to_parent(cell_id, 9) FROM test_cells"
))

results.append(bench(
    "cell_to_children",
    "SELECT a5_cell_to_children((SELECT cell_id FROM single_cell), 12)"
))

results.append(bench(
    "compact",
    "SELECT a5_compact(list(cell_id)) FROM children"
))

results.append(bench(
    "uncompact",
    "SELECT a5_uncompact(a5_compact(list(cell_id)), 5) FROM children"
))

results.append(bench(
    "cell_area",
    "SELECT a5_cell_area(r::INTEGER) FROM generate_series(0, 30) t(r)"
))

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
    SELECT list_sort(
        list_transform(a5_cell_to_children(a5_lonlat_to_cell(-3.19, 55.95, 5)),
                       x -> printf('%016llx', x))
    ) AS children
""").fetchone()

ref = {
    "cell": row[0],
    "lon": row[1][0],
    "lat": row[1][1],
    "parent": row[2],
    "children": children_row[0],
    "area_m2": row[3],
    "resolution": row[4],
}

# -- Output -------------------------------------------------------------------
print("=== BENCHMARK RESULTS (DuckDB / a5 extension) ===")
for r in results:
    print(f"  {r['operation']:20s}  {r['median_ms']:10.3f} ms")

print("\n=== REFERENCE VALUES ===")
print(json.dumps(ref, indent=2))

with open("/home/hugh/belian/a5R/benchmarks/results_duckdb.json", "w") as f:
    json.dump({"lang": "DuckDB", "results": results, "reference": ref}, f, indent=2)

con.close()
