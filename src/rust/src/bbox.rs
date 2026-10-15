//! Longitude/latitude bounding boxes of polygons with great-circle edges.
//!
//! A5 joins polygon vertices by great circles on the authalic sphere, so an
//! edge can reach beyond the latitudes of its vertices. The box here bounds
//! the edges themselves: latitudes include each edge's highest and lowest
//! point, and a ring that winds around a pole extends to that pole across
//! all longitudes. Longitudes are continuous, so a box crossing the
//! antimeridian has `xmax` above 180.

use extendr_api::prelude::*;

use a5::projections::AuthalicProjection;
use a5::Radians;

use crate::regions::{group_parts, split_rings};

#[derive(Clone, Copy)]
struct Arc {
    start: f64,
    end: f64,
}

struct Bounds {
    lon: Option<Arc>, // None: all longitudes
    ymin: f64,
    ymax: f64,
}

fn to_vec(lon: f64, authalic_lat: f64) -> [f64; 3] {
    let (lon, lat) = (lon.to_radians(), authalic_lat);
    [lat.cos() * lon.cos(), lat.cos() * lon.sin(), lat.sin()]
}

fn cross(a: [f64; 3], b: [f64; 3]) -> [f64; 3] {
    [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]]
}

fn dot(a: [f64; 3], b: [f64; 3]) -> f64 {
    a[0] * b[0] + a[1] * b[1] + a[2] * b[2]
}

/// Wrap a longitude difference into (-180, 180].
fn wrap(d: f64) -> f64 {
    let w = d.rem_euclid(360.0);
    if w > 180.0 { w - 360.0 } else { w }
}

/// Bounds of one outer ring, latitudes in authalic radians.
fn ring_bounds(ring: &[a5::LonLat]) -> Option<Bounds> {
    let n = ring.len();
    if n == 0 {
        return None;
    }
    let authalic = AuthalicProjection;
    let lat: Vec<f64> = ring
        .iter()
        .map(|p| authalic.forward(Radians::new_unchecked(p.latitude().to_radians())).get())
        .collect();
    let v: Vec<[f64; 3]> = ring.iter().zip(&lat).map(|(p, &la)| to_vec(p.longitude(), la)).collect();

    let mut ymin = lat.iter().cloned().fold(f64::INFINITY, f64::min);
    let mut ymax = lat.iter().cloned().fold(f64::NEG_INFINITY, f64::max);
    let mut unwrapped = Vec::with_capacity(n);
    let mut x = ring[0].longitude();
    let mut winding = 0.0;
    for i in 0..n {
        let j = (i + 1) % n;
        unwrapped.push(x);
        let d = wrap(ring[j].longitude() - ring[i].longitude());
        x += d;
        winding += d;
        // the great circle's highest point, and its antipode the lowest, if
        // either falls inside the edge from v[i] to v[j]
        let nrm = cross(v[i], v[j]);
        let horiz = [nrm[0] * nrm[2], nrm[1] * nrm[2], -(nrm[0] * nrm[0] + nrm[1] * nrm[1])];
        let len = dot(horiz, horiz).sqrt();
        if len > 0.0 {
            let top = [-horiz[0] / len, -horiz[1] / len, -horiz[2] / len];
            for p in [top, [-top[0], -top[1], -top[2]]] {
                if dot(cross(v[i], p), nrm) > 0.0 && dot(cross(p, v[j]), nrm) > 0.0 {
                    let la = p[2].clamp(-1.0, 1.0).asin();
                    ymin = ymin.min(la);
                    ymax = ymax.max(la);
                }
            }
        }
    }

    if winding.abs() > 180.0 {
        // the ring encircles a pole: the one on its centroid's side, the side
        // a5 treats as inside
        let cz: f64 = v.iter().map(|p| p[2]).sum();
        if cz >= 0.0 {
            ymax = std::f64::consts::FRAC_PI_2;
        } else {
            ymin = -std::f64::consts::FRAC_PI_2;
        }
        return Some(Bounds { lon: None, ymin, ymax });
    }
    let lo = unwrapped.iter().cloned().fold(f64::INFINITY, f64::min);
    let hi = unwrapped.iter().cloned().fold(f64::NEG_INFINITY, f64::max);
    let shift = 360.0 * ((lo + 180.0) / 360.0).floor();
    Some(Bounds { lon: Some(Arc { start: lo - shift, end: hi - shift }), ymin, ymax })
}

