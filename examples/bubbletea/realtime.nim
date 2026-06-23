## Port of bubbletea/examples/realtime — receive activity over time. The
## upstream example pushes from a goroutine via p.Send; here a recurring Tick
## stands in for the background producer so it runs anywhere.

import std/times
import ../../src/boba
import ../../src/boba/bubbles

type
  ActivityMsg = ref object of Msg
  App = ref object of Model
    spin: Spinner
    count: int

proc activityCmd(): Cmd =
  Tick(initDuration(milliseconds = 200), proc (t: Time): Msg = ActivityMsg())

method init(m: App): Cmd = Batch(m.spin.tickCmd(), activityCmd())

method update(m: App, msg: Msg): (Model, Cmd) =
  if msg of KeyPressMsg and KeyPressMsg(msg).key.matchString("q", "ctrl+c"):
    return (Model(m), Quit)
  if msg of ActivityMsg:
    m.count.inc
    if m.count >= 100: return (Model(m), Quit)
    return (Model(m), activityCmd())
  let cmd = m.spin.update(msg)
  (Model(m), cmd)

method view(m: App): View =
  newView("\n " & m.spin.view & " Received " & $m.count &
          " events.\n\n Press q to exit.\n")

when isMainModule:
  discard newProgram(Model(App(spin: newSpinner()))).run()
