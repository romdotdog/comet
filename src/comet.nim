when not defined(js):
  {.fatal: "comet must be compiled with the JavaScript backend.".}

# import jsconsole, jsffi, macros
import
  std/with, math, strutils,
  asyncjs, jscore, jsconsole # , jsffi
import dom except Storage

import jscanvas

import ./[vec, webgpu, typed_arrays, init, gpu_utils, compute] # , async_utils, util]

const CanvasShader = staticRead("canvas.wgsl")

type
  Lerpable = concept
    proc `-`(a, b: Self): Self
    proc `*`(a, b: Self): Self

proc lerp[T: Lerpable](v0, v1, t: T): T =
  (T(1) - t) * v0 + t * v1

proc lerp[T: Lerpable](v0, v1: Vec2[T]; t: T): Vec2[T] =
  vec2(lerp(v0.x, v1.x, t), lerp(v0.y, v1.y, t))

type Simulation = ref object
  canvas: CanvasElement

# override the dom lib so we don't have copies
proc getBoundingClientRect*(
  e: Node
): ref BoundingRect {.importcpp: "getBoundingClientRect", nodecl.}

func offset(rect: ref BoundingRect): Vec2f = vec2(rect.left, rect.top)
func size(rect: ref BoundingRect): Vec2f = vec2(rect.width, rect.height)
func size(canvas: CanvasElement): Vec2f =
  vec2(canvas.width.float, canvas.height.float)
func position(e: MouseEvent): Vec2f = vec2(e.clientX.float, e.clientY.float)


func align(x, alignment: uint): uint {.inline.} =
  let a = x mod alignment
  if a == 0: x else: x + (alignment - a)

#
# converts mouse position from top left to canvas space from bottom left
func toBLCanvasCoords(
  pos: Vec2f,
  rect: ref BoundingRect,
  canvas: CanvasElement
): Vec2sf =
  result = pos.to(float32)
  result -= rect.offset.to(float32) # remove canvas offset
  result /= rect.size.to(float32) # [0, 1]
  result.y = 1 - result.y # invert y coordinate (0 means bottom)
  result *= canvas.size.to(float32) # [0, canvas size]

