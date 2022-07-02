import std / [sequtils, sugar, terminal, random]
import types

randomize()

proc exec(part: RollPart, verbose: bool): seq[(int, int)]
proc exec*(roll: Roll, verbose: bool): int =
  var results = newSeq[(int, int)]()
  for partResult in roll.parts.map(p => exec(p, verbose)):
    results.add partResult
  if verbose:
    for i, r in results:
      var (a, b) = r
      var col = fgDefault
      if a == b:
        col = fgGreen
      elif a == 1 and b > 0:
        col = fgRed
      stdout.styledWrite(col, $a)
      if i < results.high:
        stdout.write(" + ")
    stdout.write(" = ")
  results.map(pr => pr[0]).foldl(a + b)

proc exec(part: RollPart, verbose: bool): seq[(int, int)] =
  ## Returns seq of (result, max)
  case part.kind:
    of Modifier:
      result.add (part.value, 0)
    of DiceRoll:
      result = toSeq(1..part.num).map(i => (rand(part.sides - 1) + 1, part.sides))
    of Identifier:
      raise newException(Defect, "exec called on a non-flattened roll")

proc rollResultRange*(roll: Roll): (int, int) =
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
      else:
        debugEcho "Got an identifier in a normalized roll during rollResultRange"

  (rollMin, rollMax)
