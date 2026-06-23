## Port of bubbletea/examples/stopwatch.

import std/times
import ../../src/boba
import ../../src/boba/bubbles

type App = ref object of Model
  sw: Stopwatch

method init(m: App): Cmd = m.sw.start()

method update(m: App, msg: Msg): (Model, Cmd) =
  if msg of KeyPressMsg:
    let k = KeyPressMsg(msg).key
    if k.matchString("q", "ctrl+c"): return (Model(m), Quit)
    if k.matchString("s"): return (Model(m), m.sw.toggle())
    if k.matchString("r"): m.sw.reset()
  let cmd = m.sw.update(msg)
  (Model(m), cmd)

method view(m: App): View =
  newView("Elapsed: " & m.sw.view & "\n\ns: start/stop · r: reset · q: quit")

when isMainModule:
  discard newProgram(Model(App(sw: newStopwatch(initDuration(milliseconds = 100))))).run()
