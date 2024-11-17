when not defined(js):
  {.fatal: "comet must be compiled with the JavaScript backend.".}

# import jsconsole, jsffi, macros
import dom, asyncjs, std/with, std/random, jsconsole # , sugar

import jscanvas

import ./[webgpu, typed_arrays, init]

const
  CircleWGSL = staticRead("circle.wgsl")

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
    format: presentationFormat,
    alphaMode: "premultiplied"
  ))

  # var data {.group: 0, binding: 0, flags: [storage, read_write].}: array[f32]

  # proc main(id {.builtin: global_invocation_id.}: vec3u) {.compute, workgroup_size: 1.} =
  #   let i = id.x
  #   data[i] = data[i] * 2

  let
    shaderModule = device.createShaderModule(GPUShaderModuleDescriptor(
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

    computePipeline = device.createComputePipeline(GPUComputePipelineDescriptor(
      label: "doubling compute pipeline",
      layout: "auto",
      compute: GPUComputeDescriptor(
        entryPoint: "main",
        module: shaderModule
      )
    ))

  let n = rand(3..1000)
  var input = TypedArray[float32].new(n * 4)

  for i in 0..<n:
    input[i * 4] = rand[float32](-1000.0'f32..1000.0'f32)
    input[i * 4 + 1] = rand[float32](-1000.0'f32..1000.0'f32)
    input[i * 4 + 2] = rand[float32](10.0'f32..20.0'f32)

  console.log("input", input)

  # we have to add zeroes because of padding

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

  # let
  #   bindGroup = device.createBindGroup(GPUBindGroupDescriptor(
  #     label: "bindGroup for work buffer",
  #     layout: computePipeline.getBindGroupLayout(0),
  #     entries: @[
  #       GPUBindGroupEntry(
  #         binding: 0,
  #         resource: GPUResourceDescriptor(buffer: workBuffer)
  #       )
  #     ]
  #   ))

  #   encoder = device.createCommandEncoder(label = "doubling encoder")
  #   pass = encoder.beginComputePass(label = "doublin compute pass")

  # with pass:
  #   setPipeline(computePipeline)
  #   setBindGroup(0, bindGroup)
  #   dispatchWorkgroups(int(input.len / 4))
  #   `end`()

  # encoder.copyBufferToBuffer(
  #   workBuffer,
  #   0,
  #   resultBuffer,
  #   0,
  #   input.byteLength
  # )

  let module = device.createShaderModule(GPUShaderModuleDescriptor(code: CircleWGSL))

  let pipeline = device.createRenderPipeline(GPURenderPipelineDescriptor(
    layout: "auto",
    vertex: GPUVertex(
      module: module
    ),
    fragment: GPUFragment(
      module: module,
      targets: @[
        GPUTarget(
          format: presentationFormat,
          blend: GPUBlend(
            color: GPUBlendComponent(
              srcFactor: "src-alpha",
              dstFactor: "one-minus-src-alpha"
            ),
            alpha: GPUBlendComponent(
              srcFactor: "src-alpha",
              dstFactor: "one-minus-src-alpha"
            )
          )
        )
      ]
    ),
    primitive: GPUPrimitive(
      topology: "triangle-list"
    )
  ))

  let dimensionsBuffer = device.createBuffer(GPUBufferDescriptor(
    label: "dimensions buffer",
    size: 16,
    usage: {CopyDst, Uniform}.toInt()
  ))

  let dimensions = TypedArray.new(@[canvas.width.float32, canvas.height.float32])
  device.queue.writeBuffer(dimensionsBuffer, 0, dimensions)

  let bindGroup = device.createBindGroup(GPUBindGroupDescriptor(
      label: "bindGroup for vertex shader",
      layout: pipeline.getBindGroupLayout(0),
      entries: @[
        GPUBindGroupEntry(
          binding: 0,
          resource: GPUResourceDescriptor(buffer: dimensionsBuffer)
        ),
        GPUBindGroupEntry(
          binding: 1,
          resource: GPUResourceDescriptor(buffer: workBuffer)
        )
      ]
    ))


  let renderPassDescriptor = GPURenderPassDescriptor(
    colorAttachments: @[
      GPURenderPassColorAttachment(
        view: nil,
        clearValue: [0.0, 0.0, 0.0, 0.0], # Clear to transparent black
        loadOp: "clear",
        storeOp: "store"
      )
    ]
  )

  let texture = ctx.getCurrentTexture()
  let textureView = texture.createView()

  renderPassDescriptor.colorAttachments[0].view = textureView

  let commandEncoder = device.createCommandEncoder()

  let passEncoder = commandEncoder.beginRenderPass(renderPassDescriptor)
  with passEncoder:
    setPipeline(pipeline)
    setBindGroup(0, bindGroup)
    draw(6, n)
    `end`()

  let commandBuffer = commandEncoder.finish()

  device.queue.submit(@[commandBuffer])

  # await resultBuffer.mapAsync(Read)
  # let shaderResult = TypedArray[float32].new(resultBuffer.getMappedRange())

  # console.log("input", input)
  # console.log("result", shaderResult)

  # resultBuffer.unmap()


  # proc frame(time: float) =
  #   
  #   discard window.requestAnimationFrame(frame)

  # discard window.requestAnimationFrame(frame)

discard getDeviceAndExecute(main)
