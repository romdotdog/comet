// vi: ft=wgsl ts=4 sw=4

// shared
@group(0) @binding(0) var<uniform> n_objects: u32;
@group(0) @binding(1) var<storage, read_write> objects: array<vec3f>; // xy is current pos, z is mass
@group(0) @binding(2) var<storage, read_write> prevpos_newaccel: array<vec4f>; // xy is prev pos, wz is new accel

const EPS2: f32 = 1e-3;
const MASS_MULTIPLIER = 1000;

const p = $#;
const q = $#;
const workgroup_size = p; //  * q;

var<workgroup> tile_objects: array<vec3f, workgroup_size>;

@compute @workgroup_size(p, 1, 1) fn main(
    @builtin(global_invocation_id) id: vec3u,
    @builtin(local_invocation_id) local_id: vec3u,
    @builtin(workgroup_id) wg_id: vec3u,
) {
    let n_objects = n_objects;
    let object = objects[id.x];
    var acc = vec2f(0, 0);
    var prev_pos = prevpos_newaccel[id.x].xy;

    var tile = 0u;
    var i = 0u;
    while (i < n_objects) {
        tile_objects[local_id.x] = objects[i + local_id.x];
        workgroupBarrier();

        // start tile
        let n_wg_objects = min(n_objects - i, workgroup_size);
        for (var j = 0u; j < n_wg_objects; j++) {
            let bj = tile_objects[j];
            acc += body_body_interaction(object, bj);
            prev_pos += resolve_collision(object, bj);
        }
        // end tile

        workgroupBarrier();
        i += p;
        tile++;
    }

    prevpos_newaccel[id.x] = vec4f(prev_pos, acc);
}

fn body_body_interaction(bi: vec3f, bj: vec3f) -> vec2f {
    let r = bj - bi;
    let distSqr = dot(r, r) + EPS2;
    let distSixth = distSqr * distSqr * distSqr;
    let invDistCube = inverseSqrt(distSixth);
    let m = MASS_MULTIPLIER * bj.z * bj.z;
    let s = m * invDistCube;
    return r.xy * s;
}

fn resolve_collision(bi: vec3f, bj: vec3f) -> vec2f {
    var correction = vec2f(0, 0);
    let pi = bi.xy;
    let pj = bj.xy;
    let ri = bi.z;
    let rj = bj.z;

    let delta = pj - pi;
    let dist = length(delta);
    let minDist = ri + rj;
    if (dist < minDist && dist > 0.0) {
        let n = delta / dist;
        let penetration = minDist - dist;

        // move them apart proportional to inverse mass
        let w1 = (rj * rj) / (ri * ri + rj * rj);
        correction = n * penetration * w1;
    }

    return correction;
}
