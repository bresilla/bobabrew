## Port of bubbletea/examples/list-fancy — styled list with a title bar.

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
  let title = newStyle()
    .foreground(trueColor(255, 255, 255))
    .background(trueColor(170, 60, 200))
    .padding(0, 1).render("✨ My Fave Things")
  newView(title & "\n\n" & m.list.view & "\n\n↑/↓ move · q quit")

when isMainModule:
  let items = @[
    item("Raindrops on roses", "and whiskers on kittens"),
    item("Bright copper kettles", "and warm woolen mittens"),
    item("Brown paper packages", "tied up with strings"),
    item("Cream colored ponies", "and crisp apple strudels"),
  ]
  var l = newList(items, 12)
  l.showDesc = true
  discard newProgram(Model(App(list: l))).run()
