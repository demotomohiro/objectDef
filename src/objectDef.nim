import macros

macro tupleCtorToObjectDef(name: static[string];
                           isExported: static[bool];
                           isRef: static[bool];
                           procDef: typed{nkProcDef}): untyped =
  func getObjType(name: string; isExported: bool; isRef: bool; node: NimNode): NimNode =
    if node.kind == nnkAsgn and node[0].strVal == "result":
      node[1].expectKind nnkTupleConstr
      var recList = newNimNode(nnkRecList)
      for n in node[1]:
        n.expectKind nnkExprColonExpr
        n[1].expectKind nnkTupleConstr
        let
          fieldIdent = n[0].strVal.ident
          fieldType = n[1][0].getTypeInst
        if n[1].len == 1:
          recList.add newIdentDefs(fieldIdent, fieldType)
        else:
          recList.add newIdentDefs(postfix(fieldIdent, "*"), fieldType)
      let objNameIdent = if isExported:
          postfix(name.ident, "*")
        else:
          name.ident
      if isRef:
        let typDef = quote do:
          type `objNameIdent` = ref object
        typDef[0][2][0][2] = recList
        return typDef
      else:
        let typDef = quote do:
          type `objNameIdent` = object
        typDef[0][2][2] = recList
        return typDef
    else:
      return nil

  var objType = getObjType(name, isExported, isRef, procDef.body)
  if objType == nil:
    for n in procDef.body:
      objType = getObjType(name, isExported, isRef, n)
      if objType != nil:
        break
  objType

macro objectDef*(isRef: static[bool]; procDef: untyped{nkProcDef}): untyped =
  ## Create a object type definition from a constructor proc.
  ## This macro works by adding `objectDef` pragma to your constructor proc.
  ## It read assignments and var statements under `fieldDef` and
  ## create an object type that has corresponding fields.
  ## New object type have same name to the input proc.
  ##
  ## When `isRef == false`, object type is defined and
  ## `init` prefix is added to the input proc name.
  ## When `isRef == true`, ref object type is defined and
  ## `new` prefix is added to the input proc name.
  ## When the input proc is exported, new object type is also exported.
  ##
  ## Limitations:
  ## - Only assignments, var statements and comments are allowed under `fieldDef`.
  ## - Generic proc is not supported.
  ## - You can use `fieldDef` only once in a input proc.
  ## - `fieldDef` must be placed under input proc and cannot be placed under other statments.
  runnableExamples:
    proc Foo() {.objectDef(false).} =
      fieldDef:
        x = 1 + 2
        y = "foo " & "bar"
    let a = initFoo()
    doAssert a == Foo(x: 3, y: "foo bar")

  proc isExportedIdent(n: NimNode): bool =
    n.kind == nnkPostfix and n.len == 2 and n[0].strVal == "*"

  var dummyProc = procDef.copy
  dummyProc.name = genSym(nskProc)
  dummyProc.params[0] = ident"auto"

  let
    objName = procDef.name.strVal
    isExported = isExportedIdent(procDef[0])
  var newCtor = procDef.copy
  newCtor.name = ident((if isRef: "new" else: "init") & objName)
  if isExported:
    newCtor[0] = postfix(newCtor.name, "*")
  newCtor.params[0] = objName.ident

  var foundFieldDef: bool
  for i, n in procDef.body.pairs:
    if n.kind == nnkCall and n[0].strVal == "fieldDef":
      if foundFieldDef:
        error "You may not use multiple fieldDef in a proc body"
      foundFieldDef = true

      var
        tupleCtor = nnkPar.newNimNode
        objCtor = nnkObjConstr.newTree(objName.ident)
      n.expectLen 2
      n[1].expectKind nnkStmtList
      for m in n[1]:
        m.expectKind {nnkAsgn, nnkVarSection, nnkCommentStmt}
        if m.kind == nnkAsgn:
          m[0].expectKind nnkIdent
          tupleCtor.add newColonExpr(m[0], nnkTupleConstr.newTree(m[1]))
          objCtor.add newColonExpr(m[0], m[1])
        elif m.kind == nnkVarSection:
          for l in m:
            let initVal = l.last or newCall(bindSym"default", l[^2])
            for k in 0..<(l.len - 2):
              if l[k].isExportedIdent:
                tupleCtor.add newColonExpr(l[k][1], nnkTupleConstr.newTree(initVal, nnkTupleConstr.newNimNode()))
                objCtor.add newColonExpr(l[k][1], initVal)
              else:
                tupleCtor.add newColonExpr(l[k], nnkTupleConstr.newTree(initVal))
                objCtor.add newColonExpr(l[k], initVal)

      #echo tupleCtor.treeRepr
      dummyProc.body[i] = newAssignment(ident"result", tupleCtor)
      newCtor.body[i] = newAssignment(ident"result", objCtor)

  if not foundFieldDef:
    warning "There is no fieldDef in your proc with objectDef macro"

  newStmtList(
              newCall(
                      bindSym"tupleCtorToObjectDef",
                      objName.newLit,
                      isExported.newLit,
                      isRef.newLit,
                      dummyProc),
              newCtor)
