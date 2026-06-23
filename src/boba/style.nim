## A Lipgloss-style fluent styling layer: declarative text styling with colors,
## attributes, padding, width/height, alignment, and borders. Renders to a
## styled string suitable for a `View.content`.
##
## This is the start of the Nim "Lipgloss" companion (docs/PLAN.md §11). It
## composes `ansi` (SGR + width) and `uv.border`.

import std/[strutils, options, unicode]
import ./ansi/style as asty
import ./ansi/color
import ./ansi/width
import ./uv/border

type
  Align* = enum alLeft, alCenter, alRight

  Style* = object
    fg*, bg*, ulColor*: Color
    attrs*: set[Attr]
    underline*: UnderlineStyle
    padTop*, padRight*, padBottom*, padLeft*: int
    w*, h*: int
    hAlign*: Align
    border*: Option[Border]

proc newStyle*(): Style =
  Style(fg: NoColor, bg: NoColor, ulColor: NoColor, underline: ulNone)

# ---- fluent builders -------------------------------------------------------

proc foreground*(s: Style, c: Color): Style = (result = s; result.fg = c)
proc background*(s: Style, c: Color): Style = (result = s; result.bg = c)
proc bold*(s: Style, on = true): Style =
  (result = s; (if on: result.attrs.incl aBold else: result.attrs.excl aBold))
proc italic*(s: Style, on = true): Style =
  (result = s; (if on: result.attrs.incl aItalic else: result.attrs.excl aItalic))
proc faint*(s: Style, on = true): Style =
  (result = s; (if on: result.attrs.incl aFaint else: result.attrs.excl aFaint))
proc reverse*(s: Style, on = true): Style =
  (result = s; (if on: result.attrs.incl aReverse else: result.attrs.excl aReverse))
proc underlined*(s: Style, u = ulSingle): Style =
  (result = s; result.underline = u)
proc width*(s: Style, n: int): Style = (result = s; result.w = n)
proc height*(s: Style, n: int): Style = (result = s; result.h = n)
proc align*(s: Style, a: Align): Style = (result = s; result.hAlign = a)
proc padding*(s: Style, all: int): Style =
  result = s
  result.padTop = all; result.padRight = all
  result.padBottom = all; result.padLeft = all
proc padding*(s: Style, vertical, horizontal: int): Style =
  result = s
  result.padTop = vertical; result.padBottom = vertical
  result.padLeft = horizontal; result.padRight = horizontal
proc withBorder*(s: Style, b: Border): Style =
  (result = s; result.border = some(b))

# ---- rendering -------------------------------------------------------------

proc truncateToWidth(s: string, maxW: int): string =
  var w = 0
  var i = 0
  while i < s.len:
    var r: Rune
    let start = i
    fastRuneAt(s, i, r, true)
    let rw = max(runeWidth(r), 1)
    if w + rw > maxW: break
    result.add s[start ..< i]
    w += rw

proc toAnsi(s: Style): asty.Style =
  result = EmptyStyle
  result.attrs = s.attrs
  result.underline = s.underline
  result.fg = s.fg
  result.bg = s.bg
  result.ul = s.ulColor

proc render*(s: Style, text: string): string =
  var lines = text.split('\n')

  # Content width (or fixed width if set).
  var cw = 0
  for ln in lines: cw = max(cw, stringWidth(ln))
  let innerW = if s.w > 0: s.w else: cw

  # Horizontal alignment / width fitting.
  for i in 0 ..< lines.len:
    let lw = stringWidth(lines[i])
    if lw < innerW:
      let pad = innerW - lw
      case s.hAlign
      of alLeft: lines[i] = lines[i] & spaces(pad)
      of alRight: lines[i] = spaces(pad) & lines[i]
      of alCenter:
        let l = pad div 2
        lines[i] = spaces(l) & lines[i] & spaces(pad - l)
    elif lw > innerW and s.w > 0:
      lines[i] = truncateToWidth(lines[i], innerW)

  # Vertical height fitting.
  if s.h > 0 and lines.len < s.h:
    for _ in lines.len ..< s.h: lines.add spaces(innerW)

  # Padding (blank rows top/bottom, spaces left/right).
  let fullW = innerW + s.padLeft + s.padRight
  var padded: seq[string]
  for _ in 0 ..< s.padTop: padded.add spaces(fullW)
  for ln in lines:
    padded.add spaces(s.padLeft) & ln & spaces(s.padRight)
  for _ in 0 ..< s.padBottom: padded.add spaces(fullW)

  # Apply SGR to each full line so the background fills the whole box.
  let a = s.toAnsi()
  var outLines: seq[string]
  for ln in padded:
    outLines.add (if a.isEmpty: ln else: a.styled(ln))
  result = outLines.join("\n")

  # Border wraps the styled block.
  if s.border.isSome:
    result = s.border.get.box(result)
