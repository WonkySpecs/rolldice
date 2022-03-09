import std / [parsecsv, tables, os, sequtils, options]
import types, parser, constants

proc save*(name: string, rolls: Table[string, Roll]) =
  if not dirExists(dataDir):
    createDir(dataDir)

  var content = "id,roll\n"

  for k, v in rolls:
    content &= k & "," & $v & "\n"

  writeFile(dataDir / name, content)

proc load*(name: string): Option[Table[string, Roll]] =
  let f = dataDir / name
  if not fileExists(f):
    return none(Table[string, Roll])

  result = some(initTable[string, Roll]())
  var csv: CsvParser

  csv.open(dataDir / name)
  csv.readHeaderRow()
  while csv.readRow():
    let parsed = parseRoll(csv.rowEntry("roll"))
    case parsed.kind:
      of prkRoll:
        result.get()[csv.rowEntry("id")] = parsed.roll
      else:
        echo "oh no"

  csv.close()

proc listSaves*(): seq[string] =
  if not dirExists(dataDir):
    return

  result = toSeq(walkFiles(dataDir / "*"))
    .map(extractFilename)
