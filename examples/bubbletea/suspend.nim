## Port of bubbletea/examples/suspend — ctrl+z suspends, fg resumes.

import ../../src/boba

type App = ref object of Model
  resumes: int

method update(m: App, msg: Msg): (Model, Cmd) =
  if msg of KeyPressMsg:
    let k = KeyPressMsg(msg).key
    if k.matchString("q", "ctrl+c"): return (Model(m), Quit)
    if k.matchString("ctrl+z"): return (Model(m), proc (): Msg = Suspend())
  if msg of ResumeMsg: m.resumes.inc
  (Model(m), nil)

method view(m: App): View =
  newView("ctrl+z to suspend, fg to resume.\nResumed " & $m.resumes &
          " time(s).\n\nq to quit.")

when isMainModule:
  discard newProgram(Model(App())).run()
