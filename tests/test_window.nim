import std/unittest
import ../src/boba/uv/cell
import ../src/boba/uv/buffer
import ../src/boba/uv/window

proc grid(b: Buffer): seq[string] =
  for y in 0 ..< b.lines.len:
    var row = ""
    for c in b.lines[y]:
      if c.width == 0 and c.content.len == 0: continue
      row.add (if c.content.len == 0: " " else: c.content)
    result.add row

suite "uv window":
  test "draws at offset, clipped":
    var b = newBuffer(6, 3)
    let win = window(b, 2, 1, 3, 2)
    win.draw("XY\nZ")
    check b.cellAt(2, 1).content == "X"
    check b.cellAt(3, 1).content == "Y"
    check b.cellAt(2, 2).content == "Z"
    check b.cellAt(0, 0).isEmpty   # untouched

  test "clips overflow":
    var b = newBuffer(6, 3)
    let win = window(b, 4, 0, 3, 1)   # only 2 cols actually fit (x=4,5)
    win.draw("ABCDEF")
    check b.cellAt(4, 0).content == "A"
    check b.cellAt(5, 0).content == "B"
    # x=6 is out of buffer, dropped

  test "setCell respects window bounds":
    var b = newBuffer(4, 2)
    let win = window(b, 1, 0, 2, 2)
    win.setCell(5, 0, newCell("Z"))   # outside window -> dropped
    check b.cellAt(1, 0).isEmpty

suite "uv blit":
  test "composites a buffer into another":
    var dest = newBuffer(6, 3)
    var src = newBuffer(2, 2)
    src.setCell(0, 0, newCell("a"))
    src.setCell(1, 1, newCell("b"))
    dest.blit(src, 3, 1)
    check dest.cellAt(3, 1).content == "a"
    check dest.cellAt(4, 2).content == "b"

  test "blit clips at edges":
    var dest = newBuffer(3, 2)
    var src = newBuffer(2, 2)
    src.setCell(0, 0, newCell("x"))
    dest.blit(src, 2, 1)
    check dest.cellAt(2, 1).content == "x"
