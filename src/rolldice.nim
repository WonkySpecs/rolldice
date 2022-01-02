import std / [random, strutils, sequtils, sugar, rdstdin]
import types, parser

randomize()

proc execPart(part: RollPart): int =
  case part.kind:
    of Modifier: part.value
    of DiceRoll:
      toSeq(1..part.num).map(i => rand(part.sides)).foldl(a + b)
    else: 1

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
      else: echo execRoll(parsed.roll)

    previous = parsed

  echo "Bye high roller"
