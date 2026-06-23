## An animated spinner component — port of the core of
## `charmbracelet/bubbles/spinner`.
##
## `tickCmd` schedules the next frame; forward messages to `update`, which
## advances the frame on a `SpinnerTickMsg` and returns the next tick command.

import std/times
import ../tea/msg
import ../tea/cmd

type
  SpinnerTickMsg* = ref object of Msg

  Spinner* = object
    frames*: seq[string]
    interval*: Duration
    idx*: int

const
  DotsFrames* = @["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]
  LineFrames* = @["|", "/", "-", "\\"]
  MiniDotFrames* = @[".  ", ".. ", "...", " ..", "  .", "   "]

proc newSpinner*(frames = DotsFrames, interval = initDuration(milliseconds = 100)): Spinner =
  Spinner(frames: frames, interval: interval, idx: 0)

proc tickCmd*(s: Spinner): Cmd =
  let d = s.interval
  Tick(d, proc (t: Time): Msg = SpinnerTickMsg())

proc update*(s: var Spinner, m: Msg): Cmd =
  ## Advance the spinner on its tick; returns the command to schedule the next.
  if m of SpinnerTickMsg:
    s.idx = (s.idx + 1) mod max(s.frames.len, 1)
    return s.tickCmd()
  nil

proc view*(s: Spinner): string =
  if s.frames.len == 0: return ""
  s.frames[s.idx mod s.frames.len]
