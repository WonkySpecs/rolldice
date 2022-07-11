import std / [strutils, strformat, options, marshal, tables, math]
import .. / types
import .. / basics
import .. / utils

const modeName* = "dndchar"

type
  DndCharMode* = ref object of Mode
    str, dex, con, intelligence, wis, cha: int
    class: Class
    level: int

  CommandKind = enum
    Str, Dex, Con, Int, Wis, Cha,
    StrSave, DexSave, ConSave, IntSave, WisSave, ChaSave,
    Initiative,
    Set

  Command = object
    kind: CommandKind
    args: seq[string]

  Class = enum
    Barbarian, Bard, Cleric, Druid, Fighter, Monk, Paladin, Ranger, Rogue,
    Sorc, Warlock, Wizard

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

const saveProficiencies = {
  Barbarian: [StrSave, ConSave],
  Bard: [DexSave, ChaSave],
  Cleric: [WisSave, ChaSave],
  Druid: [IntSave, WisSave],
  Fighter: [StrSave, ConSave],
  Monk: [StrSave, DexSave],
  Paladin: [WisSave, ChaSave],
  Ranger: [StrSave, DexSave],
  Rogue: [DexSave, IntSave],
  Sorc: [ConSave, ChaSave],
  Warlock: [WisSave, ChaSave],
  Wizard: [IntSave, WisSave]
}.toTable

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
    echo "Possible attrs are 'str', 'dex', 'con', 'int', 'wis', 'cha', 'class' and 'level'"
    return true

  elif command.args.len == 1:
    case command.args[0]:
      of "str": echo mode.str
      of "dex": echo mode.dex
      of "con": echo mode.con
      of "int": echo mode.intelligence
      of "wis": echo mode.wis
      of "cha": echo mode.cha
      of "class": echo mode.class
      of "level": echo mode.level
      else:
        echo &"Unkown attribute '{command.args[0]}'"
        return false
    return true

  let attr = command.args[0]
  try:
    let value = parseInt(command.args[1])
    var handled = true
    case attr:
      of "str": mode.str = value
      of "dex": mode.dex = value
      of "con": mode.con = value
      of "int": mode.intelligence = value
      of "wis": mode.wis = value
      of "cha": mode.cha = value
      of "level": mode.level = value
      else: handled = false

    if handled: return true

  except ValueError: discard

  if attr == "class":
    try:
      let
        name = command.args[1].toLowerAscii.capitalizeAscii
        class = parseEnum[Class](name)
      mode.class = class
    except:
      echo &"Unknown class '{command.args[1]}'"
  else:
    echo &"Cannot set unknown attribute '{attr}'"
    return false

  true

const rollKinds = @[
  Str, Dex, Con, Int, Wis, Cha, Initiative,
  StrSave, DexSave, ConSave, IntSave, WisSave, ChaSave, Initiative,
]

func modifier(attValue: int): int = floor((attValue - 10) / 2).toInt

func proficiency(level: int): int = floor((level - 1) / 4).toInt + 2
func proficiency(mode: DndCharMode): int = proficiency(mode.level)
func proficiencyBonus(mode: DndCharMode, kind: CommandKind): int =
  if kind in saveProficiencies[mode.class]: proficiency(mode)
  else: 0

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
    let modifier = modifier(score) + mode.proficiencyBonus(kind)
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

    test "proficiencies":
      check:
        proficiency(1) == 2
        proficiency(4) == 2
        proficiency(5) == 3
        proficiency(8) == 3
        proficiency(9) == 4
        proficiency(12) == 4
