import std/unittest
import ../src/boba/ansi
import ../src/boba/uv/cell
import ../src/boba/uv/buffer
import ../src/boba/uv/styled

suite "uv/cell":
  test "newCell width":
    check newCell("a").width == 1
    check newCell("世").width == 2
    check newCell("").width == 0

  test "empty detection":
    check EmptyCell.isEmpty
    check not newCell("x").isEmpty

suite "uv/buffer":
  test "new buffer is blank":
    var b = newBuffer(4, 2)
    check b.width == 4
    check b.height == 2
    check b.cellAt(0, 0).isEmpty

  test "set/get cell":
    var b = newBuffer(4, 2)
    b.setCell(1, 0, newCell("x"))
    check b.cellAt(1, 0).content == "x"

  test "wide char writes spacer":
    var b = newBuffer(4, 1)
    b.setCell(0, 0, newCell("世"))
    check b.cellAt(0, 0).width == 2
    check b.cellAt(1, 0).content == ""
    check b.cellAt(1, 0).width == 0

  test "resize preserves and extends":
    var b = newBuffer(2, 1)
    b.setCell(0, 0, newCell("a"))
    b.resize(4, 2)
    check b.cellAt(0, 0).content == "a"
    check b.height == 2
    check b.cellAt(3, 1).isEmpty

suite "uv/styled":
  test "plain text":
    let ss = newStyledString("hello")
    let ls = ss.lines()
    check ls.len == 1
    check ls[0].len == 5
    check ls[0][0].content == "h"

  test "multiline":
    let ss = newStyledString("ab\ncd")
    check ss.height == 2
    check ss.unicodeWidth == 2

  test "SGR styling carries to cells":
    let ss = newStyledString("\x1b[1;31mhi\x1b[0m")
    let ls = ss.lines()
    check ls[0][0].content == "h"
    check aBold in ls[0][0].style.attrs
    check ls[0][0].style.fg == basicColor(Red)
    check ls[0].len == 2

  test "reset clears style":
    let ss = newStyledString("\x1b[1mA\x1b[0mB")
    let ls = ss.lines()
    check aBold in ls[0][0].style.attrs
    check ls[0][1].style.isEmpty

  test "truecolor fg":
    let ss = newStyledString("\x1b[38;2;10;20;30mX")
    let ls = ss.lines()
    check ls[0][0].style.fg == trueColor(10, 20, 30)

  test "256 color fg":
    let ss = newStyledString("\x1b[38;5;200mX")
    let ls = ss.lines()
    check ls[0][0].style.fg == extendedColor(200)

  test "wide char in styled string":
    let ss = newStyledString("世a")
    let ls = ss.lines()
    check ls[0][0].width == 2
    check ls[0][1].width == 0
    check ls[0][2].content == "a"

  test "draw into buffer":
    var b = newBuffer(10, 2)
    newStyledString("hi\nyo").draw(b)
    check b.cellAt(0, 0).content == "h"
    check b.cellAt(1, 0).content == "i"
    check b.cellAt(0, 1).content == "y"

  test "renderLine roundtrips style":
    let ss = newStyledString("\x1b[31mred\x1b[0m")
    let rendered = renderLine(ss.lines()[0])
    check rendered == "\x1b[31mred\x1b[0m"
