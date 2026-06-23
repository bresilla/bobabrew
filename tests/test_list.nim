import std/[unittest, strutils]
import ../src/boba
import ../src/boba/bubbles

proc special(code: int32): Msg = newKeyPress(Key(code: code))
proc letter(c: char): Msg = newKeyPress(Key(code: int32(c.ord), text: $c))

proc items(n: int): seq[ListItem] =
  for i in 1 .. n: result.add item("item " & $i)

suite "bubbles/list":
  test "starts at first":
    let l = newList(items(5), 3)
    check l.selected.title == "item 1"
    check l.cursor == 0

  test "moves down/up":
    var l = newList(items(5), 3)
    l.update(letter('j'))
    check l.selected.title == "item 2"
    l.update(letter('k'))
    check l.selected.title == "item 1"

  test "clamps at ends":
    var l = newList(items(3), 3)
    l.update(special(KeyUp))
    check l.cursor == 0
    for _ in 0 ..< 10: l.update(special(KeyDown))
    check l.cursor == 2

  test "scrolls to follow cursor":
    var l = newList(items(10), 3)
    for _ in 0 ..< 5: l.moveDown()
    check l.offset > 0
    # selected line is within the visible window
    check l.cursor >= l.offset
    check l.cursor < l.offset + l.height

  test "view shows only window and marks selection":
    var l = newList(items(10), 3)
    let v = l.view
    check v.split('\n').len == 3
    check "> item 1" in v

  test "goto top/bottom":
    var l = newList(items(10), 3)
    l.gotoBottom()
    check l.selected.title == "item 10"
    l.gotoTop()
    check l.selected.title == "item 1"
