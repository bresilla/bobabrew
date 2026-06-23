## Port of bubbletea/examples/package-manager — installs packages one by one,
## printing each above the spinner as it completes.

import std/[times, strutils]
import ../../src/boba
import ../../src/boba/bubbles

type
  InstalledMsg = ref object of Msg
    name: string
  App = ref object of Model
    spin: Spinner
    pkgs: seq[string]
    idx: int
    bar: Progress

proc installNext(i: int, name: string): Cmd =
  Tick(initDuration(milliseconds = 350), proc (t: Time): Msg = InstalledMsg(name: name))

method init(m: App): Cmd =
  Batch(m.spin.tickCmd(), installNext(0, m.pkgs[0]))

method update(m: App, msg: Msg): (Model, Cmd) =
  if msg of KeyPressMsg and KeyPressMsg(msg).key.matchString("q", "ctrl+c"):
    return (Model(m), Quit)
  if msg of InstalledMsg:
    m.idx.inc
    m.bar.setPercent(m.idx / m.pkgs.len)
    let printed = Println("✓ " & InstalledMsg(msg).name)
    if m.idx >= m.pkgs.len:
      let q: Cmd = proc (): Msg = Quit()
      return (Model(m), Sequence(printed, q))
    return (Model(m), Batch(printed, installNext(m.idx, m.pkgs[m.idx])))
  let cmd = m.spin.update(msg)
  (Model(m), cmd)

method view(m: App): View =
  if m.idx >= m.pkgs.len: return newView("Done!\n")
  newView(m.spin.view & " Installing " & m.pkgs[m.idx] & "\n\n" & m.bar.view)

when isMainModule:
  let pkgs = @["lipgloss", "bubbletea", "bubbles", "glamour", "harmonica", "wish"]
  discard newProgram(Model(App(spin: newSpinner(), pkgs: pkgs, bar: newProgress(40)))).run()
