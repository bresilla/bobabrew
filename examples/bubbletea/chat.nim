## Port of bubbletea/examples/chat — a message history (viewport) with a text
## input below. Enter sends a message.

import std/strutils
import ../../src/boba
import ../../src/boba/bubbles

type App = ref object of Model
  vp: Viewport
  input: TextInput
  history: seq[string]

proc refresh(m: App) =
  m.vp.setContent(m.history.join("\n"))
  m.vp.gotoBottom()

method update(m: App, msg: Msg): (Model, Cmd) =
  if msg of KeyPressMsg:
    let k = KeyPressMsg(msg).key
    if k.matchString("ctrl+c", "esc"): return (Model(m), Quit)
    if k.code == KeyEnter:
      if m.input.value.len > 0:
        m.history.add newStyle().foreground(basicColor(BrightGreen)).render("You: ") & m.input.value
        m.input.clear()
        m.refresh()
      return (Model(m), nil)
  m.input.update(msg)
  (Model(m), nil)

method view(m: App): View =
  newView(m.vp.view & "\n" & repeat("─", 40) & "\n" & m.input.view)

when isMainModule:
  var app = App(vp: newViewport(40, 10), input: newTextInput())
  app.history = @["Welcome to the chat!", "Type a message and press enter."]
  app.refresh()
  discard newProgram(Model(app)).run()
