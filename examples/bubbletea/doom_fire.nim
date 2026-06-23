## Port of bubbletea/examples/doom-fire — the classic DOOM fire animation in a
## cell buffer with a heat palette.

import std/[times, random]
import ../../src/boba

const
  W = 50
  H = 18

type
  FrameMsg = ref object of Msg
  App = ref object of Model
    grid: seq[int]
    palette: seq[Color]
    rng: Rand

proc frame(): Cmd = Tick(initDuration(milliseconds = 60), proc (t: Time): Msg = FrameMsg())

proc buildPalette(): seq[Color] =
  result.add gradient(trueColor(7, 7, 7), trueColor(180, 30, 0), 4)
  result.add gradient(trueColor(180, 30, 0), trueColor(255, 160, 0), 4)
  result.add gradient(trueColor(255, 160, 0), trueColor(255, 255, 200), 4)

method init(m: App): Cmd = frame()

method update(m: App, msg: Msg): (Model, Cmd) =
  if msg of KeyPressMsg and KeyPressMsg(msg).key.matchString("q", "ctrl+c"):
    return (Model(m), Quit)
  if msg of FrameMsg:
    let maxv = m.palette.high
    # Bottom row is the fire source.
    for x in 0 ..< W: m.grid[(H - 1) * W + x] = maxv
    # Propagate upward with jitter + decay.
    for y in 0 ..< H - 1:
      for x in 0 ..< W:
        let r = m.rng.rand(2)            # 0..2
        let sx = clamp(x + r - 1, 0, W - 1)
        let v = m.grid[(y + 1) * W + sx] - (r and 1)
        m.grid[y * W + x] = max(v, 0)
    return (Model(m), frame())
  (Model(m), nil)

method view(m: App): View =
  var s = ""
  for y in 0 ..< H:
    for x in 0 ..< W:
      let v = m.grid[y * W + x]
      if v <= 0: s.add " "
      else: s.add newStyle().background(m.palette[v]).render(" ")
    if y < H - 1: s.add "\n"
  newView(s & "\n\nq to quit")

when isMainModule:
  var app = App(grid: newSeq[int](W * H), palette: buildPalette(), rng: initRand(424242))
  discard newProgram(Model(app)).run()
