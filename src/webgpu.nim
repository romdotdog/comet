import dom, asyncjs

import jscanvas

import ./typed_arrays

type
  GPUBufferUsage* = enum
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

  GPUMapMode* = enum
    Read = 1
    Write

  GPU* = ref object

  GPUCanvasContext* = ref object

  GPUAdapter* = ref object

  GPUQueue* = ref object

  GPUDevice* = ref object
    queue*: GPUQueue

  GPUContextConfiguration* = ref object
    device*: GPUDevice
    format*: cstring

  GPUBuffer* = ref object

  GPUBufferDescriptor* = ref object
    label*: cstring = nil
    size*: int
    usage*: int

  GPUCommandEncoder* = ref object

  ShaderModuleDescriptor* = ref object
    label*: cstring = nil
    code*: cstring
    # hints: 
    # sourceMap: 

  GPUShaderModule* = ref object

  GPURenderPipelineDescriptor* = ref object
    layout*: cstring
    vertex*: GPUVertex
    fragment*: GPUFragment
    primitive*: GPUPrimitive

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

  GPUComputePipelineDescriptor* = ref object
    label*: cstring = nil
    layout*: cstring # XXX: shouldn't be like this
    compute*: tuple[
      entryPoint: cstring,
      module: GPUShaderModule,
    ]

  GPUComputePipeline* = ref object

  GPUBindGroupDescriptor* = ref object
    label*: cstring = nil
    layout*: GPUBindGroupLayout
    entries*: seq[tuple[binding: int, resource: GPUResourceDescriptor]]

  GPUBindGroup* = ref object

  GPUResourceDescriptor* = ref object
    buffer*: GPUBuffer

  GPUBindGroupLayout* = ref object

  GPUComputePassEncoder* = ref object

converter toInt*(gpuBufferUsage: GPUBufferUsage): int {.inline.} =
  1 shl int(gpuBufferUsage)

converter toInt*(gpuBufferUsages: set[GPUBufferUsage]): int {.inline.} =
  cast[int](gpuBufferUsages)

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
  descriptor: ShaderModuleDescriptor
): GPUShaderModule {.importjs: "#.createShaderModule(#)".}

proc createRenderPipeline*(
  device: GPUDevice,
  descriptor: GPURenderPipelineDescriptor
): GPURenderPipeline {.importjs: "#.createRenderPipeline(#)".}

proc createComputePipeline*(
  device: GPUDevice,
  descriptor: GPUComputePipelineDescriptor
): GPUComputePipeline {.importjs: "#.createComputePipeline(#)".}

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
  pipeline: GPUComputePipeline,
  index: SomeInteger
): GPUBindGroupLayout {.importjs: "#.getBindGroupLayout(#, #)".}

proc setPipeline*(
  encoder: GPURenderPassEncoder,
  pipeline: GPURenderPipeline
) {.importjs: "#.setPipeline(#)".}

proc setPipeline*(
  encoder: GPUComputePassEncoder,
  pipeline: GPUComputePipeline
) {.importjs: "#.setPipeline(#)".}

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
  vertexCount: int
) {.importjs: "#.draw(#)".}

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
