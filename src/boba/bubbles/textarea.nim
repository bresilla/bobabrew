## A multi-line text editor — port of the core of `charmbracelet/bubbles/textarea`.
## Lines are stored as rune sequences for correct cursor math.

import std/[unicode, strutils]
import ../tea/msg
import ../uv/key
import ../ansi/style

type
  TextArea* = object
    lines: seq[seq[Rune]]
    row*, col*: int          ## cursor position (col is a rune index)
    width*, height*: int     ## viewport size
    rowOffset: int
    focused*: bool

proc newTextArea*(width = 40, height = 6): TextArea =
  TextArea(lines: @[newSeq[Rune]()], row: 0, col: 0,
           width: width, height: max(height, 1), rowOffset: 0, focused: true)

proc value*(t: TextArea): string =
  var parts: seq[string]
  for ln in t.lines:
    var s = ""
    for r in ln: s.add $r
    parts.add s
  parts.join("\n")

proc setValue*(t: var TextArea, s: string) =
  t.lines = @[]
  for ln in s.split('\n'):
    t.lines.add toRunes(ln)
  if t.lines.len == 0: t.lines = @[newSeq[Rune]()]
  t.row = t.lines.high
  t.col = t.lines[t.row].len

proc clampCol(t: var TextArea) =
  t.col = max(0, min(t.col, t.lines[t.row].len))

proc clampScroll(t: var TextArea) =
  if t.row < t.rowOffset: t.rowOffset = t.row
  elif t.row >= t.rowOffset + t.height: t.rowOffset = t.row - t.height + 1
  if t.rowOffset < 0: t.rowOffset = 0

proc insertRune(t: var TextArea, r: Rune) =
  t.lines[t.row].insert(r, t.col)
  inc t.col

proc newline(t: var TextArea) =
  let tail = t.lines[t.row][t.col .. ^1]
  t.lines[t.row].setLen(t.col)
  t.lines.insert(tail, t.row + 1)
  inc t.row
  t.col = 0

proc backspace(t: var TextArea) =
  if t.col > 0:
    t.lines[t.row].delete(t.col - 1)
    dec t.col
  elif t.row > 0:
    let prevLen = t.lines[t.row - 1].len
    t.lines[t.row - 1].add t.lines[t.row]
    t.lines.delete(t.row)
    dec t.row
    t.col = prevLen

proc del(t: var TextArea) =
  if t.col < t.lines[t.row].len:
    t.lines[t.row].delete(t.col)
  elif t.row < t.lines.high:
    t.lines[t.row].add t.lines[t.row + 1]
    t.lines.delete(t.row + 1)

proc update*(t: var TextArea, m: Msg) =
  if not t.focused or not (m of KeyPressMsg): return
  let k = KeyPressMsg(m).key
  case k.code
  of KeyEnter: t.newline()
  of KeyBackspace: t.backspace()
  of KeyDelete: t.del()
  of KeyLeft:
    if t.col > 0: dec t.col
    elif t.row > 0: (dec t.row; t.col = t.lines[t.row].len)
  of KeyRight:
    if t.col < t.lines[t.row].len: inc t.col
    elif t.row < t.lines.high: (inc t.row; t.col = 0)
  of KeyUp:
    if t.row > 0: (dec t.row; t.clampCol())
  of KeyDown:
    if t.row < t.lines.high: (inc t.row; t.clampCol())
  of KeyHome: t.col = 0
  of KeyEnd: t.col = t.lines[t.row].len
  else:
    if k.text.len > 0 and (k.mods - {modShift}) == {}:
      for r in toRunes(k.text): t.insertRune(r)
  t.clampScroll()

proc lineToString(ln: seq[Rune]): string =
  for r in ln: result.add $r

proc view*(t: TextArea): string =
  var rows: seq[string]
  let last = min(t.rowOffset + t.height, t.lines.len)
  let caret = EmptyStyle.reverse
  for y in t.rowOffset ..< last:
    let ln = t.lines[y]
    if y == t.row and t.focused:
      var s = ""
      for i in 0 .. ln.len:
        if i == t.col:
          let u = if i < ln.len: $ln[i] else: " "
          s.add caret.styled(u)
          if i < ln.len: continue
        if i < ln.len: s.add $ln[i]
      rows.add s
    else:
      rows.add lineToString(ln)
  result = rows.join("\n")
