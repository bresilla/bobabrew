## Port of bubbletea/examples/simple — counts down from 5 and exits.

import std/times
import ../../src/boba

type
  TickMsg = ref object of Msg
  Simple = ref object of Model
    secs: int

proc tickCmd(): Cmd =
  Tick(initDuration(seconds = 1), proc (t: Time): Msg = TickMsg())

method init(m: Simple): Cmd = tickCmd()

method update(m: Simple, msg: Msg): (Model, Cmd) =
  if msg of KeyPressMsg: return (Model(m), Quit)
  if msg of TickMsg:
    m.secs.dec
    if m.secs <= 0: return (Model(m), Quit)
    return (Model(m), tickCmd())
  (Model(m), nil)

method view(m: Simple): View =
  newView("Hi. This program will exit in " & $m.secs &
          " seconds.\n\nTo quit sooner press any key.\n")

when isMainModule:
  discard newProgram(Model(Simple(secs: 5))).run()
