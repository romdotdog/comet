type
  ArrayBuffer* {.importjs: "ArrayBuffer".} = ref object

type
  TypedArrayItem = uint8 | int8 | uint16 | int16 | uint32 | int32 | uint64 | int64 | float32 | float64
  TypedArray*[T: TypedArrayItem] {.importjs: "TypedArray".} = ref object

func new*(
  typedArray: typedesc[TypedArray],
  items: openArray[float32]
): TypedArray[float32] {.importjs: "new Float32Array(@)", constructor.}

func new*(
  typedArray: typedesc[TypedArray[float32]],
  n: SomeInteger
): TypedArray[float32] {.importjs: "new Float32Array(@)", constructor.}

func new*(
  typedArray: typedesc[TypedArray[float32]],
  items: ArrayBuffer
): TypedArray[float32] {.importjs: "new Float32Array(@)".}

proc `[]=`*[T](typedArray: TypedArray[T], index: int, value: T) {.importjs: "#[#] = #".}

func byteLength*[T](typedArray: TypedArray[T]): int {.importjs: "#.byteLength".}
func len*[T](typedArray: TypedArray[T]): int {.importjs: "#.length".}

converter toTypedArray*[N: static[int]; T](arr: array[N, T]): TypedArray[T] {.importjs: "#".}
