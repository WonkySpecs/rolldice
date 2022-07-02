import std / [os, options, tables, marshal, streams, strformat]
import constants, saves, utils

type
  RollConfig* = object
    defaultProfile*: Option[string]

const configFile = dataDir / "config"
var loadedConfig* =
  if configFile.fileExists:
    # marshal load/store with file streams is really ugly, but the nicer options
    # in json/jsonutils didn't work - think they have a problem with Option
    var strm = newFileStream(configFile, fmRead)
    if not strm.isNil:
      var res: RollConfig
      strm.load(res)
      res
    else: RollConfig()
  else: RollConfig()

proc save() =
  var strm = newFileStream(configFile, fmWrite)
  if not strm.isNil:
    strm.store(loadedConfig)
    strm.close()

proc setDefaultProfile(value: string) =
  let loaded = load(value)
  if loaded.isNone:
    echo &"No profile called {value} currently exists"
    if not confirm("Are you sure you want to make this the default profile"):
      return
  loadedConfig.defaultProfile = some(value)
  save()

const configVariableSetters* = {
  "default": setDefaultProfile,
}.toTable

