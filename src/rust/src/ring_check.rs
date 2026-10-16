// Self-intersection check for polygon rings, before they reach the crate.
//
// a5 1.0.0 fills the centre containment of a ring that crosses itself
// inconsistently, flooding whole quintants and, at fine resolutions, running
// out of memory. Remove this once the crate rejects such rings itself.

use extendr_api::prelude::*;
use rayon::prelude::*;

use crate::threading::{get_num_threads, maybe_par};

type Vec3 = [f64; 3];

fn to_unit(lon: f64, lat: f64) -> Vec3 {
    let (lon, lat) = (lon.to_radians(), lat.to_radians());
    [lat.cos() * lon.cos(), lat.cos() * lon.sin(), lat.sin()]
}

fn cross(a: Vec3, b: Vec3) -> Vec3 {
    [
        a[1] * b[2] - a[2] * b[1],
        a[2] * b[0] - a[0] * b[2],
        a[0] * b[1] - a[1] * b[0],
    ]
}

fn dot(a: Vec3, b: Vec3) -> f64 {
    a[0] * b[0] + a[1] * b[1] + a[2] * b[2]
}

// Points closer than this (in unit-sphere units, about 6 um on the Earth) are
// one point, and a point this close to a great circle lies on it. Ring
// vertices that should coincide, as in a zero-width spike, can differ in
// their last bits, and rounding then makes their edges appear to cross.
const EPS: f64 = 1e-12;

fn same(a: Vec3, b: Vec3) -> bool {
    (a[0] - b[0]).abs() <= EPS && (a[1] - b[1]).abs() <= EPS && (a[2] - b[2]).abs() <= EPS
}

/// The side of the great circle through `a` and `b` that `c` lies on, or 0
/// when `c` is within `EPS` of it.
fn orient(a: Vec3, b: Vec3, c: Vec3) -> i8 {
    let n = cross(a, b);
    let d = dot(n, c);
    if d.abs() <= EPS * dot(n, n).sqrt() {
        return 0;
    }
    (d > 0.0) as i8 - (d < 0.0) as i8
}

/// Whether arcs `ab` and `cd` cross at a point interior to both, as S2's
/// CrossingSign decides it. Arcs sharing a vertex, touching or collinear do
/// not count, so the check never rejects a ring it cannot be sure about.
fn arcs_cross(a: Vec3, b: Vec3, c: Vec3, d: Vec3) -> bool {
    // Arcs that share a vertex meet there, which is not a crossing; rounding
    // makes orient() of a shared vertex tiny but not zero
    if same(a, c) || same(a, d) || same(b, c) || same(b, d) {
        return false;
    }
    let acb = -orient(a, b, c);
    let bda = orient(a, b, d);
    if acb == 0 || acb != bda {
        return false;
    }
    let cbd = -orient(c, d, b);
    let dac = orient(c, d, a);
    cbd == acb && dac == acb
}

/// A box holding the whole arc: its endpoints' box widened by the arc's
/// greatest distance from its chord.
fn arc_box(a: Vec3, b: Vec3) -> ([f64; 3], [f64; 3]) {
    let half = (dot(a, b).clamp(-1.0, 1.0).acos()) / 2.0;
    let sag = 1.0 - half.cos() + 1e-12;
    let mut lo = [0.0; 3];
    let mut hi = [0.0; 3];
    for k in 0..3 {
        lo[k] = a[k].min(b[k]) - sag;
        hi[k] = a[k].max(b[k]) + sag;
    }
    (lo, hi)
}

/// Whether a ring (open or closed) has two edges that cross. Edges are
/// swept along x by their boxes, so only edges whose boxes overlap are
/// compared.
fn ring_crosses_itself(lon: &[f64], lat: &[f64]) -> bool {
    let mut pts: Vec<Vec3> = Vec::with_capacity(lon.len());
    for (&x, &y) in lon.iter().zip(lat) {
        let p = to_unit(x, y);
        if !matches!(pts.last(), Some(&q) if same(q, p)) {
            pts.push(p);
        }
    }
    if pts.len() > 1 && same(pts[0], pts[pts.len() - 1]) {
        pts.pop();
    }
    let n = pts.len();
    if n < 4 {
        return false;
    }
    let edges: Vec<(usize, [f64; 3], [f64; 3])> = (0..n)
        .map(|i| {
            let (lo, hi) = arc_box(pts[i], pts[(i + 1) % n]);
            (i, lo, hi)
        })
        .collect();
    let mut order: Vec<usize> = (0..n).collect();
    order.sort_unstable_by(|&i, &j| edges[i].1[0].total_cmp(&edges[j].1[0]));

    let mut active: Vec<usize> = Vec::new();
    for &e in &order {
        let (i, lo, hi) = edges[e];
        active.retain(|&o| edges[o].2[0] >= lo[0]);
        for &o in &active {
            let j = edges[o].0;
            // Neighbouring edges share a vertex
            if (i + 1) % n == j || (j + 1) % n == i {
                continue;
            }
            let (olo, ohi) = (edges[o].1, edges[o].2);
            if olo[1] > hi[1] || ohi[1] < lo[1] || olo[2] > hi[2] || ohi[2] < lo[2] {
                continue;
            }
            if arcs_cross(pts[i], pts[(i + 1) % n], pts[j], pts[(j + 1) % n]) {
                return true;
            }
        }
        active.push(e);
    }
    false
}

/// The first ring that crosses itself, 1-based, or 0 when none does.
///
/// @param lon,lat Flat coordinate vectors.
/// @param offsets Cumulative ring offsets (length `n_rings + 1`).
/// @noRd
/// @keywords internal
#[extendr]
fn a5_ring_crossing_rs(lon: Doubles, lat: Doubles, offsets: Integers) -> i32 {
    let lon: Vec<f64> = lon.iter().map(|x| x.0).collect();
    let lat: Vec<f64> = lat.iter().map(|x| x.0).collect();
    let offsets: Vec<usize> = offsets.iter().map(|o| o.0 as usize).collect();
    let crosses = |i: usize| {
        let (a, b) = (offsets[i], offsets[i + 1]);
        ring_crosses_itself(&lon[a..b], &lat[a..b])
    };
    let n = offsets.len().saturating_sub(1);
    let first = if get_num_threads() <= 1 || n < 2 {
        (0..n).find(|&i| crosses(i))
    } else {
        maybe_par(|| (0..n).into_par_iter().find_first(|&i| crosses(i)))
    };
    first.map_or(0, |i| (i + 1) as i32)
}

extendr_module! {
    mod ring_check;
    fn a5_ring_crossing_rs;
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn bowtie_crosses_and_square_does_not() {
        let bow = ([8.30, 8.32, 8.32, 8.30, 8.30], [47.40, 47.42, 47.40, 47.42, 47.40]);
        assert!(ring_crosses_itself(&bow.0, &bow.1));
        let square = ([0.0, 1.0, 1.0, 0.0, 0.0], [0.0, 0.0, 1.0, 1.0, 0.0]);
        assert!(!ring_crosses_itself(&square.0, &square.1));
    }
}
