import std / [strutils, sequtils, sugar, strformat, re]
import types

type
  MetaCommand* = enum
    Quit, Help, Print, ToggleVerbose, ClearMemory, Save, Load

  ParseResultKind* = enum
    prkParseError, prkAssignment, prkRoll, prkMeta

  ParsedLine* = object
    case kind*: ParseResultKind
    of prkParseError:
      message*: string
    of prkRoll:
      roll*: Roll
    of prkAssignment:
      identifier*: string
      value*: Roll
    of prkMeta:
      command*: MetaCommand
      args*: seq[string]

const quit_commands = ["q", "quit", "exit", "bye"]
const help_commands = ["h", "help", "?"]
const print_commands = ["p", "print"]
const toggle_verbose_commands = ["v", "verbose"]
const clear_commands = ["clear"]
const save_commands = ["save"]
const load_commands = ["load"]

template echoCommand(s, l: untyped) = echo s & ": " & l.join(", ")
proc printCommandHelp*() =
  echoCommand("help", help_commands)
  echoCommand("quit", quit_commands)
  echoCommand("print", print_commands)
  echoCommand("toggle verbose", toggle_verbose_commands)
  echoCommand("clear memory", clear_commands)

func parseRoll*(input: string): ParsedLine =
  let parts = split(input, "+").mapIt($(it.strip()))
  var outParts = newSeq[RollPart]()

  for part in parts:
    if all(part, isDigit):
      outParts.add RollPart(kind: Modifier, value: part.parseInt())
    elif part =~ re"^(\d*)\s*d\s*(\d+)$":
      let num = if matches[0].len > 0: matches[0] else: "1"
      outParts.add RollPart(
        kind: DiceRoll,
        num: num.parseInt(),
        sides: matches[1].parseInt())
    else: outParts.add RollPart(kind: Identifier, identifier: part)

  ParsedLine(
    kind: prkRoll,
    roll: Roll(parts: outParts))

func parseCommand(input: string): ParsedLine =
  if "=" in input:
    let splitCmd = split(input, "=", 1)
    let parsed = parseRoll(splitCmd[1].strip())

    case parsed.kind:
      of prkParseError: parsed
      of prkRoll: ParsedLine(
        kind: prkAssignment,
        identifier: splitCmd[0].strip(),
        value: parsed.roll)
      else:
        raise newException(Defect, "parseRoll returned something other than error/a roll when trying to parsed an assignment")
  else:
    parseRoll(input.strip())

func parse*(input: string): ParsedLine =
  let lower = toLower(input).strip()
  let firstAndRest = lower.split(maxsplit=1)

  let
    cmd = firstAndRest[0]
    rest = if firstAndRest.len > 1: firstAndRest[1].split() else: @[]

  if any(quit_commands, c => c == cmd):
    ParsedLine(kind: prkMeta, command: Quit)
  elif any(help_commands, c => c == cmd):
    ParsedLine(kind: prkMeta, command: Help)
  elif any(print_commands, c => c == cmd):
    ParsedLine(kind: prkMeta, command: Print)
  elif any(toggle_verbose_commands, c => c == cmd):
    ParsedLine(kind: prkMeta, command: ToggleVerbose)
  elif any(clear_commands, c => c == cmd):
    ParsedLine(kind: prkMeta, command: ClearMemory)
  elif any(save_commands, c => c == cmd):
    ParsedLine(kind: prkMeta, command: Save, args: rest)
  elif any(load_commands, c => c == cmd):
    ParsedLine(kind: prkMeta, command: Load, args: rest)
  else:
    # Doesn't match any meta commands, parse as roll or assignment
    parseCommand(lower)
