import std/[unittest, tables]
import ../src/boba/colorprofile
import ../src/boba/ansi/color

proc env(pairs: varargs[(string, string)]): Table[string, string] =
  result = initTable[string, string]()
  for (k, v) in pairs: result[k] = v

suite "colorprofile detect":
  test "not a tty":
    check detect(false, env(("TERM", "xterm-256color"))) == NoTTY

  test "COLORTERM truecolor":
    check detect(true, env(("COLORTERM", "truecolor"))) == TrueColor

  test "256color TERM":
    check detect(true, env(("TERM", "xterm-256color"))) == ANSI256

  test "plain ansi TERM":
    check detect(true, env(("TERM", "xterm"))) == ANSI

  test "dumb terminal":
    check detect(true, env(("TERM", "dumb"))) == Ascii

  test "NO_COLOR forces ascii":
    check detect(true, env(("NO_COLOR", "1"), ("TERM", "xterm-256color"))) == Ascii

suite "colorprofile convert":
  test "truecolor passes through":
    check convert(TrueColor, trueColor(1, 2, 3)) == trueColor(1, 2, 3)

  test "ansi256 degrades truecolor to index":
    let c = convert(ANSI256, trueColor(255, 0, 0))
    check c.kind == ckExtended

  test "ansi degrades to one of 16":
    let c = convert(ANSI, trueColor(255, 0, 0))
    check c.kind == ckBasic
    check c.basic < 16

  test "ascii strips color":
    check convert(Ascii, trueColor(1, 2, 3)) == NoColor

  test "pure red maps to red-ish in 256":
    let c = convert(ANSI256, trueColor(255, 0, 0))
    # xterm index 196 is pure red; allow the nearest match.
    check c.index in [9'u8, 196'u8]
