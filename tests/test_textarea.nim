import std/[unittest, strutils]
import ../src/boba
import ../src/boba/bubbles

proc special(code: int32): Msg = newKeyPress(Key(code: code))
proc letter(c: char): Msg = newKeyPress(Key(code: int32(c.ord), text: $c))

suite "bubbles/textarea":
  test "type across newline":
    var ta = newTextArea()
    ta.update(letter('a'))
    ta.update(special(KeyEnter))
    ta.update(letter('b'))
    check ta.value == "a\nb"
    check ta.row == 1
    check ta.col == 1

  test "backspace joins lines":
    var ta = newTextArea()
    ta.setValue("ab\ncd")
    ta.row = 1; ta.col = 0
    ta.update(special(KeyBackspace))
    check ta.value == "abcd"
    check ta.row == 0
    check ta.col == 2

  test "delete at line end joins next":
    var ta = newTextArea()
    ta.setValue("ab\ncd")
    ta.row = 0; ta.col = 2
    ta.update(special(KeyDelete))
    check ta.value == "abcd"

  test "left wraps to previous line end":
    var ta = newTextArea()
    ta.setValue("ab\ncd")
    ta.row = 1; ta.col = 0
    ta.update(special(KeyLeft))
    check ta.row == 0
    check ta.col == 2

  test "up/down clamps column":
    var ta = newTextArea()
    ta.setValue("a\nlongline")
    ta.row = 1; ta.col = 8
    ta.update(special(KeyUp))
    check ta.row == 0
    check ta.col == 1   # clamped to "a" length

  test "value round trip":
    var ta = newTextArea()
    ta.setValue("hello\nworld\n!")
    check ta.value == "hello\nworld\n!"

  test "view shows lines":
    var ta = newTextArea(20, 3)
    ta.setValue("one\ntwo")
    ta.focused = false
    check ta.view.split('\n') == @["one", "two"]
