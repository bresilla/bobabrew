## Port of bubbletea/examples/tabs — a tab bar with per-tab content.

import std/strutils
import ../../src/boba

type App = ref object of Model
  tabs: seq[string]
  content: seq[string]
  active: int

method update(m: App, msg: Msg): (Model, Cmd) =
  if msg of KeyPressMsg:
    let k = KeyPressMsg(msg).key
    if k.matchString("q", "ctrl+c", "esc"): return (Model(m), Quit)
    if k.matchString("right", "l", "tab"): m.active = (m.active + 1) mod m.tabs.len
    elif k.matchString("left", "h"): m.active = (m.active - 1 + m.tabs.len) mod m.tabs.len
  (Model(m), nil)

method view(m: App): View =
  var headers: seq[string]
  for i, t in m.tabs:
    if i == m.active:
      headers.add newStyle().bold.foreground(basicColor(BrightMagenta)).render(" " & t & " ")
    else:
      headers.add newStyle().faint.render(" " & t & " ")
  let bar = headers.join("│")
  let body = newStyle().padding(1, 2).withBorder(roundedBorder()).render(m.content[m.active])
  newView(bar & "\n" & body & "\n\n←/→ switch · q quit")

when isMainModule:
  let tabs = @["Lip Gloss", "Blush", "Eye Shadow", "Mascara", "Foundation"]
  var content: seq[string]
  for t in tabs: content.add "This is the " & t & " tab.\nEnjoy your stay."
  discard newProgram(Model(App(tabs: tabs, content: content))).run()
