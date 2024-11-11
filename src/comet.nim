when not defined(js):
  {.fatal: "comet must be compiled with the JavaScript backend.".}

# import jsconsole, jsffi, macros
import dom, asyncjs
import jscanvas

import ./webgpu

const
  TriangleVertWGSL = staticRead("triangle.vert.wgsl")
  RedFragWGSL = staticRead("red.frag.wgsl")

proc main() {.async.} =
  let
    canvas = document.getElementById("canvas").CanvasElement
    ctx = canvas.getContextWebGPU()
    devicePixelRatio = window.devicePixelRatio;

  canvas.width = int(canvas.clientWidth.float * devicePixelRatio)
  canvas.height = int(canvas.clientHeight.float * devicePixelRatio)

  let
    adapter = await navigator.gpu.requestAdapter()
    presentationFormat = await navigator.gpu.getPreferredCanvasFormat()
    device = await adapter.getDevice()

  ctx.configure(GPUContextConfiguration(
    device: device,
    format: presentationFormat
  ))

  let pipeline = device.createRenderPipeline(GPURenderPipelineDescriptor(
    layout: "auto",
    vertex: GPUVertex(
      module: device.createShaderModule(TriangleVertWGSL)
    ),
    fragment: GPUFragment(
      module: device.createShaderModule(RedFragWGSL),
      targets: @[
        GPUTarget(format: presentationFormat)
      ]
    ),
    primitive: GPUPrimitive(
      topology: "triangle-list"
    )
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

  proc frame(time: float) =
    let texture = ctx.getCurrentTexture()
    let textureView = texture.createView()

    renderPassDescriptor.colorAttachments[0].view = textureView

    let commandEncoder = device.createCommandEncoder()

    let passEncoder = commandEncoder.beginRenderPass(renderPassDescriptor)
    passEncoder.setPipeline(pipeline)
    passEncoder.draw(3)
    passEncoder.end()

    device.queue.submit(@[commandEncoder.finish()])
    discard window.requestAnimationFrame(frame)

  discard window.requestAnimationFrame(frame)

discard main()
