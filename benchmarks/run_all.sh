#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

echo "============================================"
echo "  A5 Cross-Language Benchmark Suite"
echo "============================================"
echo ""

# -- Python setup (uv) -------------------------------------------------------
echo ">>> Setting up Python environment (latest pya5, a5_fast, h3, duckdb)..."
if [ ! -d ".venv" ]; then
    uv venv .venv
fi
uv pip install -U --python .venv/bin/python pya5 a5-fast h3 duckdb --quiet
echo ""

# -- JavaScript setup (npm) --------------------------------------------------
echo ">>> Setting up JavaScript environment (latest a5-js)..."
npm install a5-js@latest --save-dev --silent 2>/dev/null
echo ""

# -- R packages ---------------------------------------------------------------
echo ">>> Checking R packages against CRAN..."
Rscript -e '
  ap <- available.packages()
  for (p in c("a5R", "h3o")) {
    inst <- as.character(packageVersion(p))
    cran <- if (p %in% rownames(ap)) ap[p, "Version"] else NA
    status <- if (is.na(cran)) "" else if (package_version(inst) < package_version(cran)) "  <-- OLDER THAN CRAN, run install.packages()" else "  (latest)"
    cat(sprintf("  %s %s, CRAN %s%s\n", p, inst, cran, status))
  }'
echo ""

# -- Run benchmarks -----------------------------------------------------------
echo ">>> Running R benchmark (a5R installed + h3o)..."
Rscript bench_r.R
echo ""

echo ">>> Running R version benchmark (a5R releases)..."
Rscript bench_versions.R
echo ""

echo ">>> Running Python benchmark (pya5, a5_fast, h3-py)..."
.venv/bin/python bench_python.py
echo ""

echo ">>> Running JavaScript benchmark (a5-js)..."
node bench_js.mjs
echo ""

echo ">>> Running DuckDB benchmark (a5, h3 extensions)..."
.venv/bin/python bench_duckdb.py
echo ""

# -- Generate summary ---------------------------------------------------------
echo ">>> Generating summary..."
Rscript summarise.R
echo ""
echo "Done! See benchmarks/RESULTS.md"
