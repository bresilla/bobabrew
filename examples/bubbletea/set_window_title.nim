## Port of bubbletea/examples/set-window-title — sets the terminal window title.

import ../../src/boba

type App = ref object of Model

method update(m: App, msg: Msg): (Model, Cmd) =
  if msg of KeyPressMsg and KeyPressMsg(msg).key.matchString("q", "ctrl+c"):
    return (Model(m), Quit)
  (Model(m), nil)

method view(m: App): View =
  result = newView("This program sets the window title to 'Bobabrew'.\n\nq to quit.")
  result.windowTitle = "Bobabrew"

when isMainModule:
  discard newProgram(Model(App())).run()
