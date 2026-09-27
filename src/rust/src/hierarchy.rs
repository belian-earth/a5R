use extendr_api::prelude::*;
use extendr_api::wrapper::Nullable;

use crate::cell_raw::{collect_ids, map_cells, one_to_many, u64s_to_raw8_list, CellSlices};
use a5::core::cell::{cell_to_spherical, spherical_to_cell};
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

/// The cell at `resolution` containing the centre of `id`.
///
/// The centre goes straight from `cell_to_spherical` to `spherical_to_cell`,
/// so this is `lonlat_to_cell(cell_to_lonlat(id), resolution)` without the
/// round trip through degrees. `None` when `resolution` is finer than `id`.
fn spatial_parent(id: u64, resolution: i32) -> Option<u64> {
    let own = a5::get_resolution(id);
    if resolution > own {
        return None;
    }
    if resolution == own {
        return Some(id);
    }
    spherical_to_cell(cell_to_spherical(id).ok()?, resolution).ok()
}

/// Descendant centres of a cell stay within this many circumradii of the
/// cell's own centre. Measured over random cells the drift converges to
/// about 1.46 (each level adds at most ~0.77 of its own circumradius, and
/// radii halve per level); 2.0 leaves room for projection distortion when
/// the test runs in a neighbouring origin's face frame.
const DESCENDANT_DRIFT: f64 = 2.0;

/// Centres within this distance (face units) of an edge are decided by the
/// exact upstream search instead of the margin test. Projection round trips
/// agree to ~1e-15, so anything beyond this is unambiguous.
const EDGE_EPS: f64 = 1e-11;

/// A cell's shape in its origin's face frame, for signed-distance tests.
struct CellShape {
    origin_id: a5::core::utils::OriginId,
    vertices: Vec<a5::coordinate_systems::Face>,
}

impl CellShape {
    /// Mirrors the shapes `a5cell_contains_point` tests against: the face
    /// pentagon at resolution 0, a quintant triangle at 1, else the cell.
    fn new(id: u64) -> std::result::Result<Self, String> {
        use a5::core::tiling::{get_face_vertices, get_quintant_vertices};
        let cell = deserialize(id)?;
        let shape = if cell.resolution == FIRST_HILBERT_RESOLUTION - 2 {
            get_face_vertices()
        } else if cell.resolution == FIRST_HILBERT_RESOLUTION - 1 {
            let (q, _) = a5::core::origin::segment_to_quintant(cell.segment, cell.origin());
            get_quintant_vertices(q)
        } else {
            a5::core::cell::get_pentagon(&cell)?
        };
        Ok(Self { origin_id: cell.origin_id, vertices: shape.get_vertices_vec().clone() })
    }

    /// Signed distance from `p` to the boundary: positive inside, and for a
    /// point outside, at most minus its distance to the (convex) shape.
    fn margin(&self, p: a5::coordinate_systems::Face) -> f64 {
        let n = self.vertices.len();
        let mut m = f64::INFINITY;
        for i in 0..n {
            let a = self.vertices[i];
            let b = self.vertices[(i + 1) % n];
            let (ex, ey) = (b.x() - a.x(), b.y() - a.y());
            // Upstream's inside test: (a - b) x (p - a) >= 0 on every edge.
            let d = (ey * (p.x() - a.x()) - ex * (p.y() - a.y())) / (ex * ex + ey * ey).sqrt();
            m = m.min(d);
        }
        m
    }

    /// The centre of cell `id` in this shape's face frame.
    fn project_centre(&self, id: u64) -> std::result::Result<a5::coordinate_systems::Face, String> {
        let dode = a5::projections::dodecahedron::DodecahedronProjection::get_thread_local();
        dode.forward(cell_to_spherical(id)?, self.origin_id)
    }
}

/// Largest distance from a pentagon's centre to its vertices.
fn circumradius(cell: &a5::A5Cell) -> std::result::Result<f64, String> {
    let pent = a5::core::cell::get_pentagon(cell)?;
    let c = pent.get_center();
    Ok(pent
        .get_vertices_vec()
        .iter()
        .map(|v| ((v.x() - c.x()).powi(2) + (v.y() - c.y()).powi(2)).sqrt())
        .fold(0.0, f64::max))
}