/// The smallest longitude arc covering every arc, or None for all
/// longitudes. Arcs start in [-180, 180).
fn union_arcs(mut arcs: Vec<Arc>) -> Option<Arc> {
    if arcs.iter().any(|a| a.end - a.start >= 360.0) {
        return None;
    }
    arcs.sort_by(|a, b| a.start.total_cmp(&b.start));
    let mut merged: Vec<Arc> = Vec::new();
    for a in arcs {
        match merged.last_mut() {
            Some(m) if a.start <= m.end => m.end = m.end.max(a.end),
            _ => merged.push(a),
        }
    }
    // the largest gap between merged arcs, going round the circle
    let k = merged.len();
    let mut best_gap = f64::NEG_INFINITY;
    let mut best = 0;
    for i in 0..k {
        let next_start = if i + 1 < k { merged[i + 1].start } else { merged[0].start + 360.0 };
        let gap = next_start - merged[i].end;
        if gap > best_gap {
            best_gap = gap;
            best = i;
        }
    }
    if best_gap <= 0.0 {
        return None;
    }
    // the box runs from the arc after the gap round to the arc before it
    let start = if best + 1 < k { merged[best + 1].start } else { merged[0].start };
    let mut end = merged[best].end;
    while end < start {
        end += 360.0;
    }
    Some(Arc { start, end })
}

/// Bounding boxes per feature: list(xmin, ymin, xmax, ymax), NA for a
/// feature with no rings.
/// @noRd
/// @keywords internal
#[extendr]
fn a5_bbox_rs(
    lon: Doubles,
    lat: Doubles,
    offsets: Integers,
    part_id: Integers,
    is_outer: Integers,
    part_feature: Integers,
    n_features: i32,
) -> List {
    let part_id: Vec<i32> = part_id.iter().map(|p| p.0).collect();
    let is_outer: Vec<i32> = is_outer.iter().map(|b| b.0).collect();
    let part_feature: Vec<i32> = part_feature.iter().map(|f| f.0).collect();
    let parts = group_parts(split_rings(&lon, &lat, &offsets), &part_id, &is_outer, part_feature.len());

    let n = n_features.max(0) as usize;
    let mut per_feature: Vec<Vec<Bounds>> = (0..n).map(|_| Vec::new()).collect();
    for (rings, &f) in parts.iter().zip(&part_feature) {
        // holes lie inside their outer ring and cannot widen the box
        if let Some(b) = rings.first().and_then(|r| ring_bounds(r)) {
            per_feature[(f - 1) as usize].push(b);
        }
    }

    let authalic = AuthalicProjection;
    let geodetic = |a: f64| authalic.inverse(Radians::new_unchecked(a)).get().to_degrees();
    let (mut xmin, mut ymin, mut xmax, mut ymax) =
        (vec![f64::NAN; n], vec![f64::NAN; n], vec![f64::NAN; n], vec![f64::NAN; n]);
    for (i, bounds) in per_feature.into_iter().enumerate() {
        if bounds.is_empty() {
            continue;
        }
        ymin[i] = geodetic(bounds.iter().map(|b| b.ymin).fold(f64::INFINITY, f64::min));
        ymax[i] = geodetic(bounds.iter().map(|b| b.ymax).fold(f64::NEG_INFINITY, f64::max));
        let arcs: Option<Vec<Arc>> = bounds.iter().map(|b| b.lon).collect();
        match arcs.and_then(union_arcs) {
            Some(a) => {
                xmin[i] = a.start;
                xmax[i] = a.end;
            }
            None => {
                xmin[i] = -180.0;
                xmax[i] = 180.0;
            }
        }
    }
    let na = |v: Vec<f64>| -> Doubles {
        v.into_iter().map(|x| if x.is_nan() { Rfloat::na() } else { Rfloat::from(x) }).collect()
    };
    list!(xmin = na(xmin), ymin = na(ymin), xmax = na(xmax), ymax = na(ymax))
}

extendr_module! {
    mod bbox;
    fn a5_bbox_rs;
}
