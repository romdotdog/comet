// vi: ft=wgsl ts=4 sw=4

@group(0) @binding(0) var<uniform> EPS2: f32;
@group(0) @binding(1) var<uniform> n_objects: u32;
@group(0) @binding(2) var<storage, read_write> objects: array<vec3f>;
@group(0) @binding(3) var<storage, read_write> accelerations: array<vec2f>;

@compute @workgroup_size(9, 1, 1) fn main(
    @builtin(global_invocation_id) id: vec3u
) {
    let i = id.x;
    if (i >= n_objects) { return; }
    let bi = objects[i];
    let acc = tile_calculation(bi, accelerations[i]);
    accelerations[i] = acc;
}

fn tile_calculation(my_pos: vec3f, acceleration: vec2f) -> vec2f {
    var acc = acceleration;
    for (var j = 0u; j < n_objects; j++) {
        let bj = objects[j];
        acc += body_body_interaction(my_pos, bj, acc);
    }
    return acc;
}

fn body_body_interaction(bi: vec3f, bj: vec3f, ai: vec2f) -> vec2f {
    let r = bj - bi;
    let distSqr = dot(r, r) + EPS2;
    let distSixth = distSqr * distSqr * distSqr;
    let invDistCube = 1.0f / sqrt(distSixth);
    let s = bj.z * invDistCube;
    return r.xy * s;
}