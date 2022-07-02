import std / [parsecsv, tables, os, sequtils, options, sugar]
import types, parser, constants, modes

proc save*(name: string, rolls: Table[string, Roll], modes: openarray[Mode]) =
  let profileDir = dataDir / name
  if not dirExists(profileDir):
    createDir(profileDir)

  var content = "id,roll\n"

  for k, v in rolls:
    content &= k & "," & $v & "\n"

  writeFile(profiledir / "core", content)
  for mode in modes:
    writeFile(profiledir / mode.name, mode.serialize())

proc load*(name: string): (Option[Table[string, Roll]], Mode) =
  let profileDir = dataDir / name
  if not dirExists(profileDir):
    return (none(Table[string, Roll]), initDndCharMode())

  result[0] = some(initTable[string, Roll]())
  var csv: CsvParser

  csv.open(profileDir / "core")
  csv.readHeaderRow()
  while csv.readRow():
    let parsed = parseRoll(csv.rowEntry("roll")).get()
    result[0].get()[csv.rowEntry("id")] = parsed
  csv.close()

  let modeSaves = toSeq(walkFiles(profileDir / "*"))
    .map(extractFileName)
    .filter(f => f != "core")
  let f = readFile(profileDir / modeSaves[0])
  result[1] = deserialize(modeSaves[0], f)

proc listSaves*(): seq[string] =
  if not dirExists(dataDir):
    return

  result = toSeq(walkDirs(dataDir / "*"))
    .map(extractFilename)
