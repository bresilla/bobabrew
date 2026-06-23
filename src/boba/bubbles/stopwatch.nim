## A stopwatch — port of the core of `charmbracelet/bubbles/stopwatch`.

import std/times
import ../tea/msg
import ../tea/cmd

type
  StopwatchTickMsg* = ref object of Msg
  Stopwatch* = object
    elapsed*: Duration
    interval*: Duration
    running*: bool

proc newStopwatch*(interval = initDuration(seconds = 1)): Stopwatch =
  Stopwatch(elapsed: DurationZero, interval: interval, running: false)

proc tickCmd*(s: Stopwatch): Cmd =
  let d = s.interval
  Tick(d, proc (t: Time): Msg = StopwatchTickMsg())

proc start*(s: var Stopwatch): Cmd =
  s.running = true
  s.tickCmd()

proc stop*(s: var Stopwatch) = s.running = false
proc toggle*(s: var Stopwatch): Cmd =
  (if s.running: (s.stop(); nil) else: s.start())
proc reset*(s: var Stopwatch) = s.elapsed = DurationZero

proc update*(s: var Stopwatch, m: Msg): Cmd =
  if m of StopwatchTickMsg and s.running:
    s.elapsed += s.interval
    return s.tickCmd()
  nil

proc view*(s: Stopwatch): string =
  let secs = s.elapsed.inSeconds
  let h = secs div 3600
  let m = (secs mod 3600) div 60
  let sec = secs mod 60
  if h > 0:
    return $h & "h" & $m & "m" & $sec & "s"
  if m > 0:
    return $m & "m" & $sec & "s"
  $sec & "s"
