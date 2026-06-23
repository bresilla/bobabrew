## Port of bubbletea/examples/paginator — paged list of items.

import std/strutils
import ../../src/boba
import ../../src/boba/bubbles

type App = ref object of Model
  items: seq[string]
  pg: Paginator

method update(m: App, msg: Msg): (Model, Cmd) =
  if msg of KeyPressMsg and KeyPressMsg(msg).key.matchString("q", "ctrl+c", "esc"):
    return (Model(m), Quit)
  m.pg.update(msg)
  (Model(m), nil)

method view(m: App): View =
  var b = "Paginator — " & $m.items.len & " items\n\n"
  let (lo, hi) = m.pg.sliceBounds(m.items.len)
  for i in lo ..< hi:
    b.add "  • " & m.items[i] & "\n"
  b.add "\n  " & m.pg.view & "   ←/→ page · q quit\n"
  newView(b)

when isMainModule:
  var items: seq[string]
  for i in 1 .. 43: items.add "Item " & $i
  var pg = newPaginator(10)
  pg.totalItems = items.len
  discard newProgram(Model(App(items: items, pg: pg))).run()
