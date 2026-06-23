## Port of bubbletea/examples/result — choose from a menu, print the result.

import ../../src/boba

type App = ref object of Model
  choices: seq[string]
  cursor: int
  chosen: string

method update(m: App, msg: Msg): (Model, Cmd) =
  if msg of KeyPressMsg:
    let k = KeyPressMsg(msg).key
    if k.matchString("q", "ctrl+c", "esc"): return (Model(m), Quit)
    if k.matchString("up", "k"): m.cursor = max(0, m.cursor - 1)
    elif k.matchString("down", "j"): m.cursor = min(m.choices.high, m.cursor + 1)
    elif k.code == KeyEnter:
      m.chosen = m.choices[m.cursor]
      return (Model(m), Quit)
  (Model(m), nil)

method view(m: App): View =
  var b = "What kind of Bubble Tea would you like?\n\n"
  for i, c in m.choices:
    let cur = if i == m.cursor: "> " else: "  "
    b.add cur & c & "\n"
  b.add "\n↑/↓ move · enter choose · q quit"
  newView(b)

when isMainModule:
  discard newProgram(Model(App(choices: @["Classic", "Taro", "Matcha", "Brown Sugar"]))).run()
