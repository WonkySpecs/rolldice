import std / [strutils, sequtils, sugar, re, tables, strformat]
import types

type
  MetaCommand* = enum
    Quit, Help, Print, ToggleVerbose, ClearMemory, Save, Load, List, SetVariable

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

const commands = {
  Quit: @["quit", "q", "exit", "bye"],
  Help: @["help", "h", "?"],
  Print: @["print"],
  ToggleVerbose: @["verbose", "v"],
  ClearMemory: @["clear"],
  Save: @["save"],
  Load: @["load"],
  List: @["list"],
  SetVariable: @["set"],
}.toTable

const commandDescriptions = [
  Quit: "Quit rolldice",
  Help: "Show this help text",
  Print: "Show the current list of saved rolls",
  ToggleVerbose: "Toggle verbose output",
  ClearMemory: "Clear the current list of saved rolls",
  Save: "Save the list of saved rolls as a profile with the given name",
  Load: "Load a previously saved profile using its name",
  List: "List saved profiles",
  SetVariable: "Set a variable value"
]

# Compile time check that all commands have a description
static: assert(
  commandDescriptions.high == MetaCommand.high,
  "Not all commands have a description in commandDescriptions")

proc printCommandHelp*() =
  for k, v in commands:
    let commandStringList = v.map(c => '"' & c & '"').join(", ")
    echo &"[{commandStringList}]: {commandDescriptions[k]}"

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

  for k, v in commands:
    if any(v, c => c == cmd):
      return ParsedLine(kind: prkMeta, command: k, args: rest)
  # Doesn't match any meta commands, parse as roll or assignment
  parseCommand(lower)
