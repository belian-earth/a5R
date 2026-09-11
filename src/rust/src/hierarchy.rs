use extendr_api::prelude::*;
use extendr_api::wrapper::Nullable;

use crate::cell_raw::{collect_ids, map_cells, one_to_many, u64s_to_raw8_list, CellSlices};
use a5::core::serialization::{deserialize, serialize, FIRST_HILBERT_RESOLUTION};
use a5::A5Cell;

/// The descendants of a cell at a finer resolution, without enumerating them.
///
/// Mirrors `a5::cell_to_children` exactly: descendants are grouped by
/// (origin, segment) and within a group are consecutive Hilbert indices
/// `shifted_s + i`. The world cell spans 12 origins, a resolution-0 cell
/// spans 5 segments, every other cell is a single group.
struct Descendants {
    groups: Vec<(u8, usize)>,
    per_group: u64,
    shifted_s: u64,
    resolution: i32,
}

impl Descendants {
    fn new(index: u64, child_resolution: i32) -> std::result::Result<Self, String> {
        let A5Cell {
            origin_id,
            segment,
            s,
            resolution,
        } = deserialize(index)?;
        if child_resolution < resolution {
            return Err(format!(
                "Target resolution ({}) must be equal to or greater than current resolution ({})",
                child_resolution, resolution
            ));
        }
        if child_resolution > a5::MAX_RESOLUTION {
            return Err(format!(
                "Target resolution ({}) exceeds maximum resolution ({})",
                child_resolution, a5::MAX_RESOLUTION
            ));
        }
        let origins: Vec<u8> = if resolution == -1 {
            (0..12).collect()
        } else {
            vec![origin_id]
        };
        let segments: Vec<usize> = if (resolution == -1 && child_resolution > 0) || resolution == 0 {
            (0..5).collect()
        } else {
            vec![segment]
        };
        let diff = child_resolution - std::cmp::max(resolution, FIRST_HILBERT_RESOLUTION - 1);
        let per_group: u64 = if diff <= 0 {
            1
        } else if diff > 20 {
            return Err("Resolution difference too large".to_string());
        } else {
            1u64 << (2 * diff)
        };
        let shifted_s = if diff > 0 { s << (2 * diff) } else { s };
        let groups = origins
            .iter()
            .flat_map(|&o| segments.iter().map(move |&g| (o, g)))
            .collect();
        Ok(Descendants {
            groups,
            per_group,
            shifted_s,
            resolution: child_resolution,
        })
    }

    fn count(&self) -> u64 {
        self.groups.len() as u64 * self.per_group
    }

    /// The k-th descendant (0-based) in `a5::cell_to_children` order.
    fn nth(&self, k: u64) -> std::result::Result<u64, String> {
        let (origin_id, segment) = self.groups[(k / self.per_group) as usize];
        serialize(&A5Cell {
            origin_id,
            segment,
            s: self.shifted_s + k % self.per_group,
            resolution: self.resolution,
        })
    }

    /// Smallest and largest descendant id. Within a group ids increase with
    /// the Hilbert index, but groups are not ordered by segment, so every
    /// group's first and last member is examined.
    fn range(&self) -> std::result::Result<(u64, u64), String> {
        let mut lo = u64::MAX;
        let mut hi = u64::MIN;
        for g in 0..self.groups.len() as u64 {
            let first = self.nth(g * self.per_group)?;
            let last = self.nth(g * self.per_group + self.per_group - 1)?;
            lo = lo.min(first).min(last);
            hi = hi.max(first).max(last);
        }
        Ok((lo, hi))
    }
}

/// Get the resolution of A5 cell indices.
///
/// @param cells List with b1..b8 raw vectors.
/// @return Integer vector of resolutions.
/// @noRd
/// @keywords internal
#[extendr]
fn a5_get_resolution_rs(cells: List) -> Integers {
    let results = map_cells(&cells, |id| Some(a5::get_resolution(id)));

    let n = results.len();
    let mut out = Integers::new(n);
    for (i, r) in results.into_iter().enumerate() {
        match r {
            Some(v) => out.set_elt(i, Rint::from(v)),
            None => out.set_elt(i, Rint::na()),
        }
    }
    out
}

/// Navigate to parent cell(s).
///
/// @param cells List with b1..b8 raw vectors.
/// @param parent_resolution Integer: target parent resolution. NULL for
///   immediate parent.
/// @return List with b1..b8 raw vectors.
/// @noRd
/// @keywords internal
#[extendr]
fn a5_cell_to_parent_rs(cells: List, parent_resolution: Nullable<i32>) -> List {
    let pres: Option<i32> = match parent_resolution {
        Nullable::NotNull(v) => Some(v),
        Nullable::Null => None,
    };

    let results = map_cells(&cells, |id| {
        a5::cell_to_parent(id, pres).ok()
    });

    u64s_to_raw8_list(results)
}

/// Get child cells of every input cell.
///
/// @param cells List with b1..b8 raw vectors.
/// @param child_resolution Integer: target child resolution. NULL for
///   immediate children.
/// @return list(cells = b1..b8 raw list, lengths = integer per input).
/// @noRd
/// @keywords internal
#[extendr]
fn a5_cell_to_children_rs(cells: List, child_resolution: Nullable<i32>) -> List {
    let cres: Option<i32> = match child_resolution {
        Nullable::NotNull(v) => Some(v),
        Nullable::Null => None,
    };
    one_to_many(&cells, "cell_to_children", |id| a5::cell_to_children(id, cres))
}

