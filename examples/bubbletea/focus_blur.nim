## Port of bubbletea/examples/focus-blur — reports terminal focus changes.

import ../../src/boba

type App = ref object of Model
  focused: bool

method update(m: App, msg: Msg): (Model, Cmd) =
  if msg of KeyPressMsg and KeyPressMsg(msg).key.matchString("q", "ctrl+c"):
    return (Model(m), Quit)
  if msg of FocusMsg: m.focused = true
  elif msg of BlurMsg: m.focused = false
  (Model(m), nil)

method view(m: App): View =
  let state = if m.focused: "focused" else: "blurred"
  result = newView("Terminal is: " & state & "\n\n(switch focus; q to quit)")
  result.reportFocus = true

when isMainModule:
  discard newProgram(Model(App(focused: true))).run()
