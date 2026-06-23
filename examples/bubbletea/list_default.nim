## Port of bubbletea/examples/list-default — list with item descriptions.

import ../../src/boba
import ../../src/boba/bubbles

type App = ref object of Model
  list: List

method update(m: App, msg: Msg): (Model, Cmd) =
  if msg of KeyPressMsg and KeyPressMsg(msg).key.matchString("q", "ctrl+c", "esc"):
    return (Model(m), Quit)
  m.list.update(msg)
  (Model(m), nil)

method view(m: App): View =
  newView(newStyle().bold.render("Groceries") & "\n\n" & m.list.view &
          "\n\n↑/↓ move · q quit")

when isMainModule:
  let items = @[
    item("Bananas", "rich in potassium"),
    item("Coffee", "the lifeblood"),
    item("Oat milk", "for the coffee"),
    item("Bread", "the staff of life"),
    item("Cheese", "say cheese"),
  ]
  var l = newList(items, 12)
  l.showDesc = true
  discard newProgram(Model(App(list: l))).run()
