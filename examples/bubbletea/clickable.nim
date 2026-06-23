## Port of bubbletea/examples/clickable — buttons that respond to mouse clicks.

import ../../src/boba

type App = ref object of Model
  labels: seq[string]
  clicked: int
  count: int

const rowY = 2   # the row the buttons render on

method update(m: App, msg: Msg): (Model, Cmd) =
  if msg of KeyPressMsg and KeyPressMsg(msg).key.matchString("q", "ctrl+c"):
    return (Model(m), Quit)
  if msg of MouseClickMsg:
    let mo = MouseClickMsg(msg).mouse
    if mo.y == rowY:
      # Buttons are "[ label ]" laid out with single spaces between.
      var x = 0
      for i, lab in m.labels:
        let w = lab.len + 4   # "[ " + label + " ]"
        if mo.x >= x and mo.x < x + w:
          m.clicked = i
          m.count.inc
          break
        x += w + 1
  (Model(m), nil)

method view(m: App): View =
  var buttons: string
  for i, lab in m.labels:
    let face = "[ " & lab & " ]"
    if i == m.clicked:
      buttons.add newStyle().reverse.render(face)
    else:
      buttons.add face
    buttons.add " "
  result = newView("Click a button (q to quit)\n\n" & buttons &
                   "\n\nLast: " & m.labels[m.clicked] & " · clicks: " & $m.count)
  result.mouseMode = mmCellMotion

when isMainModule:
  discard newProgram(Model(App(labels: @["One", "Two", "Three"]))).run()
