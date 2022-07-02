import std / [tables, strutils, strformat, options, marshal, sequtils, deques, sugar]
import .. / types
import .. / basics
import .. / parser

const modeName* = "core"

type
  CoreMode* = ref object of Mode
    assigned: Table[string, Roll]

  CommandKind = enum
    ckRoll, ckAssignment, ckClear, ckPrint

  Command = object
    case kind: CommandKind
    of ckAssignment:
      identifier: string
      value: Roll
    of ckRoll:
      roll: Roll
    else: discard

func initCoreMode*(): CoreMode = CoreMode()

func getRoll(mode: CoreMode, identifier: string): Roll =
  if mode.assigned.contains(identifier):
    mode.assigned[identifier]
  else:
    Roll(parts: @[])

proc flatten*(mode: CoreMode, roll: Roll): Roll =
  ## Simplify a roll by resolving all identifier parts and combining modifiers.
  ##
  ## Example
  ## ---
  ## a: d20 + 1d4 + 1
  ## b: 3 + d10
  ## flatten(2d10 + a + b) -> 2d10 + d20 + 1d4 + d10 + 4

  proc depthFirstFlatten(roll: Roll): Roll =
    result = Roll()
    for part in roll.parts:
      case part.kind:
        of Identifier:
          var assignedRoll = mode.getRoll(part.identifier)
          var flattened = depthFirstFlatten(assignedRoll)
          result.parts = result.parts.concat(flattened.parts)
        else:
          result.parts.add(part)
  var flattened = depthFirstFlatten(roll)
  result = Roll()
  var totalModifier = 0
  for part in flattened.parts:
    case part.kind:
      of Modifier:
        totalModifier += part.value
      else:
        result.parts.add(part)

  if totalModifier != 0:
    result.parts.add(RollPart(kind: Modifier, value: totalModifier))

proc rollResultRange*(mode: CoreMode, roll: Roll): (int, int) =
  rollResultRange(mode.flatten(roll))

proc printAssigned*(mode: CoreMode) =
  if len(mode.assigned) == 0: echo "Nothing saved yet"
  else:
    for k, v in mode.assigned:
      echo &"{k}: {v}"

func isAssigned(mode: CoreMode, identifier: string): bool =
  mode.assigned.contains(identifier)

func referencesIdentifier(
  mode: CoreMode,
  roll: Roll,
  identifier: string): bool =
  ## Checks whether a roll ever references 'identifier'
  ## Does a breadth first search through the roll, expanding any identifier parts

  var toCheck = roll.parts.toDeque()
  while toCheck.len > 0:
    let part = toCheck.popFirst()
    case part.kind:
      of Identifier:
        if part.identifier == identifier: return true
        let subroll = mode.assigned[part.identifier]
        for p in subroll.parts:
          toCheck.addLast(p)
      else: discard
  return false

func invalidAssignmentMessage(
  mode: CoreMode,
  identifier: string,
  roll: Roll): Option[string] =
  let unknownIdentifiers = roll.parts.filter(p => p.kind == Identifier)
    .filter(p => not isAssigned(mode, p.identifier))
    .map(p => p.identifier)

  if unknownIdentifiers.len > 0:
    return some(&"Unknown identifiers: [{unknownIdentifiers.join(\", \")}]")

  if mode.referencesIdentifier(roll, identifier):
    return some("Roll cannot include a reference to itself")
  return none(string)

proc tryAssign*(mode: var CoreMode, identifier: string, roll: Roll): bool =
  ## Tries to save the roll as the given identifier
  ## If it's invalid, prints an error message instead
  let err = mode.invalidAssignmentMessage(identifier, roll)
  if err.isSome:
    echo err.get()
    true
  else:
    mode.assigned[identifier] = roll
    false

func parseCommand(input: string): Command =
  if "=" in input:
    let splitCmd = split(input, "=", 1)
    let parsed = parseRoll(splitCmd[1].strip()).get()
    Command(
      kind: ckAssignment,
      identifier: splitCmd[0].strip(),
      value: parsed)
  else:
    let parsed = parseRoll(input.strip()).get()
    Command(kind: ckRoll, roll: parsed)

func parse(input: string): Option[Command] =
  let
    lower = toLower(input).strip()
    firstAndRest = lower.split(maxsplit=1)
    cmd = firstAndRest[0]

  if cmd == "clear":
    result = some(Command(kind: ckClear))
  elif cmd == "print":
    result = some(Command(kind: ckPrint))
  else:
    result = try: some(parseCommand(input))
    except: none(Command)

method tryExec*(mode: var CoreMode, input: string): bool =
  let p = parse(input)
  if p.isNone: return false

  let parsed = p.get()
  result = case parsed.kind:
    of ckRoll:
      let roll = mode.flatten(parsed.roll)
      if roll.parts.len == 0:
        false
      else:
        let (a, b) = mode.rollResultRange(roll)
        echo &"{exec(roll)} ({a}-{b})"
        true
    of ckAssignment:
      mode.tryAssign(parsed.identifier, parsed.value):
    of ckClear:
      mode.assigned.clear()
      true
    of ckPrint:
      mode.printAssigned()
      true

method name*(mode: CoreMode): string = modeName

method serialize*(mode: CoreMode): string =
  result = $$mode

proc deserialize*(s: string): CoreMode =
  result = to[CoreMode](s)

