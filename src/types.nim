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
