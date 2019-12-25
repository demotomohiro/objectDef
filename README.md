# objectDef
Nim macro that create a object type definition from a constructor proc.

## Examples
`objectDef` macro transform following code
```nim
import objectDef

proc Foo() {.objectDef(false).} =
  fieldDef:
    x = 1
    y = 2
```
to
```nim
type
  Foo = object
    x: int
    y: int

proc initFoo(): Foo =
  result = Foo(x: 1, y: 2)
```
Transform follwoing code
```nim
proc Bar(x, y: int) {.objectDef(true).} =
  let t = getTime()
  fieldDef:
    a = {1: "one", 2: "two"}.toTable
    var
      b, c = x * y
      d, e = [x, y - x]
      f, g, h: string
    local = t.local
    t2 = t - initDuration(seconds = x)

  echo result.b
  echo result.t2
```
to
```nim
type
  Bar = ref object
    a: Table[int, string]
    b: int
    c: int
    d: array[0 .. 1, int]
    e: array[0 .. 1, int]
    f: string
    g: string
    h: string
    local: DateTime
    t2: Time

proc newBar(x, y: int): Bar =
  let t = getTime()
  result = Bar(a: toTable([(1, "one"), (2, "two")]), b: x * y, c: x * y, d: [x, y - x],
             e: [x, y - x], f: default(string), g: default(string), h: default(string),
             local: local(t), t2: t - initDuration(0, 0, 0, x, 0, 0, 0, 0))
  echo [result.b]
  echo [result.t2]
```

## How to use
This macro works by adding `objectDef` pragma to your constructor proc.
It read assignments and var statements under `fieldDef` and
create an object type that has corresponding fields.
New object type have same name to the input proc.

When `isRef == false`, object type is defined and
`init` prefix is added to the input proc name.
When `isRef == true`, ref object type is defined and
`new` prefix is added to the input proc name.
When the input proc is exported, new object type is also exported.

## Limitations:
- Only assignments, var statements and comments are allowed under `fieldDef`.
- Generic proc is not supported.
- You can use `fieldDef` only once in a input proc.
- `fieldDef` must be placed under input proc and cannot be placed under other statments.

