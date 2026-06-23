## Port of bubbletea/examples/exec — run an external editor, then resume.

import std/os
import ../../src/boba

type
  EditorDone = ref object of Msg
    code: int
  App = ref object of Model
    note: string

method update(m: App, msg: Msg): (Model, Cmd) =
  if msg of KeyPressMsg:
    let k = KeyPressMsg(msg).key
    if k.matchString("q", "ctrl+c"): return (Model(m), Quit)
    if k.matchString("e"):
      let editor = if getEnv("EDITOR").len > 0: getEnv("EDITOR") else: "vi"
      return (Model(m), ExecProcess(editor, @[],
        proc (c: int): Msg = EditorDone(code: c)))
  if msg of EditorDone:
    m.note = "Editor exited with code " & $EditorDone(msg).code
  (Model(m), nil)

method view(m: App): View =
  newView("Press e to open $EDITOR, q to quit.\n\n" & m.note)

when isMainModule:
  discard newProgram(Model(App())).run()
