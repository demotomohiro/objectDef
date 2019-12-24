import objectDef
import macros, sets, sugar

macro isItExported(p: typed): bool =
  return isExported(if p.kind == nnkDotExpr: p[1] else: p).newLit

proc Test1() {.objectDef(false).} =
  fieldDef:
    a = 1

doAssert not isItExported(Test1)
doAssert not isItExported(initTest1)
let test1 = initTest1()
doAssert test1 == Test1(a: 1)

proc Test1Ref() {.objectDef(true).} =
  fieldDef:
    a = "xyz"

doAssert not isItExported(Test1Ref)
doAssert not isItExported(newTest1Ref)
let test1Ref = newTest1Ref()
doAssert test1Ref[] == Test1Ref(a: "xyz")[]
var test1Refv: Test1Ref
doAssert test1Refv == nil

proc Foo*() {.objectDef(false).} =
  fieldDef:
    ## Fields of object type Foo.
    x = 1 + 2
    y = "foo " & "bar"
    z = 7.0

let a = initFoo()
doAssert isItExported(Foo)
doAssert isItExported(initFoo)
doAssert a == Foo(x: 3, y: "foo bar", z: 7.0)

proc FooRef*() {.objectDef(true).} =
  let a = 1
  fieldDef:
    x = a
    y = ""
    z = initFoo()

doAssert isItExported(FooRef)
doAssert isItExported(newFooRef)
let a2 = newFooRef()
doAssert a2[] == FooRef(x: 1, y: "", z: Foo(x: 3, y: "foo bar", z: 7.0))[]

proc Bar(arg: int) {.objectDef(true).} =
  var v = 1
  let ary = ['a', 'b', 'c']
  fieldDef:
    a = v + 2
    b = initHashSet[int](arg)
    c = toHashSet(ary)
    d = 1.0
    e = [3, 4]
    f = @["abc", "def"]
  dump(result.a)
  dump(result.b)

let b = newBar(4)
doAssert not isItExported(Bar)
doAssert not isItExported(newBar)
doAssert b.a == 3
doAssert b.b is HashSet[int]
doAssert b.b.len == 0
doAssert b.c == toHashSet(['a', 'b', 'c'])
doAssert b.d == 1.0
doAssert b.e == [3, 4]
doAssert b.f == @["abc", "def"]

proc TestVar*(arg: string) {.objectDef(false).} =
  var x, y = 2
  fieldDef:
    a = 1
    var
      b* = x
      c: int
    var
      e, f = y + 1
      g, h = arg
      i, j, k: string
      l*, m: array[1, char]
      n: Foo
      o*: Bar
      p, q* = (1,)

let testVar* = initTestVar("TestVar")
doAssert isItExported(TestVar)
doAssert isItExported(initTestVar)
doAssert not isItExported(testVar.a)
doAssert isItExported(testVar.b)
doAssert not isItExported(testVar.c)
doAssert not isItExported(testVar.k)
doAssert isItExported(testVar.l)
doAssert not isItExported(testVar.m)
doAssert isItExported(testVar.o)
doAssert not isItExported(testVar.p)
doAssert isItExported(testVar.q)
doAssert testVar == TestVar(a: 1, b: 2, c: 0, e: 3, f: 3, g: "TestVar", h: "TestVar", i: "", j: "", k: "", l: ['\0'], m: ['\0'], n: Foo(), o: nil, p: (1,), q: (1,))
