import std / [random, strutils, sequtils, sugar, rdstdin, strformat]
import types, parser, rollmachine

randomize()

var roller = initRollMachine()

proc rollResultRange(roller: RollMachine, roll: Roll): (int, int) =
  var
    rollMin = 0
    rollMax = 0
  for part in roll.parts:
    case part.kind:
      of Modifier:
        rollMin += part.value
        rollMax += part.value
      of DiceRoll:
        rollMin += part.num
        rollMax += part.num * part.sides
      of Identifier:
        let
          resolved = roller.getRoll(part.identifier)
          (a, b) = roller.rollResultRange(resolved)
        rollMin += a
        rollMax += b

  (rollMin, rollMax)

proc exec(roller: RollMachine, roll: Roll): int
proc exec(roller: RollMachine, part: RollPart): int =
  case part.kind:
    of Modifier: part.value
    of DiceRoll:
      toSeq(1..part.num).map(i => rand(part.sides - 1) + 1).foldl(a + b)
    of Identifier:
      roller.exec(roller.getRoll(part.identifier))

proc exec(roller: RollMachine, roll: Roll): int =
  roll.parts.map(p => roller.exec(p)).foldl(a + b)

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
            roller.print()
          of ToggleVerbose:
            roller.toggleVerbose()
            echo "Verbose mode " & (if roller.verbose: "on" else: "off")
      of ParseResultKind.Roll:
        var info = ""
        if roller.verbose:
          let (a, b) = roller.rollResultRange(parsed.roll)
          info = &" ({a}-{b})"
        echo &"{roller.exec(parsed.roll)}{info}"
      of Assignment:
        if not roller.tryAssign(parsed.identifier, parsed.value):
          echo "Assignment failed, unknown identifier included"

    previous = parsed

  echo "Bye high roller"
