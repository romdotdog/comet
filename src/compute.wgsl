// vi: ft=wgsl ts=4 sw=4

// shared
@group(0) @binding(0) var<uniform> n_objects: u32;
@group(0) @binding(1) var<storage, read> objects: array<vec3f>;

// private to pipeline
@group(1) @binding(0) var<uniform> EPS2: f32;
@group(1) @binding(1) var<storage, read_write> accelerations: array<vec2f>;

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

    var tile = 0u;
    var i = 0u;
    while (i < n_objects) {
        tile_objects[local_id.x] = objects[i + local_id.x];
        workgroupBarrier();
        let n_wg_objects = min(n_objects - i, workgroup_size);
        acc += tile_calculation(object, n_wg_objects);
        workgroupBarrier();
        i += p;
        tile++;
    }

    accelerations[id.x] = acc;
}

fn tile_calculation(my_pos: vec3f, n: u32) -> vec2f {
    var acc = vec2f(0, 0);
    for (var j = 0u; j < n; j++) {
        let bj = tile_objects[j];
        acc += body_body_interaction(my_pos, bj);
    }
    return acc;
}

fn body_body_interaction(bi: vec3f, bj: vec3f) -> vec2f {
    let r = bj - bi;
    let distSqr = dot(r, r) + EPS2;
    let distSixth = distSqr * distSqr * distSqr;
    let invDistCube = inverseSqrt(distSixth);
    let s = bj.z * invDistCube;
    return r.xy * s;
}