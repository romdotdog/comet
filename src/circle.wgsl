struct Uniforms {
  canvasSize: vec2f,
  pan: vec2f,
  cursor: vec2f,
  zoom: f32
};

struct VertexOutput {
  @builtin(position) position: vec4f,
  @location(0) color: vec4f,
  @location(1) texcoord: vec2f,
  @interpolate(flat) @location(2) hovering: u32
};

struct Output {
  @location(0) hovering: u32
}

@group(0) @binding(0) var<uniform> uniforms: Uniforms;
@group(0) @binding(1) var<storage, read> instances: array<vec3f>;
@group(0) @binding(2) var<storage, read_write> data: Output;

@vertex
fn vs(
  @builtin(vertex_index) vertexIndex: u32,
  @builtin(instance_index) instanceIndex: u32
) -> VertexOutput {
  let pos = array(
    // 1st triangle
    vec2f(0.0,  0.0),  // left, top
    vec2f(1.0,  0.0),  // right, center
    vec2f(0.0,  1.0),  // center, top
 
    // 2nd triangle
    vec2f(0.0,  1.0),  // center, top
    vec2f(1.0,  0.0),  // right, center
    vec2f(1.0,  1.0),  // right, top
  );

  let texcoord = pos[vertexIndex];

  let instance = instances[instanceIndex];
  let center = instance.xy;
  let size = instance.z;
  
  let vertexcoord = texcoord * 2.0 - 1.0;
  let vertex = ((vertexcoord * size + center) * uniforms.zoom + uniforms.pan) / uniforms.canvasSize * 2;

  let hovered = distance(center * uniforms.zoom + uniforms.pan, vec2(uniforms.cursor.x - uniforms.canvasSize.x / 2, uniforms.canvasSize.y / 2 - uniforms.cursor.y)) < size * uniforms.zoom;  
  let color = mix(vec4(0.7, 0.7, 0.7, 1.0), vec4(1.0, 0.3, 0.3, 1.0), f32(hovered));

  return VertexOutput(
    vec4f(vertex, 0.0, 1.0),
    color,
    texcoord,
    u32(hovered)
  );
}

fn circle(st: vec2f, radius: f32) -> f32 {
  let dist = st - vec2(0.5);
  return 1.0 - smoothstep(radius - (radius * 0.01),
      radius + (radius * 0.01),
      dot(dist, dist) * 4.0);
}

@fragment
fn fs(fsInput: VertexOutput) -> @location(0) vec4f {
  if (data.hovering == 0 && fsInput.hovering == 1) {
    data.hovering = 1;
  }
  return mix(vec4(0), fsInput.color, circle(fsInput.texcoord, 1.0));
}