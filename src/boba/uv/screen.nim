## A high-level drawing surface — pragmatic port of
## `ultraviolet/terminal_screen.go`.
##
## Wraps a `Buffer` you draw into and a `TerminalRenderer` that produces the
## minimal byte diff between successive `render`s. Convenient for code that wants
## to draw cells/components and emit updates without managing the diff manually.

import ./cell
import ./buffer
import ./styled
import ./renderer
import ./window

type
  TerminalScreen* = object
    buf: Buffer
    rnd: TerminalRenderer
    width*, height*: int

proc newTerminalScreen*(width, height: int): TerminalScreen =
  result.width = width
  result.height = height
  result.buf = newBuffer(width, height)
  result.rnd = newTerminalRenderer(width, height)

proc buffer*(s: TerminalScreen): Buffer = s.buf

proc setCell*(s: var TerminalScreen, x, y: int, c: Cell) =
  s.buf.setCell(x, y, c)

proc clear*(s: var TerminalScreen) = s.buf.clear()

proc draw*(s: var TerminalScreen, content: string, atX = 0, atY = 0) =
  ## Draw a (styled) string into the screen at (atX, atY).
  if atX == 0 and atY == 0:
    newStyledString(content).draw(s.buf)
  else:
    var tmp = newBuffer(s.width, s.height)
    newStyledString(content).draw(tmp)
    s.buf.blit(tmp, atX, atY)

proc resize*(s: var TerminalScreen, width, height: int) =
  s.width = width
  s.height = height
  s.buf.resize(width, height)
  s.rnd.resize(width, height)

proc render*(s: var TerminalScreen): string =
  ## Emit the minimal byte diff to bring the terminal to the current buffer.
  s.rnd.render(s.buf)

proc reset*(s: var TerminalScreen) =
  s.buf.clear()
  s.rnd.reset()
