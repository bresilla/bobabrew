## Port of bubbletea/examples/window-size — shows terminal size; 'r' re-queries.

import ../../src/boba

type App = ref object of Model
  w, h: int

method update(m: App, msg: Msg): (Model, Cmd) =
  if msg of KeyPressMsg:
    let k = KeyPressMsg(msg).key
    if k.matchString("q", "ctrl+c"): return (Model(m), Quit)
    if k.matchString("r"): return (Model(m), RequestWindowSize)
  elif msg of WindowSizeMsg:
    m.w = WindowSizeMsg(msg).width
    m.h = WindowSizeMsg(msg).height
  (Model(m), nil)

method view(m: App): View =
  newView("Window size: " & $m.w & "x" & $m.h &
          "\n\nResize the window, or press r to re-query. q to quit.")

when isMainModule:
  discard newProgram(Model(App())).run()
