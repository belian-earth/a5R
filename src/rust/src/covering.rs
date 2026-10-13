use extendr_api::prelude::*;
use extendr_api::wrapper::Nullable;
use rayon::prelude::*;

use crate::cell_raw::{collect_ids, map_cells, u64s_to_raw8_list, with_marker, CellSlices};
use crate::threading::{get_num_threads, maybe_par};
use a5::core::serialization::{cell_first_slot, cell_slot_count};

// --- Covering storage ---
//
// An `a5_covering` is an R list with one element per covering: a raw vector
// of the covering's u64 values, little-endian, exactly as upstream returns
// them (cells in curve order, then the compaction marker), or NULL for a
// missing covering. Unlike `a5_cell`, no byte is masked: a covering never
// holds NA.

/// The values of every covering in `x`, or None for a missing covering.
pub(crate) fn read_coverings(x: &List) -> Vec<Option<Vec<u64>>> {
    x.values()
        .map(|robj| {
            robj.as_raw_slice().map(|bytes| {
                bytes
                    .chunks_exact(8)
                    .map(|b| u64::from_le_bytes(b.try_into().unwrap()))
                    .collect()
            })
        })
        .collect()
}

/// One covering as an R raw vector.
fn covering_to_raw(values: &[u64]) -> Robj {
    let mut bytes = Vec::with_capacity(8 * values.len());
    for v in values {
        bytes.extend_from_slice(&v.to_le_bytes());
    }
    Robj::from(bytes.as_slice())
}

/// Coverings as the R list underlying an `a5_covering` (class set in R).
/// None becomes NULL; an error is raised as an R error prefixed by `name`.
pub(crate) fn coverings_to_list(
    name: &str,
    results: Vec<Option<std::result::Result<Vec<u64>, String>>>,
) -> List {
    let elements: Vec<Robj> = results
        .into_iter()
        .map(|r| match r {
            Some(Ok(values)) => covering_to_raw(&values),
            Some(Err(e)) => throw_r_error(format!("{} failed: {}", name, e)),
            None => ().into(),
        })
        .collect();
    List::from_values(elements)
}

/// Apply `f` to every covering, parallelising when threads > 1. Missing
/// coverings stay None.
pub(crate) fn map_coverings<T, F>(x: &List, f: F) -> Vec<Option<T>>
where
    T: Send,
    F: Fn(&[u64]) -> T + Send + Sync,
{
    let inputs = read_coverings(x);
    if get_num_threads() <= 1 {
        inputs.iter().map(|c| c.as_deref().map(&f)).collect()
    } else {
        maybe_par(|| inputs.par_iter().map(|c| c.as_deref().map(&f)).collect())
    }
}

/// Apply a covering-returning function to every cell: one covering per
/// cell, None for an NA cell.
pub(crate) fn cells_to_coverings<F>(cells: &List, name: &str, f: F) -> List
where
    F: Fn(u64) -> std::result::Result<Vec<u64>, String> + Send + Sync,
{
    coverings_to_list(name, map_cells(cells, |id| Some(f(id))))
}

/// The covering of `cells` at `resolution`, or at their finest resolution
/// when None. Errors if a cell is finer than `resolution`.
pub(crate) fn cells_to_covering(
    cells: Vec<u64>,
    resolution: Option<i32>,
) -> std::result::Result<Vec<u64>, String> {
    match resolution {
        None => a5::compact(&cells),
        Some(r) => {
            check_not_finer(&cells, r)?;
            a5::compact(&with_marker(cells, r))
        }
    }
}

fn check_not_finer(cells: &[u64], resolution: i32) -> std::result::Result<(), String> {
    for &cell in cells {
        if a5::is_compaction_marker(cell) {
            continue;
        }
        let r = a5::get_resolution(cell);
        if r > resolution {
            return Err(format!(
                "a cell at resolution {} is finer than resolution {}",
                r, resolution
            ));
        }
    }
    Ok(())
}

