## Cell buffers — port of the parts of `ultraviolet/buffer.go` the renderer
## needs: `Line`, `Buffer`, and line/string rendering with minimal SGR diffs.

import ../ansi/style
import ../ansi/c0
import ./cell

type
  Line* = seq[Cell]

  Buffer* = object
    lines*: seq[Line]
    width*: int
    height*: int

# ---- Line ------------------------------------------------------------------

proc newLine*(width: int): Line =
  result = newSeq[Cell](width)
  for i in 0 ..< width:
    result[i] = EmptyCell

proc setCell*(line: var Line, x: int, c: Cell) =
  ## Place `c` at column `x`, writing a spacer in the following cell if `c` is
  ## wide and clearing any wide char this overwrites.
  if x < 0 or x >= line.len: return
  line[x] = c
  if c.width == 2 and x + 1 < line.len:
    line[x + 1] = SpacerCell

proc renderLine*(line: Line): string =
  ## Render a line to a styled string with minimal inter-cell SGR diffs.
  var pen = EmptyStyle
  var trailingBlanks = 0
  var body = ""
  for c in line:
    if c.width == 0 and c.content.len == 0:
      continue  # spacer; the preceding wide char already emitted content
    let content = if c.content.len == 0: " " else: c.content
    # Defer trailing default-styled blanks so we don't pad lines needlessly.
    if c.isEmpty:
      inc trailingBlanks
      continue
    if trailingBlanks > 0:
      # flush deferred blanks (they were interior, not trailing)
      if not pen.isEmpty:
        body.add diff(pen, EmptyStyle)
        pen = EmptyStyle
      for _ in 0 ..< trailingBlanks: body.add ' '
      trailingBlanks = 0
    if c.style != pen:
      body.add diff(pen, c.style)
      pen = c.style
    body.add content
  if not pen.isEmpty:
    body.add CSI & "0m"
  result = body

# ---- Buffer ----------------------------------------------------------------

proc newBuffer*(width, height: int): Buffer =
  result.width = width
  result.height = height
  result.lines = newSeq[Line](height)
  for y in 0 ..< height:
    result.lines[y] = newLine(width)

proc cellAt*(b: Buffer, x, y: int): Cell =
  if y < 0 or y >= b.lines.len or x < 0 or x >= b.lines[y].len:
    return EmptyCell
  b.lines[y][x]

proc setCell*(b: var Buffer, x, y: int, c: Cell) =
  if y < 0 or y >= b.lines.len: return
  b.lines[y].setCell(x, c)

proc clear*(b: var Buffer) =
  for y in 0 ..< b.lines.len:
    for x in 0 ..< b.lines[y].len:
      b.lines[y][x] = EmptyCell

proc resize*(b: var Buffer, width, height: int) =
  b.width = width
  b.height = height
  b.lines.setLen(height)
  for y in 0 ..< height:
    if b.lines[y].len == 0:
      b.lines[y] = newLine(width)
    else:
      let old = b.lines[y].len
      b.lines[y].setLen(width)
      for x in old ..< width:
        b.lines[y][x] = EmptyCell

proc render*(b: Buffer): string =
  ## Render the whole buffer to a string (lines joined by CRLF). Used for
  ## tests/snapshots, not the live diff renderer.
  for y in 0 ..< b.lines.len:
    if y > 0: result.add "\r\n"
    result.add renderLine(b.lines[y])
