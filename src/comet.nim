when not defined(js):
  {.fatal: "comet must be compiled with the JavaScript backend.".}

# import jsconsole, jsffi, macros
import
  std/with, math, strutils,
  asyncjs, jscore, jsconsole # , jsffi
import dom except Storage

import jscanvas

import ./[vec, webgpu, typed_arrays, init] # , async_utils, util]

const
  DimP = 9
  DimQ = 1
  CanvasShader = staticRead("canvas.wgsl")
  ComputeShader = staticRead("compute.wgsl") % [$DimP, $DimQ]

proc lerp(v0, v1, t: float32): float32 =
  (1 - t) * v0 + t * v1

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

template dbg(a: untyped): untyped =
  console.log(astToStr(a), " = ", a)
  a

func align(x, alignment: uint): uint {.inline.} =
  (x + alignment - 1) and not (alignment - 1)
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

func bufferBindGroupEntry(binding: int, buffer: GPUBuffer): GPUBindGroupEntry =
  GPUBindGroupEntry(
    binding: binding,
    resource: GPUResource(
      kind: BufferBinding,
      buffer: buffer
    )
  )

func bindGroupLayoutEntry(
  binding: int,
  visibility: set[GPUShaderStage],
  buffer: GPULayoutEntryBuffer
): GPUBindGroupLayoutEntry =
  GPUBindGroupLayoutEntry(
    binding: binding,
    visibility: visibility.toInt(),
    kind: Buffer,
    buffer: buffer
  )

func createBuffer(
  device: GPUDevice,
  label: cstring,
  size: int,
  usage: set[GPUBufferUsage]
): GPUBuffer =
  device.createBuffer(GPUBufferDescriptor(
    label: label,
    size: size,
    usage: usage.toInt()
  ))

