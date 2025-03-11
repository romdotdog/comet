import ./[webgpu, gpu_utils, typed_arrays]

type
  GPUObjects* = ref object
    device: GPUDevice

    nBuffer*, buffer*: GPUBuffer
    bindGroupLayout*: GPUBindGroupLayout
    bindGroup*: GPUBindGroup

proc new*(
  _: typedesc[GPUObjects],
  device: GPUDevice,
  nObjects: uint;
  objects, accelerations: TypedArray[float32]
): GPUObjects =
  let bindGroupLayout =
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
    ))

  let
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

  let bindGroup = device.createBindGroup(GPUBindGroupDescriptor(
    label: "shared bindgroup",
    layout: bindGroupLayout,
    entries: @[
      bufferBindGroupEntry(0, nObjectsBuffer),
      bufferBindGroupEntry(1, objectsBuffer),
    ]
  ))

  GPUObjects(
    device: device,
    nBuffer: nObjectsBuffer,
    buffer: objectsBuffer,
    bindGroupLayout: bindGroupLayout,
    bindGroup: bindGroup
  )