type
  ArrayBuffer* {.importjs: "ArrayBuffer".} = ref object

type
  TypedArrayItem =
    uint8 | int8 |
    uint16 | int16 |
    uint32 | int32 |
    uint64 | int64 |
    float32 | float64
  TypedArray*[T: TypedArrayItem] {.importjs: "TypedArray".} = ref object

func new*(
  typedArray: typedesc[TypedArray],
  items: openArray[float32]
): TypedArray[float32] {.importjs: "new Float32Array(@)", constructor.}

func new*[N: static[int]](
  typedArray: typedesc[TypedArray],
  items {.byref.}: array[N, float32]
): TypedArray[float32] {.importjs: "@".}

func new*(
  typedArray: typedesc[TypedArray[float32]],
  n: SomeInteger
): TypedArray[float32] {.importjs: "new Float32Array(@)", constructor.}

func new*(
  typedArray: typedesc[TypedArray[float32]],
  items: ArrayBuffer
): TypedArray[float32] {.importjs: "new Float32Array(@)".}

func new*(
  typedArray: typedesc[TypedArray[uint32]],
  items: ArrayBuffer
): TypedArray[uint32] {.importjs: "new Uint32Array(@)".}


proc `[]=`*[T](typedArray: TypedArray[T], index: int, value: T) {.importjs: "#[#] = #".}
proc `[]`*[T](typedArray: TypedArray[T], index: int): T {.importjs: "#[#]".}

proc `[]=`*[T](
  typedArray: TypedArray[T],
  slice: Slice[int],
  values: openArray[T]
) =
  doAssert slice.len == values.len
  for (j, i) in slice.pairs():
    typedArray[i] = values[j]

proc `[]=`*[T; Idx: static[int]](
  arr: var array[Idx, T],
  slice: Slice[int],
  values: openArray[T]
) =
  doAssert slice.len == values.len
  var j = 0
  for i in slice:
    arr[i] = values[j]
    inc j

# proc `[]=`*[T; Idx, A, B: static[int]](
#   arr: var array[Idx, T],
#   slice: static[A..B],
#   values {.byref.}: array[B - A, T]
# ) =
#   doAssert slice.len == values.len
#   for (j, i) in slice.pairs():
#     arr[i] = values[j]

func byteLength*[T](typedArray: TypedArray[T]): int {.importjs: "#.byteLength".}
func len*[T](typedArray: TypedArray[T]): int {.importjs: "#.length".}

converter toTypedArray*[N: static[int]; T](arr: array[N, T]): TypedArray[T] {.importjs: "#".}