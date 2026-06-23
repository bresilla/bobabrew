## Port of bubbletea/examples/sequence — run commands one after another.

import ../../src/boba

type App = ref object of Model

method init(m: App): Cmd =
  let quitCmd: Cmd = proc (): Msg = Quit()
  Sequence(Println("A"), Println("B"), Println("C"), quitCmd)

method update(m: App, msg: Msg): (Model, Cmd) = (Model(m), nil)
method view(m: App): View = newView("")

when isMainModule:
  discard newProgram(Model(App())).run()
