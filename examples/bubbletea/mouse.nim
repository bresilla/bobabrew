## Port of bubbletea/examples/mouse — reports mouse events.

import ../../src/boba

type App = ref object of Model
  last: string

method update(m: App, msg: Msg): (Model, Cmd) =
  if msg of KeyPressMsg and KeyPressMsg(msg).key.matchString("q", "ctrl+c"):
    return (Model(m), Quit)
  if msg of MouseClickMsg:
    let mo = MouseClickMsg(msg).mouse
    m.last = "click " & $mo.button & " at " & $mo.x & "," & $mo.y
  elif msg of MouseReleaseMsg:
    let mo = MouseReleaseMsg(msg).mouse
    m.last = "release at " & $mo.x & "," & $mo.y
  elif msg of MouseWheelMsg:
    let mo = MouseWheelMsg(msg).mouse
    m.last = "wheel " & $mo.button
  elif msg of MouseMotionMsg:
    let mo = MouseMotionMsg(msg).mouse
    m.last = "motion at " & $mo.x & "," & $mo.y
  (Model(m), nil)

method view(m: App): View =
  result = newView("Do mouse stuff. (q to quit)\n\n" & m.last)
  result.mouseMode = mmAllMotion

when isMainModule:
  discard newProgram(Model(App(last: "(move or click the mouse)"))).run()
