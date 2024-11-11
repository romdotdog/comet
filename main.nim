import jsconsole
import jsffi
import macros
import dom
import std/asyncjs

when not defined(js):
  {.fatal: "comet must be compiled with the JavaScript backend.".}


const triangleVertWGSL = staticRead("triangle.vert.wgsl")
const redFragWGSL = staticRead("red.frag.wgsl")

type
  Canvas = ref object of dom.Element
    width: float
    height: float

  CanvasContextWebGPU = ref object

  Adapter = ref object
  Device = ref object

proc getCanvas(): Canvas =
  {.emit: "`result` = document.getElementById('canvas');".}


proc getContextWebGPU(c: Canvas): CanvasContextWebGPU =
  {.emit: "`result` = `c`.getContext('webgpu');".}
    
proc getAdapter(): Future[Adapter] = 
  {.emit: "`result` = navigator.gpu?.requestAdapter();".}

proc getDevice(adapter: Adapter): Future[Adapter] = 
  {.emit: "`result` = `adapter`.requestDevice();".}

let canvas = getCanvas()
let ctx = canvas.getContextWebGPU()

let devicePixelRatio = window.devicePixelRatio;
canvas.width = canvas.clientWidth.float * devicePixelRatio;
canvas.height = canvas.clientHeight.float * devicePixelRatio;

let adapter = await getAdapter()
