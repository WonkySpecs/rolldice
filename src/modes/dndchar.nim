import std / [strutils, strformat, options, marshal, tables, math]
import .. / types
import .. / basics
import .. / utils

const modeName* = "dndchar"

type
  DndCharMode* = ref object of Mode
    str, dex, con, intelligence, wis, cha: int
    level: int

  CommandKind = enum
    Str, Dex, Con, Int, Wis, Cha,
    StrSave, DexSave, ConSave, IntSave, WisSave, ChaSave,
    Initiative,
    Set

  Command = object
    kind: CommandKind
    args: seq[string]

func initDndCharMode*(): DndCharMode =
  DndCharMode(
    str: 0,
    dex: 0,
    con: 0,
    intelligence: 0,
    wis: 0,
    cha: 0,
    level: 1)

const attrStrings = {
  Str: "str",
  Dex: "dex",
  Con: "con",
  Int: "int",
  Wis: "wis",
  Cha: "cha",
}.toTable

const commands = attrStrings.concat({
  StrSave: "str_save",
  DexSave: "dex_save",
  ConSave: "con_save",
  IntSave: "int_save",
  WisSave: "wis_save",
  ChaSave: "cha_save",
  Initiative: "i",
  Set: "set",
}.toTable)

func parse(input: string): Option[Command] =
  let lower = toLower(input).strip()
  let firstAndRest = lower.split(maxsplit=1)

  let
    cmd = firstAndRest[0]
    rest = if firstAndRest.len > 1: firstAndRest[1].split() else: @[]

  for k, v in commands:
    if v == cmd:
      return some(Command(kind: k, args: rest))

  return none(Command)

proc setValue(mode: var DndCharMode, command: Command): bool =
  assert command.kind == Set
  if command.args.len == 0:
    echo "Use 'set <attr> <value>' to set a value."
    echo "Possible attrs are 'str', 'dex', 'con', 'int', 'wis', 'cha', and 'level'"
    return true

  elif command.args.len == 1:
    case command.args[0]:
      of "str": echo mode.str
      of "dex": echo mode.dex
      of "con": echo mode.con
      of "int": echo mode.intelligence
      of "wis": echo mode.wis
      of "cha": echo mode.cha
      of "level": echo mode.level
      else: return false
    return true

  try:
    let
      attr = command.args[0]
      value = parseInt(command.args[1])
    case attr:
      of "str": mode.str = value
      of "dex": mode.dex = value
      of "con": mode.con = value
      of "int": mode.intelligence = value
      of "wis": mode.wis = value
      of "cha": mode.cha = value
      of "level": mode.level = value
      else:
        echo &"Cannot set unknown attribute '{attr}'"
        return false
  except ValueError:
    echo "Argument to set must be an integer"
    return false
  true

const rollKinds = @[
  Str, Dex, Con, Int, Wis, Cha, Initiative,
  StrSave, DexSave, ConSave, IntSave, WisSave, ChaSave, Initiative,
]

proc modifier(attValue: int): int = floor((attValue - 10) / 2).toInt

method tryExec*(mode: var DndCharMode, input: string): bool =
  let p = parse(input)
  if p.isNone: return false

  let kind = p.get().kind
  if rollKinds.contains(kind):
    let score = case kind:
      of Str: mode.str
      of Dex: mode.dex
      of Con: mode.con
      of Int: mode.intelligence
      of Wis: mode.wis
      of Cha: mode.cha
      of StrSave: mode.str
      of DexSave: mode.dex
      of ConSave: mode.con
      of IntSave: mode.intelligence
      of WisSave: mode.wis
      of ChaSave: mode.cha
      of Initiative: mode.dex
      else: 0

    var roll = Roll(parts: @[RollPart(kind: DiceRoll, num: 1, sides: 20)])
    let modifier = modifier(score)
    if modifier != 0:
      roll.parts.add RollPart(kind: Modifier, value: modifier)

    let (a, b) = rollResultRange(roll)
    echo &"{exec(roll)} ({a}-{b})"
  else:
    return case kind:
      of Set: mode.setValue(p.get())
      else: false
  true

method name*(mode: DndCharMode): string = modeName

method serialize*(mode: DndCharMode): string =
  result = $$mode

proc deserialize*(s: string): DndCharMode =
  result = to[DndCharMode](s)

when isMainModule:
    import unittest

    test "modifiers":
      check:
        modifier(10) == 0
        modifier(11) == 0
        modifier(12) == 1
        modifier(13) == 1
        modifier(14) == 2
        modifier(19) == 4
        modifier(20) == 5
        modifier(9) == -1
        modifier(8) == -1
        modifier(4) == -3
        modifier(3) == -4
