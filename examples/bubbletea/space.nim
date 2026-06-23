## Port of bubbletea/examples/space — a drifting starfield.

import std/[times, random, strutils]
import ../../src/boba

const
  W = 60
  H = 18

type
  FrameMsg = ref object of Msg
  Star = object
    x: float
    y: int
    speed: float
    glyph: string
  App = ref object of Model
    stars: seq[Star]
    rng: Rand

proc frame(): Cmd = Tick(initDuration(milliseconds = 70), proc (t: Time): Msg = FrameMsg())

proc newStar(m: App): Star =
  let s = m.rng.rand(1.0) + 0.3
  let g = if s > 1.0: "+" elif s > 0.7: "*" else: "."
  Star(x: float(W - 1), y: m.rng.rand(H - 1), speed: s, glyph: g)

method init(m: App): Cmd = frame()

method update(m: App, msg: Msg): (Model, Cmd) =
  if msg of KeyPressMsg and KeyPressMsg(msg).key.matchString("q", "ctrl+c"):
    return (Model(m), Quit)
  if msg of FrameMsg:
    for i in 0 ..< m.stars.len:
      m.stars[i].x -= m.stars[i].speed
      if m.stars[i].x < 0: m.stars[i] = m.newStar()
    return (Model(m), frame())
  (Model(m), nil)

method view(m: App): View =
  var grid = newSeq[string](H)
  for y in 0 ..< H: grid[y] = " ".repeat(W)
  for s in m.stars:
    let xi = int(s.x)
    if xi >= 0 and xi < W and s.y >= 0 and s.y < H:
      grid[s.y][xi] = s.glyph[0]
  newView(grid.join("\n") & "\n\nq to quit")

when isMainModule:
  var app = App(rng: initRand(987654))
  for i in 0 ..< 60:
    app.stars.add Star(x: float(app.rng.rand(W - 1)), y: app.rng.rand(H - 1),
                       speed: app.rng.rand(1.0) + 0.3, glyph: "·")
  discard newProgram(Model(app)).run()
