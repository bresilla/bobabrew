## A countdown timer — port of the core of `charmbracelet/bubbles/timer`.
## Counts down to zero, then emits a `TimerTimeoutMsg`.

import std/times
import ../tea/msg
import ../tea/cmd

type
  TimerTickMsg* = ref object of Msg
  TimerTimeoutMsg* = ref object of Msg
  Timer* = object
    remaining*: Duration
    interval*: Duration
    running*: bool

proc newTimer*(timeout: Duration, interval = initDuration(seconds = 1)): Timer =
  Timer(remaining: timeout, interval: interval, running: false)

proc timedOut*(t: Timer): bool = t.remaining <= DurationZero

proc tickCmd*(t: Timer): Cmd =
  let d = t.interval
  Tick(d, proc (ts: Time): Msg = TimerTickMsg())

proc start*(t: var Timer): Cmd =
  t.running = true
  t.tickCmd()

proc stop*(t: var Timer) = t.running = false

proc update*(t: var Timer, m: Msg): Cmd =
  if m of TimerTickMsg and t.running:
    t.remaining -= t.interval
    if t.timedOut:
      t.remaining = DurationZero
      t.running = false
      return (proc (): Msg = TimerTimeoutMsg())
    return t.tickCmd()
  nil

proc view*(t: Timer): string =
  let secs = max(t.remaining.inSeconds, 0)
  let m = secs div 60
  let s = secs mod 60
  if m > 0: $m & "m" & $s & "s" else: $s & "s"
