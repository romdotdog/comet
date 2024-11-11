when not defined(js):
  {.fatal: "comet must be compiled with the JavaScript backend.".}

import jsconsole
import jsffi
import macros
import dom
import asyncjs
import webgpu

const triangleVertWGSL = staticRead("triangle.vert.wgsl")
const redFragWGSL = staticRead("red.frag.wgsl")

let canvas = getCanvas()
let ctx = canvas.getContextWebGPU()

let devicePixelRatio = window.devicePixelRatio;
canvas.width = canvas.clientWidth.float * devicePixelRatio;
canvas.height = canvas.clientHeight.float * devicePixelRatio;

proc main() {.async.} =
  let adapter = await webgpu.navigator.gpu.requestAdapter() 
  let presentationFormat = await webgpu.navigator.gpu.getPreferredCanvasFormat()
  let device = await adapter.getDevice()

  ctx.configure(GPUContextConfiguration(
    device: device,
    format: presentationFormat
  ))

discard main()


discard """

context.configure({
  device,
  format: presentationFormat,
});

const pipeline = device.createRenderPipeline({
  layout: 'auto',
  vertex: {
    module: device.createShaderModule({
      code: triangleVertWGSL,
    }),
  },
  fragment: {
    module: device.createShaderModule({
      code: redFragWGSL,
    }),
    targets: [
      {
        format: presentationFormat,
      },
    ],
  },
  primitive: {
    topology: 'triangle-list',
  },
});

function frame() {
  const commandEncoder = device.createCommandEncoder();
  const textureView = context.getCurrentTexture().createView();

  const renderPassDescriptor: GPURenderPassDescriptor = {
    colorAttachments: [
      {
        view: textureView,
        clearValue: [0, 0, 0, 0], // Clear to transparent
        loadOp: 'clear',
        storeOp: 'store',
      },
    ],
  };

  const passEncoder = commandEncoder.beginRenderPass(renderPassDescriptor);
  passEncoder.setPipeline(pipeline);
  passEncoder.draw(3);
  passEncoder.end();

  device.queue.submit([commandEncoder.finish()]);
  requestAnimationFrame(frame);
}

requestAnimationFrame(frame);
"""