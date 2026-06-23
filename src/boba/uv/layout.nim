## Layout helpers — a pragmatic subset of `ultraviolet/layout`.
##
## Provides proportional/fixed space splitting and block joining (the common
## needs of a TUI). The full constraint solver (Min/Max/Len/Percent/Ratio/Fill
## via Cassowary) is the M7 deepening goal; this covers fixed + proportional,
## which handles most real layouts.

import std/strutils
import ../ansi/width

type
  ConstraintKind* = enum
    ckFixed        ## exactly N cells (Length)
    ckProportional ## weighted share of leftover (Fill)
    ckPercent      ## N% of total
    ckRatio        ## num/den of total
    ckMin          ## flexible, but at least N
    ckMax          ## flexible, but at most N
  Constraint* = object
    kind*: ConstraintKind
    value*: int
    den*: int      ## denominator for ckRatio

proc fixed*(n: int): Constraint = Constraint(kind: ckFixed, value: n)
proc length*(n: int): Constraint = fixed(n)
proc proportional*(weight: int): Constraint =
  Constraint(kind: ckProportional, value: max(weight, 0))
proc fill*(weight: int): Constraint = proportional(weight)
proc percent*(p: int): Constraint = Constraint(kind: ckPercent, value: p)
proc ratio*(num, den: int): Constraint =
  Constraint(kind: ckRatio, value: num, den: max(den, 1))
proc minLen*(n: int): Constraint = Constraint(kind: ckMin, value: n)
proc maxLen*(n: int): Constraint = Constraint(kind: ckMax, value: n)

proc split*(total: int, constraints: openArray[Constraint]): seq[int] =
  ## Distribute `total` cells across the constraints, honoring lower/upper bounds
  ## and weights. Fixed sizes (Length/Percent/Ratio) take their requested value
  ## (scaled down together if they'd overflow); the remainder is distributed to
  ## the flexible segments (Fill = weighted, Min = floored, Max = capped) by a
  ## bounded water-filling pass: assign proportionally, clamp to each segment's
  ## bounds, then redistribute the freed-up amount among the unsaturated ones
  ## until the budget is spent. This solves the same layout constraint problem
  ## Cassowary is used for, with priorities expressed as bounds.
  let n = constraints.len
  result = newSeq[int](n)
  if n == 0: return

  var
    fixedAmt = newSeq[int](n)        # >=0 for fixed segments, -1 for flexible
    lo = newSeq[int](n)
    hi = newSeq[int](n)
    weight = newSeq[int](n)
    flexible: seq[int]
    fixedSum = 0

  for i, c in constraints:
    case c.kind
    of ckFixed:
      fixedAmt[i] = max(c.value, 0); fixedSum += fixedAmt[i]
    of ckPercent:
      fixedAmt[i] = (total * max(0, min(100, c.value))) div 100; fixedSum += fixedAmt[i]
    of ckRatio:
      fixedAmt[i] = (total * c.value) div c.den; fixedSum += fixedAmt[i]
    of ckProportional:
      fixedAmt[i] = -1; lo[i] = 0; hi[i] = high(int); weight[i] = max(c.value, 0)
      flexible.add i
    of ckMin:
      fixedAmt[i] = -1; lo[i] = max(c.value, 0); hi[i] = high(int); weight[i] = 1
      flexible.add i
    of ckMax:
      fixedAmt[i] = -1; lo[i] = 0; hi[i] = max(c.value, 0); weight[i] = 1
      flexible.add i

  # Scale fixed segments down proportionally if they'd overflow the total.
  if fixedSum > total and fixedSum > 0:
    for i in 0 ..< n:
      if fixedAmt[i] >= 0: fixedAmt[i] = fixedAmt[i] * total div fixedSum
    fixedSum = 0
    for i in 0 ..< n:
      if fixedAmt[i] >= 0: fixedSum += fixedAmt[i]

  for i in 0 ..< n:
    if fixedAmt[i] >= 0: result[i] = fixedAmt[i]

  var remaining = total - fixedSum
  # Seed flexible segments at their lower bound.
  for i in flexible:
    result[i] = lo[i]
    remaining -= lo[i]

  # Water-fill the remainder over unsaturated flexible segments.
  var active = flexible
  while remaining > 0 and active.len > 0:
    var totalW = 0
    for i in active: totalW += weight[i]
    if totalW <= 0: break

    var distributed = 0
    for i in active:
      var give = remaining * weight[i] div totalW
      let headroom = hi[i] - result[i]
      if give > headroom: give = headroom
      result[i] += give
      distributed += give
    remaining -= distributed

    if distributed == 0:
      # Rounding stalled: hand leftover units to the last unsaturated segment(s).
      var k = active.high
      while remaining > 0 and k >= 0:
        let i = active[k]
        if result[i] < hi[i]:
          inc result[i]; dec remaining
        dec k
      if remaining > 0 and distributed == 0:
        break  # no headroom anywhere

    # Drop saturated segments.
    var nextActive: seq[int]
    for i in active:
      if weight[i] > 0 and result[i] < hi[i]: nextActive.add i
    active = nextActive

