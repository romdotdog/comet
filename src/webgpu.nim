import dom, asyncjs

import jscanvas

type
  GPU* = ref object

  GPUCanvasContext* = ref object

  GPUAdapter* = ref object
  GPUDevice* = ref object
  GPUContextConfiguration* = ref object
    device*: GPUDevice
    format*: cstring

  GPURenderPipelineDescriptor* = ref object

func gpu*(navigator: Navigator): GPU {.importjs: "#.gpu".}

proc getContextWebGPU*(
  c: CanvasElement
): GPUCanvasContext {.importjs: "#.getContext('webgpu')".}

proc requestAdapter*(
  gpu: GPU
): Future[GPUAdapter] {.importjs: "#.requestAdapter()".}

proc getPreferredCanvasFormat*(
  gpu: GPU
): Future[cstring] {.importjs: "#.getPreferredCanvasFormat()".}

proc getDevice*(
  adapter: GPUAdapter
): Future[GPUDevice] {.importjs: "#.requestDevice()".}

proc configure*(
  ctx: GPUCanvasContext,
  config: GPUContextConfiguration
) {.importjs: "#.configure(#)".}

proc createRenderPipeline*(
  device: GPUDevice,
  config: GPURenderPipelineDescriptor
) {.importjs: "#.createRenderPipeline(#)".}
