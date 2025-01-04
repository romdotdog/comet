type
  Vec3Impl[T] = ref array[3, T]
  Vec3*[T] = distinct Vec3Impl[T]
  Vec3f* = Vec3[float]
  Vec3sf* = Vec3[float32]
  Vec3df* = Vec3[float64]

  Vec2Impl[T] = ref array[2, T]
  Vec2*[T] = distinct Vec2Impl[T]
  Vec2f* = Vec2[float]
  Vec2sf* = Vec2[float32]
  Vec2df* = Vec2[float64]

func impl[T](a: Vec3[T]): auto = Vec3Impl[T](a)
func impl[T](a: Vec2[T]): auto = Vec2Impl[T](a)

func x*[T](v: Vec3[T] | Vec2[T]): var T = v.impl[0]
func y*[T](v: Vec3[T] | Vec2[T]): var T = v.impl[1]
func z*[T](v: Vec3[T]): var T = v.impl[2]

func `x=`*[T](v: Vec3[T] | Vec2[T], c: T) = v.impl[0] = c
func `y=`*[T](v: Vec3[T] | Vec2[T], c: T) = v.impl[1] = c
func `z=`*[T](v: Vec3[T], c: T) = v.impl[2] = c

func `@=`*[T](a, b: Vec2[T]) =
  a.x = b.x
  a.y = b.y

func `@=`*[T](a, b: Vec3[T]) =
  a.x = b.x
  a.y = b.y
  a.z = b.z

func `$`*[T](a: Vec2[T]): string = "vec(x: " & $a.x & ", y: " & $a.y & ")"
func `$`*[T](a: Vec3[T]): string =
  "vec(x: " & $a.x & ", y: " & $a.y & ", z: " & $a.z & ")"

func vec2*[T](x, y: T): Vec2[T] =
  var v: ref array[2, T]
  new v
  v[0] = x
  v[1] = y
  Vec2[T](v)
func vec2*[T](a: Vec2[T]): Vec2[T] = vec2(a.x, a.y)
func default*[T](_: typedesc[Vec2[T]]): Vec2[T] = vec2(T.default, T.default)

func `==`*[T](a, b: Vec2[T]): bool = a.x == b.x and a.y == b.y
func `==`*[T](a, b: Vec3[T]): bool = a.x == b.x and a.y == b.y and a.z == b.z

func `+=`*[T](a, b: Vec2[T]) =
  a.x += b.x
  a.y += b.y
func `+`*[T](a, b: Vec2[T]): Vec2[T] =
  result = vec2(a)
  result += b

func `-=`*[T](a, b: Vec2[T]) =
  a.x -= b.x
  a.y -= b.y
func `-`*[T](a, b: Vec2[T]): Vec2[T] =
  result = vec2(a)
  result -= b

func `*=`*[T](a, b: Vec2[T]) =
  a.x = a.x * b.x
  a.y = a.y * b.y

func `/=`*[T](a, b: Vec2[T]) =
  a.x /= b.x
  a.y /= b.y
func `/`*[T](a, b: Vec2[T]): Vec2[T] =
  result = vec2(a)
  result /= b

func `*=.`*[T](a: Vec2[T], s: T) =
  a.x *= s
  a.y *= s
func `*.`*[T](a: Vec2[T], s: T): Vec2[T] =
  result = vec2(a)
  result *=. s

func `/=.`*[T](a: Vec2[T], s: T) =
  a.x /= s
  a.y /= s
func `/.`*[T](a: Vec2[T], s: T): Vec2[T] =
  result = vec2(a)
  result /=. s

func to*[T1, T2](a: Vec2[T1], _: typedesc[T2]): Vec2[T2] =
  vec2(T2(a.x), T2(a.y))


func vec2*[T](x, y, z: T): Vec2[T] =
  var v: ref array[3, T]
  new v
  v[0] = x
  v[1] = y
  v[2] = z
  Vec3[T](v)
func vec3*[T](a: Vec3[T]): Vec3[T] = vec3(a.x, a.y, a.z)
func default*[T](_: typedesc[Vec3[T]]): Vec3[T] =
  vec3(T.default, T.default, T.default)

func `+=`*[T](a, b: Vec3[T]) =
  a.x += b.x
  a.y += b.y
  a.z += b.z
func `+`*[T](a, b: Vec3[T]): Vec3[T] =
  result = vec3(a)
  result += b

func `-=`*[T](a, b: Vec3[T]) =
  a.x -= b.x
  a.y -= b.y
  a.z -= b.z
func `-`*[T](a, b: Vec3[T]): Vec3[T] =
  result = vec3(a)
  result -= b

func `*=.`*[T](a: Vec3[T], s: T) =
  a.x *= s
  a.y *= s
  a.z *= s
func `*.`*[T](a: Vec3[T], s: T): Vec3[T] =
  result = vec3(a)
  result *=. s

func `/=.`*[T](a: Vec3[T], s: T) =
  a.x /= s
  a.y /= s
  a.z /= s
func `/.`*[T](a: Vec3[T], s: T): Vec3[T] =
  result = vec3(a)
  result /=. s

func `*=`*[T](a, b: Vec3[T]) =
  a.x = a.x * b.x
  a.y = a.y * b.y