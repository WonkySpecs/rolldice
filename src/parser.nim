import std / [strutils, sequtils, sugar, re, tables, strformat, options]
import types

type
  MetaCommand* = enum
    Quit, Help, Save, Load, List, SetVariable

  ParseResultKind* = enum
    prkMeta, prkError

  ParsedLine* = object
    case kind*: ParseResultKind
    of prkMeta:
      command*: MetaCommand
      args*: seq[string]
    else: discard

const commands = {
  Quit: @["quit", "q", "exit", "bye"],
  Help: @["help", "h", "?"],
  Save: @["save"],
  Load: @["load"],
  List: @["list"],
  SetVariable: @["set"],
}.toTable

const commandDescriptions = [
  Quit: "Quit rolldice",
  Help: "Show this help text",
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

func parseRoll*(input: string): Option[Roll] =
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

  some(Roll(parts: outParts))

func parse*(input: string): ParsedLine =
  let lower = toLower(input).strip()
  let firstAndRest = lower.split(maxsplit=1)

  let
    cmd = firstAndRest[0]
    rest = if firstAndRest.len > 1: firstAndRest[1].split() else: @[]

  for k, v in commands:
    if any(v, c => c == cmd):
      return ParsedLine(kind: prkMeta, command: k, args: rest)
  ParsedLine(kind: prkError)
