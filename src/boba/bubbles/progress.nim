## A progress-bar component — port of the core of `charmbracelet/bubbles/progress`.

import std/strutils
import ../ansi/style
import ../ansi/color

type
  Progress* = object
    width*: int            ## total bar width in cells
    percent*: float        ## 0.0 .. 1.0
    full*, empty*: string  ## glyphs for filled / empty cells
    fullColor*: Color
    showPercentage*: bool

proc newProgress*(width = 40): Progress =
  Progress(width: width, percent: 0.0, full: "█", empty: "░",
           fullColor: NoColor, showPercentage: true)

proc setPercent*(p: var Progress, v: float) =
  p.percent = max(0.0, min(1.0, v))

proc incrPercent*(p: var Progress, delta: float) =
  p.setPercent(p.percent + delta)

proc view*(p: Progress): string =
  let barWidth =
    if p.showPercentage: max(p.width - 5, 1)  # leave room for " 100%"
    else: p.width
  let filled = int(p.percent * float(barWidth) + 0.5)
  let fill = p.full.repeat(filled)
  let rest = p.empty.repeat(max(barWidth - filled, 0))
  var bar =
    if p.fullColor.isNone: fill
    else: EmptyStyle.withFg(p.fullColor).styled(fill)
  bar.add rest
  if p.showPercentage:
    let pct = $int(p.percent * 100 + 0.5) & "%"
    bar.add align(" " & pct, 5)
  result = bar
