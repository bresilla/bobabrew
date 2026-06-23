import std/[unittest, strutils]
import ../src/boba
import ../src/boba/bubbles

proc special(code: int32, mods: set[KeyMod] = {}): Msg =
  newKeyPress(Key(code: code, mods: mods))

proc letter(c: char): Msg =
  newKeyPress(Key(code: int32(c.ord), text: $c))

suite "bubbles/viewport":
  test "shows first window":
    var v = newViewport(10, 2)
    v.setContent("a\nb\nc\nd")
    check v.view.split('\n').len == 2
    check v.view.split('\n')[0].startsWith("a")
    check v.atTop

  test "scroll down":
    var v = newViewport(10, 2)
    v.setContent("a\nb\nc\nd")
    v.lineDown()
    check v.view.split('\n')[0].startsWith("b")

  test "clamps at bottom":
    var v = newViewport(10, 2)
    v.setContent("a\nb\nc\nd")
    v.gotoBottom()
    check v.atBottom
    v.lineDown(100)
    check v.atBottom
    check v.view.split('\n')[0].startsWith("c")  # last 2 lines: c,d

  test "key driven scroll":
    var v = newViewport(10, 2)
    v.setContent("a\nb\nc\nd\ne")
    v.update(letter('j'))
    check not v.atTop
    v.update(special(KeyHome))
    check v.atTop

  test "scroll percent":
    var v = newViewport(10, 2)
    v.setContent("a\nb\nc\nd")  # maxOffset = 2
    check v.scrollPercent == 0.0
    v.gotoBottom()
    check v.scrollPercent == 1.0

suite "bubbles/paginator":
  test "total pages":
    var p = newPaginator(10)
    p.totalItems = 25
    check p.totalPages == 3

  test "next/prev clamps":
    var p = newPaginator(10)
    p.totalItems = 25
    check p.onFirstPage
    p.prevPage()
    check p.page == 0
    p.nextPage(); p.nextPage(); p.nextPage()
    check p.onLastPage
    check p.page == 2

  test "slice bounds":
    var p = newPaginator(10)
    p.totalItems = 25
    p.nextPage()
    check p.sliceBounds(25) == (10, 20)
    p.nextPage()
    check p.sliceBounds(25) == (20, 25)

  test "arabic view":
    var p = newPaginator(10)
    p.totalItems = 25
    check p.view == "1/3"

  test "dots view":
    var p = newPaginator(10)
    p.totalItems = 25
    p.kind = pkDots
    check p.view == "•○○"

  test "key navigation":
    var p = newPaginator(10)
    p.totalItems = 25
    p.update(special(KeyRight))
    check p.page == 1
    p.update(special(KeyLeft))
    check p.page == 0
