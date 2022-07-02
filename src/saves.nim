import std / [os, sequtils, options, sugar]
import types, constants, modes

proc save*(name: string, modes: openarray[Mode]) =
  let profileDir = dataDir / name
  if not dirExists(profileDir):
    createDir(profileDir)
  for mode in modes:
    writeFile(profiledir / mode.name, mode.serialize())

proc load*(name: string): Option[Profile] =
  let profileDir = dataDir / name
  if not dirExists(profileDir):
    return none(Profile)

  result = some(Profile())
  result.get().name = name
  result.get().modes = toSeq(walkFiles(profileDir / "*"))
    .map(extractFileName)
    .map(f => deserialize(f, readFile(profileDir / f)))

proc listSaves*(): seq[string] =
  if not dirExists(dataDir):
    return

  result = toSeq(walkDirs(dataDir / "*"))
    .map(extractFilename)
