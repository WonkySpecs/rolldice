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

proc normalize*(roller: RollMachine, roll: Roll): Roll =
  ## Turn a roll into it's simplest form, combining multiple of the same parts and
  ## resolving symbols

  proc normalize(roll: Roll): Table[int, seq[int]] =
    # number of sides:
    var counts = initTable[int, seq[int]]()
    for part in roll.parts:
      case part.kind:
        of Modifier:
          var vals = counts.getOrDefault(0, newSeq[int]())
          vals.add part.value
          counts[0] = vals
        of DiceRoll:
          var vals = counts.getOrDefault(part.sides, newSeq[int]())
          vals.add part.num
          counts[part.sides] = vals
        of Identifier:
          let nested = normalize(roller.getRoll(part.identifier))
          for k, v in nested:
            var vals = counts.getOrDefault(k, newSeq[int]())
            vals = vals & v
            counts[k] = vals
    counts

  let asTable = normalize(roll)
  var parts = newSeq[RollPart]()
  for k, v in asTable:
    parts.add(if k == 0:
        RollPart(kind: Modifier, value: v.foldl(a + b))
      else:
        RollPart(kind: DiceRoll, sides: k, num: v.foldl(a + b)))
  Roll(parts: parts)

proc rollResultRange*(roller: RollMachine, roll: Roll): (int, int) =
  var
    rollMin = 0
    rollMax = 0
  for part in roller.normalize(roll).parts:
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
