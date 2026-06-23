## Port of bubbletea/examples/spinner — a single spinner.

import ../../src/boba
import ../../src/boba/bubbles

type App = ref object of Model
  spin: Spinner

method init(m: App): Cmd = m.spin.tickCmd()

method update(m: App, msg: Msg): (Model, Cmd) =
  if msg of KeyPressMsg and KeyPressMsg(msg).key.matchString("q", "ctrl+c", "esc"):
    return (Model(m), Quit)
  let cmd = m.spin.update(msg)
  (Model(m), cmd)

method view(m: App): View =
  newView("\n  " & m.spin.view & " Loading forever...\n\n  q to quit\n")

when isMainModule:
  discard newProgram(Model(App(spin: newSpinner()))).run()
