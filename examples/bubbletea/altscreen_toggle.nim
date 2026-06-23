## Port of bubbletea/examples/altscreen-toggle — space toggles the alt screen.

import std/options
import ../../src/boba

type App = ref object of Model
  alt: bool

method update(m: App, msg: Msg): (Model, Cmd) =
  if msg of KeyPressMsg:
    let k = KeyPressMsg(msg).key
    if k.matchString("q", "ctrl+c", "esc"): return (Model(m), Quit)
    if k.matchString("space", " "): m.alt = not m.alt
  (Model(m), nil)

method view(m: App): View =
  let body =
    if m.alt: "You're in the alternate screen buffer.\n\nspace: exit · q: quit"
    else: "You're in the normal buffer.\n\nspace: enter altscreen · q: quit"
  result = newView(body)
  result.altScreen = m.alt

when isMainModule:
  discard newProgram(Model(App())).run()
