// vi: ft=wgsl ts=4 sw=4

@group(0) @binding(0) var<uniform> EPS2: f32;
@group(0) @binding(1) var<uniform> n_objects: u32;
@group(0) @binding(2) var<storage, read_write> objects: array<vec3f>;
@group(0) @binding(3) var<storage, read_write> accelerations: array<vec2f>;

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
    var acc = accelerations[id.x];

    var tile = 0u;
    var i = 0u;
    while (i < n_objects) {
        tile_objects[local_id.x] = objects[i];
        workgroupBarrier();
        acc += tile_calculation(object);
        workgroupBarrier();
        i += p;
        tile++;
    }
}

fn tile_calculation(my_pos: vec3f) -> vec2f {
    var acc = vec2f(0, 0);
    for (var j = 0u; j < p; j++) {
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