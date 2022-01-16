import std / [parsecsv, tables, os, sequtils]
import types, parser

const cfgDir = expandTilde("~" / ".rolldice")

proc save*(name: string, rolls: Table[string, Roll]) =
  if not dirExists(cfgDir):
    createDir(cfgDir)

  var content = "id,roll\n"

  for k, v in rolls:
    content &= k & "," & $v & "\n"

  writeFile(cfgDir / name, content)

proc load*(name: string): Table[string, Roll] =
  let f = cfgDir / name
  if not fileExists(f):
    echo "No save called " & name & " exists"
    return

  var csv: CsvParser

  csv.open(cfgDir / name)
  csv.readHeaderRow()
  while csv.readRow():
    let parsed = parseRoll(csv.rowEntry("roll"))
    case parsed.kind:
      of prkRoll:
        result[csv.rowEntry("id")] = parsed.roll
      else:
        echo "oh no"

  csv.close()

proc listSaves*(): seq[string] =
  if not dirExists(cfgDir):
    return

  result = toSeq(walkFiles(cfgDir / "*"))
    .map(extractFilename)
