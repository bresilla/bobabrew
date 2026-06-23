## Port of bubbletea/examples/print-key — shows the string form of each key.

import ../../src/boba

type App = ref object of Model
  last: string

method update(m: App, msg: Msg): (Model, Cmd) =
  if msg of KeyPressMsg:
    let k = KeyPressMsg(msg).key
    if k.matchString("ctrl+c"): return (Model(m), Quit)
    m.last = $k & "  (keystroke: " & k.keystroke & ")"
  (Model(m), nil)

method view(m: App): View =
  newView("Press any key (ctrl+c to quit)\n\n" & m.last)

when isMainModule:
  discard newProgram(Model(App(last: "..."))).run()
