when not defined(js):
  {.fatal: "comet must be compiled with the JavaScript backend.".}

# import jsconsole, jsffi, macros
import dom, asyncjs, std/with, jsconsole, math

import jscanvas

import ./[vec, webgpu, typed_arrays, init]

const
  CircleWGSL = staticRead("circle.wgsl")

proc lerp(v0, v1, t: float32): float32 =
  (1 - t) * v0 + t * v1

type Simulation = ref object
  canvas: CanvasElement

proc random(): float {.importjs: "Math.random()".}

# override the dom lib so we don't have copies
proc getBoundingClientRect*(
  e: Node
): ref BoundingRect {.importcpp: "getBoundingClientRect", nodecl.}

func offset(rect: ref BoundingRect): Vec2f = vec2(rect.left, rect.top)
func size(rect: ref BoundingRect): Vec2f = vec2(rect.width, rect.height)
func size(canvas: CanvasElement): Vec2f = vec2(canvas.width.float, canvas.height.float)
func position(e: MouseEvent): Vec2f = vec2(e.clientX.float, e.clientY.float)

# converts mouse position from top left to canvas space from bottom left
func toBLCanvasCoords(pos: Vec2f, rect: ref BoundingRect, canvas: CanvasElement): Vec2f =
  result = vec2(pos)
  result -= rect.offset # remove canvas offset
  result.y = rect.height.float - result.y # invert y coordinate (0 means bottom)
  result /= rect.size # [0, 1]
  result *= canvas.size # [0, canvas size]

