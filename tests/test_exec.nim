## Exec integration test: the program runs an external process and receives its
## exit code via the callback, then quits. Runs headless (no renderer/input).

import std/unittest
import ../src/boba

type
  ExecDone = ref object of Msg
    code: int
  Runner = ref object of Model
    code: int
    ran: bool

method init(m: Runner): Cmd =
  ExecProcess("true", @[], proc (c: int): Msg = ExecDone(code: c))

method update(m: Runner, msg: Msg): (Model, Cmd) =
  if msg of ExecDone:
    m.ran = true
    m.code = ExecDone(msg).code
    return (Model(m), Quit)
  (Model(m), nil)

method view(m: Runner): View = newView("")

suite "exec":
  test "runs external process and gets exit code":
    let m = Runner()
    let final = newProgram(Model(m), withoutRenderer(), withoutInput()).run()
    check Runner(final).ran
    check Runner(final).code == 0
