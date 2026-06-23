import std/[unittest, strutils, options]
import ../src/boba/style
import ../src/boba/ansi/color
import ../src/boba/ansi/width
import ../src/boba/uv/border

suite "style":
  test "plain text unchanged":
    check newStyle().render("hi") == "hi"

  test "bold + color wraps in SGR":
    let s = newStyle().bold.foreground(basicColor(Red))
    let r = s.render("x")
    check "\x1b[" in r
    check "x" in r
    check r.endsWith("\x1b[0m")

  test "width pads to fixed width (left align)":
    let r = newStyle().width(5).render("ab")
    check stringWidth(r) == 5

  test "center alignment":
    let r = newStyle().width(5).align(alCenter).render("a")
    # 'a' centered in width 5 => two spaces, a, two spaces
    check r == " a   " or r == "  a  "

  test "right alignment":
    let r = newStyle().width(4).align(alRight).render("a")
    check r == "   a"

  test "padding adds rows and columns":
    let r = newStyle().padding(1).render("x")
    let lines = r.split('\n')
    check lines.len == 3            # 1 blank + content + 1 blank
    check stringWidth(lines[1]) == 3  # 1 pad + x + 1 pad

  test "border wraps content":
    let r = newStyle().withBorder(roundedBorder()).render("hi")
    let lines = r.split('\n')
    check lines.len == 3
    check lines[0].startsWith("╭")
    check lines[2].endsWith("╯")

  test "width truncates overflow":
    let r = newStyle().width(3).render("abcdef")
    check stringWidth(r) == 3
    check r == "abc"

  test "height pads vertically":
    let r = newStyle().height(3).render("x")
    check r.split('\n').len == 3

  test "composed: bordered, padded, colored panel":
    let s = newStyle()
      .foreground(basicColor(BrightCyan))
      .padding(0, 1)
      .withBorder(normalBorder())
    let r = s.render("hello")
    let lines = r.split('\n')
    check lines.len == 3
    # inner width = 5 + 2 padding = 7, plus 2 border chars
    check stringWidth(lines[0]) == 9
