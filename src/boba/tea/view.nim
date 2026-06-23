## View — port of the `View` struct from tea.go. A `View` is what `Model.view`
## returns each frame: the screen content plus terminal state the renderer
## should apply (altscreen, cursor, colors, mouse mode, title, …).

import std/options
import ../ansi/color

type
  CursorShape* = enum
    csBlock
    csUnderline
    csBar

  Cursor* = object
    x*, y*: int
    color*: Color
    shape*: CursorShape
    blink*: bool

  MouseMode* = enum
    mmNone
    mmCellMotion
    mmAllMotion

  ProgressBarState* = enum
    pbNone, pbDefault, pbError, pbIndeterminate, pbWarning

  ProgressBar* = object
    state*: ProgressBarState
    value*: int

  View* = object
    content*: string
    altScreen*: bool
    cursor*: Option[Cursor]
    mouseMode*: MouseMode
    reportFocus*: bool
    disableBracketedPaste*: bool
    windowTitle*: string
    foregroundColor*: Color
    backgroundColor*: Color
    progressBar*: Option[ProgressBar]

proc newCursor*(x, y: int): Cursor =
  Cursor(x: x, y: y, color: NoColor, shape: csBlock, blink: true)

proc newView*(content: string): View =
  ## Convenience constructor mirroring `tea.NewView`.
  result.content = content
  result.foregroundColor = NoColor
  result.backgroundColor = NoColor

proc setContent*(v: var View, s: string) = v.content = s
