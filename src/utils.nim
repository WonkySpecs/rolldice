import std / strformat

proc confirm*(msg: string): bool =
  stdout.write &"{msg}? (y/n) "
  return stdin.readLine() == "y"