proc padLine(s: string, w: int): string =
  let pad = w - stringWidth(s)
  if pad > 0: s & spaces(pad) else: s

proc joinHorizontal*(blocks: varargs[string]): string =
  ## Place multi-line blocks side by side, top-aligned, padding each block to
  ## its own widest line and to the tallest block.
  var cols: seq[seq[string]]
  var widths: seq[int]
  var maxRows = 0
  for b in blocks:
    let lines = b.split('\n')
    cols.add lines
    var w = 0
    for ln in lines: w = max(w, stringWidth(ln))
    widths.add w
    maxRows = max(maxRows, lines.len)
  for row in 0 ..< maxRows:
    if row > 0: result.add "\n"
    for c in 0 ..< cols.len:
      let line = if row < cols[c].len: cols[c][row] else: ""
      result.add padLine(line, widths[c])

proc joinVertical*(blocks: varargs[string]): string =
  ## Stack blocks vertically.
  var first = true
  for b in blocks:
    if not first: result.add "\n"
    result.add b
    first = false

# ---- alignment / placement (Lipgloss-style positions: 0.0..1.0) ------------

const
  Left* = 0.0
  Center* = 0.5
  Right* = 1.0
  Top* = 0.0
  Bottom* = 1.0

proc placeHorizontal*(width: int, pos: float, content: string): string =
  ## Pad each line of `content` to `width`, positioning it per `pos`
  ## (0=left, 0.5=center, 1=right).
  var outLines: seq[string]
  for ln in content.split('\n'):
    let pad = width - stringWidth(ln)
    if pad <= 0:
      outLines.add ln
    else:
      let l = int(float(pad) * pos)
      outLines.add spaces(l) & ln & spaces(pad - l)
  outLines.join("\n")

proc placeVertical*(height: int, pos: float, content: string): string =
  ## Pad `content` to `height` rows, positioning it per `pos` (0=top, 1=bottom).
  ## Blank rows match the content's width.
  let lines = content.split('\n')
  var w = 0
  for ln in lines: w = max(w, stringWidth(ln))
  let pad = height - lines.len
  if pad <= 0: return content
  let top = int(float(pad) * pos)
  var rows: seq[string]
  for _ in 0 ..< top: rows.add spaces(w)
  for ln in lines: rows.add ln
  for _ in 0 ..< pad - top: rows.add spaces(w)
  rows.join("\n")

proc place*(width, height: int, hpos, vpos: float, content: string): string =
  ## Place `content` within a `width`x`height` box at the given position.
  placeVertical(height, vpos, placeHorizontal(width, hpos, content))

proc joinHorizontalAligned*(pos: float, blocks: varargs[string]): string =
  ## Like `joinHorizontal` but vertically aligns shorter blocks per `pos`
  ## (0=top, 0.5=middle, 1=bottom).
  var cols: seq[seq[string]]
  var widths: seq[int]
  var maxRows = 0
  for b in blocks:
    let lines = b.split('\n')
    cols.add lines
    var w = 0
    for ln in lines: w = max(w, stringWidth(ln))
    widths.add w
    maxRows = max(maxRows, lines.len)
  # Vertically pad each column to maxRows per pos.
  for c in 0 ..< cols.len:
    let pad = maxRows - cols[c].len
    if pad > 0:
      let top = int(float(pad) * pos)
      var padded: seq[string]
      for _ in 0 ..< top: padded.add spaces(widths[c])
      for ln in cols[c]: padded.add ln
      for _ in 0 ..< pad - top: padded.add spaces(widths[c])
      cols[c] = padded
  var rows: seq[string]
  for row in 0 ..< maxRows:
    var line = ""
    for c in 0 ..< cols.len:
      let l = if row < cols[c].len: cols[c][row] else: spaces(widths[c])
      let lw = stringWidth(l)
      line.add (if lw < widths[c]: l & spaces(widths[c] - lw) else: l)
    rows.add line
  rows.join("\n")
