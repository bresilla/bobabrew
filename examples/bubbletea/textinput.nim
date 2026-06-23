## Port of bubbletea/examples/textinput.

import ../../src/boba
import ../../src/boba/bubbles

type App = ref object of Model
  input: TextInput

method update(m: App, msg: Msg): (Model, Cmd) =
  if msg of KeyPressMsg:
    let k = KeyPressMsg(msg).key
    if k.matchString("ctrl+c", "esc") or k.code == KeyEnter:
      return (Model(m), Quit)
  m.input.update(msg)
  (Model(m), nil)

method view(m: App): View =
  newView("What's your favorite Pokémon?\n\n" & m.input.view &
          "\n\n(esc to quit)")

when isMainModule:
  var ti = newTextInput()
  ti.placeholder = "Pikachu"
  discard newProgram(Model(App(input: ti))).run()
