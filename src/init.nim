# Initializes the WebGPU device

import dom, asyncjs, jsconsole
import ./webgpu

proc getDeviceAndExecute*[A](main: proc(device: GPUDevice): A {.nimcall.}) {.async.} =
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

    discard main(device)
