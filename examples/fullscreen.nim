## Alt-screen (full-window) example: a centered, bordered clock that ticks every
## second. Demonstrates AltScreen + Tick + cell-level diff rendering.

import std/[times, strutils]
import ../src/boba

type Clock = ref object of Model
  now: string
  w, h: int

proc tickCmd(): Cmd =
  Tick(initDuration(seconds = 1), proc (t: Time): Msg = WindowSizeMsg())
  # NB: we reuse a Tick that just nudges a repaint; the time is read in view().

method init(m: Clock): Cmd = tickCmd()

method update(m: Clock, msg: Msg): (Model, Cmd) =
  if msg of KeyPressMsg and KeyPressMsg(msg).key.matchString("q", "ctrl+c", "esc"):
    return (Model(m), Quit)
  if msg of WindowSizeMsg:
    let ws = WindowSizeMsg(msg)
    if ws.width > 0: m.w = ws.width
    if ws.height > 0: m.h = ws.height
    return (Model(m), tickCmd())
  (Model(m), nil)

method view(m: Clock): View =
  let face = roundedBorder().box(" " & now().format("HH:mm:ss") & " ")
  # Vertically + horizontally center within the window.
  let lines = face.split('\n')
  let padTop = max((m.h - lines.len) div 2, 0)
  let padLeft = max((m.w - 10) div 2, 0)
  var body = "\n".repeat(padTop)
  for ln in lines:
    body.add spaces(padLeft) & ln & "\n"
  var v = newView(body & "\n(press q to quit)")
  v.altScreen = true
  v

when isMainModule:
  discard newProgram(Clock(w: 80, h: 24)).run()
