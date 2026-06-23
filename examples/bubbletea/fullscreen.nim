## Port of bubbletea/examples/fullscreen — alt screen, counts down from 5.

import std/times
import ../../src/boba

type
  TickMsg = ref object of Msg
  App = ref object of Model
    secs: int

proc tickCmd(): Cmd =
  Tick(initDuration(seconds = 1), proc (t: Time): Msg = TickMsg())

method init(m: App): Cmd = tickCmd()

method update(m: App, msg: Msg): (Model, Cmd) =
  if msg of KeyPressMsg and KeyPressMsg(msg).key.matchString("q", "esc", "ctrl+c"):
    return (Model(m), Quit)
  if msg of TickMsg:
    m.secs.dec
    if m.secs <= 0: return (Model(m), Quit)
    return (Model(m), tickCmd())
  (Model(m), nil)

method view(m: App): View =
  result = newView("\n\n     Hi. This program will exit in " & $m.secs & " seconds...")
  result.altScreen = true

when isMainModule:
  discard newProgram(Model(App(secs: 5))).run()
