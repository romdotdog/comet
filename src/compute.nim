import
  strutils, macros, std/with,
  asyncjs, jscore, jsconsole

import ./[webgpu, gpu_utils, typed_arrays]

const
  DimP* = 9
  DimQ* = 1
  DimIntegrator = 64
  KernelShader = staticRead("kernel.wgsl") % [$DimP, $DimQ]
  IntegratorShader = staticRead("integrator.wgsl")

template dbg*(a: untyped): untyped =
  {.noSideEffect.}:
    console.log(astToStr(a), " = ", a)
  a

type
  GPUCompute* = ref object
    device: GPUDevice
    kernelPipeline, integratorPipeline: GPUComputePipeline
    kernelWorkgroups, integratorWorkgroups: uint

    layout: GPUPipelineLayout

    nObjects, nObjectsAligned: uint

    nObjectsBuffer: GPUBuffer
    objectsBuffer, objectsMapBuffer: GPUBuffer

    sharedBindGroup, bindGroup: GPUBindGroup

func nObjectsBuffer*(compute: GPUCompute): GPUBuffer = compute.nObjectsBuffer
func objectsBuffer*(compute: GPUCompute): GPUBuffer = compute.objectsBuffer
func sharedBindGroup*(compute: GPUCompute): GPUBindGroup =
  compute.sharedBindGroup

proc initCompute*(
  device: GPUDevice,
  nObjects, nObjectsAligned: uint;
  objects: TypedArray[float32]
): Future[GPUCompute] {.async.} =
  # internal buffer
  let ppnl = TypedArray[float32].new(4 * nObjects)

  # set prev position to current
  for i in 0..<nObjects.int:
    ppnl[i * 4 + 0] = objects[i * 4 + 0]
    ppnl[i * 4 + 1] = objects[i * 4 + 1]

  # modules
  let kernelModule = device.createShaderModule(GPUShaderModuleDescriptor(
    label: "kernel module",
    code: KernelShader
  ))

  let integratorModule = device.createShaderModule(GPUShaderModuleDescriptor(
    label: "integrator module",
    code: IntegratorShader
  ))

  # layout and pipeline

  let 
    bindGroupLayout = device.createBindGroupLayout(GPUBindGroupLayoutDescriptor(
      label: "compute shared bindgroup layout",
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
        bindGroupLayoutEntry(
          binding = 2,
          visibility = {Compute},
          buffer = GPULayoutEntryBuffer(`type`: "storage")
        ),
      ]
    ))

    pipelineLayout = device.createPipelineLayout(GPUPipelineLayoutDescriptor(
      label: "compute pipeline layout",
      bindGroupLayouts: @[
        bindGroupLayout
      ]
    ))

    kernelPipeline =
      await device.createComputePipelineAsync(GPUComputePipelineDescriptor(
        label: "kernel pipeline",
        layout: pipelineLayout,
        compute: GPUComputeDescriptor(
          entryPoint: "main",
          module: kernelModule
        )
      ))

    integratorPipeline =
      await device.createComputePipelineAsync(GPUComputePipelineDescriptor(
        label: "integrator pipeline",
        layout: pipelineLayout,
        compute: GPUComputeDescriptor(
          entryPoint: "main",
          module: integratorModule
        )
      ))

  # buffers
  let
    nObjectsBuffer = device.createBuffer(
      label = "nObjects buffer",
      size = sizeof(uint32),
      usage = {Uniform, CopyDst}
    )
    objectsBuffer = device.createBuffer(
      label = "objects buffer",
      size = objects.byteLength,
      usage = {GPUBufferUsage.Storage, CopySrc, CopyDst}
    )
    objectsMapBuffer = device.createBuffer(
      label = "objects map buffer",
      size = objects.byteLength,
      usage = {MapRead, CopyDst}
    )
    ppnlBuffer = device.createBuffer(
      label = "<prev_pos, new_accel> buffer",
      size = objects.byteLength,
      usage = {GPUBufferUsage.Storage, CopyDst}
    )

  with device.queue:
    writeBuffer(nObjectsBuffer, 0, [nObjects])
    writeBuffer(objectsBuffer, 0, objects)
    writeBuffer(ppnlBuffer, 0, ppnl)

  let
    bindGroup = device.createBindGroup(GPUBindGroupDescriptor(
      label: "compute shared bindgroup",
      layout: bindGroupLayout,
      entries: @[
        bufferBindGroupEntry(0, nObjectsBuffer),
        bufferBindGroupEntry(1, objectsBuffer),
        bufferBindGroupEntry(2, ppnlBuffer)
      ]
    ))

  result = GPUCompute(
    device: device,
    kernelPipeline: kernelPipeline,
    integratorPipeline: integratorPipeline,
    nObjects: nObjects.dbg,
    nObjectsAligned: nObjectsAligned,
    kernelWorkgroups: (nObjects + DimP - 1) div DimP,
    integratorWorkgroups: (nObjects + DimIntegrator - 1) div DimIntegrator,
    nObjectsBuffer: nObjectsBuffer,
    objectsBuffer: objectsBuffer,
    objectsMapBuffer: objectsMapBuffer,
    bindGroup: bindGroup
  )

func step*(compute: GPUCompute) =
  let
    encoder = compute.device.createCommandEncoder()
    pass = encoder.beginComputePass()

  with pass:
    setBindGroup(0, compute.bindGroup)

    setPipeline(compute.kernelPipeline)
    dispatchWorkgroups(compute.kernelWorkgroups)

    setPipeline(compute.integratorPipeline)
    dispatchWorkgroups(compute.integratorWorkgroups)

    `end`()

  let commandBuffer = encoder.finish()
  compute.device.queue.submit(@[commandBuffer])

proc positions*(
  compute: GPUCompute
): Future[GPUBuffer] {.async.} =
  let encoder = compute.device.createCommandEncoder()
  encoder.copyBufferToBuffer(
    compute.objectsBuffer,
    0,
    compute.objectsMapBuffer,
    0,
    compute.nObjectsAligned.int * sizeof(float32) * 4
  )
  let commandBuffer = encoder.finish()
  compute.device.queue.submit(@[commandBuffer])
  discard await compute.objectsMapBuffer.mapAsync(Read)
  result = compute.objectsMapBuffer