proc main(device: GPUDevice) {.async.} =
  let
    timing = document.getElementById("timing")
    canvas = document.getElementById("canvas").CanvasElement
    rect = canvas.getBoundingClientRect()
    ctx = canvas.getContextWebGPU()
    devicePixelRatio = window.devicePixelRatio

  # TODO: Move this to a separate module
  var
    scaleOffset = 1.0
    scaleTarget = 1.0
    panOffset = default Vec2f
    panVelocity = default Vec2f
    mouse = default Vec2f
    currentlyPanning = false

  canvas.addEventListener("mousedown", proc(e: Event) =
    currentlyPanning = true
    canvas.setAttribute("grabbing", "")
    mouse @= MouseEvent(e).position.toBLCanvasCoords(rect, canvas))

  canvas.addEventListener("mouseup", proc(e: Event) =
    canvas.removeAttribute("grabbing")

    if abs(panVelocity.x) < devicePixelRatio:
      panVelocity.x = 0
    if abs(panVelocity.y) < devicePixelRatio:
      panVelocity.y = 0

    currentlyPanning = false)

  canvas.addEventListener("mousemove", proc(e: Event) =
    let currentMouse = e.MouseEvent.position.toBLCanvasCoords(rect, canvas)
    # console.log(currentMouse.x, currentMouse.y)
    if currentlyPanning:
      # calculate delta
      var delta = currentMouse - mouse
      # apply delta to pan offsets
      panOffset += delta
      # track velocity
      panVelocity.x = lerp(panVelocity.x, delta.x, 0.8) # TODO: make lerp work on vecs?
      panVelocity.y = lerp(panVelocity.y, delta.y, 0.8)

    # update mouse position
    mouse @= currentMouse)

  type WheelEvent = ref object of MouseEvent
    deltaY: float32

  canvas.addEventListener("wheel", proc(e: Event) =
    let wheelEvent = e.WheelEvent
    mouse @= wheelEvent.position().toBLCanvasCoords(rect, canvas)
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

      # map mouse position to canvas clip space
      # map x from [0, width] to [-width/2, width/2]
      # map y from [0, height] to [-height/2, height/2]
      let mouseClip = mouse - canvas.size /. 2.0

      # TODO: consider whether taking into account the mouse position
      # while zooming out is inconvenient
      panOffset += (mouseClip - panOffset) *. factor

    # pan

    if not currentlyPanning:
      panOffset += panVelocity *. 2

    panVelocity *=. 0.9

  canvas.width =
    int(rect.right.float * devicePixelRatio) -
    int(rect.left.float * devicePixelRatio)
  canvas.height =
    int(rect.bottom.float * devicePixelRatio) -
    int(rect.top.float * devicePixelRatio)

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

  let n = 1000 #int(random() * 1000 + 3)
  var input = TypedArray[float32].new(n * 4)

  for i in 0..<n:
    input[i * 4] = random() * 1000 - 500
    input[i * 4 + 1] = random() * 1000 - 500
    input[i * 4 + 2] = random() * 5 + 5

  console.log("input", input)

  # we have to add zeroes because of padding

  let
    workBuffer = device.createBuffer(GPUBufferDescriptor(
      label: "work buffer",
      size: input.byteLength,
      usage: {GPUBufferUsage.Storage, CopySrc, CopyDst}.toInt()
    ))

    outBuffer = device.createBuffer(GPUBufferDescriptor(
      label: "out buffer",
      size: 4,
      usage: {GPUBufferUsage.Storage, CopySrc, CopyDst}.toInt()
    ))

    resultBuffer = device.createBuffer(GPUBufferDescriptor(
      label: "result buffer",
      size: 4,
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

  var uniform = TypedArray[float32].new(@[
    canvas.width.float32,
    canvas.height.float32,
    panOffset.x,
    panOffset.y,
    mouse.x,
    mouse.y,
    1,
    0
  ])

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
        ),
        GPUBindGroupEntry(
          binding: 2,
          resource: GPUResourceDescriptor(buffer: outBuffer)
        )
      ]
    ))

    renderPassDescriptor = GPURenderPassDescriptor(
      colorAttachments: @[
        GPURenderPassColorAttachment(
          view: nil,
          clearValue: [0.1'f32, 0.1, 0.1, 1], # Clear to transparent black
          loadOp: "clear",
          storeOp: "store"
        )
      ]
    )

  var prevTime = 0.0
  proc frame(time: float) {.async.} =
    let dt = time - prevTime
    prevTime = time

    processMomentum()
    uniform[2] = panOffset.x
    uniform[3] = panOffset.y
    uniform[4] = mouse.x
    uniform[5] = mouse.y
    uniform[6] = scaleOffset
    device.queue.writeBuffer(uniformBuffer, 0, uniform)

    let
      texture = ctx.getCurrentTexture()
      textureView = texture.createView()

    renderPassDescriptor.colorAttachments[0].view = textureView

    let
      commandEncoder = device.createCommandEncoder()

    commandEncoder.clearBuffer(outBuffer)

    let passEncoder = commandEncoder.beginRenderPass(renderPassDescriptor)

    with passEncoder:
      setPipeline(pipeline)
      setBindGroup(0, bindGroup)
      draw(6, n)
      `end`()

    commandEncoder.copyBufferToBuffer(
      outBuffer,
      0,
      resultBuffer,
      0,
      4
    )

    let commandBuffer = commandEncoder.finish()

    device.queue.submit(@[commandBuffer])

    discard await resultBuffer.mapAsync(Read)
    let shaderResult = TypedArray[uint32].new(resultBuffer.getMappedRange())
    if shaderResult[0] == 1:
      canvas.setAttribute("pointing", "")
    else:
      canvas.removeAttribute("pointing")

    # console.log("result", shaderResult[0])
    resultBuffer.unmap()

    timing.textContent = cstring($round(1000 / dt, 1))

    discard window.requestAnimationFrame() do (time: float): discard frame(time)

  discard window.requestAnimationFrame() do (time: float): discard frame(time)


  # await resultBuffer.mapAsync(Read)
  # let shaderResult = TypedArray[float32].new(resultBuffer.getMappedRange())

  # console.log("input", input)
  # console.log("result", shaderResult)

  # resultBuffer.unmap()

discard getDeviceAndExecute() do (device: GPUDevice):
  discard main(device)