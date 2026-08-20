## nimin dialect linter.
##
## This module inspects code for constructs that are outside the nimin dialect.
## It plugs into the compiler via `ModuleGraph.strongSemCheck` (the same hook
## DrNim uses), which fires for every routine body after semantic analysis.
## We only act on the main project module.
##
## Rejected constructs:
##   - dynamic exceptions: `try` / `except` / `raise`
##   - procedural `macro` declarations
##   - polymorphic object inheritance without an explicit pragma
##
## Type definitions are checked by parsing the source file directly, via
## `lintModuleTypes` which must be called from the driver before `mainCommand`.
## This is necessary because `strongSemCheck` does not fire for `nkTypeSection`
## nodes (the compiler's `trackStmt` handles them separately).
##
## Diagnostics follow the plan's style, e.g.:
##   NimiError: Dynamic exceptions are disabled. Use Result[T, E] or panic instead

import std/os

import compiler/ast
import compiler/idents
import compiler/modulegraphs
import compiler/msgs
import compiler/options
import compiler/lineinfos
import compiler/parser
import compiler/llstream
import compiler/pathutils

const
  NimiError = "NimiError"

var
  typesChecked = false

proc resetLintState*() =
  ## Reset linter state. Must be called at the start of each compilation.
  typesChecked = false

proc reject(conf: ConfigRef; info: TLineInfo; msg: string) =
  ## Emit a user error at `info`. Increments `conf.errorCounter`, which the
  ## driver surfaces as a non-zero exit code.
  localError(conf, info, NimiError & ": " & msg)

proc rejectParsed(conf: ConfigRef; msg: string) =
  ## Emit a user error for nodes produced by the standalone parser.
  ## These nodes carry FileIndex(0) which isn't in the compiler's file table
  ## yet, so we can't use `localError` (it would crash in toFileLineCol).
  ## Instead we increment the error counter and write the message directly.
  inc conf.errorCounter
  msgWriteln(conf, NimiError & ": " & msg)

proc hasExplicitPragma(typedef: PNode): bool =
  ## A type declaration carries its pragma in the `nkPragmaExpr` wrapper
  ## (son 0 of the `nkTypeDef`). Presence of any explicit pragma opts the
  ## declaration out of the inheritance guard.
  if typedef == nil or typedef.len < 1: return false
  let lhs = typedef[0]
  result = lhs != nil and lhs.kind == nkPragmaExpr and
           lhs.len >= 2 and lhs[1].kind == nkPragma and lhs[1].len > 0

proc isRootObjParent(n: PNode): bool =
  ## Check if `n` is an identifier referencing `RootObj`.
  if n == nil: return false
  case n.kind
  of nkIdent: result = n.ident.s == "RootObj"
  of nkSym: result = n.sym.name.s == "RootObj"
  else: result = false

proc checkTypeDef(conf: ConfigRef; td: PNode) =
  ## Validate a single `nkTypeDef` node for the main project module.
  ## Uses the PARSED AST (not typed), so we check for `nkOfInherit` directly
  ## in the object type's second child.
  if td == nil or td.kind != nkTypeDef or td.len < 3: return
  if hasExplicitPragma(td): return

  proc hasInheritance(n: PNode): bool =
    if n == nil: return false
    case n.kind
    of nkObjectTy:
      # In the parsed AST, `object of X` produces nkObjectTy with:
      #   [0] = nkRecList (fields, may be empty)
      #   [1] = nkOfInherit (parent type reference)
      if n.len >= 2 and n[1].kind == nkOfInherit:
        # `object of RootObj` is the standard explicit base — allow it.
        if n[1].len >= 1 and isRootObjParent(n[1][0]):
          return false
        return true
    of nkRefTy, nkPtrTy:
      if n.len >= 1:
        return hasInheritance(n[0])
    else:
      discard
    result = false

  if hasInheritance(td[2]):
    rejectParsed(conf,
      "Polymorphic object inheritance is disabled. Use a tagged union or " &
      "add an explicit pragma (e.g. `{.nimin.}`) to opt in.")

proc checkRoutine(conf: ConfigRef; owner: PSym; body: PNode) =
  ## Check a routine's body for disallowed constructs.
  if owner != nil and owner.kind == skMacro:
    reject(conf, owner.info,
      "Procedural `macro` declarations are disabled. Use templates, " &
      "generics, or `importc` for metaprogramming.")
    return
  if body == nil: return
  proc walk(n: PNode) =
    if n == nil: return
    case n.kind
    of nkTryStmt, nkExceptBranch, nkFinally:
      reject(conf, n.info,
        "Dynamic exceptions are disabled. Use Result[T, E] or panic instead.")
    of nkRaiseStmt:
      reject(conf, n.info,
        "Dynamic exceptions are disabled. Use Result[T, E] or panic instead.")
    of nkMacroDef:
      reject(conf, n.info,
        "Procedural `macro` declarations are disabled. Use templates, " &
        "generics, or `importc` for metaprogramming.")
    else:
      discard
    for c in n:
      if c != nil and c.kind notin {nkSym, nkIdent} and c.safeLen > 0:
        walk(c)
  walk(body)

proc lintModuleTypes*(conf: ConfigRef; cache: IdentCache) =
  ## Parse the source file and check type definitions for inheritance violations.
  ## Must be called from the driver before `mainCommand`, because
  ## `strongSemCheck` does not fire for `nkTypeSection` nodes.
  ## Guarded by `typesChecked` so it only runs once per compilation.
  if typesChecked: return
  typesChecked = true

  let sourceFile = conf.projectFull.string
  if not fileExists(sourceFile): return

  let stream = llStreamOpen(readFile(sourceFile))
  if stream == nil: return
  defer: llStreamClose(stream)

  var p: Parser
  # Use the filename overload which registers the file in the config's file
  # table via `fileInfoIdx`. The FileIndex overload would use
  # conf.projectMainIdx which may not be registered yet, causing a crash
  # when the parser reports syntax errors.
  openParser(p, AbsoluteFile(sourceFile), stream, cache, conf)
  defer: closeParser(p)

  let ast = p.parseAll()
  if ast == nil: return

  proc walk(n: PNode) =
    if n == nil: return
    case n.kind
    of nkTypeSection:
      for child in n:
        if child != nil and child.kind == nkTypeDef:
          checkTypeDef(conf, child)
    else:
      discard
    for c in n:
      if c != nil and c.kind notin {nkSym, nkIdent} and c.safeLen > 0:
        walk(c)
  walk(ast)

proc strongSemCheck*(graph: ModuleGraph; owner: PSym; body: PNode) {.nimcall.} =
  ## DrNim-style hook installed into `graph.strongSemCheck`. Called after a
  ## routine body is semantically analyzed. We only act on the main module.
  if body == nil: return

  let conf = graph.config

  # Determine if we're processing code from the main module.
  let ownerFileIdx = if owner != nil: owner.info.fileIndex else: body.info.fileIndex
  if int(ownerFileIdx) != int(conf.projectMainIdx): return

  # Handle routine bodies: macros caught via owner.kind, exceptions via AST walk.
  checkRoutine(conf, owner, body)
