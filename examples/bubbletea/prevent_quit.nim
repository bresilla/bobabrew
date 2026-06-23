## Port of bubbletea/examples/prevent-quit — confirm before quitting when there
## are unsaved changes.

import ../../src/boba
import ../../src/boba/bubbles

type App = ref object of Model
  input: TextInput
  hasChanges: bool
  asking: bool

method update(m: App, msg: Msg): (Model, Cmd) =
  if msg of KeyPressMsg:
    let k = KeyPressMsg(msg).key
    if m.asking:
      if k.matchString("y"): return (Model(m), Quit)
      m.asking = false
      return (Model(m), nil)
    if k.matchString("ctrl+c", "esc"):
      if m.hasChanges: (m.asking = true; return (Model(m), nil))
      return (Model(m), Quit)
    m.input.update(msg)
    m.hasChanges = m.input.value.len > 0
    return (Model(m), nil)
  (Model(m), nil)

method view(m: App): View =
  if m.asking:
    return newView("You have unsaved changes. Quit anyway? (y/n)")
  newView("Type something, then try to quit with esc.\n\n" & m.input.view)

when isMainModule:
  discard newProgram(Model(App(input: newTextInput()))).run()
