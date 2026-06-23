## Port of bubbletea/examples/textinputs — multiple inputs, tab to switch focus.

import ../../src/boba
import ../../src/boba/bubbles

type App = ref object of Model
  inputs: seq[TextInput]
  focus: int

proc syncFocus(m: App) =
  for i in 0 ..< m.inputs.len:
    m.inputs[i].focused = (i == m.focus)

method update(m: App, msg: Msg): (Model, Cmd) =
  if msg of KeyPressMsg:
    let k = KeyPressMsg(msg).key
    if k.matchString("ctrl+c", "esc"): return (Model(m), Quit)
    if k.code == KeyTab or k.code == KeyEnter or k.matchString("down"):
      m.focus = (m.focus + 1) mod m.inputs.len
      m.syncFocus()
      return (Model(m), nil)
    if k.matchString("shift+tab", "up"):
      m.focus = (m.focus - 1 + m.inputs.len) mod m.inputs.len
      m.syncFocus()
      return (Model(m), nil)
  m.inputs[m.focus].update(msg)
  (Model(m), nil)

method view(m: App): View =
  var b = "Enter your details:\n\n"
  let labels = ["Name", "Email", "Password"]
  for i, ti in m.inputs:
    b.add labels[i] & ": " & ti.view & "\n"
  b.add "\ntab: next · shift+tab: prev · esc: quit"
  newView(b)

when isMainModule:
  var inputs: seq[TextInput]
  for ph in ["Jane Doe", "jane@example.com", "••••••"]:
    var ti = newTextInput()
    ti.prompt = ""
    ti.placeholder = ph
    ti.focused = false
    inputs.add ti
  inputs[0].focused = true
  discard newProgram(Model(App(inputs: inputs, focus: 0))).run()
