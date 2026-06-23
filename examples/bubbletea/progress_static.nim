## Port of bubbletea/examples/progress-static — adjust a bar with the keyboard.

import ../../src/boba
import ../../src/boba/bubbles

type App = ref object of Model
  bar: Progress

method update(m: App, msg: Msg): (Model, Cmd) =
  if msg of KeyPressMsg:
    let k = KeyPressMsg(msg).key
    if k.matchString("q", "ctrl+c"): return (Model(m), Quit)
    if k.matchString("right", "l"): m.bar.incrPercent(0.1)
    elif k.matchString("left", "h"): m.bar.incrPercent(-0.1)
  (Model(m), nil)

method view(m: App): View =
  newView("\n  " & m.bar.view & "\n\n  ←/→ adjust · q quit\n")

when isMainModule:
  var b = newProgress(40)
  b.setPercent(0.5)
  discard newProgram(Model(App(bar: b))).run()
