## Cell-diff renderer tests, including a property check: apply the emitted ANSI
## to the previous screen and confirm it reproduces the target buffer (the
## "virtual terminal" approach from docs/PLAN.md §9). Content-only (styles are
## covered by the ansi/styled suites).

import std/[unittest, unicode, strutils]
import ../src/boba/uv/cell
import ../src/boba/uv/buffer
import ../src/boba/uv/styled
import ../src/boba/uv/renderer
import ../src/boba/ansi/width

proc parseIntC(s: string): int =
  for c in s:
    if c in '0' .. '9': result = result * 10 + (ord(c) - ord('0'))

proc buf(width, height: int, content: string): Buffer =
  result = newBuffer(width, height)
  newStyledString(content).draw(result)

proc contentGrid(b: Buffer): seq[string] =
  for y in 0 ..< b.lines.len:
    var row = ""
    for c in b.lines[y]:
      if c.width == 0 and c.content.len == 0: continue
      row.add (if c.content.len == 0: " " else: c.content)
    result.add row

# Minimal virtual terminal: interprets CSI H (move), CSI K (erase EOL), skips
# SGR, and writes printable runes. Enough to verify content placement.
proc applyTo(b: var Buffer, s: string) =
  var x, y = 0
  var i = 0
  let n = s.len
  while i < n:
    let ch = s[i]
    if ch == '\x1b' and i + 1 < n and s[i + 1] == '[':
      var j = i + 2
      while j < n and (s[j] < '\x40' or s[j] > '\x7e'): inc j
      if j >= n: break
      let final = s[j]
      let params = s[i + 2 ..< j]
      case final
      of 'H':
        var row = 1
        var col = 1
        let semi = params.find(';')
        if semi >= 0:
          if semi > 0: row = parseIntC(params[0 ..< semi])
          if semi + 1 < params.len: col = parseIntC(params[semi + 1 .. ^1])
        elif params.len > 0:
          row = parseIntC(params)
        y = row - 1
        x = col - 1
      of 'K':
        for k in x ..< b.width: b.setCell(k, y, EmptyCell)
      else: discard  # SGR and others: ignore for content check
      i = j + 1
      continue
    var r: Rune
    let start = i
    fastRuneAt(s, i, r, true)
    let g = s[start ..< i]
    b.setCell(x, y, newCell(g))
    x += max(stringWidth(g), 1)

suite "uv renderer diff":
  test "identical buffers emit nothing":
    var r = newTerminalRenderer(10, 2)
    let a = buf(10, 2, "hello\nworld")
    discard r.render(a)           # prime
    check r.render(a) == ""

  test "single cell change emits a short diff":
    var r = newTerminalRenderer(10, 1)
    discard r.render(buf(10, 1, "hello"))
    let outp = r.render(buf(10, 1, "hewlo"))
    check outp.len > 0
    check outp.len < 20            # not a full-line rewrite
    check "hello" notin outp

  test "diff reproduces target (property): single change":
    var r = newTerminalRenderer(10, 2)
    let prev = buf(10, 2, "hello\nworld")
    discard r.render(prev)
    let next = buf(10, 2, "hello\nwOrld")
    let outp = r.render(next)
    var screen = prev
    applyTo(screen, outp)
    check contentGrid(screen) == contentGrid(next)

  test "diff reproduces target (property): shrink line":
    var r = newTerminalRenderer(12, 1)
    let prev = buf(12, 1, "longer text!")
    discard r.render(prev)
    let next = buf(12, 1, "short")
    let outp = r.render(next)
    var screen = prev
    applyTo(screen, outp)
    check contentGrid(screen) == contentGrid(next)

  test "diff reproduces target (property): grow + wide chars":
    var r = newTerminalRenderer(12, 2)
    let prev = buf(12, 2, "a\nb")
    discard r.render(prev)
    let next = buf(12, 2, "世界ok\nhello")
    let outp = r.render(next)
    var screen = prev
    applyTo(screen, outp)
    check contentGrid(screen) == contentGrid(next)

  test "reset forces full repaint":
    var r = newTerminalRenderer(10, 1)
    let a = buf(10, 1, "hello")
    discard r.render(a)
    r.reset()
    check r.render(a) != ""