/// The i-th child of each cell at a resolution, without building the list.
///
/// @param cells List with b1..b8 raw vectors.
/// @param child_resolution Integer target resolution (scalar).
/// @param i Integer vector of 1-based child positions, same length as cells.
/// @return List with b1..b8 raw vectors. NA where the cell or i is NA;
///   an error if i is out of range.
/// @noRd
/// @keywords internal
#[extendr]
fn a5_cell_child_rs(cells: List, child_resolution: i32, i: Integers) -> List {
    let cs = CellSlices::from_list(&cells);
    let mut results: Vec<Option<u64>> = Vec::with_capacity(cs.len);
    for idx in 0..cs.len {
        let pos = i[idx];
        let out = match (cs.get(idx), pos.is_na()) {
            (Some(id), false) => {
                let d = match Descendants::new(id, child_resolution) {
                    Ok(d) => d,
                    Err(e) => throw_r_error(format!("cell_child failed: {}", e)),
                };
                let k = pos.inner();
                if k < 1 || (k as u64) > d.count() {
                    throw_r_error(format!(
                        "child index {} is out of range: cell {} has {} descendants at resolution {}",
                        k,
                        idx + 1,
                        d.count(),
                        child_resolution
                    ));
                }
                match d.nth(k as u64 - 1) {
                    Ok(c) => Some(c),
                    Err(e) => throw_r_error(format!("cell_child failed: {}", e)),
                }
            }
            _ => None,
        };
        results.push(out);
    }
    u64s_to_raw8_list(results)
}

/// Smallest and largest descendant of each cell at a resolution.
///
/// @param cells List with b1..b8 raw vectors.
/// @param child_resolution Integer target resolution (scalar).
/// @return List of two cell lists: `lo` and `hi`. NA where the cell is NA.
/// @noRd
/// @keywords internal
#[extendr]
fn a5_cell_children_range_rs(cells: List, child_resolution: i32) -> List {
    let cs = CellSlices::from_list(&cells);
    let mut lo: Vec<Option<u64>> = Vec::with_capacity(cs.len);
    let mut hi: Vec<Option<u64>> = Vec::with_capacity(cs.len);
    for idx in 0..cs.len {
        match cs.get(idx) {
            Some(id) => {
                let range = Descendants::new(id, child_resolution).and_then(|d| d.range());
                match range {
                    Ok((a, b)) => {
                        lo.push(Some(a));
                        hi.push(Some(b));
                    }
                    Err(e) => throw_r_error(format!("cell_children_range failed: {}", e)),
                }
            }
            None => {
                lo.push(None);
                hi.push(None);
            }
        }
    }
    list!(lo = u64s_to_raw8_list(lo), hi = u64s_to_raw8_list(hi))
}

/// Get all 12 resolution-0 root cells.
///
/// @return List with b1..b8 raw vectors.
/// @noRd
/// @keywords internal
#[extendr]
fn a5_get_res0_cells_rs() -> List {
    match a5::get_res0_cells() {
        Ok(cells) => {
            let results: Vec<Option<u64>> = cells.into_iter().map(|c| Some(c)).collect();
            u64s_to_raw8_list(results)
        }
        Err(e) => throw_r_error(format!("get_res0_cells failed: {}", e)),
    }
}

/// Compact a set of A5 cell IDs.
///
/// @param cells List with b1..b8 raw vectors.
/// @return List with b1..b8 raw vectors.
/// @noRd
/// @keywords internal
#[extendr]
fn a5_compact_rs(cells: List) -> List {
    let ids = collect_ids(&cells);
    match a5::compact(&ids) {
        Ok(compacted) => {
            let results: Vec<Option<u64>> = compacted.into_iter().map(|c| Some(c)).collect();
            u64s_to_raw8_list(results)
        }
        Err(e) => throw_r_error(format!("compact failed: {}", e)),
    }
}

/// Uncompact a set of A5 cell IDs to a target resolution.
///
/// @param cells List with b1..b8 raw vectors.
/// @param target_resolution Integer: the resolution to expand to.
/// @return List with b1..b8 raw vectors.
/// @noRd
/// @keywords internal
#[extendr]
fn a5_uncompact_rs(cells: List, target_resolution: i32) -> List {
    let ids = collect_ids(&cells);
    match a5::uncompact(&ids, target_resolution) {
        Ok(result) => {
            let results: Vec<Option<u64>> = result.into_iter().map(|c| Some(c)).collect();
            u64s_to_raw8_list(results)
        }
        Err(e) => throw_r_error(format!("uncompact failed: {}", e)),
    }
}

extendr_module! {
    mod hierarchy;
    fn a5_get_resolution_rs;
    fn a5_cell_to_parent_rs;
    fn a5_cell_to_children_rs;
    fn a5_cell_child_rs;
    fn a5_cell_children_range_rs;
    fn a5_get_res0_cells_rs;
    fn a5_compact_rs;
    fn a5_uncompact_rs;
}
