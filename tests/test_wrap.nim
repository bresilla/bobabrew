import std/[unittest, strutils]
import ../src/boba/ansi/wrap
import ../src/boba/ansi/width

suite "truncate":
  test "no-op when short":
    check truncate("hello", 10) == "hello"

  test "cuts to width":
    check truncate("hello world", 5) == "hello"

  test "with ellipsis tail":
    let r = truncate("hello world", 8, "…")
    check stringWidth(r) <= 8
    check r.endsWith("…")

  test "preserves ANSI, counts visible only":
    let r = truncate("\x1b[31mhello\x1b[0m world", 5)
    check stringWidth(r) == 5
    check "\x1b[31m" in r

  test "wide chars":
    check truncate("世界ab", 2) == "世"

suite "wrap":
  test "wraps on word boundary":
    check wrap("the quick brown fox", 10) == "the quick\nbrown fox"

  test "preserves existing newlines":
    check wrap("a b\nc d", 10) == "a b\nc d"

  test "hard-breaks long word":
    let r = wrap("abcdefghij", 4)
    check r.split('\n').len == 3
    check r.split('\n')[0] == "abcd"

  test "short text unchanged":
    check wrap("hi there", 20) == "hi there"
