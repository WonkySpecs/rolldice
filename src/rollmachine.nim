import std / [tables, sugar, sequtils, strformat, deques, options, strutils, random]
import types, saves, config

randomize()

type
  RollMachine* = object
    verbose*: bool
    assigned: Table[string, Roll]

func getRoll*(roller: RollMachine, identifier: string): Roll =
  if roller.assigned.contains(identifier):
    roller.assigned[identifier]
  else:
    Roll(parts: @[])

proc flatten*(roller: RollMachine, roll: Roll): Roll =
  ## Simplify a roll by resolving all identifier parts and combining modifiers.
  ##
  ## Example
  ## ---
  ## a: d20 + 1d4 + 1
  ## b: 3 + d10
  ## flatten(2d10 + a + b) -> 2d10 + d20 + 1d4 + d10 + 3

  proc depthFirstFlatten(roll: Roll): Roll =
    result = Roll()
    for part in roll.parts:
      case part.kind:
        of Identifier:
          var asdf = roller.getRoll(part.identifier)
          var flattened = depthFirstFlatten(asdf)
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


proc rollResultRange*(roller: RollMachine, roll: Roll): (int, int) =
  var
    rollMin = 0
    rollMax = 0
  for part in roller.flatten(roll).parts:
    case part.kind:
      of Modifier:
        rollMin += part.value
        rollMax += part.value
      of DiceRoll:
        rollMin += part.num
        rollMax += part.num * part.sides
      else:
        debugEcho "Got an identifier in a normalized roll during rollResultRange"

  (rollMin, rollMax)

proc exec(roller: RollMachine, part: RollPart): int
proc exec*(roller: RollMachine, roll: Roll): int =
  roll.parts.map(p => roller.exec(p)).foldl(a + b)

proc exec(roller: RollMachine, part: RollPart): int =
  case part.kind:
    of Modifier: part.value
    of DiceRoll:
      toSeq(1..part.num).map(i => rand(part.sides - 1) + 1).foldl(a + b)
    of Identifier:
      roller.exec(roller.getRoll(part.identifier))

func isAssigned(roller: RollMachine, identifier: string): bool =
  roller.assigned.contains(identifier)
proc toggleVerbose*(roller: var RollMachine) = roller.verbose = not roller.verbose

func referencesIdentifier(
  roller: RollMachine,
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
        let subroll = roller.assigned[part.identifier]
        for p in subroll.parts:
          toCheck.addLast(p)
      else: discard
  return false

func invalidAssignmentMessage(
  roller: RollMachine,
  identifier: string,
  roll: Roll): Option[string] =
  let unknownIdentifiers = roll.parts.filter(p => p.kind == Identifier)
    .filter(p => not isAssigned(roller, p.identifier))
    .map(p => p.identifier)

  if unknownIdentifiers.len > 0:
    return some(&"Unknown identifiers: [{unknownIdentifiers.join(\", \")}]")

  if roller.referencesIdentifier(roll, identifier):
    return some("Roll cannot include a reference to itself")
  return none(string)

proc tryAssign*(roller: var RollMachine, identifier: string, roll: Roll) =
  ## Tries to save the roll as the given identifier in the roller
  ## If it's invalid, prints an error message instead
  let err = roller.invalidAssignmentMessage(identifier, roll)
  if err.isSome:
    echo err.get()
  else:
    roller.assigned[identifier] = roll

proc print*(roller: RollMachine) =
  if len(roller.assigned) == 0: echo "Nothing saved yet"
  else:
    for k, v in roller.assigned:
      echo &"{k}: {v}"

proc clearMemory*(roller: var RollMachine) = roller.assigned.clear()

proc save*(roller: RollMachine, name: string) = save(name, roller.assigned)

proc load*(roller: var RollMachine, name: string) =
  let loaded = load(name)
  if loaded.isSome:
    roller.assigned = loaded.get
  else:
    echo &"Profile '{name}' does not exist"

proc set*(roller: var RollMachine, variable, value: string) =
  if not configVariableSetters.hasKey(variable):
    echo &"'{variable}' cannot be set"
    echo "Use 'help set' to see all settable things (not really, but I'll add this at some point"
  else:
    configVariableSetters[variable](value)

proc initRollMachine*(): RollMachine =
  var machine = RollMachine(verbose: true, assigned: initTable[string, Roll]())
  let cfg = loadedConfig
  if cfg.defaultProfile.isSome:
    echo &"Loading initial profile {cfg.defaultProfile.get}"
    machine.load(cfg.defaultProfile.get)
  machine
