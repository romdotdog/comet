type
  TypedArrayItem = uint8 | int8 | uint16 | int16 | uint32 | int32 | uint64 | int64 | float32 | float64
  TypedArray*[T: TypedArrayItem] {.importjs: "TypedArray".} = ref object

  ArrayBuffer* {.importjs: "ArrayBuffer".} = ref object

func new*(
  typedArray: typedesc[TypedArray],
  items: openArray[float32]
): TypedArray[float32] {.importjs: "new Float32Array(#)".}

func new*(
  typedArray: typedesc[TypedArray[float32]],
  items: ArrayBuffer
): TypedArray[float32] {.importjs: "new Float32Array(#)".}

func byteLength*[T](typedArray: TypedArray[T]): int {.importjs: "#.byteLength".}
func len*[T](typedArray: TypedArray[T]): int {.importjs: "#.len".}

