import std / [strutils, rdstdin, strformat, terminal, tables, options]
import types, parser, saves, config, modes

var initialModes: seq[Mode]
initialModes.add initCoreMode()
var profile = Profile(name: "", modes: initialModes)

if loadedConfig.defaultProfile.isSome:
  let default = load(loadedConfig.defaultProfile.get())
  if default.isSome:
    profile = default.get()

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
    for mode in profile.modes:
      var v = mode
      if v.tryExec(line):
        handled = true
        break
    if handled: continue

    let parsed = parse(line)
    case parsed.kind:
      of prkError: echo "Unknown command (type 'help' for help)"
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
          of Save:
            if parsed.args.len == 0 and profile.name.isEmptyOrWhiteSpace:
              echo "Must specify a name, ie. 'save savename'"
            elif parsed.args.len == 0:
              save(profile.name, profile.modes)
            else:
              save(parsed.args[0], profile.modes)
          of Load:
            if parsed.args.len == 0:
              echo "Must specify profile to load, ie. 'load savename'"
            else:
              let loadedProfile = load(parsed.args[0])
              if loadedProfile.isNone:
                echo &"Profile '{parsed.args[0]}' does not exist"
              else:
                profile = loadedProfile.get()
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
            elif not configVariableSetters.hasKey(parsed.args[0]):
              echo &"'{parsed.args[0]}' cannot be set"
              echo "Use 'help set' to see all settable things (not really, but I'll add this at some point"
            else:
              configVariableSetters[parsed.args[0]](parsed.args[1])


  stdout.resetAttributes
  echo "Bye high roller"
