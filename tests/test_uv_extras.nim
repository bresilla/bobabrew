import std/[unittest, strutils]
import ../src/boba/uv/tabstop
import ../src/boba/uv/screen
import ../src/boba/uv/buffer
import ../src/boba/uv/cell

suite "uv tabstop":
  test "default stops every 8":
    let t = newTabStops(40)
    check t.isStop(0)
    check t.isStop(8)
    check t.isStop(16)
    check not t.isStop(5)

  test "next stop":
    let t = newTabStops(40)
    check t.next(0) == 8
    check t.next(3) == 8
    check t.next(8) == 16

  test "custom set/clear":
    var t = newTabStops(40)
    t.clearStop(8)
    check not t.isStop(8)
    t.setStop(5)
    check t.isStop(5)
    check t.next(0) == 5

  test "next clamps at width":
    let t = newTabStops(10)
    check t.next(9) == 9

suite "uv screen":
  test "draw + render produces output, then stable":
    var s = newTerminalScreen(10, 2)
    s.draw("hi")
    let first = s.render()
    check first.len > 0
    check "hi" in first
    check s.render() == ""    # no change second time

  test "change yields a diff":
    var s = newTerminalScreen(10, 1)
    s.draw("hello")
    discard s.render()
    s.clear()
    s.draw("hxllo")
    let d = s.render()
    check d.len > 0
    check "hello" notin d

  test "draw at offset":
    var s = newTerminalScreen(10, 3)
    s.draw("X", atX = 3, atY = 1)
    check s.buffer.cellAt(3, 1).content == "X"
