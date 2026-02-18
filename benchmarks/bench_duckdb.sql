-- A5 DuckDB benchmarks
-- Run with: duckdb < bench_duckdb.sql

INSTALL a5 FROM community;
LOAD a5;

-- Generate test data (10k random points)
CREATE OR REPLACE TABLE test_points AS
SELECT
    setseed(0.42),
    random() * 360 - 180 AS lon,
    random() * 170 - 85 AS lat
FROM generate_series(1, 10000);

-- Pre-compute cells
CREATE OR REPLACE TABLE test_cells AS
SELECT *, a5_lonlat_to_cell(lon, lat, 10) AS cell_id
FROM test_points;

-- Single cell for hierarchy tests
CREATE OR REPLACE TABLE single_cell AS
SELECT cell_id FROM test_cells LIMIT 1;

-- Pre-compute children for compact benchmark
CREATE OR REPLACE TABLE children AS
SELECT unnest(a5_cell_to_children(
    a5_cell_to_parent((SELECT cell_id FROM single_cell), 3), 5
)) AS cell_id;

-- ============================================================================
-- Benchmarks (using epoch_ms timing)
-- ============================================================================

.timer on

-- lonlat_to_cell
SELECT 'lonlat_to_cell' AS op;
SELECT a5_lonlat_to_cell(lon, lat, 10) FROM test_points;

-- cell_to_lonlat
SELECT 'cell_to_lonlat' AS op;
SELECT a5_cell_to_lonlat(cell_id) FROM test_cells;

-- cell_to_boundary
SELECT 'cell_to_boundary' AS op;
SELECT a5_cell_to_boundary(cell_id) FROM test_cells;

-- get_resolution
SELECT 'get_resolution' AS op;
SELECT a5_get_resolution(cell_id) FROM test_cells;

-- cell_to_parent
SELECT 'cell_to_parent' AS op;
SELECT a5_cell_to_parent(cell_id, 9) FROM test_cells;

-- cell_to_children
SELECT 'cell_to_children' AS op;
SELECT a5_cell_to_children((SELECT cell_id FROM single_cell), 12);

-- compact
SELECT 'compact' AS op;
SELECT a5_compact(list(cell_id)) FROM children;

-- uncompact
SELECT 'uncompact' AS op;
SELECT a5_uncompact(a5_compact(list(cell_id)), 5) FROM children;

-- cell_area
SELECT 'cell_area' AS op;
SELECT a5_cell_area(r) FROM generate_series(0, 30) t(r);

.timer off

-- ============================================================================
-- Reference values
-- ============================================================================
SELECT '=== REFERENCE VALUES ===' AS msg;

SELECT
    printf('%016llx', a5_lonlat_to_cell(-3.19, 55.95, 5)) AS cell,
    a5_cell_to_lonlat(a5_lonlat_to_cell(-3.19, 55.95, 5)) AS lonlat,
    printf('%016llx', a5_cell_to_parent(a5_lonlat_to_cell(-3.19, 55.95, 5), 4)) AS parent,
    a5_cell_area(5) AS area_m2,
    a5_get_resolution(a5_lonlat_to_cell(-3.19, 55.95, 5)) AS resolution;
