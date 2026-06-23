## Tab-stop table — port of `ultraviolet/tabstop.go`.
##
## Tracks column tab stops (every `interval` columns by default, e.g. 8) and
## supports setting/clearing individual stops. Used by the renderer when hard
## tabs are enabled to compute cursor movement.

type
  TabStops* = object
    width*: int
    interval*: int
    stops: seq[bool]      ## per-column override; populated lazily

const DefaultTabInterval* = 8

proc newTabStops*(width: int, interval = DefaultTabInterval): TabStops =
  result.width = max(width, 0)
  result.interval = max(interval, 1)
  result.stops = newSeq[bool](result.width)
  var c = 0
  while c < result.width:
    result.stops[c] = true
    c += result.interval

proc isStop*(t: TabStops, col: int): bool =
  if col < 0 or col >= t.stops.len: return false
  t.stops[col]

proc setStop*(t: var TabStops, col: int) =
  if col >= 0 and col < t.stops.len: t.stops[col] = true

proc clearStop*(t: var TabStops, col: int) =
  if col >= 0 and col < t.stops.len: t.stops[col] = false

proc next*(t: TabStops, col: int): int =
  ## The next tab stop strictly after `col`, clamped to the last column.
  var c = col + 1
  while c < t.width:
    if t.stops[c]: return c
    inc c
  max(t.width - 1, 0)

proc prev*(t: TabStops, col: int): int =
  ## The previous tab stop strictly before `col`, or 0.
  var c = col - 1
  while c > 0:
    if t.stops[c]: return c
    dec c
  0

proc resize*(t: var TabStops, width: int) =
  t = newTabStops(width, t.interval)

proc clearAll*(t: var TabStops) =
  for i in 0 ..< t.stops.len: t.stops[i] = false
