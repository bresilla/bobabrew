## Port of bubbletea/examples/set-terminal-color — cycles the terminal
## foreground/background colors.

import ../../src/boba

type App = ref object of Model
  idx: int

const palette = [
  (trueColor(0, 0, 0), trueColor(255, 255, 255)),
  (trueColor(255, 255, 255), trueColor(30, 30, 60)),
  (trueColor(0, 255, 0), trueColor(0, 0, 0)),
]

method update(m: App, msg: Msg): (Model, Cmd) =
  if msg of KeyPressMsg:
    let k = KeyPressMsg(msg).key
    if k.matchString("q", "ctrl+c"): return (Model(m), Quit)
    if k.matchString("space", " "): m.idx = (m.idx + 1) mod palette.len
  (Model(m), nil)

method view(m: App): View =
  result = newView("Press space to cycle terminal colors. q to quit.")
  result.foregroundColor = palette[m.idx][0]
  result.backgroundColor = palette[m.idx][1]

when isMainModule:
  discard newProgram(Model(App())).run()
