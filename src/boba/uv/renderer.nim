## Cell-level diff renderer — the core of `ultraviolet/terminal_renderer.go`.
##
## Given the previously-displayed `Buffer` and a new one, `render` emits the
## minimal byte stream to transform the screen: per line it finds the changed
## span, moves the cursor there, rewrites only the changed cells (with minimal
## SGR diffs), and erases to end-of-line when the tail became blank. Unchanged
## lines emit nothing.
##
## This first cut uses absolute cursor positioning (correct for the alt screen).
## Relative-cursor optimization and hashmap/hardscroll line-scrolling are the
## remaining M5 deepening items; the API is stable so those land internally.

import ../ansi/style
import ../ansi/sequences
import ../ansi/c0
import ./cell
import ./buffer

type
  TerminalRenderer* = object
    prev*: Buffer          ## what is currently on screen
    width*, height*: int
    initialized: bool

proc newTerminalRenderer*(width, height: int): TerminalRenderer =
  result.width = width
  result.height = height
  result.prev = newBuffer(width, height)
  result.initialized = false

proc lineAt(b: Buffer, y: int): Line =
  if y < b.lines.len: b.lines[y] else: @[]

proc cellOr(l: Line, x: int): Cell =
  if x < l.len: l[x] else: EmptyCell

proc spanDiff(o, n: Line): tuple[lo, hi: int] =
  ## Inclusive range of differing columns, or lo<0 when the lines are equal.
  var lo = -1
  var hi = -2
  let w = max(o.len, n.len)
  for x in 0 ..< w:
    if cellOr(o, x) != cellOr(n, x):
      if lo < 0: lo = x
      hi = x
  (lo, hi)

proc render*(r: var TerminalRenderer, next: Buffer): string =
  ## Diff `next` against the on-screen buffer and return the bytes to write.
  ## Also updates the renderer's record of the screen.
  var pen = EmptyStyle
  result = ""
  let h = max(r.prev.lines.len, next.lines.len)
  for y in 0 ..< h:
    let ol = lineAt(r.prev, y)
    let nl = lineAt(next, y)
    let (lo, hi) = spanDiff(ol, nl)
    if lo < 0: continue

    # Trim the write span to the last cell that actually has content in the new
    # line; anything past it that changed becomes an erase-to-EOL.
    var writeHi = hi
    while writeHi >= lo and cellOr(nl, writeHi).isEmpty:
      dec writeHi

    if writeHi >= lo:
      result.add moveTo(lo, y)
      var x = lo
      while x <= writeHi:
        let c = cellOr(nl, x)
        if c.width == 0 and c.content.len == 0:
          inc x
          continue
        if c.style != pen:
          result.add diff(pen, c.style)
          pen = c.style
        result.add (if c.content.len == 0: " " else: c.content)
        x += max(c.width, 1)
    else:
      # Whole changed span became blank: just position for the erase.
      result.add moveTo(lo, y)

    # Erase to EOL if the new line is shorter / the tail cleared out.
    if hi > writeHi:
      if pen != EmptyStyle:
        result.add CSI & "0m"
        pen = EmptyStyle
      result.add EraseLineRight

  if pen != EmptyStyle:
    result.add CSI & "0m"

  r.prev = next
  r.initialized = true

proc reset*(r: var TerminalRenderer) =
  ## Forget the screen state so the next render repaints everything.
  r.prev = newBuffer(r.width, r.height)
  r.initialized = false

proc resize*(r: var TerminalRenderer, width, height: int) =
  r.width = width
  r.height = height
  r.reset()
