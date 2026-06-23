## Port of bubbletea/examples/table-resize — adjust the first column's width.

import ../../src/boba
import ../../src/boba/bubbles

type App = ref object of Model
  tbl: Table

method update(m: App, msg: Msg): (Model, Cmd) =
  if msg of KeyPressMsg:
    let k = KeyPressMsg(msg).key
    if k.matchString("q", "ctrl+c", "esc"): return (Model(m), Quit)
    if k.matchString("+", "="): m.tbl.columns[0].width.inc
    elif k.matchString("-", "_"): m.tbl.columns[0].width = max(3, m.tbl.columns[0].width - 1)
  m.tbl.update(msg)
  (Model(m), nil)

method view(m: App): View =
  newView(m.tbl.view & "\n\n+/- resize col 1 · ↑/↓ move · q quit")

when isMainModule:
  let cols = @[column("Name", 12), column("Role", 16)]
  let rows = @[
    @["Ada Lovelace", "Mathematician"],
    @["Alan Turing", "Computer Scientist"],
    @["Grace Hopper", "Rear Admiral"],
    @["Katherine Johnson", "Mathematician"],
  ]
  discard newProgram(Model(App(tbl: newTable(cols, rows, 4)))).run()
