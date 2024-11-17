struct Uniforms {
  canvasSize: vec2f,
  pan: vec2f,
  zoom: f32
};

struct Output {
  @builtin(position) position: vec4f,
  @location(0) texcoord: vec2f
};

@group(0) @binding(0) var<uniform> uniforms: Uniforms;
@group(0) @binding(1) var<storage, read> instances: array<vec3f>;

@vertex
fn vs(
  @builtin(vertex_index) vertexIndex: u32,
  @builtin(instance_index) instanceIndex: u32
) -> Output {
  let pos = array(
    // 1st triangle
    vec2f( 0.0,  0.0),  // left, top
    vec2f( 1.0,  0.0),  // right, center
    vec2f( 0.0,  1.0),  // center, top
 
    // 2nd triangle
    vec2f( 0.0,  1.0),  // center, top
    vec2f( 1.0,  0.0),  // right, center
    vec2f( 1.0,  1.0),  // right, top
  );

  let texcoord = pos[vertexIndex];

  let instance = instances[instanceIndex];
  let center = instance.xy;
  let size = instance.z;
  
  let vertexcoord = texcoord * 2.0 - 1.0;
  let vertex = ((vertexcoord * size + center) * uniforms.zoom + uniforms.pan) / uniforms.canvasSize * 2;

  return Output(
    vec4f(vertex, 0.0, 1.0),
    texcoord
  );
}

fn circle(st: vec2f, radius: f32) -> f32 {
  let dist = st - vec2(0.5);
  return 1.0 - smoothstep(radius - (radius * 0.01),
      radius + (radius * 0.01),
      dot(dist, dist) * 4.0);
}

@fragment
fn fs(fsInput: Output) -> @location(0) vec4f {
  return mix(vec4(0), vec4(1.0, 0.0, 0.0, 1.0), circle(fsInput.texcoord, 1.0));
}