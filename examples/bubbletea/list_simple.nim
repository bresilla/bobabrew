## Port of bubbletea/examples/list-simple.

import ../../src/boba
import ../../src/boba/bubbles

type App = ref object of Model
  list: List
  chosen: string

method update(m: App, msg: Msg): (Model, Cmd) =
  if msg of KeyPressMsg:
    let k = KeyPressMsg(msg).key
    if k.matchString("q", "ctrl+c", "esc"): return (Model(m), Quit)
    if k.code == KeyEnter:
      m.chosen = m.list.selected.title
      return (Model(m), Quit)
  m.list.update(msg)
  (Model(m), nil)

method view(m: App): View =
  newView("What do you want for dinner?\n\n" & m.list.view &
          "\n\n↑/↓ move · enter choose · q quit")

when isMainModule:
  let items = @[
    item("Ramen"), item("Tomato Soup"), item("Hummus"),
    item("Sushi"), item("Tacos"), item("Gyros"),
  ]
  discard newProgram(Model(App(list: newList(items, 6)))).run()
