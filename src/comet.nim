when not defined(js):
  {.fatal: "comet must be compiled with the JavaScript backend.".}

# import jsconsole, jsffi, macros
import dom, asyncjs, std/with, std/random, jsconsole, math # , sugar

import jscanvas

import ./[webgpu, typed_arrays, init]

const
  CircleWGSL = staticRead("circle.wgsl")

proc lerp(v0, v1, t: float32): float32 =
  (1 - t) * v0 + t * v1

type Simulation = ref object
  canvas: CanvasElement

proc main(device: GPUDevice) {.async.} =
  let
    canvas = document.getElementById("canvas").CanvasElement
    rect = canvas.getBoundingClientRect()
    ctx = canvas.getContextWebGPU()
    devicePixelRatio = window.devicePixelRatio

  # TODO: Move this to a separate module
  var
    scaleOffset = 1.0
    scaleTarget = 1.0

    panOffsetX = 0.0
    panOffsetY = 0.0
    panVelocityX = 0.0
    panVelocityY = 0.0

    lastMouseX = 0.0
    lastMouseY = 0.0

    currentlyPanning = false

    retMouseX = 0.0
    retMouseY = 0.0

  proc getMouse(e: MouseEvent) =
    retMouseX =
      (e.clientX.float - rect.left) * (canvas.width.float / rect.width.float)
    retMouseY =
      (e.clientY.float - rect.top) * (canvas.height.float / rect.height.float)

  canvas.addEventListener("mousedown", proc(e: Event) =
    currentlyPanning = true
    canvas.setAttribute("grabbing", "")

    let mouseEvent = e.MouseEvent
    getMouse(mouseEvent)
    lastMouseX = retMouseX
    lastMouseY = retMouseY)

  canvas.addEventListener("mouseup", proc(e: Event) =
    canvas.removeAttribute("grabbing")

    if abs(panVelocityX) < devicePixelRatio:
      panVelocityX = 0
    if abs(panVelocityY) < devicePixelRatio:
      panVelocityY = 0

    currentlyPanning = false)

  canvas.addEventListener("mousemove", proc(e: Event) =
    if currentlyPanning:
      let mouseEvent = e.MouseEvent

      getMouse(mouseEvent)
      let
        currentMouseX = retMouseX
        currentMouseY = retMouseY

      # calculate delta
      let
        deltaX = (currentMouseX - lastMouseX)
        deltaY = -(currentMouseY - lastMouseY)

      # apply delta to pan offsets
      panOffsetX += deltaX
      panOffsetY += deltaY

      # track velocity
      panVelocityX = lerp(panVelocityX, deltaX, 0.8)
      panVelocityY = lerp(panVelocityY, deltaY, 0.8)

      # update last mouse position
      lastMouseX = currentMouseX
      lastMouseY = currentMouseY)

  type WheelEvent = ref object of MouseEvent
    deltaY: float32

  canvas.addEventListener("wheel", proc(e: Event) =
    let wheelEvent = e.WheelEvent
    getMouse(wheelEvent)
    lastMouseX = retMouseX
    lastMouseY = retMouseY
    scaleTarget *= pow(1.4, -wheelEvent.deltaY.float32 / 100.0))

  proc processMomentum() =
    # wheel
    if scaleTarget < 0.03:
      scaleTarget = 0.03
    elif scaleTarget > 4.0:
      scaleTarget = 4.0

    if abs(scaleOffset - scaleTarget) > 0.01:
      let old = scaleOffset
      scaleOffset = lerp(scaleOffset, scaleTarget, 0.9)

      let factor = 1 - scaleOffset / old

      # map mouse position to canvas space

      # map x from [0, width] to [-width/2, width/2]
      let mouseX = lastMouseX - canvas.width/2
      
      # map y from [0, height] to [height/2, -height/2]
      let mouseY = canvas.height/2 - lastMouseY

      # consider whether taking into account the mouse position
      # while zooming out is inconvenient
      panOffsetX += (mouseX - panOffsetX) * factor
      panOffsetY += (mouseY - panOffsetY) * factor
      
    # pan

    if not currentlyPanning:
      panOffsetX += 2 * panVelocityX
      panOffsetY += 2 * panVelocityY

    panVelocityX *= 0.9
    panVelocityY *= 0.9

  canvas.width = int(rect.right.float * devicePixelRatio) - int(rect.left.float * devicePixelRatio)
  canvas.height = int(rect.bottom.float * devicePixelRatio) - int(rect.top.float * devicePixelRatio)

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

    computePipeline =
      await device.createComputePipelineAsync(GPUComputePipelineDescriptor(
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
    input[i * 4] = rand[float32](-500.0'f32..500.0'f32)
    input[i * 4 + 1] = rand[float32](-500.0'f32..500.0'f32)
    input[i * 4 + 2] = rand[float32](5.0'f32..10.0'f32)

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

  var uniform = [canvas.width.float32, canvas.height.float32, 0, 0, 1, 0]

  let
    module =
      device.createShaderModule(GPUShaderModuleDescriptor(code: CircleWGSL))

    pipeline =
      await device.createRenderPipelineAsync(GPURenderPipelineDescriptor(
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

    uniformBuffer = device.createBuffer(GPUBufferDescriptor(
      label: "uniform buffer",
      size: uniform.byteLength,
      usage: {CopyDst, Uniform}.toInt()
    ))

    bindGroup = device.createBindGroup(GPUBindGroupDescriptor(
      label: "bindGroup for vertex shader",
      layout: pipeline.getBindGroupLayout(0),
      entries: @[
        GPUBindGroupEntry(
          binding: 0,
          resource: GPUResourceDescriptor(buffer: uniformBuffer)
        ),
        GPUBindGroupEntry(
          binding: 1,
          resource: GPUResourceDescriptor(buffer: workBuffer)
        )
      ]
    ))

    renderPassDescriptor = GPURenderPassDescriptor(
      colorAttachments: @[
        GPURenderPassColorAttachment(
          view: nil,
          clearValue: [0'f32, 0, 0, 0], # Clear to transparent black
          loadOp: "clear",
          storeOp: "store"
        )
      ]
    )

  proc frame(time: float) =
    processMomentum()
    uniform[2] = panOffsetX
    uniform[3] = panOffsetY
    uniform[4] = scaleOffset
    device.queue.writeBuffer(uniformBuffer, 0, uniform)

    let
      texture = ctx.getCurrentTexture()
      textureView = texture.createView()

    renderPassDescriptor.colorAttachments[0].view = textureView

    let
      commandEncoder = device.createCommandEncoder()
      passEncoder = commandEncoder.beginRenderPass(renderPassDescriptor)

    with passEncoder:
      setPipeline(pipeline)
      setBindGroup(0, bindGroup)
      draw(6, n)
      `end`()

    let commandBuffer = commandEncoder.finish()

    device.queue.submit(@[commandBuffer])

    discard window.requestAnimationFrame(frame)

  discard window.requestAnimationFrame(frame)


  # await resultBuffer.mapAsync(Read)
  # let shaderResult = TypedArray[float32].new(resultBuffer.getMappedRange())

  # console.log("input", input)
  # console.log("result", shaderResult)

  # resultBuffer.unmap()

discard getDeviceAndExecute() do (device: GPUDevice):
  discard main(device)