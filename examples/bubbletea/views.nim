## Port of bubbletea/examples/views — switch between multiple views (a menu, a
## "working" view with a spinner, and a done view).

import std/times
import ../../src/boba
import ../../src/boba/bubbles

type
  Screen = enum scMenu, scWorking, scDone
  DoneMsg = ref object of Msg
  App = ref object of Model
    screen: Screen
    cursor: int
    choices: seq[string]
    spin: Spinner
    chosen: string

method update(m: App, msg: Msg): (Model, Cmd) =
  if msg of KeyPressMsg:
    let k = KeyPressMsg(msg).key
    if k.matchString("q", "ctrl+c"): return (Model(m), Quit)
    case m.screen
    of scMenu:
      if k.matchString("up", "k"): m.cursor = max(0, m.cursor - 1)
      elif k.matchString("down", "j"): m.cursor = min(m.choices.high, m.cursor + 1)
      elif k.code == KeyEnter:
        m.chosen = m.choices[m.cursor]
        m.screen = scWorking
        return (Model(m), Batch(m.spin.tickCmd(),
          Tick(initDuration(seconds = 2), proc (t: Time): Msg = DoneMsg())))
    of scDone:
      return (Model(m), Quit)
    else: discard
  if msg of DoneMsg:
    m.screen = scDone
    return (Model(m), nil)
  if m.screen == scWorking:
    return (Model(m), m.spin.update(msg))
  (Model(m), nil)

method view(m: App): View =
  case m.screen
  of scMenu:
    var b = "Pick a task:\n\n"
    for i, c in m.choices:
      b.add (if i == m.cursor: "> " else: "  ") & c & "\n"
    b.add "\n↑/↓ · enter · q"
    newView(b)
  of scWorking:
    newView(m.spin.view & " Working on '" & m.chosen & "'...")
  of scDone:
    newView("Done with '" & m.chosen & "'!\n\nPress any key to exit.")

when isMainModule:
  discard newProgram(Model(App(choices: @["Build", "Test", "Deploy"], spin: newSpinner()))).run()
