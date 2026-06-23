## Port of bubbletea/examples/table.

import ../../src/boba
import ../../src/boba/bubbles

type App = ref object of Model
  tbl: Table
  chosen: string

method update(m: App, msg: Msg): (Model, Cmd) =
  if msg of KeyPressMsg:
    let k = KeyPressMsg(msg).key
    if k.matchString("q", "ctrl+c", "esc"): return (Model(m), Quit)
    if k.code == KeyEnter:
      let r = m.tbl.selectedRow
      if r.len > 0: m.chosen = r[0]
  m.tbl.update(msg)
  (Model(m), nil)

method view(m: App): View =
  var b = m.tbl.view & "\n\n↑/↓ move · enter select · q quit"
  if m.chosen.len > 0: b.add "\nYou chose: " & m.chosen
  newView(b)

when isMainModule:
  let cols = @[column("City", 14), column("Country", 14), column("Pop.", 10)]
  let rows = @[
    @["Tokyo", "Japan", "37M"],
    @["Delhi", "India", "32M"],
    @["Shanghai", "China", "29M"],
    @["São Paulo", "Brazil", "22M"],
    @["Mexico City", "Mexico", "22M"],
    @["Cairo", "Egypt", "21M"],
  ]
  discard newProgram(Model(App(tbl: newTable(cols, rows, 6)))).run()
