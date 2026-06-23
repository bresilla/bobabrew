## The canonical Bubble Tea hello-world, in Nim.
## Run it, then press q / esc / ctrl+c to quit.

import ../src/boba

type Hello = ref object of Model

method view(m: Hello): View =
  newView("Hello, World!\n\nPress q to quit.")

method update(m: Hello, msg: Msg): (Model, Cmd) =
  if msg of KeyPressMsg:
    if KeyPressMsg(msg).key.matchString("q", "esc", "ctrl+c"):
      return (Model(m), Quit)
  (Model(m), nil)

when isMainModule:
  discard newProgram(Hello()).run()
