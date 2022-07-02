import std / [tables, strutils, strformat, options, marshal]
import .. / types
import .. / basics

const modeName* = "dndchar"

type
  DndCharMode* = ref object of Mode
    str_mod, dex_mod, con_mod, int_mod, wis_mod, cha_mod: int
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
    str_mod: 0,
    dex_mod: 0,
    con_mod: 0,
    int_mod: 0,
    wis_mod: 0,
    cha_mod: 0,
    level: 1)

const commands = {
  Str: "str",
  Dex: "dex",
  Initiative: "i",
  Set: "set",
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

proc setValue(mode: var DndCharMode, command: Command) =
  assert command.kind == Set
  try:
    let
      attr = command.args[0]
      value = parseInt(command.args[1])
    case attr:
      of "str": mode.str_mod = value
      of "dex": mode.dex_mod = value
      of "con": mode.con_mod = value
      of "int": mode.int_mod = value
      of "wis": mode.wis_mod = value
      of "cha": mode.cha_mod = value
      of "level": mode.level = value
      else:
        echo &"Cannot set unknown attribute '{attr}'"
  except ValueError:
    echo "Argument to set must be an integer"

const rollKinds = @[
  Str, Dex, Con, Int, Wis, Cha, Initiative
]

method tryExec*(mode: var DndCharMode, input: string, verbose: bool): bool =
  let p = parse(input)
  if p.isNone: return false

  let kind = p.get().kind
  if rollKinds.contains(kind):
    let modifier = case kind:
      of Str: mode.str_mod
      of Dex: mode.dex_mod
      of Con: mode.con_mod
      of Int: mode.int_mod
      of Wis: mode.wis_mod
      of Cha: mode.cha_mod
      of Initiative: mode.dex_mod
      else: 0

    var roll = Roll(parts: @[
      RollPart(kind: DiceRoll, num: 1, sides: 20),
      RollPart(kind: Modifier, value: modifier)])

    var info = ""
    if verbose:
      let (a, b) = rollResultRange(roll)
      info = &" ({a}-{b})"
    echo &"{exec(roll, verbose)}{info}"
  else:
    case kind:
      of Set: mode.setValue(p.get())
      else: discard
  true

method name*(mode: DndCharMode): string = modeName

method serialize*(mode: DndCharMode): string =
  result = $$mode

proc deserialize*(s: string): DndCharMode =
  result = to[DndCharMode](s)

