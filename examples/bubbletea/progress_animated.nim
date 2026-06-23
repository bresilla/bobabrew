## Port of bubbletea/examples/progress-animated — animates a bar to 100%.

import std/times
import ../../src/boba
import ../../src/boba/bubbles

type
  TickMsg = ref object of Msg
  App = ref object of Model
    bar: Progress

proc tickCmd(): Cmd =
  Tick(initDuration(milliseconds = 100), proc (t: Time): Msg = TickMsg())

method init(m: App): Cmd = tickCmd()

method update(m: App, msg: Msg): (Model, Cmd) =
  if msg of KeyPressMsg and KeyPressMsg(msg).key.matchString("q", "ctrl+c"):
    return (Model(m), Quit)
  if msg of TickMsg:
    if m.bar.percent >= 1.0: return (Model(m), Quit)
    m.bar.incrPercent(0.05)
    return (Model(m), tickCmd())
  (Model(m), nil)

method view(m: App): View =
  newView("\n  " & m.bar.view & "\n\n  q to quit\n")

when isMainModule:
  discard newProgram(Model(App(bar: newProgress(50)))).run()
