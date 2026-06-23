## Port of bubbletea/examples/tui-daemon-combo — a spinner, a progress bar, and
## a scrolling activity log driven by a background ticker.

import std/[times, strutils]
import ../../src/boba
import ../../src/boba/bubbles

type
  WorkMsg = ref object of Msg
  App = ref object of Model
    spin: Spinner
    bar: Progress
    log: seq[string]
    n: int

proc work(): Cmd = Tick(initDuration(milliseconds = 250), proc (t: Time): Msg = WorkMsg())

method init(m: App): Cmd = Batch(m.spin.tickCmd(), work())

method update(m: App, msg: Msg): (Model, Cmd) =
  if msg of KeyPressMsg and KeyPressMsg(msg).key.matchString("q", "ctrl+c"):
    return (Model(m), Quit)
  if msg of WorkMsg:
    m.n.inc
    m.bar.setPercent(m.n / 20)
    m.log.add "task #" & $m.n & " done"
    if m.log.len > 6: m.log = m.log[^6 .. ^1]
    if m.n >= 20: return (Model(m), Quit)
    return (Model(m), work())
  let cmd = m.spin.update(msg)
  (Model(m), cmd)

method view(m: App): View =
  newView(m.spin.view & " daemon running\n\n" & m.bar.view & "\n\n" &
          m.log.join("\n") & "\n\nq to quit")

when isMainModule:
  discard newProgram(Model(App(spin: newSpinner(), bar: newProgress(40)))).run()
