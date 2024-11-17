# Initializes the WebGPU device

import dom, asyncjs, jsconsole, sugar

import ./webgpu

proc getDeviceAndExecute*(main: GPUDevice -> void) {.async.} =
  if navigator.gpu == nil:
    console.error("Your browser doesn't support WebGPU")
    return

  let adapter = await navigator.gpu.requestAdapter()

  if adapter == nil:
    console.error("Your browser supports WebGPU but it might be disabled")
    return

  let device = await adapter.requestDevice()

  proc ifLost(info: GPUDeviceLostInfo) =
    console.error("Device lost: ", info.message)

    if info.reason != "destroyed":
      discard getDeviceAndExecute(main)

  discard device.lost.then(ifLost)

  main(device)