## Port of bubbletea/examples/dynamic-textarea — a text area that grows in height
## as you add lines.

import std/strutils
import ../../src/boba
import ../../src/boba/bubbles

type App = ref object of Model
  area: TextArea

method update(m: App, msg: Msg): (Model, Cmd) =
  if msg of KeyPressMsg and KeyPressMsg(msg).key.matchString("ctrl+c", "esc"):
    return (Model(m), Quit)
  m.area.update(msg)
  # Grow (or shrink) the visible height to fit the content, within bounds.
  let lineCount = m.area.value.split('\n').len
  m.area.height = max(3, min(lineCount + 1, 12))
  (Model(m), nil)

method view(m: App): View =
  newView("This text area grows as you type. (esc to quit)\n\n" &
          newStyle().withBorder(roundedBorder()).render(m.area.view))

when isMainModule:
  discard newProgram(Model(App(area: newTextArea(50, 3)))).run()
