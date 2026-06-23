## A scrollable viewport — port of the core of `charmbracelet/bubbles/viewport`.
## Holds content larger than its window and shows a vertical slice you can
## scroll with the keyboard.

import std/strutils
import ../tea/msg
import ../uv/key
import ../ansi/width

type
  Viewport* = object
    width*, height*: int
    yOffset*: int
    lines: seq[string]

proc newViewport*(width, height: int): Viewport =
  Viewport(width: width, height: height, yOffset: 0)

proc totalLines*(v: Viewport): int = v.lines.len

proc maxOffset(v: Viewport): int = max(v.lines.len - v.height, 0)

proc clampOffset(v: var Viewport) =
  v.yOffset = max(0, min(v.yOffset, v.maxOffset))

proc setContent*(v: var Viewport, s: string) =
  v.lines = s.split('\n')
  v.clampOffset()

proc atTop*(v: Viewport): bool = v.yOffset <= 0
proc atBottom*(v: Viewport): bool = v.yOffset >= v.maxOffset

proc scrollPercent*(v: Viewport): float =
  if v.maxOffset == 0: return 1.0
  v.yOffset.float / v.maxOffset.float

proc lineDown*(v: var Viewport, n = 1) = (v.yOffset += n; v.clampOffset())
proc lineUp*(v: var Viewport, n = 1) = (v.yOffset -= n; v.clampOffset())
proc halfPageDown*(v: var Viewport) = v.lineDown(max(v.height div 2, 1))
proc halfPageUp*(v: var Viewport) = v.lineUp(max(v.height div 2, 1))
proc pageDown*(v: var Viewport) = v.lineDown(v.height)
proc pageUp*(v: var Viewport) = v.lineUp(v.height)
proc gotoTop*(v: var Viewport) = (v.yOffset = 0)
proc gotoBottom*(v: var Viewport) = (v.yOffset = v.maxOffset)

proc update*(v: var Viewport, m: Msg) =
  if not (m of KeyPressMsg): return
  let k = KeyPressMsg(m).key
  if k.matchString("down", "j"): v.lineDown()
  elif k.matchString("up", "k"): v.lineUp()
  elif k.code == KeyPgDown: v.pageDown()
  elif k.code == KeyPgUp: v.pageUp()
  elif k.matchString("d", "ctrl+d"): v.halfPageDown()
  elif k.matchString("u", "ctrl+u"): v.halfPageUp()
  elif k.matchString("g", "home") or k.code == KeyHome: v.gotoTop()
  elif k.matchString("G", "end") or k.code == KeyEnd: v.gotoBottom()

proc view*(v: Viewport): string =
  ## The currently-visible window, padded/truncated to width and height.
  var rows: seq[string]
  for i in 0 ..< v.height:
    let idx = v.yOffset + i
    var line = if idx < v.lines.len: v.lines[idx] else: ""
    if v.width > 0:
      let lw = stringWidth(line)
      if lw < v.width: line = line & spaces(v.width - lw)
      # (overflow is left as-is; callers usually pre-wrap)
    rows.add line
  result = rows.join("\n")
