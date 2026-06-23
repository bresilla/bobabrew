## Port of bubbletea/examples/file-picker — browse the filesystem.

import std/[os, algorithm]
import ../../src/boba

type App = ref object of Model
  cwd: string
  entries: seq[tuple[name: string, dir: bool]]
  cursor: int
  picked: string

proc load(m: App) =
  m.entries = @[]
  m.cursor = 0
  try:
    for kind, path in walkDir(m.cwd):
      m.entries.add (extractFilename(path), kind == pcDir)
  except OSError: discard
  m.entries.sort(proc (a, b: auto): int =
    if a.dir != b.dir: (if a.dir: -1 else: 1) else: cmp(a.name, b.name))

method init(m: App): Cmd =
  m.load()
  nil

method update(m: App, msg: Msg): (Model, Cmd) =
  if msg of KeyPressMsg:
    let k = KeyPressMsg(msg).key
    if k.matchString("q", "ctrl+c", "esc"): return (Model(m), Quit)
    if k.matchString("up", "k"): m.cursor = max(0, m.cursor - 1)
    elif k.matchString("down", "j"): m.cursor = min(m.entries.high, m.cursor + 1)
    elif k.matchString("backspace", "h"):
      m.cwd = parentDir(m.cwd); m.load()
    elif k.code == KeyEnter and m.entries.len > 0:
      let e = m.entries[m.cursor]
      if e.dir: (m.cwd = m.cwd / e.name; m.load())
      else: (m.picked = m.cwd / e.name; return (Model(m), Quit))
  (Model(m), nil)

method view(m: App): View =
  var b = "Browsing: " & m.cwd & "\n\n"
  let lo = max(0, m.cursor - 8)
  let hi = min(m.entries.len, lo + 16)
  for i in lo ..< hi:
    let e = m.entries[i]
    let cur = if i == m.cursor: "> " else: "  "
    let name = if e.dir: e.name & "/" else: e.name
    b.add cur & name & "\n"
  b.add "\n↑/↓ move · enter open · backspace up · q quit"
  newView(b)

when isMainModule:
  discard newProgram(Model(App(cwd: getCurrentDir()))).run()