/// Whether a covering is well formed: every value but a trailing compaction
/// marker is a valid cell, no cell is finer than the covering's resolution,
/// and the cells are sorted in curve order without overlapping, as the set
/// operations and `contains` require.
fn is_valid_covering(values: &[u64]) -> bool {
    let cells = match values.split_last() {
        Some((&last, rest)) if a5::is_compaction_marker(last) => rest,
        _ => values,
    };
    let resolution = a5::covering_resolution(values);
    let mut next_free: u64 = 0;
    for &cell in cells {
        if !a5::is_valid_cell(cell) || a5::get_resolution(cell) > resolution {
            return false;
        }
        let first = match cell_first_slot(cell) {
            Ok(slot) => slot,
            Err(_) => return false,
        };
        if first < next_free {
            return false;
        }
        next_free = first + cell_slot_count(cell);
    }
    true
}

// --- Exported functions ---

/// Compact cells into one covering.
///
/// @param cells List with b1..b8 raw vectors. NA cells are skipped.
/// @param resolution Integer resolution the covering stands for, or NULL
///   for the finest cell's.
/// @return A list holding one covering.
/// @noRd
/// @keywords internal
#[extendr]
fn a5_compact_rs(cells: List, resolution: Nullable<i32>) -> List {
    let resolution = match resolution {
        Nullable::NotNull(r) => Some(r),
        Nullable::Null => None,
    };
    let covering = cells_to_covering(collect_ids(&cells), resolution);
    coverings_to_list("compact", vec![Some(covering)])
}

/// Compact each element of a list of cell vectors into a covering.
///
/// @param cell_lists List of a5_cell objects (b1..b8 lists).
/// @param resolution As for `a5_compact_rs()`.
/// @return A list of coverings, one per element.
/// @noRd
/// @keywords internal
#[extendr]
fn a5_compact_each_rs(cell_lists: List, resolution: Nullable<i32>) -> List {
    let resolution = match resolution {
        Nullable::NotNull(r) => Some(r),
        Nullable::Null => None,
    };
    let results: Vec<Option<std::result::Result<Vec<u64>, String>>> = cell_lists
        .values()
        .map(|el| {
            let cells = List::try_from(el).expect("element is not an a5_cell");
            Some(cells_to_covering(collect_ids(&cells), resolution))
        })
        .collect();
    coverings_to_list("compact", results)
}

/// Normalise raw coverings from outside a5R: re-sort and compact them, and
/// record their resolution in a compaction marker.
///
/// @param x List of raw vectors (u64 values, little-endian) or NULL.
/// @param resolution Integer resolution for coverings without a compaction
///   marker, or NULL for their finest cell's. A marker always wins.
/// @return A list of coverings.
/// @noRd
/// @keywords internal
#[extendr]
fn a5_covering_normalise_rs(x: List, resolution: Nullable<i32>) -> List {
    let resolution = match resolution {
        Nullable::NotNull(r) => Some(r),
        Nullable::Null => None,
    };
    let results = map_coverings(&x, |values| {
        for &v in values {
            if !a5::is_compaction_marker(v) && !a5::is_valid_cell(v) {
                return Err(format!("{:#018x} is neither an A5 cell nor a compaction marker", v));
            }
        }
        let marked = values.last().is_some_and(|&v| a5::is_compaction_marker(v));
        let resolution = if marked { None } else { resolution };
        cells_to_covering(values.to_vec(), resolution)
    });
    coverings_to_list("as_a5_covering", results)
}

