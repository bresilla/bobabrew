## StyledString — port of `ultraviolet/styled.go`.
##
## Parses a string with embedded ANSI escape sequences (SGR styling and OSC 8
## hyperlinks) into lines of styled `Cell`s. This is what turns a Bubble Tea
## `View.Content` string into something the renderer can diff and draw.

import std/[unicode, strutils]
import ../ansi/style
import ../ansi/color
import ../ansi/width
import ../ansi/c0
import ./cell
import ./buffer

type
  StyledString* = object
    raw*: string

proc newStyledString*(s: string): StyledString = StyledString(raw: s)

# ---- SGR application -------------------------------------------------------

proc pi(s: string): int =
  ## Parse an int, defaulting to 0 (empty SGR params mean 0).
  try: (if s.len == 0: 0 else: parseInt(s)) except ValueError: 0

proc applySgr(params: string, st: var Style, link: var Link) =
  ## Apply one `CSI ... m` parameter list to the running style.
  if params.len == 0 or params == "0":
    st = EmptyStyle
    return
  let parts = params.split(';')
  var i = 0
  while i < parts.len:
    # A part may carry colon sub-parameters, e.g. "4:3".
    let raw = parts[i]
    let colon = raw.split(':')
    let n = pi(colon[0])
    case n
    of 0: st = EmptyStyle
    of 1: st.attrs.incl aBold
    of 2: st.attrs.incl aFaint
    of 3: st.attrs.incl aItalic
    of 4:
      if colon.len > 1:
        let sub = pi(colon[1])
        st.underline = case sub
          of 0: ulNone
          of 1: ulSingle
          of 2: ulDouble
          of 3: ulCurly
          of 4: ulDotted
          of 5: ulDashed
          else: ulSingle
      else:
        st.underline = ulSingle
    of 5: st.attrs.incl aBlink
    of 7: st.attrs.incl aReverse
    of 8: st.attrs.incl aConceal
    of 9: st.attrs.incl aStrike
    of 21: st.underline = ulDouble
    of 22: st.attrs.excl aBold; st.attrs.excl aFaint
    of 23: st.attrs.excl aItalic
    of 24: st.underline = ulNone
    of 25: st.attrs.excl aBlink
    of 27: st.attrs.excl aReverse
    of 28: st.attrs.excl aConceal
    of 29: st.attrs.excl aStrike
    of 30 .. 37: st.fg = basicColor(uint8(n - 30))
    of 39: st.fg = NoColor
    of 40 .. 47: st.bg = basicColor(uint8(n - 40))
    of 49: st.bg = NoColor
    of 90 .. 97: st.fg = basicColor(uint8(n - 90 + 8))
    of 100 .. 107: st.bg = basicColor(uint8(n - 100 + 8))
    of 59: st.ul = NoColor
    of 38, 48, 58:
      # Extended color: 5;n (indexed) or 2;r;g;b (truecolor).
      if i + 1 < parts.len:
        let mode = pi(parts[i + 1])
        var col = NoColor
        if mode == 5 and i + 2 < parts.len:
          col = extendedColor(uint8(pi(parts[i + 2])))
          i += 2
        elif mode == 2 and i + 4 < parts.len:
          col = trueColor(uint8(pi(parts[i + 2])), uint8(pi(parts[i + 3])),
                          uint8(pi(parts[i + 4])))
          i += 4
        case n
        of 38: st.fg = col
        of 48: st.bg = col
        else: st.ul = col
    else: discard
    inc i

# ---- parse to lines --------------------------------------------------------

proc lines*(s: StyledString): seq[Line] =
  ## Parse into a ragged list of cell lines (no width padding).
  result = @[]
  var cur: Line = @[]
  var st = EmptyStyle
  var link = Link()
  let raw = s.raw
  var i = 0
  let n = raw.len
  while i < n:
    let ch = raw[i]
    if ch == ESC and i + 1 < n:
      let nxt = raw[i + 1]
      case nxt
      of '[':
        # CSI: collect until a final byte (0x40..0x7e).
        var j = i + 2
        while j < n and (raw[j] < '\x40' or raw[j] > '\x7e'): inc j
        if j < n:
          let final = raw[j]
          let params = raw[i + 2 ..< j]
          if final == 'm':
            applySgr(params, st, link)
          i = j + 1
        else:
          i = n
        continue
      of ']':
        # OSC: terminated by BEL or ST. Parse OSC 8 hyperlinks.
        var j = i + 2
        var body = ""
        while j < n:
          if raw[j] == BEL: (inc j; break)
          if raw[j] == ESC and j + 1 < n and raw[j + 1] == '\\': (j += 2; break)
          body.add raw[j]
          inc j
        if body.startsWith("8;"):
          let segs = body.split(';')
          if segs.len >= 3:
            link.params = segs[1]
            link.url = segs[2]
            if link.url.len == 0: link = Link()
        i = j
        continue
      else:
        i += 2
        continue
    elif ch == '\n':
      result.add cur
      cur = @[]
      inc i
      continue
    elif ch == '\r':
      inc i
      continue
    elif ch == '\t':
      # Expand tab to the next multiple of 8 columns.
      let stop = ((cur.len div 8) + 1) * 8
      while cur.len < stop:
        cur.add Cell(content: " ", width: 1, style: st, link: link)
      inc i
      continue
    else:
      var r: Rune
      let start = i
      fastRuneAt(raw, i, r, true)
      let g = raw[start ..< i]
      let w = runeWidth(r)
      cur.add Cell(content: g, width: max(w, 1), style: st, link: link)
      if w == 2:
        cur.add SpacerCell
  result.add cur

proc height*(s: StyledString): int =
  s.lines().len

proc unicodeWidth*(s: StyledString): int =
  ## Width of the widest line.
  result = 0
  for ln in s.lines():
    var w = 0
    for c in ln: w += c.width
    result = max(result, w)

proc draw*(s: StyledString, buf: var Buffer) =
  ## Draw the styled string into `buf` starting at (0,0), clipping to bounds.
  let ls = s.lines()
  for y in 0 ..< min(ls.len, buf.lines.len):
    var x = 0
    for c in ls[y]:
      if c.width == 0 and c.content.len == 0: continue
      if x >= buf.width: break
      buf.setCell(x, y, c)
      x += max(c.width, 1)
