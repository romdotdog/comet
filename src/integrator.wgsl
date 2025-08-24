@group(0) @binding(0) var<uniform> n_objects: u32;
@group(0) @binding(1) var<storage, read_write> objects: array<vec3f>; // xy is current pos, z is mass
@group(0) @binding(2) var<storage, read_write> prevpos_newaccel: array<vec4f>; // xy is prev pos, wz is new accel

const dt: f32 = 1.0/60.0; // for now

@compute @workgroup_size(64)
fn main(@builtin(global_invocation_id) id: vec3u) {
    let i = id.x;
    if (i >= n_objects) { return; }

    let this_prevpos_newaccel = prevpos_newaccel[i];

    let prev_pos = this_prevpos_newaccel.xy;
    let accel = this_prevpos_newaccel.zw;

    let this_object = objects[i];
    let cur_pos = this_object.xy;

    // verlet integration
    let next_pos = 2.0 * cur_pos - prev_pos + accel * (dt * dt);

    // update
    prevpos_newaccel[i] = vec4f(cur_pos, 0, 0);
    objects[i] = vec3f(next_pos, this_object.z);
}