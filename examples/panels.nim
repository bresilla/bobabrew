## Two bordered panels side by side, styled text, live counter.
## ←/→ move focus, ↑/↓ change the active panel's value, q quits.

import std/strutils
import ../src/boba

type Panels = ref object of Model
  left, right: int
  focusLeft: bool

proc panel(title: string, value: int, focused: bool): string =
  let header =
    if focused: newStyle().bold.foreground(basicColor(BrightGreen)).render(title)
    else: newStyle().faint.render(title)
  let body = header & "\n\nvalue: " & $value
  let b = if focused: roundedBorder() else: normalBorder()
  newStyle().padding(0, 1).withBorder(b).render(body)

method view(m: Panels): View =
  let row = joinHorizontal(
    panel("LEFT", m.left, m.focusLeft),
    "  ",
    panel("RIGHT", m.right, not m.focusLeft))
  newView(row & "\n\n←/→ focus · ↑/↓ change · q quit")

method update(m: Panels, msg: Msg): (Model, Cmd) =
  if msg of KeyPressMsg:
    let k = KeyPressMsg(msg).key
    if k.matchString("q", "ctrl+c", "esc"): return (Model(m), Quit)
    if k.matchString("left", "h"): m.focusLeft = true
    elif k.matchString("right", "l"): m.focusLeft = false
    elif k.matchString("up", "k"):
      if m.focusLeft: m.left.inc else: m.right.inc
    elif k.matchString("down", "j"):
      if m.focusLeft: m.left.dec else: m.right.dec
  (Model(m), nil)

when isMainModule:
  discard newProgram(Panels(focusLeft: true)).run()
