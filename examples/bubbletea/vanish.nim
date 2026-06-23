## Port of bubbletea/examples/vanish — clears its output on quit so the program
## leaves no trace in the scrollback.

import ../../src/boba

type App = ref object of Model

method update(m: App, msg: Msg): (Model, Cmd) =
  if msg of KeyPressMsg and KeyPressMsg(msg).key.matchString("q", "ctrl+c", "esc"):
    # Clear the screen, then quit — nothing remains behind.
    let clear: Cmd = proc (): Msg = ClearScreen()
    let q: Cmd = proc (): Msg = Quit()
    return (Model(m), Sequence(clear, q))
  (Model(m), nil)

method view(m: App): View =
  newView("Now you see me.\n\nPress q and I'll vanish without a trace.")

when isMainModule:
  discard newProgram(Model(App())).run()
