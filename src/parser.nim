import std / [strutils, sequtils, sugar, strformat, re]
import types

type
  MetaCommand* = enum
    Quit, Help, Print, ToggleVerbose, ClearMemory

  ParseResultKind* = enum
    ParseError, Assignment, Roll, Meta

  ParsedLine* = object
    case kind*: ParseResultKind
    of ParseError:
      message*: string
    of Roll:
      roll*: Roll
    of Assignment:
      identifier*: string
      value*: Roll
    of Meta:
      command*: MetaCommand

const quit_commands = ["q", "quit", "exit", "bye"]
const help_commands = ["h", "help", "?"]
const print_commands = ["p", "print"]
const toggle_verbose_commands = ["v", "verbose"]
const clear_commands = ["clear"]

template echoCommand(s, l: untyped) = echo s & ": " & l.join(", ")
proc printCommandHelp*() =
  echoCommand("help", help_commands)
  echoCommand("quit", quit_commands)
  echoCommand("print", print_commands)
  echoCommand("toggle verbose", toggle_verbose_commands)
  echoCommand("clear memory", clear_commands)

func parseRoll(input: string): ParsedLine =
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
    kind: Roll,
    roll: Roll(parts: outParts))

func parseCommand(input: string): ParsedLine =
  if "=" in input:
    let splitCmd = split(input, "=", 1)
    let parsed = parseRoll(splitCmd[1].strip())

    case parsed.kind:
    of ParseError: parsed
    of Roll: ParsedLine(
      kind: Assignment,
      identifier: splitCmd[0].strip(),
      value: parsed.roll)
    else:
      raise newException(Defect, "parseRoll returned something other than error/a roll when trying to parsed an assignment")
  else:
    parseRoll(input.strip())

func parse*(input: string): ParsedLine =
  let lower = toLower(input).strip()
  if any(quit_commands, c => c == lower):
    ParsedLine(kind: Meta, command: Quit)
  elif any(help_commands, c => c == lower):
    ParsedLine(kind: Meta, command: Help)
  elif any(print_commands, c => c == lower):
    ParsedLine(kind: Meta, command: Print)
  elif any(toggle_verbose_commands, c => c == lower):
    ParsedLine(kind: Meta, command: ToggleVerbose)
  elif any(clear_commands, c => c == lower):
    ParsedLine(kind: Meta, command: ClearMemory)
  else:
    parseCommand(lower)
