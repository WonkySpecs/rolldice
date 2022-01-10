import std / [random, strutils, sequtils, sugar, rdstdin, tables, strformat]
import types, parser

randomize()

var
  assigned = initTable[string, types.Roll]()
  verbose = true

proc rollResultRange(roll: Roll): (int, int) =
  var
    rollMin = 0
    rollMax = 0
  for part in roll.parts:
    debugEcho part
    case part.kind:
      of Modifier:
        rollMin += part.value
        rollMax += part.value
      of DiceRoll:
        debugEcho "dice roll"
        rollMin += part.num
        rollMax += part.num * part.sides
      of Identifier:
        if assigned.contains(part.identifier):
          let (a, b) = rollResultRange(assigned[part.identifier])
          rollMin += a
          rollMax += b

  (rollMin, rollMax)

proc execRoll(roll: Roll): int
proc execPart(part: RollPart): int =
  case part.kind:
    of Modifier: part.value
    of DiceRoll:
      toSeq(1..part.num).map(i => rand(part.sides - 1) + 1).foldl(a + b)
    of Identifier:
      if assigned.contains(part.identifier):
        execRoll(assigned[part.identifier])
      else:
        echo "Warning: No saved value for '" & part.identifier & "'"
        0

proc execRoll(roll: Roll): int =
  roll.parts.map(execPart).foldl(a + b)

proc normalizeRoll(roll: Roll): Roll =
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
          if not assigned.hasKey(part.identifier):
            echo "Warning: No saved value for '" & part.identifier & "'"
          else:
            let nested = normalize(assigned[part.identifier])
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

const helpText = "'q' to quit, 'XdY' to roll X dice with Y sides, blank to repeat the last line, 'dmg = d12 + 5' to store a roll, then run with 'dmg'"

when isMainModule:
  echo helpText
  var quit = false
  var previous = ParsedLine(kind: ParseResultKind.Roll,
    roll: types.Roll(parts: @[RollPart(kind: DiceRoll, num: 1, sides: 20)]))

  while not quit:
    let line = readLineFromStdin("> ")
    let parsed = if line.isEmptyOrWhitespace(): previous else: parse(line)

    case parsed.kind:
      of ParseError: echo parsed.message
      of Meta:
        case parsed.command:
          of Quit: quit = true
          of Help: echo helpText
          of Print:
            if len(assigned) == 0: echo "Nothing saved yet"
            else:
              for k, v in assigned:
                echo &"{k}: {normalizeRoll(v)}"
          of ToggleVerbose:
            verbose = not verbose
            echo "Verbose mode " & (if verbose: "on" else: "off")
      of ParseResultKind.Roll:
        var info = ""
        if verbose:
          let (a, b) = rollResultRange(parsed.roll)
          info = &" ({a}-{b})"
        echo &"{execRoll(parsed.roll)}{info}"
      of Assignment:
        assigned[parsed.identifier] = normalizeRoll(parsed.value)

    previous = parsed

  echo "Bye high roller"
