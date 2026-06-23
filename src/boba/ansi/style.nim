## SGR style model — port of `x/ansi/style.go`.
##
## A `Style` is the set of text attributes + colors applied to a run of cells.
## `sgr` renders it as a single `CSI ... m` sequence; `diff` renders the minimal
## sequence to transform one style into another (used heavily by the renderer).

import ./color
import ./c0

type
  UnderlineStyle* = enum
    ulNone
    ulSingle
    ulDouble
    ulCurly
    ulDotted
    ulDashed

  Attr* = enum
    aBold
    aFaint
    aItalic
    aBlink
    aReverse
    aConceal
    aStrike

  Style* = object
    attrs*: set[Attr]
    underline*: UnderlineStyle
    fg*: Color
    bg*: Color
    ul*: Color           ## underline color

const EmptyStyle* = Style(fg: NoColor, bg: NoColor, ul: NoColor,
                          underline: ulNone, attrs: {})

proc isEmpty*(s: Style): bool {.inline.} =
  s.attrs == {} and s.underline == ulNone and s.fg.isNone and s.bg.isNone and
    s.ul.isNone

proc `==`*(a, b: Style): bool =
  a.attrs == b.attrs and a.underline == b.underline and a.fg == b.fg and
    a.bg == b.bg and a.ul == b.ul

# SGR attribute on/reset parameter codes.
const
  attrOn: array[Attr, string] = ["1", "2", "3", "5", "7", "8", "9"]
  attrOff: array[Attr, string] = ["22", "22", "23", "25", "27", "28", "29"]
    ## NB: bold and faint share reset code 22.

proc underlineParam(u: UnderlineStyle): string =
  case u
  of ulNone: "24"
  of ulSingle: "4"
  of ulDouble: "21"
  of ulCurly: "4:3"
  of ulDotted: "4:4"
  of ulDashed: "4:5"

proc sgrParams*(s: Style): string =
  ## The semicolon-joined SGR parameters for this style (no CSI/`m`).
  if s.isEmpty: return "0"
  var parts: seq[string]
  for a in Attr:
    if a in s.attrs: parts.add attrOn[a]
  if s.underline != ulNone:
    parts.add underlineParam(s.underline)
  if not s.fg.isNone: parts.add s.fg.fgParams()
  if not s.bg.isNone: parts.add s.bg.bgParams()
  if not s.ul.isNone: parts.add s.ul.underlineColorParams()
  if parts.len == 0: return "0"
  result = parts[0]
  for i in 1 ..< parts.len:
    result.add ';'
    result.add parts[i]

proc sgr*(s: Style): string =
  ## Full `CSI ... m` sequence for this style. Empty style → reset (`CSI 0 m`).
  CSI & sgrParams(s) & "m"

proc styled*(s: Style, str: string): string =
  ## Wraps `str` in this style, resetting afterwards.
  if s.isEmpty: return str
  sgr(s) & str & CSI & "0m"

proc diff*(frm, to: Style): string =
  ## Minimal SGR sequence to go from style `frm` to style `to`.
  if frm == to: return ""
  if to.isEmpty:
    return CSI & "0m"

  var parts: seq[string]

  # Attributes: turn on those newly set, turn off those newly cleared.
  for a in Attr:
    let was = a in frm.attrs
    let now = a in to.attrs
    if now and not was: parts.add attrOn[a]
    elif was and not now:
      # Avoid emitting a 22 reset twice for the bold/faint pair.
      if not (a == aFaint and aBold in frm.attrs and aBold notin to.attrs):
        parts.add attrOff[a]

  if frm.underline != to.underline:
    parts.add underlineParam(to.underline)
  if frm.fg != to.fg:
    parts.add to.fg.fgParams()
  if frm.bg != to.bg:
    parts.add to.bg.bgParams()
  if frm.ul != to.ul:
    parts.add to.ul.underlineColorParams()

  if parts.len == 0: return ""
  result = CSI
  for i, p in parts:
    if i > 0: result.add ';'
    result.add p
  result.add 'm'

# Convenience builders.
proc withFg*(s: Style, c: Color): Style = (result = s; result.fg = c)
proc withBg*(s: Style, c: Color): Style = (result = s; result.bg = c)
proc withUl*(s: Style, c: Color): Style = (result = s; result.ul = c)
proc withAttr*(s: Style, a: Attr): Style = (result = s; result.attrs.incl a)
proc withUnderline*(s: Style, u: UnderlineStyle): Style =
  (result = s; result.underline = u)
proc bold*(s: Style): Style = s.withAttr(aBold)
proc faint*(s: Style): Style = s.withAttr(aFaint)
proc italic*(s: Style): Style = s.withAttr(aItalic)
proc reverse*(s: Style): Style = s.withAttr(aReverse)
