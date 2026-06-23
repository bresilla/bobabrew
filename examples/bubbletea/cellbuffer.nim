## Port of bubbletea/examples/cellbuffer — draw to a cell buffer and animate.
## A character bounces around inside a box, redrawn each frame.

import std/times
import ../../src/boba
import ../../src/boba/uv/buffer
import ../../src/boba/uv/cell

type
  FrameMsg = ref object of Msg
  App = ref object of Model
    w, h, x, y, dx, dy: int

proc frame(): Cmd = Tick(initDuration(milliseconds = 60), proc (t: Time): Msg = FrameMsg())

method init(m: App): Cmd = frame()

method update(m: App, msg: Msg): (Model, Cmd) =
  if msg of KeyPressMsg and KeyPressMsg(msg).key.matchString("q", "ctrl+c"):
    return (Model(m), Quit)
  if msg of FrameMsg:
    m.x += m.dx; m.y += m.dy
    if m.x <= 0 or m.x >= m.w - 1: m.dx = -m.dx
    if m.y <= 0 or m.y >= m.h - 1: m.dy = -m.dy
    m.x = max(0, min(m.w - 1, m.x))
    m.y = max(0, min(m.h - 1, m.y))
    return (Model(m), frame())
  (Model(m), nil)

method view(m: App): View =
  var b = newBuffer(m.w, m.h)
  b.setCell(m.x, m.y, newCell("●"))
  # buffer.render joins rows with CRLF; the renderer is happy with that.
  newView(b.render & "\n\nq to quit")

when isMainModule:
  discard newProgram(Model(App(w: 40, h: 12, x: 5, y: 3, dx: 1, dy: 1))).run()
