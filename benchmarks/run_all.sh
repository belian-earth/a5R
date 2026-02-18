#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

echo "============================================"
echo "  A5 Cross-Language Benchmark Suite"
echo "============================================"
echo ""

# -- Python setup (uv) -------------------------------------------------------
echo ">>> Setting up Python environment..."
if [ ! -d ".venv" ]; then
    uv venv .venv
fi
uv pip install pya5 duckdb --quiet
echo ""

# -- JavaScript setup (npm) --------------------------------------------------
echo ">>> Setting up JavaScript environment..."
if [ ! -f "node_modules/a5-js/package.json" ]; then
    npm install a5-js --save-dev --silent 2>/dev/null
fi
echo ""

# -- Run benchmarks -----------------------------------------------------------
echo ">>> Running R benchmark..."
Rscript bench_r.R
echo ""

echo ">>> Running Python benchmark..."
.venv/bin/python bench_python.py
echo ""

echo ">>> Running JavaScript benchmark..."
node bench_js.mjs
echo ""

echo ">>> Running DuckDB benchmark..."
.venv/bin/python bench_duckdb.py
echo ""

# -- Generate summary ---------------------------------------------------------
echo ">>> Generating summary..."
Rscript summarise.R
echo ""
echo "Done! See benchmarks/RESULTS.md"
