## Port of bubbletea/examples/textarea.

import ../../src/boba
import ../../src/boba/bubbles

type App = ref object of Model
  area: TextArea

method update(m: App, msg: Msg): (Model, Cmd) =
  if msg of KeyPressMsg:
    let k = KeyPressMsg(msg).key
    if k.matchString("ctrl+c", "esc"): return (Model(m), Quit)
  m.area.update(msg)
  (Model(m), nil)

method view(m: App): View =
  newView("Tell me a story.\n\n" & m.area.view & "\n\n(esc to quit)")

when isMainModule:
  discard newProgram(Model(App(area: newTextArea(50, 6)))).run()