# TODO: Refactor, separate into different files. Organize, make it easy for the
#       render pipeline to be able to use the shared layout and bindgroup. Shit
#       here should be shorter, 500loc is too much
proc compute(device: GPUDevice) {.async.} =
  let
    nObjects = 4'u
    # shit must be padded for aligned
    nObjectsAligned = nObjects.align(DimP)
    eps2 = 1e-3'f32
    objects = TypedArray[float32].new(4 * nObjectsAligned)
    accelerations = TypedArray[float32].new(2 * nObjectsAligned)

  for i in countup(0, nObjects.int * 4, step = 4):
    objects[i + 0] = Math.random() * 40
    objects[i + 1] = Math.random() * 40
    objects[i + 2] = Math.random() * 10
    # objects[i + 0] = i.float32 * 4
    # objects[i + 1] = i.float32 * 5 - 0.5
    # objects[i + 2] = i.float32 * 10

  let compute = await initCompute(
    device,
    nObjects,
    objects,
    accelerations,
    eps2
  )

  compute.run()

  let
    resultBuffer = await compute.accelerations()
    shaderResult = TypedArray[float32].new(resultBuffer.getMappedRange())

  console.log("nObjects", nObjects)
  console.log("nObjectsAligned", nObjectsAligned)
  console.log("objects", objects)
  console.log("accelerations", accelerations)
  console.log("result", shaderResult)

  resultBuffer.unmap()

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
    panOffset = default Vec2sf
    panVelocity = default Vec2sf
    mouse = default Vec2sf
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
      panVelocity @= lerp(panVelocity, delta, 0.9)

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
      let mouseClip = mouse - canvas.size.to(float32) /. 2.0

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

  await compute(device)

  return

  # var data {.group: 0, binding: 0, flags: [storage, read_write].}: array[f32]

  # proc main(id {.builtin: global_invocation_id.}: vec3u) {.compute, workgroup_size: 1.} =
  #   let i = id.x
  #   data[i] = data[i] * 2

  let n = 1000
  var input = TypedArray[float32].new(n * 4)

  for i in 0..<n:
    input[i * 4 + 0] = Math.random() * 1000 - 500
    input[i * 4 + 1] = Math.random() * 1000 - 500
    input[i * 4 + 2] = Math.random() * 5 + 5

  console.log("input", input)

  # we have to add zeroes because of padding

  let
    workBuffer = device.createBuffer(
      label = "work buffer",
      size = input.byteLength,
      usage = {Storage, CopySrc, CopyDst}
    )

    outBuffer = device.createBuffer(
      label = "out buffer",
      size = 4,
      usage = {Storage, CopySrc, CopyDst}
    )

    resultBuffer = device.createBuffer(
      label = "result buffer",
      size = 4,
      usage = {MapRead, CopyDst}
    )

  device.queue.writeBuffer(workBuffer, 0, input)

  var uniform = [
    canvas.width.float32,
    canvas.height.float32,
    panOffset.x,
    panOffset.y,
    mouse.x,
    mouse.y,
    1,
    0
  ]

  let
    module =
      device.createShaderModule(GPUShaderModuleDescriptor(code: CanvasShader))

    pipeline =
      await device.createRenderPipelineAsync(GPURenderPipelineDescriptor(
        layout: device.createPipelineLayout(GPUPipelineLayoutDescriptor(
          label: "render pipeline layout",
          bindGroupLayouts: @[
            # sharedLayout,
            device.createBindGroupLayout(GPUBindGroupLayoutDescriptor(
              label: "render bindgroup layout",
              entries: @[
                bindGroupLayoutEntry(
                  binding = 0,
                  visibility = {GPUShaderStage.Vertex, Fragment},
                  buffer = GPULayoutEntryBuffer(`type`: "uniform")
                ),
                bindGroupLayoutEntry(
                  binding = 1,
                  visibility = {GPUShaderStage.Vertex, Fragment},
                  buffer = GPULayoutEntryBuffer(`type`: "storage")
                ),
              ]
            )),
          ]
        )),
        vertex: GPUVertex(
          module: module,
          buffers: @[
            GPUVertexBufferLayout(
              arrayStride: 16,
              stepMode: "vertex",
              attributes: @[
                GPUVertexBufferAttribute(
                  format: "float32x4",
                  shaderLocation: 0,
                  offset: 0
                )
              ]
            )
          ]
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

    uniformBuffer = device.createBuffer(
      label = "uniform buffer",
      size = uniform.byteLength,
      usage = {CopyDst, Uniform}
    )

    renderBindGroup = device.createBindGroup(GPUBindGroupDescriptor(
      label: "bindGroup for vertex shader",
      layout: pipeline.getBindGroupLayout(1),
      entries: @[
        bufferBindGroupEntry(
          binding = 0,
          buffer = uniformBuffer
        ),
        bufferBindGroupEntry(
          binding = 1,
          buffer = outBuffer
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
    uniform[2..6] = [
      panOffset.x.float32,
      panOffset.y,
      mouse.x,
      mouse.y,
      scaleOffset
    ]
    device.queue.writeBuffer(uniformBuffer, 0, uniform)

    let
      texture = ctx.getCurrentTexture()
      textureView = texture.createView()

    renderPassDescriptor.colorAttachments[0].view = textureView

    let commandEncoder = device.createCommandEncoder()

    commandEncoder.clearBuffer(outBuffer)

    let passEncoder = commandEncoder.beginRenderPass(renderPassDescriptor)

    with passEncoder:
      setPipeline(pipeline)
      # setBindGroup(0, sharedBindGroup)
      setBindGroup(1, renderBindGroup)
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

    timing.textContent = cstring(formatFloat(1000 / dt, precision = 1))

    # discard window.requestAnimationFrame() do (time: float): discard frame(time)

  discard window.requestAnimationFrame() do (time: float): discard frame(time)


discard getDeviceAndExecute() do (device: GPUDevice):
  discard main(device)