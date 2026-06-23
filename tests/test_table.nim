import std/[unittest, strutils]
import ../src/boba
import ../src/boba/bubbles
import ../src/boba/ansi/width

proc special(code: int32): Msg = newKeyPress(Key(code: code))

proc sampleTable(): Table =
  newTable(
    @[column("Name", 6), column("Age", 3)],
    @[@["Ann", "30"], @["Bob", "25"], @["Cara", "41"], @["Dan", "19"]],
    height = 2)

suite "bubbles/table":
  test "selected row":
    var t = sampleTable()
    check t.selectedRow == @["Ann", "30"]
    t.update(special(KeyDown))
    check t.selectedRow == @["Bob", "25"]

  test "scrolls with cursor":
    var t = sampleTable()
    t.update(special(KeyDown))
    t.update(special(KeyDown))
    t.update(special(KeyDown))
    check t.selectedRow == @["Dan", "19"]
    check t.offset > 0

  test "view has header + window rows":
    let t = sampleTable()
    let lines = t.view.split('\n')
    check lines.len == 3   # header + 2 body rows
    check "Name" in lines[0]

  test "cells fit column width":
    let t = newTable(@[column("X", 3)], @[@["toolong"]], 1)
    let body = t.view.split('\n')[1]
    check stringWidth(body) == 3   # truncated to width with ellipsis
