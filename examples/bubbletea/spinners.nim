## Port of bubbletea/examples/spinners — cycle through spinner styles.

import ../../src/boba
import ../../src/boba/bubbles

type App = ref object of Model
  spin: Spinner
  styles: seq[seq[string]]
  idx: int

method init(m: App): Cmd = m.spin.tickCmd()

method update(m: App, msg: Msg): (Model, Cmd) =
  if msg of KeyPressMsg:
    let k = KeyPressMsg(msg).key
    if k.matchString("q", "ctrl+c", "esc"): return (Model(m), Quit)
    if k.matchString("right", "l", "tab"):
      m.idx = (m.idx + 1) mod m.styles.len
      m.spin = newSpinner(m.styles[m.idx])
      return (Model(m), m.spin.tickCmd())
    if k.matchString("left", "h"):
      m.idx = (m.idx - 1 + m.styles.len) mod m.styles.len
      m.spin = newSpinner(m.styles[m.idx])
      return (Model(m), m.spin.tickCmd())
  let cmd = m.spin.update(msg)
  (Model(m), cmd)

method view(m: App): View =
  newView("\n  " & m.spin.view & " Spinning...\n\n  ←/→ change style · q quit\n")

when isMainModule:
  let styles = @[DotsFrames, LineFrames, MiniDotFrames]
  discard newProgram(Model(App(spin: newSpinner(styles[0]), styles: styles))).run()
