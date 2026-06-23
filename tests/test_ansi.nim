import std/unittest
import std/unicode
import ../src/boba/ansi

suite "ansi/color":
  test "SGR foreground params":
    check basicColor(Red).fgParams == "31"
    check basicColor(BrightRed).fgParams == "91"
    check extendedColor(123).fgParams == "38;5;123"
    check trueColor(10, 20, 30).fgParams == "38;2;10;20;30"
    check NoColor.fgParams == "39"

  test "SGR background params":
    check basicColor(Blue).bgParams == "44"
    check basicColor(BrightBlue).bgParams == "104"
    check trueColor(1, 2, 3).bgParams == "48;2;1;2;3"

  test "hex":
    check trueColor(0xff, 0x00, 0x80).hex == "#ff0080"
    check basicColor(Red).hex == "#800000"
    check basicColor(BrightWhite).hex == "#ffffff"

  test "equality":
    check basicColor(Red) == basicColor(Red)
    check basicColor(Red) != basicColor(Green)
    check NoColor == NoColor
    check trueColor(1, 2, 3) != extendedColor(1)

  test "adaptive picks by darkness":
    let c = adaptive(basicColor(Black), basicColor(White), isDark = true)
    check c == basicColor(White)
    check adaptive(trueColor(0,0,0), trueColor(255,255,255), false) == trueColor(0,0,0)

  test "lerp midpoint":
    check lerp(trueColor(0, 0, 0), trueColor(10, 20, 40), 0.5) == trueColor(5, 10, 20)

  test "gradient endpoints":
    let g = gradient(trueColor(0, 0, 0), trueColor(255, 0, 0), 3)
    check g.len == 3
    check g[0] == trueColor(0, 0, 0)
    check g[2] == trueColor(255, 0, 0)

suite "ansi/style":
  test "empty style is reset":
    check EmptyStyle.sgr == "\x1b[0m"
    check EmptyStyle.isEmpty

  test "single attr":
    check EmptyStyle.bold.sgr == "\x1b[1m"
    check EmptyStyle.italic.sgr == "\x1b[3m"

  test "compound style":
    let s = EmptyStyle.bold.withFg(basicColor(Red)).withBg(basicColor(Blue))
    check s.sgr == "\x1b[1;31;44m"

  test "styled wraps and resets":
    check EmptyStyle.bold.styled("hi") == "\x1b[1mhi\x1b[0m"
    check EmptyStyle.styled("hi") == "hi"

  test "diff to empty resets":
    let a = EmptyStyle.bold.withFg(basicColor(Red))
    check diff(a, EmptyStyle) == "\x1b[0m"

  test "diff identical is empty":
    let a = EmptyStyle.bold
    check diff(a, a) == ""

  test "diff adds and removes":
    let a = EmptyStyle.bold
    let b = EmptyStyle.italic
    # turn off bold (22), turn on italic (3)
    check diff(a, b) == "\x1b[22;3m"

  test "diff changes color only":
    let a = EmptyStyle.withFg(basicColor(Red))
    let b = EmptyStyle.withFg(basicColor(Green))
    check diff(a, b) == "\x1b[32m"

suite "ansi/width":
  test "ascii":
    check stringWidth("hello") == 5
    check runeWidth(Rune('a'.ord)) == 1

  test "wide CJK":
    check runeWidth("世".runeAt(0)) == 2
    check stringWidth("世界") == 4

  test "combining marks are zero width":
    check runeWidth(Rune(0x0301)) == 0  # combining acute accent

  test "control chars are zero width":
    check runeWidth(Rune(0)) == 0

  test "skips ANSI escapes":
    check stringWidth("\x1b[1;31mhi\x1b[0m") == 2
    check stringWidth("\x1b]2;title\x07x") == 1

suite "ansi/sequences":
  test "cursor movement":
    check cursorUp(3) == "\x1b[3A"
    check cursorUp(0) == ""
    check moveTo(0, 0) == "\x1b[1;1H"
    check moveTo(4, 2) == "\x1b[3;5H"

  test "modes":
    check SetModeBracketedPaste == "\x1b[?2004h"
    check ResetModeAltScreenSaveCursor == "\x1b[?1049l"
    check SetModeSynchronizedOutput == "\x1b[?2026h"

  test "osc":
    check setWindowTitle("hi") == "\x1b]2;hi\x07"
    check setForegroundColor(trueColor(255, 0, 0)) == "\x1b]10;#ff0000\x07"

  test "kitty":
    check kittyKeyboard(1, 1) == "\x1b[=1;1u"
