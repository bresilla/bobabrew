## Port of bubbletea/examples/capability — detect a terminal capability. We
## probe the background color (a widely-supported OSC query) and report whether
## the terminal answered.

import ../../src/boba

type App = ref object of Model
  answered: bool
  dark: bool

method init(m: App): Cmd = RequestBackgroundColor

method update(m: App, msg: Msg): (Model, Cmd) =
  if msg of KeyPressMsg and KeyPressMsg(msg).key.matchString("q", "ctrl+c"):
    return (Model(m), Quit)
  if msg of BackgroundColorMsg:
    m.answered = true
    m.dark = BackgroundColorMsg(msg).isDark
  (Model(m), nil)

method view(m: App): View =
  let s =
    if not m.answered: "Querying terminal..."
    elif m.dark: "Terminal reports a DARK background."
    else: "Terminal reports a LIGHT background."
  newView(s & "\n\nq to quit.")

when isMainModule:
  discard newProgram(Model(App())).run()
