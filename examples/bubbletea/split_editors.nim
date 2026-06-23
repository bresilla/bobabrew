## Port of bubbletea/examples/split-editors — two text areas, tab switches focus.

import ../../src/boba
import ../../src/boba/bubbles

type App = ref object of Model
  editors: seq[TextArea]
  focus: int

proc syncFocus(m: App) =
  for i in 0 ..< m.editors.len:
    m.editors[i].focused = (i == m.focus)

method update(m: App, msg: Msg): (Model, Cmd) =
  if msg of KeyPressMsg:
    let k = KeyPressMsg(msg).key
    if k.matchString("ctrl+c", "esc"): return (Model(m), Quit)
    if k.code == KeyTab:
      m.focus = (m.focus + 1) mod m.editors.len
      m.syncFocus()
      return (Model(m), nil)
  m.editors[m.focus].update(msg)
  (Model(m), nil)

method view(m: App): View =
  var panes: seq[string]
  for i, e in m.editors:
    let b = if i == m.focus: roundedBorder() else: normalBorder()
    panes.add newStyle().withBorder(b).render(e.view)
  newView(joinHorizontal(panes[0], "  ", panes[1]) & "\n\ntab: switch · esc: quit")

when isMainModule:
  discard newProgram(Model(App(editors: @[newTextArea(24, 8), newTextArea(24, 8)]))).run()
