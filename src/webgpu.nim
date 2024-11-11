import dom, asyncjs

import jscanvas

const
  GPUBufferUsageMapRead = 1 shl 0
  GPUBufferUsageMapWrite = 1 shl 1
  GPUBufferUsageCopySrc = 1 shl 2
  GPUBufferUsageCopyDst = 1 shl 3
  GPUBufferUsageIndex = 1 shl 4
  GPUBufferUsageVertex = 1 shl 5
  GPUBufferUsageUniform = 1 shl 6
  GPUBufferUsageStorage = 1 shl 7
  GPUBufferUsageIndirect = 1 shl 8
  GPUBufferUsageQueryResolve = 1 shl 9

type
  GPU* = ref object

  GPUCanvasContext* = ref object

  GPUAdapter* = ref object

  GPUQueue* = ref object
  GPUDevice* = ref object
    queue*: GPUQueue

  GPUContextConfiguration* = ref object
    device*: GPUDevice
    format*: cstring

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


# Buffers

type
  GPUBuffer* = ref object

  GPUBufferDescriptor* = ref object
    size*: int
    usage*: int

  GPUCommandEncoder* = ref object

proc createBuffer*(device: GPUDevice, descriptor: GPUBufferDescriptor): GPUBuffer {.importjs: "#.createBuffer(#)".}

# Shader modules

type GPUShaderModule* = ref object

proc createShaderModule*(device: GPUDevice, code: cstring): GPUShaderModule {.importjs: "#.createShaderModule({ code: # })".}


# Create render pipeline

type
  GPURenderPipeline* = ref object
  GPUVertex* = ref object
    module*: GPUShaderModule
  GPUTarget* = ref object
    format*: cstring
  GPUFragment* = ref object
    module*: GPUShaderModule
    targets*: seq[GPUTarget]
  GPUPrimitive* = ref object
    topology*: cstring
  GPURenderPipelineDescriptor* = ref object
    layout*: cstring
    vertex*: GPUVertex  
    fragment*: GPUFragment
    primitive*: GPUPrimitive

proc createRenderPipeline*(device: GPUDevice, descriptor: GPURenderPipelineDescriptor): GPURenderPipeline {.importjs: "#.createRenderPipeline(#)".}


# Command encoder and render pass

type
  GPURenderPassEncoder* = ref object
  GPURenderPassColorAttachment* = ref object
    view*: GPUTextureView
    clearValue*: seq[float32] # RGBA values for clearing
    loadOp*: cstring # either "clear" or "load"
    storeOp*: cstring # either "store" or "discard"
  GPUCommandBuffer* = ref object
  GPURenderPassDescriptor* = ref object
    colorAttachments*: seq[GPURenderPassColorAttachment] # List of color attachments
  GPUTexture* = ref object
  GPUTextureView* = ref object


proc createCommandEncoder*(device: GPUDevice): GPUCommandEncoder {.importjs: "#.createCommandEncoder()".}
proc beginRenderPass*(encoder: GPUCommandEncoder, descriptor: GPURenderPassDescriptor): GPURenderPassEncoder {.importjs: "#.beginRenderPass(#)".}
proc finish*(encoder: GPUCommandEncoder): GPUCommandBuffer {.importjs: "#.finish()".}

proc setPipeline*(encoder: GPURenderPassEncoder, pipeline: GPURenderPipeline) {.importjs: "#.setPipeline(#)".}
proc draw*(encoder: GPURenderPassEncoder, vertexCount: int) {.importjs: "#.draw(#)".}
proc `end`*(encoder: GPURenderPassEncoder) {.importjs: "#.end()".}

proc getCurrentTexture*(context: GPUCanvasContext): GPUTexture {.importjs: "#.getCurrentTexture()".}

proc createView*(texture: GPUTexture): GPUTextureView {.importjs: "#.createView()".}

# Submit queue

proc submit*(queue: GPUQueue, commandBuffers: seq[GPUCommandBuffer]) {.importjs: "#.submit(#)".}

