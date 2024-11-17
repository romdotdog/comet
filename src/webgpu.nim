import dom, asyncjs # , sugar

import jscanvas

import ./typed_arrays

type
  GPUBufferUsage* {.importjs: "GPUBufferUsage".} = enum
    MapRead
    MapWrite
    CopySrc
    CopyDst
    Index
    Vertex
    Uniform
    Storage
    Indirect
    QueryResolve

  GPUMapMode* {.importjs: "GPUMapMode".} = enum
    Read = 1
    Write

  GPU* {.importjs: "GPU".} = ref object

  GPUCanvasContext* {.importjs: "GPUCanvasContext".} = ref object

  GPUAdapter* {.importjs: "GPUAdapter".} = ref object

  GPUDeviceLostInfo* {.importjs: "GPUDeviceLostInfo".} = ref object
    message*: cstring
    reason*: cstring

  GPUQueue* {.importjs: "GPUQueue".} = ref object

  GPUDevice* {.importjs: "GPUDevice".} = ref object
    lost*: Future[GPUDeviceLostInfo]
    queue*: GPUQueue

  GPUContextConfiguration* = ref object
    device*: GPUDevice
    format*: cstring
    alphaMode*: cstring = nil

  GPUBuffer* {.importjs: "GPUBuffer".} = ref object

  GPUBufferDescriptor* = ref object
    label*: cstring = nil
    size*: int
    usage*: int

  GPUCommandEncoder* {.importjs: "GPUCommandEncoder".} = ref object

  GPUShaderModuleDescriptor* = ref object
    label*: cstring = nil
    code*: cstring
    # hints: 
    # sourceMap: 

  GPUShaderModule* {.importjs: "GPUShaderModule".} = ref object

  GPURenderPipelineDescriptor* = ref object
    layout*: cstring
    vertex*: GPUVertex
    fragment*: GPUFragment
    primitive*: GPUPrimitive

  GPURenderPipeline* {.importjs: "GPURenderPipeline".} = ref object

  GPUVertex* = ref object
    module*: GPUShaderModule

  GPUBlendComponent* = ref object
    srcFactor*: cstring
    dstFactor*: cstring

  GPUBlend* = ref object
    color*: GPUBlendComponent
    alpha*: GPUBlendComponent

  GPUTarget* = ref object
    format*: cstring
    blend*: GPUBlend

  GPUFragment* = ref object
    module*: GPUShaderModule
    targets*: seq[GPUTarget]

  GPUPrimitive* = ref object
    topology*: cstring

  GPUComputeDescriptor* = ref object
    entryPoint*: cstring
    module*: GPUShaderModule

  GPUComputePipelineDescriptor* = ref object
    label*: cstring = nil
    layout*: cstring # XXX: shouldn't be like this
    compute*: GPUComputeDescriptor

  GPUComputePipeline* {.importjs: "GPUComputePipeline".} = ref object

  GPUBindGroupEntry* = ref object
    label*: cstring = nil
    binding*: int
    resource*: GPUResourceDescriptor

  GPUBindGroupDescriptor* = ref object
    label*: cstring = nil
    layout*: GPUBindGroupLayout
    entries*: seq[GPUBindGroupEntry]

  GPUBindGroup* {.importjs: "GPUBindGroup".} = ref object

  GPUResourceDescriptor* = ref object
    buffer*: GPUBuffer

  GPUBindGroupLayout* {.importjs: "GPUBindGroupLayout".} = ref object

  GPUComputePassEncoder* {.importjs: "GPUComputePassEncoder".} = ref object

converter toInt*(gpuBufferUsage: GPUBufferUsage): int {.inline.} =
  result = 1 shl gpuBufferUsage.ord

converter toInt*(gpuBufferUsages: set[GPUBufferUsage]): int {.inline.} =
  result = 0
  for usage in gpuBufferUsages:
    # dump (usage, usage.ord, 1 shl usage.ord, result)
    result = result or usage.toInt()

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

proc requestDevice*(
  adapter: GPUAdapter
): Future[GPUDevice] {.importjs: "#.requestDevice()".}

proc configure*(
  ctx: GPUCanvasContext,
  config: GPUContextConfiguration
) {.importjs: "#.configure(#)".}

proc createBuffer*(
  device: GPUDevice,
  descriptor: GPUBufferDescriptor
): GPUBuffer {.importjs: "#.createBuffer(#)".}

proc createShaderModule*(
  device: GPUDevice,
  descriptor: GPUShaderModuleDescriptor
): GPUShaderModule {.importjs: "#.createShaderModule(#)".}

proc createRenderPipelineAsync*(
  device: GPUDevice,
  descriptor: GPURenderPipelineDescriptor
): Future[GPURenderPipeline] {.importjs: "#.createRenderPipelineAsync(#)".}

proc createComputePipelineAsync*(
  device: GPUDevice,
  descriptor: GPUComputePipelineDescriptor
): Future[GPUComputePipeline] {.importjs: "#.createComputePipelineAsync(#)".}

