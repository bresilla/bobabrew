import std/[unittest, unicode, strutils]
import ../src/boba
import ../src/boba/bubbles

proc keyMsg(s: string): Msg =
  ## Build a printable key press.
  newKeyPress(Key(code: int32(s.runeAt(0)), text: s))

proc special(code: int32, mods: set[KeyMod] = {}): Msg =
  newKeyPress(Key(code: code, mods: mods))

suite "bubbles/textinput":
  test "typing inserts text":
    var ti = newTextInput()
    ti.update(keyMsg("h"))
    ti.update(keyMsg("i"))
    check ti.value == "hi"
    check ti.cursor == 2

  test "backspace deletes":
    var ti = newTextInput()
    ti.setValue("abc")
    ti.update(special(KeyBackspace))
    check ti.value == "ab"

  test "cursor movement + insertion":
    var ti = newTextInput()
    ti.setValue("ac")
    ti.update(special(KeyLeft))        # cursor between a and c
    ti.update(keyMsg("b"))
    check ti.value == "abc"

  test "home / end":
    var ti = newTextInput()
    ti.setValue("hello")
    ti.update(special(KeyHome))
    check ti.cursor == 0
    ti.update(special(KeyEnd))
    check ti.cursor == 5

  test "ctrl+u kills to start":
    var ti = newTextInput()
    ti.setValue("hello")
    ti.update(special(KeyHome))
    ti.update(special(KeyEnd))
    ti.update(special(int32('u'.ord), {modCtrl}))
    check ti.value == ""

  test "char limit":
    var ti = newTextInput()
    ti.charLimit = 2
    ti.update(keyMsg("a")); ti.update(keyMsg("b")); ti.update(keyMsg("c"))
    check ti.value == "ab"

  test "renders prompt + content":
    var ti = newTextInput()
    ti.focused = false
    ti.setValue("hi")
    check ti.view.startsWith("> ")
    check "hi" in ti.view

suite "bubbles/progress":
  test "empty bar":
    var p = newProgress(20)
    p.showPercentage = false
    p.setPercent(0.0)
    check "█" notin p.view

  test "half bar":
    var p = newProgress(20)
    p.showPercentage = false
    p.setPercent(0.5)
    check "█" in p.view
    check "░" in p.view

  test "percentage label":
    var p = newProgress(20)
    p.setPercent(0.42)
    check "42%" in p.view

  test "clamps":
    var p = newProgress(10)
    p.setPercent(5.0)
    check p.percent == 1.0

suite "bubbles/spinner":
  test "advances on tick":
    var s = newSpinner(LineFrames)
    check s.view == "|"
    let cmd = s.update(SpinnerTickMsg())
    check s.view == "/"
    check cmd != nil

  test "ignores other messages":
    var s = newSpinner(LineFrames)
    let cmd = s.update(keyMsg("x"))
    check s.view == "|"
    check cmd == nil

  test "wraps around":
    var s = newSpinner(LineFrames)
    for _ in 0 ..< 4: discard s.update(SpinnerTickMsg())
    check s.view == "|"
