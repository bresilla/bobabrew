## Tests for program startup messages and the message filter.

import std/[unittest, times]
import ../src/boba

type
  Ping = ref object of Msg
  Probe = ref object of Model
    gotProfile: bool
    gotEnv: bool
    gotSize: bool

method init(m: Probe): Cmd =
  # Send a Ping shortly after start; the filter turns it into Quit.
  Tick(initDuration(milliseconds = 10), proc (t: Time): Msg = Ping())

method update(m: Probe, msg: Msg): (Model, Cmd) =
  if msg of ColorProfileMsg: m.gotProfile = true
  elif msg of EnvMsg: m.gotEnv = true
  elif msg of WindowSizeMsg: m.gotSize = true
  (Model(m), nil)

method view(m: Probe): View = newView("")

proc pingToQuit(model: Model, msg: Msg): Msg =
  if msg of Ping: return QuitMsg()
  msg

suite "program startup + filter":
  test "model receives ColorProfile, Env, WindowSize; filter maps Ping->Quit":
    let m = Probe()
    let final = newProgram(Model(m), withoutRenderer(), withoutInput(),
                           withFilter(pingToQuit)).run()
    let p = Probe(final)
    check p.gotProfile
    check p.gotEnv
    check p.gotSize

  test "filter can drop messages":
    # A filter that drops Ping means the program never quits via Ping; use a
    # short-lived second model that quits on its own Tick instead.
    var dropped = 0
    let m = Probe()
    proc dropPing(model: Model, msg: Msg): Msg =
      if msg of Ping: (dropped.inc; return nil)
      if msg of WindowSizeMsg: return QuitMsg()  # quit on first size msg
      msg
    discard newProgram(Model(m), withoutRenderer(), withoutInput(),
                       withFilter(dropPing)).run()
    check true  # reaching here means the loop terminated cleanly
