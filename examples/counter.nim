## A small counter: up/down (or k/j) to change, q to quit.

import std/strutils
import ../src/boba

type Counter = ref object of Model
  count: int

method view(m: Counter): View =
  newView("Count: " & $m.count & "\n\n↑/k up · ↓/j down · q quit")

method update(m: Counter, msg: Msg): (Model, Cmd) =
  if msg of KeyPressMsg:
    let k = KeyPressMsg(msg).key
    if k.matchString("q", "ctrl+c", "esc"):
      return (Model(m), Quit)
    if k.matchString("up", "k"):
      m.count.inc
    elif k.matchString("down", "j"):
      m.count.dec
  (Model(m), nil)

when isMainModule:
  discard newProgram(Counter()).run()