/// The cells at `resolution` whose spatial parent at the resolution of `id`
/// is `id`, in ascending id order.
///
/// Every such cell is an index descendant of `id` or of one of its vertex
/// neighbours (checked at every resolution pair in the tests). Those index
/// trees are walked top down: a subtree whose descendant centres all lie
/// clearly inside the cell is taken whole, one whose centres all lie clearly
/// outside is skipped, and only the rest is split further. Finest-level
/// centres near an edge go to `spatial_parent`, so the result is exactly the
/// inverse of `spatial_parent`.
fn spatial_children(id: u64, resolution: i32) -> std::result::Result<Vec<u64>, String> {
    let own = a5::get_resolution(id);
    if resolution < own {
        return Err(format!(
            "target resolution {} is coarser than cell resolution {}",
            resolution, own
        ));
    }
    if resolution == own {
        return Ok(vec![id]);
    }
    // The world cell (resolution -1) contains every centre.
    if own < 0 {
        return a5::cell_to_children(id, Some(resolution));
    }
    let shape = CellShape::new(id)?;
    // grid_disk returns a compacted set: bring it back to the cell's own
    // resolution so compacted parents do not add far-away candidates.
    // Nodes carry their nominal resolution: at resolution 30 some faces
    // cannot be encoded and upstream returns resolution-29 ids instead, so
    // the id's own resolution would never reach the target.
    let mut stack: Vec<(u64, i32)> = a5::uncompact(&a5::grid_disk_vertex(id, 1)?, own)?
        .into_iter()
        .map(|c| (c, own))
        .collect();
    let mut out = Vec::with_capacity(4usize.pow((resolution - own).min(15) as u32));
    while let Some((x, res)) = stack.pop() {
        if res == resolution {
            let m = shape.margin(shape.project_centre(x)?);
            if m > EDGE_EPS || (m >= -EDGE_EPS && spatial_parent(x, own) == Some(id)) {
                out.push(x);
            }
            continue;
        }
        // Below the first Hilbert resolution there is no pentagon to bound
        // with, and only a handful of cells: always split.
        if res >= FIRST_HILBERT_RESOLUTION {
            let reach = DESCENDANT_DRIFT * circumradius(&deserialize(x)?)? + EDGE_EPS;
            let m = shape.margin(shape.project_centre(x)?);
            if m > reach {
                out.extend(a5::cell_to_children(x, Some(resolution))?);
                continue;
            }
            if m < -reach {
                continue;
            }
        }
        stack.extend(a5::cell_to_children(x, Some(res + 1))?.into_iter().map(|c| (c, res + 1)));
    }
    out.sort_unstable();
    Ok(out)
}

/// Spatial parent: the coarser cell containing each cell's centre.
///
/// @param cells List with b1..b8 raw vectors.
/// @param parent_resolution Integer target resolution. NULL for one coarser.
/// @return List with b1..b8 raw vectors.
/// @noRd
/// @keywords internal
#[extendr]
fn a5_cell_to_spatial_parent_rs(cells: List, parent_resolution: Nullable<i32>) -> List {
    let pres: Option<i32> = match parent_resolution {
        Nullable::NotNull(v) => Some(v),
        Nullable::Null => None,
    };
    let results = map_cells(&cells, |id| {
        let res = pres.unwrap_or_else(|| a5::get_resolution(id) - 1);
        if res < 0 {
            return None;
        }
        spatial_parent(id, res)
    });
    u64s_to_raw8_list(results)
}

/// Spatial children: the finer cells whose centres lie in each cell.
///
/// @param cells List with b1..b8 raw vectors.
/// @param child_resolution Integer target resolution. NULL for one finer.
/// @param simplify If TRUE one flat b1..b8 list, else a list of a5_cell
///   objects, one per input.
/// @return See simplify.
/// @noRd
/// @keywords internal
#[extendr]
fn a5_cell_to_spatial_children_rs(cells: List, child_resolution: Nullable<i32>, simplify: bool) -> Robj {
    let cres: Option<i32> = match child_resolution {
        Nullable::NotNull(v) => Some(v),
        Nullable::Null => None,
    };
    one_to_many(&cells, "cell_to_spatial_children", simplify, |id| {
        spatial_children(id, cres.unwrap_or_else(|| a5::get_resolution(id) + 1))
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
    fn a5_cell_to_spatial_parent_rs;
    fn a5_cell_to_spatial_children_rs;
    fn a5_cell_child_rs;
    fn a5_cell_children_range_rs;
    fn a5_get_res0_cells_rs;
    fn a5_compact_rs;
    fn a5_uncompact_rs;
}
