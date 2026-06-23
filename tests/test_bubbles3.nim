import std/[unittest, times, strutils]
import ../src/boba
import ../src/boba/bubbles

proc special(code: int32): Msg = newKeyPress(Key(code: code))

suite "bubbles/keymap":
  test "binding matches its keys":
    let up = newBinding(@["up", "k"], "↑/k", "up")
    check up.matches(special(KeyUp))
    check up.matches(newKeyPress(Key(code: int32('k'.ord), text: "k")))
    check not up.matches(special(KeyDown))

  test "disabled binding never matches":
    var b = newBinding(@["q"], "q", "quit")
    b.enabled = false
    check not b.matches(newKeyPress(Key(code: int32('q'.ord), text: "q")))

  test "shortHelp renders enabled bindings":
    let b = @[newBinding(@["up"], "↑", "up"), newBinding(@["q"], "q", "quit")]
    check shortHelp(b) == "↑ up • q quit"

  test "fullHelp renders columns":
    let col1 = @[newBinding(@["up"], "↑", "up"), newBinding(@["down"], "↓", "down")]
    let col2 = @[newBinding(@["q"], "q", "quit")]
    let r = fullHelp([col1, col2])
    let lines = r.split('\n')
    check lines.len == 2
    check "↑  up" in lines[0]
    check "q  quit" in lines[0]

suite "bubbles/stopwatch":
  test "ticks accumulate while running":
    var s = newStopwatch(initDuration(seconds = 1))
    discard s.start()
    check s.running
    discard s.update(StopwatchTickMsg())
    discard s.update(StopwatchTickMsg())
    check s.elapsed.inSeconds == 2

  test "stopped does not accumulate":
    var s = newStopwatch()
    discard s.update(StopwatchTickMsg())
    check s.elapsed.inSeconds == 0

  test "reset":
    var s = newStopwatch()
    discard s.start()
    discard s.update(StopwatchTickMsg())
    s.reset()
    check s.elapsed.inSeconds == 0

  test "view format":
    var s = newStopwatch()
    discard s.start()
    for _ in 0 ..< 65: discard s.update(StopwatchTickMsg())
    check s.view == "1m5s"

suite "bubbles/timer":
  test "counts down and times out":
    var t = newTimer(initDuration(seconds = 2))
    discard t.start()
    discard t.update(TimerTickMsg())
    check t.remaining.inSeconds == 1
    let cmd = t.update(TimerTickMsg())
    check t.timedOut
    check not t.running
    check cmd != nil
    check cmd() of TimerTimeoutMsg

  test "view":
    let t = newTimer(initDuration(seconds = 90))
    check t.view == "1m30s"
