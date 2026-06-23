## Port of bubbletea/examples/pager — scroll through long content in a viewport.

import std/strutils
import ../../src/boba
import ../../src/boba/bubbles

type App = ref object of Model
  vp: Viewport

method update(m: App, msg: Msg): (Model, Cmd) =
  if msg of KeyPressMsg and KeyPressMsg(msg).key.matchString("q", "ctrl+c", "esc"):
    return (Model(m), Quit)
  m.vp.update(msg)
  (Model(m), nil)

method view(m: App): View =
  let pct = int(m.vp.scrollPercent * 100)
  let header = newStyle().bold.render("── Pager ──")
  let footer = "↑/↓ scroll · " & $pct & "% · q quit"
  newView(header & "\n" & m.vp.view & "\n" & footer)

when isMainModule:
  var lines: seq[string]
  for i in 1 .. 80: lines.add "Line " & $i & ": the quick brown fox jumps over the lazy dog."
  var vp = newViewport(70, 18)
  vp.setContent(lines.join("\n"))
  discard newProgram(Model(App(vp: vp))).run()
