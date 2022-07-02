import std / tables
import modes / [dndchar, core]
import types

export dndchar.initDndCharMode
export core.initCoreMode

proc deserialize*(modeName, s: string): Mode =
  case modeName:
    of core.modeName: core.deserialize(s)
    of dndchar.modeName: dndchar.deserialize(s)
    else: raise newException(Defect, "asdfSADF")
