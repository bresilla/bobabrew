## Port of bubbletea/examples/isbn-form — a small form with several fields.

import ../../src/boba
import ../../src/boba/bubbles

type App = ref object of Model
  fields: seq[TextInput]
  labels: seq[string]
  focus: int
  done: bool

proc syncFocus(m: App) =
  for i in 0 ..< m.fields.len: m.fields[i].focused = (i == m.focus)

method update(m: App, msg: Msg): (Model, Cmd) =
  if msg of KeyPressMsg:
    let k = KeyPressMsg(msg).key
    if k.matchString("ctrl+c", "esc"): return (Model(m), Quit)
    if k.code == KeyTab or k.code == KeyEnter:
      if m.focus == m.fields.high and k.code == KeyEnter:
        m.done = true; return (Model(m), Quit)
      m.focus = (m.focus + 1) mod m.fields.len; m.syncFocus(); return (Model(m), nil)
    if k.matchString("shift+tab"):
      m.focus = (m.focus - 1 + m.fields.len) mod m.fields.len; m.syncFocus(); return (Model(m), nil)
  m.fields[m.focus].update(msg)
  (Model(m), nil)

method view(m: App): View =
  var b = "Add a book:\n\n"
  for i, f in m.fields:
    b.add m.labels[i] & ": " & f.view & "\n"
  b.add "\ntab/enter: next · esc: quit"
  newView(b)

when isMainModule:
  var fields: seq[TextInput]
  for ph in ["978-3-16-148410-0", "The Go Programming Language", "Donovan & Kernighan"]:
    var t = newTextInput()
    t.prompt = ""; t.placeholder = ph; t.focused = false
    fields.add t
  fields[0].focused = true
  discard newProgram(Model(App(fields: fields, labels: @["ISBN", "Title", "Author"]))).run()
