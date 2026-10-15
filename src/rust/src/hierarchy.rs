use extendr_api::prelude::*;
use extendr_api::wrapper::Nullable;

use crate::cell_raw::{map_cells, one_to_many, u64s_to_raw8_list, CellSlices};
use crate::covering::{cells_to_covering, cells_to_coverings, coverings_to_list, read_coverings};
use crate::threading::{get_num_threads, maybe_par};
use rayon::prelude::*;
use std::collections::HashSet;
use a5::core::serialization::{
    cell_first_slot, cell_slot_count, slot_to_cell, QUINTANT_SHIFT, RES30_QUINTANTS,
    SLOT_COUNTS,
};

/// The descendants of a cell at a finer resolution, without enumerating them.
///
/// Mirrors `a5::cell_to_children` exactly. A cell occupies a contiguous block
/// of leaf slots along the curve, and its descendants at `resolution` step
/// through that block in strides of their own slot count, in ascending id
/// order. At resolution 30 the quintants past `RES30_QUINTANTS` have no ids,
/// and upstream gives each child as its resolution-29 parent instead.
struct Descendants {
    first_slot: u64,
    stride: u64,
    count: u64,
    resolution: i32,
}

impl Descendants {
    fn new(index: u64, child_resolution: i32) -> std::result::Result<Self, String> {
        let resolution = a5::get_resolution(index);
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
        // Unlike `a5::cell_to_children`, no limit on the resolution difference:
        // nothing is enumerated, and slots stay below 60 * 2^58.
        let first_slot = cell_first_slot(index)?;
        let stride = SLOT_COUNTS[child_resolution as usize];
        Ok(Descendants {
            first_slot,
            stride,
            count: cell_slot_count(index) / stride,
            resolution: child_resolution,
        })
    }

    fn count(&self) -> u64 {
        self.count
    }

    /// The k-th descendant (0-based) in `a5::cell_to_children` order.
    fn nth(&self, k: u64) -> u64 {
        let slot = self.first_slot + k * self.stride;
        if self.resolution == a5::MAX_RESOLUTION
            && (slot >> QUINTANT_SHIFT) as usize >= RES30_QUINTANTS
        {
            return slot_to_cell(slot & !3, a5::MAX_RESOLUTION - 1);
        }
        slot_to_cell(slot, self.resolution)
    }

