## Port of bubbletea/examples/canvas — draw shapes into a cell buffer.

import ../../src/boba
import ../../src/boba/uv/buffer
import ../../src/boba/uv/cell

type App = ref object of Model

method update(m: App, msg: Msg): (Model, Cmd) =
  if msg of KeyPressMsg and KeyPressMsg(msg).key.matchString("q", "ctrl+c"):
    return (Model(m), Quit)
  (Model(m), nil)

method view(m: App): View =
  const w = 30
  const h = 12
  var b = newBuffer(w, h)
  # Border.
  for x in 0 ..< w:
    b.setCell(x, 0, newCell("─"))
    b.setCell(x, h - 1, newCell("─"))
  for y in 0 ..< h:
    b.setCell(0, y, newCell("│"))
    b.setCell(w - 1, y, newCell("│"))
  b.setCell(0, 0, newCell("┌")); b.setCell(w - 1, 0, newCell("┐"))
  b.setCell(0, h - 1, newCell("└")); b.setCell(w - 1, h - 1, newCell("┘"))
  # Diagonal.
  for i in 1 ..< min(w, h) - 1:
    b.setCell(i, i, newCell("╲"))
  newView(b.render & "\n\nq to quit")

when isMainModule:
  discard newProgram(Model(App())).run()
