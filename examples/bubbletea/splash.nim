## Port of bubbletea/examples/splash — an animated splash screen: the title
## sweeps through a color gradient.

import std/[times, strutils]
import ../../src/boba

type
  FrameMsg = ref object of Msg
  App = ref object of Model
    phase: int
    ramp: seq[Color]

proc frame(): Cmd = Tick(initDuration(milliseconds = 90), proc (t: Time): Msg = FrameMsg())

method init(m: App): Cmd = frame()

method update(m: App, msg: Msg): (Model, Cmd) =
  if msg of KeyPressMsg and KeyPressMsg(msg).key.matchString("q", "ctrl+c", "esc"):
    return (Model(m), Quit)
  if msg of FrameMsg:
    m.phase = (m.phase + 1) mod m.ramp.len
    return (Model(m), frame())
  (Model(m), nil)

method view(m: App): View =
  const title = "B O B A B R E W"
  var s = "\n\n   "
  var i = 0
  for ch in title:
    if ch == ' ': (s.add " "; continue)
    let c = m.ramp[(i + m.phase) mod m.ramp.len]
    s.add newStyle().bold.foreground(c).render($ch)
    inc i
  s.add "\n\n   a Bubble Tea framework for Nim\n\n   press q to continue"
  newView(s)

when isMainModule:
  var ramp: seq[Color]
  ramp.add gradient(trueColor(255, 90, 200), trueColor(120, 100, 255), 6)
  ramp.add gradient(trueColor(120, 100, 255), trueColor(0, 220, 200), 6)
  ramp.add gradient(trueColor(0, 220, 200), trueColor(255, 90, 200), 6)
  discard newProgram(Model(App(ramp: ramp))).run()
