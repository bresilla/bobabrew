## Port of bubbletea/examples/progress-download — a simulated download with a
## progress bar (the upstream example streams an HTTP body; here we simulate
## byte progress with a ticker so it runs without network access).

import std/times
import ../../src/boba
import ../../src/boba/bubbles

type
  ProgMsg = ref object of Msg
    ratio: float
  App = ref object of Model
    bar: Progress
    total: int
    got: int

proc step(total: int): Cmd =
  Tick(initDuration(milliseconds = 80), proc (t: Time): Msg =
    ProgMsg(ratio: 0.07))

method init(m: App): Cmd = step(m.total)

method update(m: App, msg: Msg): (Model, Cmd) =
  if msg of KeyPressMsg and KeyPressMsg(msg).key.matchString("q", "ctrl+c"):
    return (Model(m), Quit)
  if msg of ProgMsg:
    m.bar.incrPercent(ProgMsg(msg).ratio)
    if m.bar.percent >= 1.0:
      return (Model(m), Quit)
    return (Model(m), step(m.total))
  (Model(m), nil)

method view(m: App): View =
  newView("\n  Downloading...\n\n  " & m.bar.view & "\n\n  q to cancel\n")

when isMainModule:
  discard newProgram(Model(App(bar: newProgress(50), total: 100))).run()
