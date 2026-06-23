## The cell model — port of `ultraviolet/cell.go`.
##
## A `Cell` is one terminal grid position: a grapheme (usually one rune), its
## display width, an SGR `Style`, and an optional hyperlink. Wide characters
## occupy a width-2 cell followed by a width-0 spacer cell.

import ../ansi/style
import ../ansi/width

type
  Link* = object
    url*: string
    params*: string

  Cell* = object
    content*: string   ## the grapheme content ("" == spacer/continuation)
    width*: int        ## display width: 0 (spacer), 1, or 2
    style*: Style
    link*: Link

const
  EmptyCell* = Cell(content: " ", width: 1, style: EmptyStyle, link: Link())
    ## a blank, default-styled cell
  SpacerCell* = Cell(content: "", width: 0, style: EmptyStyle, link: Link())
    ## the trailing half of a wide character

proc `==`*(a, b: Link): bool = a.url == b.url and a.params == b.params

proc `==`*(a, b: Cell): bool =
  a.content == b.content and a.width == b.width and a.style == b.style and
    a.link == b.link

proc isEmpty*(c: Cell): bool {.inline.} =
  ## True if the cell is a blank, default-styled space.
  (c.content == " " or c.content == "") and c.style.isEmpty and
    c.link.url.len == 0

proc newCell*(grapheme: string): Cell =
  ## Build a cell from a grapheme, computing its display width.
  if grapheme.len == 0:
    return SpacerCell
  Cell(content: grapheme, width: stringWidth(grapheme), style: EmptyStyle,
       link: Link())

proc blank*(style: Style): Cell =
  ## A blank cell carrying a background style (used to clear regions).
  Cell(content: " ", width: 1, style: style, link: Link())
