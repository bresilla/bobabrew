import std/[os, osproc, strutils]

const Binary = "/tmp/bobabrew-test-bin"

proc checked(command: string): string =
  let res = execCmdEx(command)
  doAssert res.exitCode == 0, command & "\n" & res.output
  res.output

discard checked("nim c --out:" & quoteShell(Binary) & " src/bobabrew.nim")
doAssert checked(quoteShell(Binary) & " --version").strip() == "0.1.0"
doAssert checked(quoteShell(Binary) & " --help").contains("bobabrew")

