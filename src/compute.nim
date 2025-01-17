import
  strutils, macros, std/with,
  asyncjs, jscore, jsconsole

import ./[webgpu, gpu_utils, typed_arrays]

const
  DimP* = 9
  DimQ* = 1
  ComputeShader = staticRead("compute.wgsl") % [$DimP, $DimQ]

template dbg*(a: untyped): untyped =
  console.log(astToStr(a), " = ", a)
  a

type
  GPUCompute* = ref object
    device: GPUDevice
    module: GPUShaderModule
    layout: GPUPipelineLayout
    pipeline: GPUComputePipeline

    nObjects, nBufferObjects: uint

    accelerationsMapBuffer: GPUBuffer
    accelerationsBuffer: GPUBuffer

    nObjectsBuffer, objectsBuffer: GPUBuffer
    sharedBindGroup, bindGroup: GPUBindGroup

func nObjectsBuffer*(compute: GPUCompute): GPUBuffer = compute.nObjectsBuffer
func objectsBuffer*(compute: GPUCompute): GPUBuffer = compute.objectsBuffer
func sharedBindGroup*(compute: GPUCompute): GPUBindGroup =
  compute.sharedBindGroup

proc initCompute*(
  device: GPUDevice,
  nObjects: uint;
  objects, accelerations: TypedArray[float32];
  eps2: float32 = 1e-3'f32
): Future[GPUCompute] {.async.} =
  # modules
  let shaderModule = device.createShaderModule(GPUShaderModuleDescriptor(
    label: "compute shader",
    code: ComputeShader
  ))

  # layout and pipeline
  let
    layout = device.createPipelineLayout(GPUPipelineLayoutDescriptor(
        label: "compute pipeline layout",
        bindGroupLayouts: @[
          device.createBindGroupLayout(GPUBindGroupLayoutDescriptor(
            label: "shared bindgroup layout",
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
            ]
          )),
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
      ))

    pipeline =
      await device.createComputePipelineAsync(GPUComputePipelineDescriptor(
        label: "compute pipeline",
        layout: layout,
        compute: GPUComputeDescriptor(
          entryPoint: "main",
          module: shaderModule
        )
      ))

  # buffers
  let
    eps2Buffer = device.createBuffer(
      label = "eps^2 buffer",
      size = sizeof(float32),
      usage = {Uniform, CopyDst}
    )
    nObjectsBuffer = device.createBuffer(
      label = "nObjects buffer",
      size = sizeof(uint32),
      usage = {Uniform, CopyDst}
    )
    # nObjectsMapBuffer = device.createBuffer(
    #   label = "nObjects map buffer",
    #   size = sizeof(uint32),
    #   usage = {Uniform, CopyDst, MapRead}
    # )
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

  with device.queue:
    writeBuffer(eps2Buffer, 0, [eps2])
    writeBuffer(nObjectsBuffer, 0, [nObjects])
    writeBuffer(objectsBuffer, 0, objects)
    writeBuffer(accelerationsBuffer, 0, accelerations)

  let
    sharedBindGroup = device.createBindGroup(GPUBindGroupDescriptor(
      label: "shared bindgroup",
      layout: pipeline.getBindGroupLayout(0),
      entries: @[
        bufferBindGroupEntry(0, nObjectsBuffer),
        bufferBindGroupEntry(1, objectsBuffer),
      ]
    ))
    computeBindGroup = device.createBindGroup(GPUBindGroupDescriptor(
      label: "compute bindgroup",
      layout: pipeline.getBindGroupLayout(1),
      entries: @[
        bufferBindGroupEntry(0, eps2Buffer),
        bufferBindGroupEntry(1, accelerationsBuffer),
      ]
    ))

  result = GPUCompute(
    device: device,
    module: shaderModule,
    layout: layout,
    pipeline: pipeline,
    nObjects: nObjects.dbg,
    nBufferObjects: objects.len.uint div 4,
    accelerationsMapBuffer: accelerationsMapBuffer,
    accelerationsBuffer: accelerationsBuffer,
    nObjectsBuffer: nObjectsBuffer,
    objectsBuffer: objectsBuffer,
    sharedBindGroup: sharedBindGroup,
    bindGroup: computeBindGroup
  )

func run*(compute: GPUCompute) =
  let
    encoder = compute.device.createCommandEncoder()
    pass = encoder.beginComputePass()

  {.noSideEffect.}:
    with pass:
      setPipeline(compute.pipeline)
      setBindGroup(0, compute.sharedBindGroup)
      setBindGroup(1, compute.bindGroup)
      dispatchWorkgroups(compute.nBufferObjects.dbg div DimP)
      `end`()

  let commandBuffer = encoder.finish()
  compute.device.queue.submit(@[commandBuffer])

proc accelerations*(
  compute: GPUCompute
): Future[GPUBuffer] {.async.} =
  let encoder = compute.device.createCommandEncoder()
  encoder.copyBufferToBuffer(
    compute.accelerationsBuffer,
    0,
    compute.accelerationsMapBuffer,
    0,
    compute.nBufferObjects.int * sizeof(float32) * 2
  )
  let commandBuffer = encoder.finish()
  compute.device.queue.submit(@[commandBuffer])
  discard await compute.accelerationsMapBuffer.mapAsync(Read)
  result = compute.accelerationsMapBuffer