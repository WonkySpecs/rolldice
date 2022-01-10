import std / [tables, sugar, sequtils, strformat]
import types

type
  RollMachine* = object
    verbose*: bool
    assigned: Table[string, Roll]

func initRollMachine*(): RollMachine =
  RollMachine(verbose: true, assigned: initTable[string, Roll]())

func isAssigned(roller: RollMachine, identifier: string): bool =
  roller.assigned.contains(identifier)
proc toggleVerbose*(roller: var RollMachine) = roller.verbose = not roller.verbose

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
          if not roller.assigned.hasKey(part.identifier):
            echo "Warning: No saved value for '" & part.identifier & "'"
          else:
            let nested = normalize(roller.assigned[part.identifier])
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

proc tryAssign*(roller: var RollMachine, identifier: string, roll: Roll): bool =
  ## Tries to save the roll as the given identifier in the roller
  ## Returns false if any identifiers in the roll aren't assigned, otherwise
  ## assigns and returns true
  if roll.parts.filter(p => p.kind == Identifier)
    .anyIt(not isAssigned(roller, it.identifier)):
    return false

  roller.assigned[identifier] = roller.normalize(roll)
  true

proc print*(roller: RollMachine) =
  if len(roller.assigned) == 0: echo "Nothing saved yet"
  else:
    for k, v in roller.assigned:
      echo &"{k}: {roller.normalize(v)}"

proc clearMemory*(roller: var RollMachine) = roller.assigned.clear()
