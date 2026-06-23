## Port of bubbletea/examples/eyes — googly eyes whose pupils follow the mouse.

import ../../src/boba

type App = ref object of Model
  mx, my: int
  w, h: int

method update(m: App, msg: Msg): (Model, Cmd) =
  if msg of KeyPressMsg and KeyPressMsg(msg).key.matchString("q", "ctrl+c"):
    return (Model(m), Quit)
  if msg of WindowSizeMsg:
    m.w = WindowSizeMsg(msg).width; m.h = WindowSizeMsg(msg).height
  elif msg of MouseMotionMsg:
    m.mx = MouseMotionMsg(msg).mouse.x; m.my = MouseMotionMsg(msg).mouse.y
  elif msg of MouseClickMsg:
    m.mx = MouseClickMsg(msg).mouse.x; m.my = MouseClickMsg(msg).mouse.y
  (Model(m), nil)

proc pupil(cx, cy, mx, my: int): string =
  ## Pick a pupil glyph pointing roughly toward (mx,my) from eye center.
  let dx = mx - cx
  let dy = my - cy
  if dx == 0 and dy == 0: return "o"
  if abs(dx) > abs(dy) * 2: return (if dx < 0: "(• )" else: "( •)")
  if abs(dy) > abs(dx) * 2: return (if dy < 0: "(˙)" else: "(.)")
  return (if dx < 0: "(•.)" else: "(.•)")

method view(m: App): View =
  let cx = m.w div 2
  let cy = m.h div 2
  let p = pupil(cx, cy, m.mx, m.my)
  result = newView("Move the mouse. q to quit.\n\n    " & p & "   " & p & "\n")
  result.mouseMode = mmAllMotion

when isMainModule:
  discard newProgram(Model(App(w: 80, h: 24))).run()