/// Expand coverings to their cells.
///
/// @param x List of coverings.
/// @param resolution Integer target resolution, or NULL for each
///   covering's own. Must be at or finer than every covering's resolution.
/// @param simplify If TRUE one flat b1..b8 list, else a list of a5_cell
///   objects, one per covering (empty for a missing covering).
/// @noRd
/// @keywords internal
#[extendr]
fn a5_uncompact_rs(x: List, resolution: Nullable<i32>, simplify: bool) -> Robj {
    let resolution = match resolution {
        Nullable::NotNull(r) => Some(r),
        Nullable::Null => None,
    };
    let results = map_coverings(&x, |values| {
        let own = a5::covering_resolution(values);
        match resolution {
            None => a5::uncompact(values),
            Some(r) if r < own => Err(format!(
                "Cannot uncompact a covering at resolution {} to coarser resolution {}",
                own, r
            )),
            Some(r) => {
                let cells: Vec<u64> = values
                    .iter()
                    .copied()
                    .filter(|&v| !a5::is_compaction_marker(v))
                    .collect();
                a5::uncompact(&with_marker(cells, r))
            }
        }
    });
    let unwrap = |r: Option<std::result::Result<Vec<u64>, String>>| -> Vec<Option<u64>> {
        match r {
            Some(Ok(v)) => v.into_iter().map(Some).collect(),
            Some(Err(e)) => throw_r_error(format!("uncompact failed: {}", e)),
            None => Vec::new(),
        }
    };
    if simplify {
        let mut flat: Vec<Option<u64>> = Vec::new();
        for r in results {
            flat.extend(unwrap(r));
        }
        return u64s_to_raw8_list(flat).into();
    }
    let elements: Vec<Robj> = results
        .into_iter()
        .map(|r| {
            let mut cell: Robj = u64s_to_raw8_list(unwrap(r)).into();
            cell.set_class(["a5_cell", "vctrs_rcrd", "vctrs_vctr"])
                .expect("set class on a5_cell");
            cell
        })
        .collect();
    List::from_values(elements).into()
}

/// Resolution, cell count and stored-cell count of every covering.
///
/// @param x List of coverings.
/// @return list(resolution = integer, count = double, stored = integer),
///   NA for a missing covering. Counts above 2^53 are rounded.
/// @noRd
/// @keywords internal
#[extendr]
fn a5_covering_summary_rs(x: List) -> List {
    let results = map_coverings(&x, |values| {
        let stored = values.iter().filter(|&&v| !a5::is_compaction_marker(v)).count();
        let count = a5::count(values).map(|c| c as f64).unwrap_or(f64::NAN);
        (a5::covering_resolution(values), count, stored)
    });
    let n = results.len();
    let mut resolution = Integers::new(n);
    let mut count = Doubles::new(n);
    let mut stored = Integers::new(n);
    for (i, r) in results.into_iter().enumerate() {
        match r {
            Some((res, c, s)) => {
                resolution.set_elt(i, Rint::from(res));
                count.set_elt(i, if c.is_nan() { Rfloat::na() } else { Rfloat::from(c) });
                stored.set_elt(i, Rint::from(s as i32));
            }
            None => {
                resolution.set_elt(i, Rint::na());
                count.set_elt(i, Rfloat::na());
                stored.set_elt(i, Rint::na());
            }
        }
    }
    list!(resolution = resolution, count = count, stored = stored)
}

/// Digits of `n` in groups of three, separated by commas.
fn group_digits(n: u64) -> String {
    let digits = n.to_string();
    let mut out = String::with_capacity(digits.len() + digits.len() / 3);
    for (i, c) in digits.chars().enumerate() {
        if i > 0 && (digits.len() - i) % 3 == 0 {
            out.push(',');
        }
        out.push(c);
    }
    out
}

/// One line per covering for `format()`: its resolution, the exact number
/// of cells it stands for and the number it stores.
///
/// @param x List of coverings.
/// @return Character vector, NA for a missing covering.
/// @noRd
/// @keywords internal
#[extendr]
fn a5_covering_format_rs(x: List) -> Strings {
    let results = map_coverings(&x, |values| {
        let resolution = a5::covering_resolution(values);
        let stored = values.iter().filter(|&&v| !a5::is_compaction_marker(v)).count();
        let count = match a5::count(values) {
            Ok(c) => c,
            Err(_) => return "invalid covering".to_string(),
        };
        match (resolution, count) {
            (-1, 0) => "empty".to_string(),
            (-1, _) => "world".to_string(),
            (r, 0) => format!("res {}: empty", r),
            (r, c) => format!(
                "res {}: {} {} ({} stored)",
                r,
                group_digits(c),
                if c == 1 { "cell" } else { "cells" },
                group_digits(stored as u64)
            ),
        }
    });
    let mut out = Strings::new(results.len());
    for (i, r) in results.into_iter().enumerate() {
        match r {
            Some(text) => out.set_elt(i, Rstr::from(text)),
            None => out.set_elt(i, Rstr::na()),
        }
    }
    out
}

