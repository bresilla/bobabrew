## Port of bubbletea/examples/pipe — read piped stdin, then run the TUI on the
## controlling terminal. Try:  echo "hello from a pipe" | nim c -r pipe.nim
## The piped text pre-fills an editable text area.

import std/[strutils, syncio]
import ../../src/boba
import ../../src/boba/bubbles
import ../../src/boba/term/raw

type App = ref object of Model
  area: TextArea

method update(m: App, msg: Msg): (Model, Cmd) =
  if msg of KeyPressMsg and KeyPressMsg(msg).key.matchString("ctrl+c", "esc"):
    return (Model(m), Quit)
  m.area.update(msg)
  (Model(m), nil)

method view(m: App): View =
  newView("Piped input (edit it; esc to quit):\n\n" &
          newStyle().withBorder(roundedBorder()).render(m.area.view))

when isMainModule:
  var content = ""
  if not isTerminal(0):
    content = readAll(stdin)          # consume the pipe
  var area = newTextArea(60, 10)
  if content.strip.len > 0: area.setValue(content.strip)

  # Interact via the controlling terminal, since stdin was the pipe.
  var input = stdin
  try: input = open("/dev/tty", fmRead)
  except CatchableError: discard

  discard newProgram(Model(App(area: area)), withInput(input)).run()
