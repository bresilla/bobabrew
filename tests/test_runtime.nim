## Non-TTY smoke test for the runtime: drives the full threaded event loop
## (workers + mailbox + update + render) and proves it starts and shuts down
## cleanly. The model auto-quits via a Tick command, and also exercises Batch
## and a custom message, so we don't depend on a terminal.

import std/[unittest, times]
import ../src/boba

type
  Bump = ref object of Msg
  Driver = ref object of Model
    bumps: int
    quit: bool

proc bumpSoon(): Cmd =
  Tick(initDuration(milliseconds = 10), proc (t: Time): Msg = Bump())

method init(m: Driver): Cmd =
  # Fire two bumps concurrently via Batch.
  Batch(bumpSoon(), bumpSoon())

method update(m: Driver, msg: Msg): (Model, Cmd) =
  if msg of Bump:
    m.bumps.inc
    if m.bumps >= 2:
      m.quit = true
      return (Model(m), Quit)
  (Model(m), nil)

method view(m: Driver): View =
  newView("bumps=" & $m.bumps)

suite "runtime":
  test "threaded loop runs Batch+Tick and quits":
    let d = Driver()
    # Disable renderer + input so this is safe and deterministic without a TTY.
    let final = newProgram(Model(d), withoutRenderer(), withoutInput()).run()
    check Driver(final).quit
    check Driver(final).bumps >= 2
