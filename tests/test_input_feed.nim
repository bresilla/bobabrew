## Integration test: feed bytes through the real input thread + decoder + event
## loop by pointing the program's input at a file. Validates the end-to-end
## input path (read -> decode -> KeyPressMsg -> update -> Quit) without a TTY.

import std/[unittest, os]
import ../src/boba

type Keys = ref object of Model
  pressed: seq[string]

method update(m: Keys, msg: Msg): (Model, Cmd) =
  if msg of KeyPressMsg:
    let k = KeyPressMsg(msg).key
    m.pressed.add $k
    if k.matchString("q"): return (Model(m), Quit)
  (Model(m), nil)

method view(m: Keys): View = newView("")

suite "input feed":
  test "reads keys from a piped input file and quits on q":
    let path = getTempDir() / "boba_feed_test.txt"
    writeFile(path, "abq")
    let f = open(path, fmRead)
    defer:
      f.close()
      removeFile(path)
    let m = Keys()
    let final = newProgram(Model(m), withoutRenderer(), withInput(f)).run()
    let got = Keys(final).pressed
    check got.len >= 3
    check got[0] == "a"
    check got[1] == "b"
    check got[2] == "q"
