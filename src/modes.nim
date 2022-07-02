import std / tables
import modes / dndchar

export dndchar.initDndCharMode

let deserializers* = {
  dndchar.modeName: dndchar.deserialize
}.toTable