proc createBindGroup*(
  device: GPUDevice,
  descriptor: GPUBindGroupDescriptor
): GPUBindGroup {.importjs: "#.createBindGroup(#)".}

# Command encoder and render pass

type
  GPURenderPassEncoder* = ref object

  GPURenderPassColorAttachment* = ref object
    view*: GPUTextureView
    clearValue*: array[0..3, float32] ## RGBA values for clearing
    loadOp*: cstring ## either "clear" or "load"
    storeOp*: cstring ## either "store" or "discard"

  GPUCommandBuffer* = ref object

  GPURenderPassDescriptor* = ref object
    colorAttachments*: seq[GPURenderPassColorAttachment] ## List of color attachments

  GPUTexture* = ref object

  GPUTextureView* = ref object

proc createCommandEncoder*(
  device: GPUDevice,
): GPUCommandEncoder {.importjs: "#.createCommandEncoder()".}

proc createCommandEncoder*(
  device: GPUDevice,
  label: cstring
): GPUCommandEncoder {.importjs: "#.createCommandEncoder({ label: # })".}

proc beginRenderPass*(
  encoder: GPUCommandEncoder,
  descriptor: GPURenderPassDescriptor
): GPURenderPassEncoder {.importjs: "#.beginRenderPass(#)".}

proc beginComputePass*(
  encoder: GPUCommandEncoder
): GPUComputePassEncoder {.importjs: "#.beginComputePass()".}

proc beginComputePass*(
  encoder: GPUCommandEncoder,
  label: cstring
): GPUComputePassEncoder {.importjs: "#.beginComputePass({ label: # })".}

proc finish*(
  encoder: GPUCommandEncoder
): GPUCommandBuffer {.importjs: "#.finish()".}

proc getBindGroupLayout*(
  pipeline: GPURenderPipeline,
  index: SomeInteger
): GPUBindGroupLayout {.importjs: "#.getBindGroupLayout(#)".}

proc getBindGroupLayout*(
  pipeline: GPUComputePipeline,
  index: SomeInteger
): GPUBindGroupLayout {.importjs: "#.getBindGroupLayout(#)".}

proc setPipeline*(
  encoder: GPURenderPassEncoder,
  pipeline: GPURenderPipeline
) {.importjs: "#.setPipeline(#)".}

proc setPipeline*(
  encoder: GPUComputePassEncoder,
  pipeline: GPUComputePipeline
) {.importjs: "#.setPipeline(#)".}

proc setBindGroup*(
  encoder: GPURenderPassEncoder,
  index: SomeInteger,
  bindGroup: GPUBindGroup
) {.importjs: "#.setBindGroup(#, #)".}

proc setBindGroup*(
  encoder: GPUComputePassEncoder,
  index: SomeInteger,
  bindGroup: GPUBindGroup
) {.importjs: "#.setBindGroup(#, #)".}

proc dispatchWorkgroups*(
  encoder: GPUComputePassEncoder,
  count: Natural
) {.importjs: "#.dispatchWorkgroups(#)".}

proc copyBufferToBuffer*(
  encoder: GPUCommandEncoder,
  source: GPUBuffer,
  sourceOffset: int,
  destination: GPUBuffer,
  destinationOffset: int,
  size: int
) {.importjs: "#.copyBufferToBuffer(#, #, #, #, #)".}

proc draw*(
  encoder: GPURenderPassEncoder,
  vertexCount: int,
) {.importjs: "#.draw(#)".}

proc draw*(
  encoder: GPURenderPassEncoder,
  vertexCount: int,
  instanceCount: int,
) {.importjs: "#.draw(#, #)".}

proc `end`*(
  encoder: GPURenderPassEncoder
) {.importjs: "#.end()".}

proc `end`*(
  encoder: GPUComputePassEncoder
) {.importjs: "#.end()".}

proc getCurrentTexture*(
  context: GPUCanvasContext
): GPUTexture {.importjs: "#.getCurrentTexture()".}

proc createView*(
  texture: GPUTexture
): GPUTextureView {.importjs: "#.createView()".}

proc submit*(
  queue: GPUQueue,
  commandBuffers: seq[GPUCommandBuffer]
) {.importjs: "#.submit(#)".}

proc writeBuffer*(
  queue: GPUQueue,
  buffer: GPUBuffer,
  bufferOffset: int,
  data: TypedArray,
) {.importjs: "#.writeBuffer(#, #, #)".}

# TODO: Bind mapAsync/3, mapAsync/4
proc mapAsync*(
  buffer: GPUBuffer,
  mode: GPUMapMode
): Future[void] {.importjs: "#.mapAsync(#)".}

# TODO: Bind getMappedRange/2, getMappedRange/3
proc getMappedRange*(
  buffer: GPUBuffer,
): ArrayBuffer {.importjs: "#.getMappedRange()".}

proc unmap*(
  buffer: GPUBuffer
) {.importjs: "#.unmap()".}