proc compute(device: GPUDevice) {.async.} =
  let
    shaderModule = device.createShaderModule(
      GPUShaderModuleDescriptor(label: "compute shader", code: ComputeShader)
    )
    sharedLayout = device.createBindGroupLayout(GPUBindGroupLayoutDescriptor(
      label: "shared bindgroup layout",
      entries: @[
        bindGroupLayoutEntry(
          binding = 0,
          visibility = {Compute, GPUShaderStage.Vertex},
          buffer = GPULayoutEntryBuffer(`type`: "uniform")
        ),
        bindGroupLayoutEntry(
          binding = 1,
          visibility = {Compute, GPUShaderStage.Vertex},
          buffer = GPULayoutEntryBuffer(`type`: "read-only-storage")
        ),
      ]
    ))

    computePipeline =
      await device.createComputePipelineAsync(GPUComputePipelineDescriptor(
        label: "compute pipeline",
        layout: device.createPipelineLayout(GPUPipelineLayoutDescriptor(
          label: "compute pipeline layout",
          bindGroupLayouts: @[
            sharedLayout,
            device.createBindGroupLayout(GPUBindGroupLayoutDescriptor(
              label: "compute bindgroup layout",
              entries: @[
                bindGroupLayoutEntry(
                  binding = 0,
                  visibility = {Compute},
                  buffer = GPULayoutEntryBuffer(`type`: "uniform")
                ),
                bindGroupLayoutEntry(
                  binding = 1,
                  visibility = {Compute},
                  buffer = GPULayoutEntryBuffer(`type`: "storage")
                ),
                # TODO: Left here
                # GPUBindGroupLayoutEntry(
                #   binding: 4,
                #   visibility: {GPUShaderStage.Compute}.toInt(),
                #   kind: Buffer,
                #   buffer: GPULayoutEntryBuffer(`type`: "storage")
                # ),
              ]
            )),
          ]
        )),
        compute: GPUComputeDescriptor(
          entryPoint: "main",
          module: shaderModule
        )
      ))

  let
    nObjects = 4'u
    # shit must be padded for aligned
    nObjectsAligned = nObjects.align(DimP)
    eps2Arr = [1e-3'f32]
    nObjectsArr = [nObjects]
    objects = TypedArray[float32].new(4 * nObjectsAligned)
    accelerations = TypedArray[float32].new(2 * nObjectsAligned)

    eps2Buffer = device.createBuffer(
      label = "eps^2 buffer",
      size = eps2Arr.byteLength,
      usage = {Uniform, CopyDst}
    )
    nObjectsBuffer = device.createBuffer(
      label = "nObjects buffer",
      size = nObjectsArr.byteLength,
      usage = {Uniform, CopyDst}
    )
    objectsBuffer = device.createBuffer(
      label = "objects buffer",
      size = objects.byteLength,
      usage = {GPUBufferUsage.Storage, CopyDst}
    )
    accelerationsBuffer = device.createBuffer(
      label = "accelerations buffer",
      size = accelerations.byteLength,
      usage = {GPUBufferUsage.Storage, CopyDst, CopySrc}
    )
    accelerationsMapBuffer = device.createBuffer(
      label = "accelerations map buffer",
      size = accelerations.byteLength,
      usage = {MapRead, CopyDst}
    )

  for i in countup(0, nObjects.int, step = 4):
    # objects[i + 0] = Math.random() * 40
    # objects[i + 1] = Math.random() * 40
    # objects[i + 2] = Math.random() * 10
    objects[i + 0] = i.float32 * 4
    objects[i + 1] = i.float32 * 5 - 0.5
    objects[i + 2] = i.float32 * 10

  with device.queue:
    writeBuffer(eps2Buffer, 0, eps2Arr)
    writeBuffer(nObjectsBuffer, 0, nObjectsArr)
    writeBuffer(objectsBuffer, 0, objects)
    writeBuffer(accelerationsBuffer, 0, accelerations)

  let
    sharedBindGroup = device.createBindGroup(GPUBindGroupDescriptor(
      label: "shared bindgroup",
      layout: computePipeline.getBindGroupLayout(0),
      entries: @[
        bufferBindGroupEntry(0, nObjectsBuffer),
        bufferBindGroupEntry(1, objectsBuffer),
      ]
    ))
    computeBindGroup = device.createBindGroup(GPUBindGroupDescriptor(
      label: "compute bindgroup",
      layout: computePipeline.getBindGroupLayout(1),
      entries: @[
        bufferBindGroupEntry(0, eps2Buffer),
        bufferBindGroupEntry(1, accelerationsBuffer),
      ]
    ))

    encoder = device.createCommandEncoder()
    pass = encoder.beginComputePass()

  with pass:
    setPipeline(computePipeline)
    setBindGroup(0, sharedBindGroup)
    setBindGroup(1, computeBindGroup)
    dispatchWorkgroups(objects.len div DimP)
    `end`()

  encoder.copyBufferToBuffer(
    accelerationsBuffer,
    0,
    accelerationsMapBuffer,
    0,
    accelerations.byteLength
  )

  let commandBuffer = encoder.finish()

  device.queue.submit(@[commandBuffer])

  discard await accelerationsMapBuffer.mapAsync(Read)
  let shaderResult =
    TypedArray[float32].new(accelerationsMapBuffer.getMappedRange())

  console.log("objects", objects)
  console.log("accelerations", accelerations)
  console.log("result", shaderResult)

  accelerationsMapBuffer.unmap()

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
        layout: GPUPipelineLayout.auto(),
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

    uniformBuffer = device.createBuffer(
      label = "uniform buffer",
      size = uniform.byteLength,
      usage = {CopyDst, Uniform}
    )

    bindGroup = device.createBindGroup(GPUBindGroupDescriptor(
      label: "bindGroup for vertex shader",
      layout: pipeline.getBindGroupLayout(0),
      entries: @[
        bufferBindGroupEntry(
          binding = 0,
          buffer = uniformBuffer
        ),
        bufferBindGroupEntry(
          binding = 1,
          buffer = workBuffer
        ),
        bufferBindGroupEntry(
          binding = 2,
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

    timing.textContent = cstring(formatFloat(1000 / dt, precision = 1))

    discard window.requestAnimationFrame() do (time: float): discard frame(time)

  discard window.requestAnimationFrame() do (time: float): discard frame(time)


discard getDeviceAndExecute() do (device: GPUDevice):
  discard main(device)