## Box-drawing borders — port of `ultraviolet/border.go`.
##
## A `Border` is the set of glyphs for the four sides and corners. `box` wraps a
## (possibly multi-line) string in a border, padding each line to the widest so
## the box is rectangular. Width is measured with `ansi.stringWidth`, so styled
## and wide-character content boxes correctly.

import std/strutils
import ../ansi/width

type
  Border* = object
    top*, bottom*, left*, right*: string
    topLeft*, topRight*, bottomLeft*, bottomRight*: string

proc normalBorder*(): Border =
  Border(top: "─", bottom: "─", left: "│", right: "│",
         topLeft: "┌", topRight: "┐", bottomLeft: "└", bottomRight: "┘")

proc roundedBorder*(): Border =
  Border(top: "─", bottom: "─", left: "│", right: "│",
         topLeft: "╭", topRight: "╮", bottomLeft: "╰", bottomRight: "╯")

proc thickBorder*(): Border =
  Border(top: "━", bottom: "━", left: "┃", right: "┃",
         topLeft: "┏", topRight: "┓", bottomLeft: "┗", bottomRight: "┛")

proc doubleBorder*(): Border =
  Border(top: "═", bottom: "═", left: "║", right: "║",
         topLeft: "╔", topRight: "╗", bottomLeft: "╚", bottomRight: "╝")

proc blockBorder*(): Border =
  Border(top: "█", bottom: "█", left: "█", right: "█",
         topLeft: "█", topRight: "█", bottomLeft: "█", bottomRight: "█")

proc asciiBorder*(): Border =
  Border(top: "-", bottom: "-", left: "|", right: "|",
         topLeft: "+", topRight: "+", bottomLeft: "+", bottomRight: "+")

proc hiddenBorder*(): Border =
  Border(top: " ", bottom: " ", left: " ", right: " ",
         topLeft: " ", topRight: " ", bottomLeft: " ", bottomRight: " ")

proc box*(b: Border, content: string): string =
  ## Wrap `content` in the border, padding to the widest line.
  let lines = content.split('\n')
  var w = 0
  for ln in lines: w = max(w, stringWidth(ln))

  proc rep(s: string, n: int): string =
    for _ in 0 ..< n: result.add s

  result = b.topLeft & rep(b.top, w) & b.topRight & "\n"
  for ln in lines:
    let pad = w - stringWidth(ln)
    result.add b.left & ln & spaces(pad) & b.right & "\n"
  result.add b.bottomLeft & rep(b.bottom, w) & b.bottomRight
