## Sub-window views and buffer compositing — pragmatic port of
## `ultraviolet/window.go`.
##
## A `Window` is a clipped, offset view into a parent `Buffer`: writes are
## translated by the window origin and dropped if they fall outside its bounds.
## `blit` composites one buffer into another. Together these let you place
## independent components at absolute positions.

import ./cell
import ./buffer
import ./styled

type
  Window* = object
    target: ptr Buffer
    ox*, oy*, w*, h*: int

proc window*(b: var Buffer, x, y, w, h: int): Window =
  ## A `w`x`h` sub-window of `b` whose origin maps to (x, y) in the parent.
  ## The parent buffer must outlive the window.
  Window(target: addr b, ox: x, oy: y, w: w, h: h)

proc width*(win: Window): int = win.w
proc height*(win: Window): int = win.h

proc setCell*(win: Window, x, y: int, c: Cell) =
  if x < 0 or y < 0 or x >= win.w or y >= win.h: return
  win.target[].setCell(win.ox + x, win.oy + y, c)

proc draw*(win: Window, content: string) =
  ## Draw a (styled) string into the window, clipping to its bounds.
  let ls = newStyledString(content).lines()
  for yy in 0 ..< min(ls.len, win.h):
    var xx = 0
    for c in ls[yy]:
      if c.width == 0 and c.content.len == 0: continue
      if xx >= win.w: break
      win.setCell(xx, yy, c)
      xx += max(c.width, 1)

proc blit*(dest: var Buffer, src: Buffer, atX, atY: int) =
  ## Composite `src` into `dest` at (atX, atY), clipping to `dest` bounds.
  for sy in 0 ..< src.height:
    let dy = atY + sy
    if dy < 0 or dy >= dest.height: continue
    for sx in 0 ..< src.width:
      let dx = atX + sx
      if dx < 0 or dx >= dest.width: continue
      let c = src.cellAt(sx, sy)
      if c.width == 0 and c.content.len == 0: continue
      dest.setCell(dx, dy, c)
