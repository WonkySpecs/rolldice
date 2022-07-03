import std / [strformat, tables]

proc confirm*(msg: string): bool =
  stdout.write &"{msg}? (y/n) "
  return stdin.readLine() == "y"

proc concat*[K, V](t1, t2: Table[K, V]): Table[K, V] =
  result = t1
  for k, v in t2:
    result[k] = v
