## Port of bubbletea/examples/debounce — quits after a period of no input.

import std/times
import ../../src/boba

type
  TickMsg = ref object of Msg
    id: int
  App = ref object of Model
    id: int
    presses: int

proc debounceCmd(id: int): Cmd =
  Tick(initDuration(milliseconds = 600), proc (t: Time): Msg = TickMsg(id: id))

method update(m: App, msg: Msg): (Model, Cmd) =
  if msg of KeyPressMsg:
    if KeyPressMsg(msg).key.matchString("ctrl+c"): return (Model(m), Quit)
    m.presses.inc
    m.id.inc
    return (Model(m), debounceCmd(m.id))
  if msg of TickMsg:
    if TickMsg(msg).id == m.id:   # no newer keypress arrived
      return (Model(m), Quit)
  (Model(m), nil)

method view(m: App): View =
  newView("Key presses: " & $m.presses &
          "\n\nThis program quits 600ms after you stop typing.\n(ctrl+c to quit now)")

when isMainModule:
  discard newProgram(Model(App())).run()
