## Display-width calculation — port of `x/ansi/width.go` (which wraps
## `uniseg`/`runewidth`).
##
## `runeWidth` implements a wcwidth-style table covering combining/zero-width
## marks and East-Asian wide / emoji ranges. `stringWidth` measures the visible
## width of a string, skipping any embedded ANSI escape sequences.
##
## NOTE: full UAX#29 grapheme-cluster segmentation (the `GraphemeWidth` method,
## terminal mode 2027) is approximated here by per-rune widths. Exact grapheme
## clustering is a planned deepening task (see docs/PLAN.md M1).

import std/unicode
import ./c0

type
  Method* = enum
    WcWidth        ## measure by wcwidth (default)
    GraphemeWidth  ## measure by grapheme cluster (mode 2027)

# Zero-width: combining marks, ZWJ/ZWNJ, variation selectors, etc.
const zeroWidthRanges: array[0 .. 23, tuple[lo, hi: int32]] = [
  (0x0300'i32, 0x036F'i32),   # combining diacritical marks
  (0x0483'i32, 0x0489'i32),
  (0x0591'i32, 0x05BD'i32),
  (0x0610'i32, 0x061A'i32),
  (0x064B'i32, 0x065F'i32),
  (0x0670'i32, 0x0670'i32),
  (0x06D6'i32, 0x06DC'i32),
  (0x06DF'i32, 0x06E4'i32),
  (0x0900'i32, 0x0902'i32),
  (0x093C'i32, 0x093C'i32),
  (0x0941'i32, 0x0948'i32),
  (0x0E31'i32, 0x0E31'i32),
  (0x0E34'i32, 0x0E3A'i32),
  (0x1AB0'i32, 0x1AFF'i32),
  (0x1DC0'i32, 0x1DFF'i32),
  (0x200B'i32, 0x200F'i32),   # ZWSP, ZWNJ, ZWJ, LRM, RLM
  (0x20D0'i32, 0x20FF'i32),   # combining marks for symbols
  (0xFE00'i32, 0xFE0F'i32),   # variation selectors
  (0xFE20'i32, 0xFE2F'i32),   # combining half marks
  (0x1D167'i32, 0x1D169'i32),
  (0x1D17B'i32, 0x1D182'i32),
  (0xE0100'i32, 0xE01EF'i32), # variation selectors supplement
  (0x070F'i32, 0x070F'i32),   # syriac abbreviation mark
  (0x00AD'i32, 0x00AD'i32),   # soft hyphen
]

# East-Asian Wide / Fullwidth and 2-cell emoji ranges.
const wideRanges: array[0 .. 21, tuple[lo, hi: int32]] = [
  (0x1100'i32, 0x115F'i32),   # Hangul Jamo
  (0x2329'i32, 0x232A'i32),
  (0x2E80'i32, 0x303E'i32),   # CJK radicals, Kangxi, symbols
  (0x3041'i32, 0x33FF'i32),   # Hiragana .. CJK compat
  (0x3400'i32, 0x4DBF'i32),   # CJK Ext A
  (0x4E00'i32, 0x9FFF'i32),   # CJK Unified
  (0xA000'i32, 0xA4CF'i32),   # Yi
  (0xAC00'i32, 0xD7A3'i32),   # Hangul syllables
  (0xF900'i32, 0xFAFF'i32),   # CJK compat ideographs
  (0xFE10'i32, 0xFE19'i32),   # vertical forms
  (0xFE30'i32, 0xFE6F'i32),   # CJK compat / small forms
  (0xFF00'i32, 0xFF60'i32),   # fullwidth forms
  (0xFFE0'i32, 0xFFE6'i32),
  (0x1F300'i32, 0x1F64F'i32), # misc symbols & pictographs, emoticons
  (0x1F900'i32, 0x1F9FF'i32), # supplemental symbols & pictographs
  (0x1FA70'i32, 0x1FAFF'i32),
  (0x20000'i32, 0x2FFFD'i32), # CJK Ext B+
  (0x30000'i32, 0x3FFFD'i32),
  (0x1F000'i32, 0x1F02F'i32), # mahjong
  (0x1F0A0'i32, 0x1F0FF'i32), # playing cards
  (0x1F200'i32, 0x1F2FF'i32), # enclosed ideographic supplement
  (0x1F600'i32, 0x1F64F'i32), # emoticons (overlaps; harmless)
]

proc inRanges(c: int32, ranges: openArray[tuple[lo, hi: int32]]): bool =
  # Linear scan; ranges are small and this is not on the hot path for ASCII.
  for r in ranges:
    if c < r.lo: continue
    if c <= r.hi: return true
  result = false

proc runeWidth*(r: Rune): int =
  ## The terminal cell width of a single rune: 0, 1, or 2.
  let c = int32(r)
  if c == 0: return 0
  if c < 0x20 or (c >= 0x7f and c < 0xa0): return 0  # C0/C1 controls
  if c < 0x7f: return 1                              # fast path: ASCII
  if inRanges(c, zeroWidthRanges): return 0
  if inRanges(c, wideRanges): return 2
  result = 1

proc stringWidth*(s: string): int =
  ## Visible width of `s`, skipping embedded ANSI escape sequences.
  var i = 0
  let n = s.len
  while i < n:
    let ch = s[i]
    if ch == ESC and i + 1 < n:
      let nxt = s[i + 1]
      case nxt
      of '[':
        # CSI: ESC [ ... final byte in 0x40..0x7e
        i += 2
        while i < n and (s[i] < '\x40' or s[i] > '\x7e'): inc i
        if i < n: inc i
        continue
      of ']':
        # OSC: ESC ] ... terminated by BEL or ST (ESC \)
        i += 2
        while i < n:
          if s[i] == BEL: (inc i; break)
          if s[i] == ESC and i + 1 < n and s[i + 1] == '\\': (i += 2; break)
          inc i
        continue
      of 'P', 'X', '^', '_':
        # DCS/SOS/PM/APC: terminated by ST
        i += 2
        while i < n:
          if s[i] == ESC and i + 1 < n and s[i + 1] == '\\': (i += 2; break)
          inc i
        continue
      else:
        i += 2  # two-byte escape
        continue
    # Decode one UTF-8 rune.
    var r: Rune
    fastRuneAt(s, i, r, true)
    result += runeWidth(r)