/// Structural validity of every covering.
///
/// @param x List of coverings.
/// @return Logical vector, NA for a missing covering.
/// @noRd
/// @keywords internal
#[extendr]
fn a5_is_valid_covering_rs(x: List) -> Logicals {
    let results = map_coverings(&x, is_valid_covering);
    let mut out = Logicals::new(results.len());
    for (i, r) in results.into_iter().enumerate() {
        out.set_elt(i, r.map(Rbool::from).unwrap_or(Rbool::na()));
    }
    out
}

// --- Set operations, predicates and measures ---

/// An empty covering with no recorded resolution (`compact` of no cells)
/// takes `resolution`, so it combines with any covering as the empty set.
fn adopt_resolution(values: &[u64], resolution: i32) -> std::borrow::Cow<'_, [u64]> {
    if values.is_empty() && resolution >= 0 {
        std::borrow::Cow::Owned(with_marker(Vec::new(), resolution))
    } else {
        std::borrow::Cow::Borrowed(values)
    }
}

/// Apply `f` to pairs of coverings from `x` and `y`, recycling a length-one
/// side without copying it. None where either covering is missing. Errors
/// are raised with the element index.
fn map_covering_pairs<T, F>(x: &List, y: &List, name: &str, f: F) -> Vec<Option<T>>
where
    T: Send,
    F: Fn(&[u64], &[u64]) -> std::result::Result<T, String> + Send + Sync,
{
    let a = read_coverings(x);
    let b = read_coverings(y);
    let n = if a.is_empty() || b.is_empty() { 0 } else { a.len().max(b.len()) };
    let pick = |v: &Vec<Option<Vec<u64>>>, i: usize| if v.len() == 1 { 0 } else { i };
    let one = |i: usize| -> Option<std::result::Result<T, String>> {
        match (&a[pick(&a, i)], &b[pick(&b, i)]) {
            (Some(ai), Some(bi)) => {
                let ra = a5::covering_resolution(ai);
                let rb = a5::covering_resolution(bi);
                Some(f(&adopt_resolution(ai, rb), &adopt_resolution(bi, ra)))
            }
            _ => None,
        }
    };
    let results: Vec<Option<std::result::Result<T, String>>> = if get_num_threads() <= 1 {
        (0..n).map(one).collect()
    } else {
        maybe_par(|| (0..n).into_par_iter().map(one).collect())
    };
    results
        .into_iter()
        .enumerate()
        .map(|(i, r)| match r {
            Some(Ok(v)) => Some(v),
            Some(Err(e)) => throw_r_error(format!("{} failed for element {}: {}", name, i + 1, e)),
            None => None,
        })
        .collect()
}

fn logicals(results: Vec<Option<bool>>) -> Logicals {
    let mut out = Logicals::new(results.len());
    for (i, r) in results.into_iter().enumerate() {
        out.set_elt(i, r.map(Rbool::from).unwrap_or(Rbool::na()));
    }
    out
}

/// Element-wise union, intersection or difference of two covering lists.
///
/// @param x,y Lists of coverings; a length-one side is recycled.
/// @param op One of "union", "intersect", "difference".
/// @return A list of coverings.
/// @noRd
/// @keywords internal
#[extendr]
fn a5_covering_set_op_rs(x: List, y: List, op: &str) -> List {
    let f: fn(&[u64], &[u64]) -> std::result::Result<Vec<u64>, String> = match op {
        "union" => a5::union,
        "intersect" => a5::intersect,
        "difference" => a5::difference,
        other => throw_r_error(format!("unknown set operation {:?}", other)),
    };
    let results = map_covering_pairs(&x, &y, op, f);
    coverings_to_list(op, results.into_iter().map(|r| r.map(Ok)).collect())
}

