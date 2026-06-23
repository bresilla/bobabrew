## Port of bubbletea/examples/help — short/full help, toggled with '?'.

import ../../src/boba
import ../../src/boba/bubbles

type App = ref object of Model
  full: bool
  bindings: seq[Binding]

method update(m: App, msg: Msg): (Model, Cmd) =
  if msg of KeyPressMsg:
    let k = KeyPressMsg(msg).key
    if k.matchString("q", "ctrl+c", "esc"): return (Model(m), Quit)
    if k.matchString("?"): m.full = not m.full
  (Model(m), nil)

method view(m: App): View =
  let help =
    if m.full: fullHelp([m.bindings])
    else: shortHelp(m.bindings)
  newView("Help component demo.\n\nPress ? to toggle full help.\n\n" & help)

when isMainModule:
  let b = @[
    newBinding(@["up", "k"], "↑/k", "move up"),
    newBinding(@["down", "j"], "↓/j", "move down"),
    newBinding(@["?"], "?", "toggle help"),
    newBinding(@["q"], "q", "quit"),
  ]
  discard newProgram(Model(App(bindings: b))).run()
