## Port of bubbletea/examples/send-msg — messages arriving from "outside". The
## upstream example calls p.Send from a goroutine; here a recurring Tick injects
## results, which is the same unidirectional flow into Update.

import std/[times, strutils]
import ../../src/boba
import ../../src/boba/bubbles

type
  ResultMsg = ref object of Msg
    food: string
  App = ref object of Model
    spin: Spinner
    results: seq[string]

const foods = ["an apple", "a sandwich", "noodles", "tacos", "sushi"]

proc nextResult(i: int): Cmd =
  Tick(initDuration(milliseconds = 500), proc (t: Time): Msg =
    ResultMsg(food: foods[i mod foods.len]))

method init(m: App): Cmd = Batch(m.spin.tickCmd(), nextResult(0))

method update(m: App, msg: Msg): (Model, Cmd) =
  if msg of KeyPressMsg and KeyPressMsg(msg).key.matchString("q", "ctrl+c"):
    return (Model(m), Quit)
  if msg of ResultMsg:
    m.results.add "Ate " & ResultMsg(msg).food
    if m.results.len >= 8: return (Model(m), Quit)
    return (Model(m), nextResult(m.results.len))
  let cmd = m.spin.update(msg)
  (Model(m), cmd)

method view(m: App): View =
  newView(m.spin.view & " Eating...\n\n" & m.results.join("\n") & "\n\nq to quit")

when isMainModule:
  discard newProgram(Model(App(spin: newSpinner()))).run()
