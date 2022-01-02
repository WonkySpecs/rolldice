import std / [random, strutils, sequtils, sugar, rdstdin, tables]
import types, parser

randomize()

var
  assigned = initTable[string, types.Roll]()

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
        echo "No saved value for " & part.identifier
        0

proc execRoll(roll: Roll): int =
  roll.parts.map(execPart).foldl(a + b)

const helpText = "'q' to quit, 'XdY' to roll X dice with Y sides, 'a' to roll d20 with advantage, blank to repeat the last line"

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
      of ParseResultKind.Roll:
        echo execRoll(parsed.roll)
      of Assignment:
        assigned[parsed.identifier] = parsed.value

    previous = parsed

  echo "Bye high roller"
