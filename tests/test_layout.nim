import std/[unittest, strutils]
import ../src/boba/uv/border
import ../src/boba/uv/layout
import ../src/boba/ansi/width

suite "border":
  test "rounded box":
    let b = roundedBorder().box("hi")
    let lines = b.split('\n')
    check lines.len == 3
    check lines[0] == "╭──╮"
    check lines[1] == "│hi│"
    check lines[2] == "╰──╯"

  test "pads to widest line":
    let b = normalBorder().box("a\nbcd")
    let lines = b.split('\n')
    check lines[1] == "│a  │"
    check lines[2] == "│bcd│"

  test "ascii border":
    check asciiBorder().box("x").split('\n')[0] == "+-+"

suite "layout split":
  test "fixed + proportional":
    check split(10, [fixed(3), proportional(1)]) == @[3, 7]

  test "two equal proportionals":
    check split(10, [proportional(1), proportional(1)]) == @[5, 5]

  test "weighted proportionals sum to total":
    let s = split(10, [proportional(1), proportional(3)])
    check s[0] + s[1] == 10
    check s == @[2, 8]

  test "fixed clamped to total":
    check split(5, [fixed(10), proportional(1)]) == @[5, 0]

  test "percent":
    check split(100, [percent(25), percent(75)]) == @[25, 75]
    check split(10, [percent(50), fill(1)]) == @[5, 5]

  test "ratio":
    check split(12, [ratio(1, 3), ratio(2, 3)]) == @[4, 8]

  test "fill shares remainder after fixed":
    check split(10, [length(2), fill(1), fill(1)]) == @[2, 4, 4]

  test "min grows to floor":
    let s = split(10, [fixed(8), minLen(5)])
    check s[0] == 8
    check s[1] >= 5

  test "max caps":
    let s = split(20, [maxLen(3), fill(1)])
    check s[0] <= 3

  test "solver: min floor + fill share, sum preserved":
    let s = split(10, [minLen(3), fill(1)])
    check s[0] >= 3
    check s[0] + s[1] == 10

  test "solver: two maxes spill into fill":
    let s = split(10, [maxLen(2), maxLen(2), fill(1)])
    check s[0] <= 2
    check s[1] <= 2
    check s[0] + s[1] + s[2] == 10
    check s[2] >= 6

  test "solver: fixed + min + max + fill all satisfied":
    let s = split(30, [length(5), minLen(4), maxLen(3), fill(1)])
    check s[0] == 5
    check s[1] >= 4
    check s[2] <= 3
    check s[0] + s[1] + s[2] + s[3] == 30

  test "solver: weighted fills proportional":
    let s = split(12, [fill(1), fill(2)])
    check s[0] + s[1] == 12
    check s[1] > s[0]

suite "layout join":
  test "joinHorizontal":
    let r = joinHorizontal("a\nb", "1\n2")
    check r == "a1\nb2"

  test "joinHorizontal pads uneven heights":
    let r = joinHorizontal("a\nbb", "x")
    # second block has one row; missing rows are blank, padded to width 1.
    check r.split('\n') == @["a x", "bb "]

  test "joinVertical":
    check joinVertical("a", "b", "c") == "a\nb\nc"

suite "layout place":
  test "placeHorizontal center":
    check placeHorizontal(5, Center, "a") == "  a  "
  test "placeHorizontal right":
    check placeHorizontal(4, Right, "a") == "   a"
  test "placeVertical center":
    let r = placeVertical(3, Center, "x")
    check r.split('\n') == @[" ", "x", " "]
  test "place in box":
    let r = place(3, 3, Center, Center, "x")
    let lines = r.split('\n')
    check lines.len == 3
    check lines[1] == " x "
  test "joinHorizontalAligned middle":
    let r = joinHorizontalAligned(Center, "a\nb\nc", "X")
    # X is vertically centered against the 3-row block
    check r.split('\n')[1] == "bX"
