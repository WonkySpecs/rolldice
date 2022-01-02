import std / [strutils, sequtils, sugar, re]
import types

type
  MetaCommand* = enum
    Quit, Help

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
  let lower = toLower(input)
  if any(quit_commands, c => c == lower):
    ParsedLine(kind: Meta, command: Quit)
  elif any(help_commands, c => c == lower):
    ParsedLine(kind: Meta, command: Help)
  else:
    parseCommand(lower)
