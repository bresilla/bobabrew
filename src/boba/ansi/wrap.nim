## Width-aware truncate and word-wrap — port of `x/ansi/truncate.go` + `wrap.go`
## (core paths). Widths are measured with `stringWidth`, so embedded ANSI escape
## sequences don't count toward the visible width.

import std/[unicode, strutils]
import ./width
import ./c0

proc isEscStart(s: string, i: int): bool =
  i < s.len and s[i] == ESC

proc copyEsc(s: string, i: var int, dst: var string) =
  ## Copy a full escape sequence starting at i (assumes s[i] == ESC).
  let n = s.len
  if i + 1 >= n:
    dst.add s[i]; inc i; return
  let nxt = s[i + 1]
  case nxt
  of '[':
    let start = i
    i += 2
    while i < n and (s[i] < '\x40' or s[i] > '\x7e'): inc i
    if i < n: inc i
    dst.add s[start ..< i]
  of ']':
    let start = i
    i += 2
    while i < n:
      if s[i] == BEL: (inc i; break)
      if s[i] == ESC and i + 1 < n and s[i + 1] == '\\': (i += 2; break)
      inc i
    dst.add s[start ..< i]
  else:
    dst.add s[i]; dst.add s[i + 1]; i += 2

proc truncate*(s: string, maxWidth: int, tail = ""): string =
  ## Truncate `s` to at most `maxWidth` display columns, appending `tail` (e.g.
  ## "…") within the limit. ANSI sequences are preserved and don't count.
  if maxWidth <= 0: return ""
  let tw = stringWidth(tail)
  let limit = max(maxWidth - tw, 0)
  var w = 0
  var i = 0
  let n = s.len
  var truncated = false
  while i < n:
    if isEscStart(s, i):
      copyEsc(s, i, result)
      continue
    var r: Rune
    let start = i
    fastRuneAt(s, i, r, true)
    let rw = runeWidth(r)
    if w + rw > limit:
      truncated = true
      break
    result.add s[start ..< i]
    w += rw
  if truncated and tail.len > 0:
    result.add tail

proc wrap*(s: string, width: int): string =
  ## Word-wrap `s` to `width` columns. Existing newlines are preserved; words
  ## longer than `width` are hard-broken.
  if width <= 0: return s
  var outLines: seq[string]
  for paragraph in s.split('\n'):
    var line = ""
    var lineW = 0
    for word in paragraph.split(' '):
      let ww = stringWidth(word)
      if lineW == 0:
        if ww <= width:
          line = word; lineW = ww
        else:
          # Hard-break an over-long first word.
          var rest = word
          while stringWidth(rest) > width:
            let head = truncate(rest, width)
            outLines.add head
            rest = rest[head.len .. ^1]
          line = rest; lineW = stringWidth(rest)
      elif lineW + 1 + ww <= width:
        line.add ' '; line.add word; lineW += 1 + ww
      else:
        outLines.add line
        if ww <= width:
          line = word; lineW = ww
        else:
          var rest = word
          while stringWidth(rest) > width:
            let head = truncate(rest, width)
            outLines.add head
            rest = rest[head.len .. ^1]
          line = rest; lineW = stringWidth(rest)
    outLines.add line
  result = outLines.join("\n")
