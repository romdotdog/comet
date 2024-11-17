when not defined(js):
  {.fatal: "comet must be compiled with the JavaScript backend.".}

# import jsconsole, jsffi, macros
import dom, asyncjs, std/with, jsconsole # , sugar

import jscanvas

import ./[webgpu, typed_arrays, init]

# const
#   TriangleVertWGSL = staticRead("triangle.vert.wgsl")
#   RedFragWGSL = staticRead("red.frag.wgsl")

proc main(device: GPUDevice) {.async nimcall.} =
  let
    canvas = document.getElementById("canvas").CanvasElement
    ctx = canvas.getContextWebGPU()
    devicePixelRatio = window.devicePixelRatio;

  canvas.width = int(canvas.clientWidth.float * devicePixelRatio)
  canvas.height = int(canvas.clientHeight.float * devicePixelRatio)

  let presentationFormat = await navigator.gpu.getPreferredCanvasFormat()

  ctx.configure(GPUContextConfiguration(
    device: device,
    format: presentationFormat
  ))

  # var data {.group: 0, binding: 0, flags: [storage, read_write].}: array[f32]

  # proc main(id {.builtin: global_invocation_id.}: vec3u) {.compute, workgroup_size: 1.} =
  #   let i = id.x
  #   data[i] = data[i] * 2

  let
    shaderModule = device.createShaderModule(ShaderModuleDescriptor(
      label: "doubling compute shader",
      code: """
      @group(0) @binding(0) var<storage, read_write> data: array<vec3f>;

      @compute @workgroup_size(1) fn main(
        @builtin(global_invocation_id) id: vec3u
      ) {
        let i = id.x;
        data[i] = data[i] * 2;
      }
      """
    ))

    pipeline = device.createComputePipeline(GPUComputePipelineDescriptor(
      label: "doubling compute pipeline",
      layout: "auto",
      compute: GPUComputeDescriptor(
        entryPoint: "main",
        module: shaderModule
      )
    ))

  # we have to add zeroes because of padding
  var input = TypedArray.new(@[1'f32, 3, 5, 0, 1, 3, 5, 0, 1, 3, 5, 0])

  let
    workBuffer = device.createBuffer(GPUBufferDescriptor(
      label: "work buffer",
      size: input.byteLength,
      usage: {GPUBufferUsage.Storage, CopySrc, CopyDst}.toInt()
    ))

    resultBuffer = device.createBuffer(GPUBufferDescriptor(
      label: "result buffer",
      size: input.byteLength,
      usage: {MapRead, CopyDst}.toInt()
    ))

  device.queue.writeBuffer(workBuffer, 0, input)

  let
    bindGroup = device.createBindGroup(GPUBindGroupDescriptor(
      label: "bindGroup for work buffer",
      layout: pipeline.getBindGroupLayout(0),
      entries: @[
        GPUBindGroupEntry(
          binding: 0,
          resource: GPUResourceDescriptor(buffer: workBuffer)
        )
      ]
    ))

    encoder = device.createCommandEncoder(label = "doubling encoder")
    pass = encoder.beginComputePass(label = "doublin compute pass")

  with pass:
    setPipeline(pipeline)
    setBindGroup(0, bindGroup)
    dispatchWorkgroups(int(input.len / 4))
    `end`()

  encoder.copyBufferToBuffer(
    workBuffer,
    0,
    resultBuffer,
    0,
    input.byteLength
  )

  let commandBuffer = encoder.finish()

  device.queue.submit(@[commandBuffer])

  await resultBuffer.mapAsync(Read)
  let shaderResult = TypedArray[float32].new(resultBuffer.getMappedRange())

  console.log("input", input)
  console.log("result", shaderResult)

  resultBuffer.unmap()

  # let pipeline = device.createRenderPipeline(GPURenderPipelineDescriptor(
  #   layout: "auto",
  #   vertex: GPUVertex(
  #     module: device.createShaderModule(TriangleVertWGSL)
  #   ),
  #   fragment: GPUFragment(
  #     module: device.createShaderModule(RedFragWGSL),
  #     targets: @[
  #       GPUTarget(format: presentationFormat)
  #     ]
  #   ),
  #   primitive: GPUPrimitive(
  #     topology: "triangle-list"
  #   )
  # ))

  # let renderPassDescriptor = GPURenderPassDescriptor(
  #   colorAttachments: @[
  #     GPURenderPassColorAttachment(
  #       view: nil,
  #       clearValue: [0.0, 0.0, 0.0, 0.0], # Clear to transparent black
  #       loadOp: "clear",
  #       storeOp: "store"
  #     )
  #   ]
  # )

  # proc frame(time: float) =
  #   let texture = ctx.getCurrentTexture()
  #   let textureView = texture.createView()

  #   renderPassDescriptor.colorAttachments[0].view = textureView

  #   let commandEncoder = device.createCommandEncoder()

  #   let passEncoder = commandEncoder.beginRenderPass(renderPassDescriptor)
  #   passEncoder.setPipeline(pipeline)
  #   passEncoder.draw(3)
  #   passEncoder.end()

  #   device.queue.submit(@[commandEncoder.finish()])
  #   discard window.requestAnimationFrame(frame)

  # discard window.requestAnimationFrame(frame)

discard getDeviceAndExecute(main)
