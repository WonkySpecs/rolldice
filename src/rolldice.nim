import std / [strutils, rdstdin, strformat, terminal, sequtils]
import types, parser, rollmachine, saves, modes, basics

var roller = initRollMachine()
var activeModes = newSeq[Mode]()
activeModes.add initDndCharMode()

when isMainModule:
  echo "Get rolling, or enter 'help' for help"
  var quit = false
  var previous = "d20"

  while not quit:
    let next = readLineFromStdin("> ")
    let line = if next.isEmptyOrWhiteSpace: previous else: next
    if not next.isEmptyOrWhiteSpace:
      previous = next

    var handled = false
    for mode in activeModes:
      var v = mode
      if v.tryExec(line, roller.verbose):
        handled = true
        break
    if handled: continue

    let parsed = parse(line)
    case parsed.kind:
      of prkParseError: echo parsed.message
      of prkRoll:
        let roll = roller.flatten(parsed.roll)
        if roll.parts.len == 0:
          echo "Unknown identifier"
        else:
          var info = ""
          if roller.verbose:
            let (a, b) = roller.rollResultRange(roll)
            info = &" ({a}-{b})"
          echo &"{exec(roll, roller.verbose)}{info}"
      of prkAssignment: roller.tryAssign(parsed.identifier, parsed.value)
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
              roller.save(parsed.args[0], activeModes[activeModes.high])
          of Load:
            if parsed.args.len == 0:
              echo "Must specify profile to load, ie. 'load savename'"
            else:
              # TODO: move mode into machine
              activeModes.add roller.load(parsed.args[0])
          of List:
            let saves = listSaves()
            if saves.len == 0:
              echo "No saved profiles"
            else:
              for s in saves:
                echo s
          of SetVariable:
            if parsed.args.len < 2:
              echo "'set' requires two arguments, the variable to set and its value"
            else:
              roller.set(parsed.args[0], parsed.args[1])

  stdout.resetAttributes
  echo "Bye high roller"
