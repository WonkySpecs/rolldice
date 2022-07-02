import std / [sugar, sequtils, strformat, strutils, algorithm]

type
  RollPartKind* = enum
    Modifier, Identifier, DiceRoll

  RollPart* = object
    case kind*: RollPartKind
    of Modifier:
      value*: int
    of Identifier:
      identifier*: string
    of DiceRoll:
      num*: int
      sides*: int

  Roll* = object
    parts*: seq[RollPart]

  Mode* = ref object of RootObj

  Profile* = ref object
    name*: string
    modes*: seq[Mode]

func partCmp(p1, p2: RollPart): int =
  case p1.kind:
    of Modifier:
      case p2.kind:
        of Modifier: p1.value - p2.value
        of Identifier: 1
        of DiceRoll: 1
    of Identifier:
      case p2.kind:
        of Modifier: -1
        of Identifier: 0
        of DiceRoll: 1
    of DiceRoll:
      case p2.kind:
        of Modifier: 1
        of Identifier: 1
        of DiceRoll: p2.sides - p1.sides

func `$`(p: RollPart): string =
  case p.kind:
    of Modifier: $p.value
    of Identifier: p.identifier
    of DiceRoll: &"{p.num}d{p.sides}"

func `$`*(roll: Roll): string =
  sorted(roll.parts, partCmp)
    .map(p => $p)
    .join(" + ")

method tryExec*(mode: var Mode, input: string): bool {.base} =
  raise newException(Exception, "Method without override")

method name*(mode: Mode): string {.base} =
  raise newException(Exception, "Method without override")

method serialize*(mode: Mode): string {.base} =
  raise newException(Exception, "Method without override")
