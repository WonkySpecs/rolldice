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

when isMainModule:
  echo "Get rolling, or enter 'help' for help"
  var quit = false
  var previous = ParsedLine(kind: prkRoll,
    roll: Roll(parts: @[RollPart(kind: DiceRoll, num: 1, sides: 20)]))

  while not quit:
    let line = readLineFromStdin("> ")
    let parsed = if line.isEmptyOrWhitespace(): previous else: parse(line)

    case parsed.kind:
      of prkParseError: echo parsed.message
      of prkMeta:
        case parsed.command:
          of Quit: quit = true
          of Help:
            echo "'XdY' rolls X dice with Y sides. Add rolls and modifiers with '+'"
            echo "Save a roll using 'a = d20 + 6', then reroll with 'a'"
            echo "Enter an empty line to repeat the last roll/command"
            echo ""
            echo "Commands:"
            echo "-----"
            printCommandHelp()
          of Print:
            roller.print()
          of ToggleVerbose:
            roller.toggleVerbose()
            echo "Verbose mode " & (if roller.verbose: "on" else: "off")
          of ClearMemory:
            echo "Clearing..."
            roller.clearMemory()
          of Save:
            if parsed.args.len == 0:
              echo "Must specify a name, ie. 'save savename'"
            else:
              roller.save(parsed.args[0])
          of Load:
            if parsed.args.len == 0:
              echo "Must specify profile to load, ie. 'load savename'"
            else:
              roller.load(parsed.args[0])
      of prkRoll:
        let roll = roller.normalize(parsed.roll)
        if roll.parts.len == 0:
          echo "Unknown identifier"
        else:
          var info = ""
          if roller.verbose:
            let (a, b) = roller.rollResultRange(roll)
            info = &" ({a}-{b})"
          echo &"{roller.exec(roll)}{info}"
      of prkAssignment:
        if not roller.tryAssign(parsed.identifier, parsed.value):
          echo "Assignment failed, unknown identifier included"

    previous = parsed

  echo "Bye high roller"
