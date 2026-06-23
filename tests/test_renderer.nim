## Renderer output tests. The renderer writes to a File, so we point it at a
## temp file, render frames, and inspect the emitted byte stream. This is the
## seed of the golden-output testing approach from docs/PLAN.md §9.

import std/[unittest, os, strutils, options]
import ../src/boba/tea/renderer
import ../src/boba/tea/view
import ../src/boba/ansi/sequences

proc withCapture(body: proc (r: var Renderer)): string =
  let path = getTempDir() / "boba_render_test.out"
  var f = open(path, fmWrite)
  var r = newRenderer(f, 20, 5)
  body(r)
  f.close()
  result = readFile(path)
  removeFile(path)

suite "renderer inline":
  test "emits content":
    let outp = withCapture(proc (r: var Renderer) =
      r.render(newView("hello")))
    check "hello" in outp

  test "hides then shows cursor around frame":
    let outp = withCapture(proc (r: var Renderer) =
      var v = newView("x")
      v.cursor = some(newCursor(0, 0))
      r.render(v))
    # cursor enable should appear once a cursor is requested
    check "\x1b[?25h" in outp

  test "erases line right after content":
    let outp = withCapture(proc (r: var Renderer) =
      r.render(newView("hi")))
    check EraseLineRight in outp

  test "second frame moves cursor up to repaint":
    let outp = withCapture(proc (r: var Renderer) =
      r.render(newView("a\nb\nc"))
      r.render(newView("a\nb\nc")))
    # after the first 3-line frame, the second repaint moves the cursor up 2.
    check cursorUp(2) in outp

suite "renderer altscreen":
  test "enters alt screen":
    let outp = withCapture(proc (r: var Renderer) =
      var v = newView("full")
      v.altScreen = true
      r.render(v))
    check SetModeAltScreenSaveCursor in outp
    check "full" in outp

suite "renderer disabled":
  test "nil renderer writes nothing":
    let path = getTempDir() / "boba_render_nil.out"
    var f = open(path, fmWrite)
    var r = newRenderer(f, 20, 5, disabled = true)
    r.render(newView("nope"))
    f.close()
    let outp = readFile(path)
    removeFile(path)
    check outp.len == 0