/// The union of all coverings in a list, as one covering. Missing coverings
/// are skipped; all others must share a resolution.
///
/// @param x List of coverings.
/// @return A list holding one covering.
/// @noRd
/// @keywords internal
#[extendr]
fn a5_covering_union_all_rs(x: List) -> List {
    let coverings: Vec<Vec<u64>> = read_coverings(&x).into_iter().flatten().collect();
    let mut resolution: Option<i32> = None;
    for c in &coverings {
        if c.is_empty() {
            continue;
        }
        let r = a5::covering_resolution(c);
        match resolution {
            Some(prev) if prev != r => throw_r_error(format!(
                "union failed: Cannot combine cells at resolution {} with cells at resolution {}",
                prev, r
            )),
            _ => resolution = Some(r),
        }
    }
    let cells: Vec<u64> = coverings
        .into_iter()
        .flatten()
        .filter(|&v| !a5::is_compaction_marker(v))
        .collect();
    let covering = match resolution {
        Some(r) if r >= 0 => a5::compact(&with_marker(cells, r)),
        _ => a5::compact(&cells),
    };
    coverings_to_list("union", vec![Some(covering)])
}

/// Element-wise test of whether two coverings share a cell.
///
/// @param x,y Lists of coverings; a length-one side is recycled.
/// @return Logical vector, NA where either covering is missing.
/// @noRd
/// @keywords internal
#[extendr]
fn a5_covering_overlaps_rs(x: List, y: List) -> Logicals {
    logicals(map_covering_pairs(&x, &y, "overlaps", a5::overlaps))
}

/// Whether each cell is in its covering.
///
/// @param x List of coverings; a length-one list is recycled.
/// @param cells List with b1..b8 raw vectors; a length-one vector is
///   recycled.
/// @return Logical vector, NA where the covering or the cell is missing.
///   An empty covering contains no cell, whatever its resolution.
/// @noRd
/// @keywords internal
#[extendr]
fn a5_covering_contains_rs(x: List, cells: List) -> Logicals {
    let coverings = read_coverings(&x);
    let cs = CellSlices::from_list(&cells);
    let ids: Vec<Option<u64>> = (0..cs.len).map(|i| cs.get(i)).collect();
    let n = if coverings.is_empty() || ids.is_empty() {
        0
    } else {
        coverings.len().max(ids.len())
    };
    let one = |i: usize| -> Option<std::result::Result<bool, String>> {
        let covering = coverings[if coverings.len() == 1 { 0 } else { i }].as_deref()?;
        let cell = ids[if ids.len() == 1 { 0 } else { i }]?;
        if covering.iter().all(|&v| a5::is_compaction_marker(v)) {
            return Some(Ok(false));
        }
        Some(a5::contains(covering, cell))
    };
    let results: Vec<Option<std::result::Result<bool, String>>> = if get_num_threads() <= 1 {
        (0..n).map(one).collect()
    } else {
        maybe_par(|| (0..n).into_par_iter().map(one).collect())
    };
    let out = results
        .into_iter()
        .enumerate()
        .map(|(i, r)| match r {
            Some(Ok(v)) => Some(v),
            Some(Err(e)) => throw_r_error(format!("contains failed for element {}: {}", i + 1, e)),
            None => None,
        })
        .collect();
    logicals(out)
}

/// Area of every covering in square metres.
///
/// @param x List of coverings.
/// @return Numeric vector, NA for a missing covering.
/// @noRd
/// @keywords internal
#[extendr]
fn a5_covering_area_rs(x: List) -> Doubles {
    let results = map_coverings(&x, a5::area);
    let mut out = Doubles::new(results.len());
    for (i, r) in results.into_iter().enumerate() {
        match r {
            Some(Ok(v)) => out.set_elt(i, Rfloat::from(v)),
            Some(Err(e)) => throw_r_error(format!("area failed for element {}: {}", i + 1, e)),
            None => out.set_elt(i, Rfloat::na()),
        }
    }
    out
}

extendr_module! {
    mod covering;
    fn a5_covering_set_op_rs;
    fn a5_covering_union_all_rs;
    fn a5_covering_overlaps_rs;
    fn a5_covering_contains_rs;
    fn a5_covering_area_rs;
    fn a5_compact_rs;
    fn a5_compact_each_rs;
    fn a5_covering_normalise_rs;
    fn a5_uncompact_rs;
    fn a5_covering_summary_rs;
    fn a5_is_valid_covering_rs;
    fn a5_covering_format_rs;
}
