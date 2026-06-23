## Commands — port of `commands.go` plus the special commands from tea.go.
##
## A `Cmd` is a `proc(): Msg` run off the event loop on a worker thread. A `nil`
## Cmd is a no-op. `batch`/`sequence` wrap several into one.

import std/[times, os]
import ./msg

type
  Cmd* = proc (): Msg {.gcsafe.}

  BatchMsg* = ref object of Msg
    cmds*: seq[Cmd]
  SequenceMsg* = ref object of Msg
    cmds*: seq[Cmd]

proc compact(cmds: openArray[Cmd]): seq[Cmd] =
  for c in cmds:
    if c != nil: result.add c

proc Batch*(cmds: varargs[Cmd]): Cmd =
  ## Run commands concurrently, no ordering guarantees.
  let valid = compact(cmds)
  case valid.len
  of 0: nil
  of 1: valid[0]
  else:
    (proc (): Msg = BatchMsg(cmds: valid))

proc Sequence*(cmds: varargs[Cmd]): Cmd =
  ## Run commands one at a time, in order.
  let valid = compact(cmds)
  case valid.len
  of 0: nil
  of 1: valid[0]
  else:
    (proc (): Msg = SequenceMsg(cmds: valid))

# ---- special commands (capitalized to match the Bubble Tea API and to avoid
# clashing with system.quit) -------------------------------------------------

proc Quit*(): Msg = QuitMsg()
  ## A command that tells the program to exit. Use as `return (m, Quit)`.

proc Interrupt*(): Msg = InterruptMsg()
proc Suspend*(): Msg = SuspendMsg()
proc ClearScreen*(): Msg = clearScreenMsg()
proc RequestWindowSize*(): Msg = windowSizeReqMsg()

proc Tick*(d: Duration, fn: proc (t: Time): Msg {.gcsafe.}): Cmd =
  ## Produce a message after `d`, independent of the system clock.
  (proc (): Msg =
    sleep(int(d.inMilliseconds))
    fn(getTime()))

proc Every*(d: Duration, fn: proc (t: Time): Msg {.gcsafe.}): Cmd =
  ## Like `Tick`, but aligned to the system clock.
  (proc (): Msg =
    let now = getTime()
    let ms = int(d.inMilliseconds)
    if ms > 0:
      let nowMs = now.toUnixFloat() * 1000.0
      let wait = ms - (int(nowMs) mod ms)
      sleep(wait)
    fn(getTime()))

proc Println*(s: string): Cmd =
  (proc (): Msg = printLineMessage(body: s))

proc SetClipboard*(s: string): Cmd =
  (proc (): Msg = setClipboardMsg(content: s, primary: false))
proc ReadClipboard*(): Msg = readClipboardMsg(primary: false)

proc RequestBackgroundColor*(): Msg = reqBackgroundColorMsg()
  ## Query the terminal's background color; reply arrives as BackgroundColorMsg.
proc RequestForegroundColor*(): Msg = reqForegroundColorMsg()
proc RequestCursorColor*(): Msg = reqCursorColorMsg()

proc Raw*(s: string): Cmd =
  (proc (): Msg = rawMsg(body: s))

proc ExecProcess*(command: string, args: seq[string] = @[],
                  fn: proc (exitCode: int): Msg {.gcsafe.} = nil): Cmd =
  ## Run an external program (e.g. `$EDITOR`) in a blocking fashion, pausing the
  ## Bubble Tea program and giving the child the terminal. `fn` receives the
  ## child's exit code and may return a follow-up message.
  (proc (): Msg = ExecMsg(command: command, args: args, callback: fn))