    /// Smallest and largest descendant id: the first and last, as ids below
    /// resolution 30 ascend with their slots.
    fn range(&self) -> (u64, u64) {
        (self.nth(0), self.nth(self.count - 1))
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
fn a5_cell_to_parent_rs(cells: List, parent_resolution: Nullable<i32>) -> extendr_api::Result<List> {
    let pres: Option<i32> = match parent_resolution {
        Nullable::NotNull(v) => Some(v),
        Nullable::Null => None,
    };

    if let Some(p) = pres {
        let cs = CellSlices::from_list(&cells);
        if let Some(r) = (0..cs.len).filter_map(|i| cs.get(i)).map(a5::get_resolution).find(|&r| r < p) {
            return Err(Error::Other(format!(
                "`resolution` ({p}) must not be finer than the cell resolution ({r})."
            )));
        }
    }

    let results = map_cells(&cells, |id| {
        a5::cell_to_parent(id, pres).ok()
    });

    Ok(u64s_to_raw8_list(results))
}

/// Get child cells of every input cell.
///
/// @param cells List with b1..b8 raw vectors.
/// @param child_resolution Integer: target child resolution. NULL for
///   immediate children.
/// @param simplify If TRUE one flat b1..b8 list, else a list of a5_cell
///   objects, one per input.
/// @return See simplify.
/// @noRd
/// @keywords internal
#[extendr]
fn a5_cell_to_children_rs(cells: List, child_resolution: Nullable<i32>, simplify: bool) -> Robj {
    let cres: Option<i32> = match child_resolution {
        Nullable::NotNull(v) => Some(v),
        Nullable::Null => None,
    };
    one_to_many(&cells, "cell_to_children", simplify, |id| a5::cell_to_children(id, cres))
}

/// Supercells: the coarser cell containing each cell's centre.
///
/// @param cells List with b1..b8 raw vectors.
/// @param resolution Integer target resolution. NULL for one coarser.
/// @return List with b1..b8 raw vectors. NA where the cell is NA, where the
///   resolution is finer than the cell, or below 0.
/// @noRd
/// @keywords internal
#[extendr]
fn a5_cell_to_supercell_rs(cells: List, resolution: Nullable<i32>) -> List {
    let target: Option<i32> = match resolution {
        Nullable::NotNull(v) => Some(v),
        Nullable::Null => None,
    };
    let results = map_cells(&cells, |id| {
        let res = target.unwrap_or_else(|| a5::get_resolution(id) - 1);
        if res < 0 {
            return None;
        }
        a5::cell_to_supercell(id, res).ok()
    });
    u64s_to_raw8_list(results)
}

/// Subcells: the finer cells whose centres lie in each cell, as coverings.
///
/// @param cells List with b1..b8 raw vectors.
/// @param resolution Integer target resolution. NULL for one finer.
/// @return A list of coverings, one per cell (NULL for an NA cell).
/// @noRd
/// @keywords internal
#[extendr]
fn a5_cell_to_subcell_rs(cells: List, resolution: Nullable<i32>) -> List {
    let target: Option<i32> = match resolution {
        Nullable::NotNull(v) => Some(v),
        Nullable::Null => None,
    };
    cells_to_coverings(&cells, "cell_to_subcell", |id| {
        a5::cell_to_subcell(id, target.unwrap_or_else(|| a5::get_resolution(id) + 1))
    })
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
                let k = pos.0;
                if k < 1 || (k as u64) > d.count() {
                    throw_r_error(format!(
                        "child index {} is out of range: cell {} has {} descendants at resolution {}",
                        k,
                        idx + 1,
                        d.count(),
                        child_resolution
                    ));
                }
                Some(d.nth(k as u64 - 1))
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
                let range = Descendants::new(id, child_resolution).map(|d| d.range());
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

/// The supercells at `resolution` of a covering's cells: the coarse cells
/// containing each cell's centre, as a covering at `resolution`. Walks the
/// cells without building them.
fn covering_supercells(values: &[u64], resolution: i32) -> std::result::Result<Vec<u64>, String> {
    let r = a5::covering_resolution(values);
    let stored: Vec<u64> = values.iter().copied().filter(|&c| !a5::is_compaction_marker(c)).collect();
    if stored.is_empty() {
        return cells_to_covering(Vec::new(), Some(resolution));
    }
    if resolution > r {
        return Err(format!(
            "resolution ({resolution}) must not be finer than the covering's resolution ({r})"
        ));
    }
    let blocks = stored
        .iter()
        .map(|&c| Descendants::new(c, r))
        .collect::<std::result::Result<Vec<_>, _>>()?;
    // (block, first k, last k) chunks of at most CHUNK cells, for parallel work
    const CHUNK: u64 = 1 << 16;
    let mut chunks: Vec<(usize, u64, u64)> = Vec::new();
    for (b, d) in blocks.iter().enumerate() {
        let mut k = 0;
        while k < d.count() {
            let end = (k + CHUNK).min(d.count());
            chunks.push((b, k, end));
            k = end;
        }
    }
    let supercells = |&(b, k0, k1): &(usize, u64, u64)| -> std::result::Result<HashSet<u64>, String> {
        let mut set = HashSet::new();
        let mut last = u64::MAX;
        for k in k0..k1 {
            let sc = a5::cell_to_supercell(blocks[b].nth(k), resolution)?;
            // neighbouring cells along the curve usually share a supercell
            if sc != last {
                set.insert(sc);
                last = sc;
            }
        }
        Ok(set)
    };
    let sets: Vec<std::result::Result<HashSet<u64>, String>> = if get_num_threads() <= 1 {
        chunks.iter().map(supercells).collect()
    } else {
        maybe_par(|| chunks.par_iter().map(supercells).collect())
    };
    let mut all = HashSet::new();
    for s in sets {
        all.extend(s?);
    }
    cells_to_covering(all.into_iter().collect(), Some(resolution))
}

/// Supercells of every covering.
/// @noRd
/// @keywords internal
#[extendr]
fn a5_covering_to_supercells_rs(x: List, resolution: i32) -> List {
    let results = read_coverings(&x)
        .into_iter()
        .map(|c| c.map(|values| covering_supercells(&values, resolution)))
        .collect();
    coverings_to_list("a5_covering_to_supercells", results)
}

extendr_module! {
    mod hierarchy;
    fn a5_get_resolution_rs;
    fn a5_cell_to_parent_rs;
    fn a5_cell_to_children_rs;
    fn a5_cell_to_supercell_rs;
    fn a5_covering_to_supercells_rs;
    fn a5_cell_to_subcell_rs;
    fn a5_cell_child_rs;
    fn a5_cell_children_range_rs;
    fn a5_get_res0_cells_rs;
}
