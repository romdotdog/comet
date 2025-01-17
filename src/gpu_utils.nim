import ./webgpu

func bufferBindGroupEntry*(binding: int, buffer: GPUBuffer): GPUBindGroupEntry =
  GPUBindGroupEntry(
    binding: binding,
    resource: GPUResource(
      kind: BufferBinding,
      buffer: buffer
    )
  )

func bindGroupLayoutEntry*(
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

func createBuffer*(
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