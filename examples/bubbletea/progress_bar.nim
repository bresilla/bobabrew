## Port of bubbletea/examples/progress-bar — animated bar; enter restarts.

import std/times
import ../../src/boba
import ../../src/boba/bubbles

type
  FrameMsg = ref object of Msg
  App = ref object of Model
    bar: Progress

proc frame(): Cmd = Tick(initDuration(milliseconds = 80), proc (t: Time): Msg = FrameMsg())

method init(m: App): Cmd = frame()

method update(m: App, msg: Msg): (Model, Cmd) =
  if msg of KeyPressMsg:
    let k = KeyPressMsg(msg).key
    if k.matchString("q", "ctrl+c"): return (Model(m), Quit)
    if k.code == KeyEnter: (m.bar.setPercent(0.0); return (Model(m), frame()))
  if msg of FrameMsg:
    if m.bar.percent < 1.0:
      m.bar.incrPercent(0.04)
      return (Model(m), frame())
  (Model(m), nil)

method view(m: App): View =
  newView("\n  " & m.bar.view & "\n\n  enter: restart · q: quit\n")

when isMainModule:
  discard newProgram(Model(App(bar: newProgress(50)))).run()
