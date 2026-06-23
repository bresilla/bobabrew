## Port of bubbletea/examples/cursor-style — cycle cursor shape and blink.

import std/options
import ../../src/boba

type App = ref object of Model
  shapes: seq[CursorShape]
  idx: int
  blink: bool

method update(m: App, msg: Msg): (Model, Cmd) =
  if msg of KeyPressMsg:
    let k = KeyPressMsg(msg).key
    if k.matchString("q", "ctrl+c"): return (Model(m), Quit)
    if k.matchString("right", "l"): m.idx = (m.idx + 1) mod m.shapes.len
    elif k.matchString("left", "h"): m.idx = (m.idx - 1 + m.shapes.len) mod m.shapes.len
    elif k.matchString("b"): m.blink = not m.blink
  (Model(m), nil)

method view(m: App): View =
  let names = ["block", "underline", "bar"]
  let prompt = "cursor here: "
  result = newView(prompt & "\n\nshape: " & names[m.idx] &
                   " · blink: " & $m.blink &
                   "\n←/→ shape · b blink · q quit")
  var c = newCursor(prompt.len, 0)
  c.shape = m.shapes[m.idx]
  c.blink = m.blink
  result.cursor = some(c)

when isMainModule:
  discard newProgram(Model(App(shapes: @[csBlock, csUnderline, csBar], blink: true))).run()
