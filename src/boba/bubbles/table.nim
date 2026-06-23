## A scrollable, selectable table — port of the core of
## `charmbracelet/bubbles/table`.

import std/strutils
import ../tea/msg
import ../uv/key
import ../ansi/style
import ../ansi/color
import ../ansi/width
import ../ansi/wrap

type
  Column* = object
    title*: string
    width*: int

  Table* = object
    columns*: seq[Column]
    rows*: seq[seq[string]]
    cursor*: int
    height*: int          ## visible body rows
    offset*: int

proc column*(title: string, width: int): Column =
  Column(title: title, width: width)

proc newTable*(columns: seq[Column], rows: seq[seq[string]], height = 10): Table =
  Table(columns: columns, rows: rows, cursor: 0, height: max(height, 1), offset: 0)

proc selectedRow*(t: Table): seq[string] =
  if t.cursor >= 0 and t.cursor < t.rows.len: t.rows[t.cursor] else: @[]

proc clampScroll(t: var Table) =
  if t.cursor < t.offset: t.offset = t.cursor
  elif t.cursor >= t.offset + t.height: t.offset = t.cursor - t.height + 1
  if t.offset < 0: t.offset = 0

proc moveUp*(t: var Table) =
  if t.cursor > 0: dec t.cursor
  t.clampScroll()
proc moveDown*(t: var Table) =
  if t.cursor < t.rows.len - 1: inc t.cursor
  t.clampScroll()

proc update*(t: var Table, m: Msg) =
  if not (m of KeyPressMsg): return
  let k = KeyPressMsg(m).key
  if k.matchString("up", "k"): t.moveUp()
  elif k.matchString("down", "j"): t.moveDown()

proc cell(text: string, w: int): string =
  ## Fit `text` to exactly `w` columns (truncate with … or pad with spaces).
  let tw = stringWidth(text)
  if tw == w: text
  elif tw > w: truncate(text, w, "…")
  else: text & spaces(w - tw)

proc renderRow(t: Table, cols: openArray[string]): string =
  var parts: seq[string]
  for i, c in t.columns:
    let v = if i < cols.len: cols[i] else: ""
    parts.add cell(v, c.width)
  parts.join(" ")

proc view*(t: Table): string =
  var rows: seq[string]
  # Header.
  var headerCells: seq[string]
  for c in t.columns: headerCells.add c.title
  rows.add EmptyStyle.bold.styled(t.renderRow(headerCells))
  # Body window.
  let last = min(t.offset + t.height, t.rows.len)
  for i in t.offset ..< last:
    let line = t.renderRow(t.rows[i])
    if i == t.cursor:
      rows.add EmptyStyle.reverse.styled(line)
    else:
      rows.add line
  result = rows.join("\n")
