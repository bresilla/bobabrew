## Port of bubbletea/examples/composable-views — two components (spinner + timer)
## composed side by side; tab focuses one.

import std/times
import ../../src/boba
import ../../src/boba/bubbles

type App = ref object of Model
  spin: Spinner
  timer: Timer
  focusTimer: bool

method init(m: App): Cmd = Batch(m.spin.tickCmd(), m.timer.start())

method update(m: App, msg: Msg): (Model, Cmd) =
  if msg of KeyPressMsg:
    let k = KeyPressMsg(msg).key
    if k.matchString("q", "ctrl+c"): return (Model(m), Quit)
    if k.code == KeyTab: m.focusTimer = not m.focusTimer
  var c1 = m.spin.update(msg)
  var c2 = m.timer.update(msg)
  (Model(m), Batch(c1, c2))

method view(m: App): View =
  let left = newStyle().padding(1, 2).withBorder(
    if not m.focusTimer: roundedBorder() else: normalBorder())
    .render("Spinner\n\n" & m.spin.view & " working")
  let right = newStyle().padding(1, 2).withBorder(
    if m.focusTimer: roundedBorder() else: normalBorder())
    .render("Timer\n\n" & m.timer.view)
  newView(joinHorizontal(left, "  ", right) & "\n\ntab: focus · q: quit")

when isMainModule:
  discard newProgram(Model(App(
    spin: newSpinner(),
    timer: newTimer(initDuration(seconds = 60))))).run()
