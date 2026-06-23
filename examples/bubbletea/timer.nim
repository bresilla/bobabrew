## Port of bubbletea/examples/timer.

import std/times
import ../../src/boba
import ../../src/boba/bubbles

type App = ref object of Model
  t: Timer
  done: bool

method init(m: App): Cmd = m.t.start()

method update(m: App, msg: Msg): (Model, Cmd) =
  if msg of KeyPressMsg:
    let k = KeyPressMsg(msg).key
    if k.matchString("q", "ctrl+c"): return (Model(m), Quit)
    if k.matchString("s"): return (Model(m), m.t.start())
  if msg of TimerTimeoutMsg:
    m.done = true
    return (Model(m), Quit)
  let cmd = m.t.update(msg)
  (Model(m), cmd)

method view(m: App): View =
  if m.done: return newView("All done!\n")
  newView("Exiting in " & m.t.view & "\n\ns: start · q: quit")

when isMainModule:
  discard newProgram(Model(App(t: newTimer(initDuration(seconds = 5))))).run()
