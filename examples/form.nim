## A tiny form: a text input plus a spinner, composed from Bubbles components.
## Type to edit, Enter to "submit" (shows the value), q/esc/ctrl+c to quit.

import ../src/boba
import ../src/boba/bubbles

type Form = ref object of Model
  input: TextInput
  spin: Spinner
  submitted: string

method init(m: Form): Cmd = m.spin.tickCmd()

method update(m: Form, msg: Msg): (Model, Cmd) =
  if msg of KeyPressMsg:
    let k = KeyPressMsg(msg).key
    if k.matchString("ctrl+c", "esc"):
      return (Model(m), Quit)
    if k.code == KeyEnter:
      m.submitted = m.input.value
      m.input.clear()
      return (Model(m), nil)
  let cmd = m.spin.update(msg)
  m.input.update(msg)
  (Model(m), cmd)

method view(m: Form): View =
  let title = newStyle().bold.foreground(basicColor(BrightMagenta)).render("Name?")
  var body = m.spin.view & " " & title & "\n\n" & m.input.view
  if m.submitted.len > 0:
    body.add "\n\nSubmitted: " & newStyle().foreground(basicColor(Green)).render(m.submitted)
  body.add "\n\n(enter submits · esc quits)"
  newStyle().padding(1, 2).withBorder(roundedBorder()).render(body).newView

when isMainModule:
  var f = Form(input: newTextInput(), spin: newSpinner())
  f.input.placeholder = "type here"
  discard newProgram(Model(f)).run()
