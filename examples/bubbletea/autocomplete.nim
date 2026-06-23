## Port of bubbletea/examples/autocomplete — text input with live suggestions.

import std/strutils
import ../../src/boba
import ../../src/boba/bubbles

type App = ref object of Model
  input: TextInput
  pool: seq[string]
  matches: seq[string]

proc refilter(m: App) =
  m.matches = @[]
  let q = m.input.value.toLowerAscii
  for s in m.pool:
    if q.len == 0 or q in s.toLowerAscii: m.matches.add s

method update(m: App, msg: Msg): (Model, Cmd) =
  if msg of KeyPressMsg:
    let k = KeyPressMsg(msg).key
    if k.matchString("ctrl+c", "esc"): return (Model(m), Quit)
    if k.code == KeyTab and m.matches.len > 0:
      m.input.setValue(m.matches[0]); m.refilter(); return (Model(m), nil)
  m.input.update(msg)
  m.refilter()
  (Model(m), nil)

method view(m: App): View =
  var b = "Search a Charm project (tab to complete):\n\n" & m.input.view & "\n\n"
  for s in m.matches[0 ..< min(m.matches.len, 6)]:
    b.add "  " & s & "\n"
  newView(b & "\nesc to quit")

when isMainModule:
  var app = App(input: newTextInput(), pool: @[
    "bubbletea", "bubbles", "lipgloss", "glamour", "harmonica", "wish",
    "soft-serve", "gum", "vhs", "freeze", "mods", "skate"])
  app.refilter()
  discard newProgram(Model(app)).run()
