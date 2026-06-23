## Port of bubbletea/examples/glamour — render Markdown in the terminal. The
## upstream uses the full Glamour renderer; this is a compact Markdown styler
## (headings, bold, inline code, bullet lists) shown in a scrollable viewport.

import std/strutils
import ../../src/boba
import ../../src/boba/bubbles

const doc = """
# Bobabrew

A **Nim** port of *Bubble Tea*.

## Features

- The Elm Architecture
- A `Style` styling layer
- A `Bubbles` component set

## Code

Use `newProgram(model).run()` to start.

Enjoy your **boba**!
"""

proc renderInline(s: string): string =
  ## Handle **bold** and `code` spans.
  result = ""
  var i = 0
  while i < s.len:
    if i + 1 < s.len and s[i] == '*' and s[i + 1] == '*':
      let close = s.find("**", i + 2)
      if close > 0:
        result.add newStyle().bold.render(s[i + 2 ..< close])
        i = close + 2; continue
    if s[i] == '`':
      let close = s.find('`', i + 1)
      if close > 0:
        result.add newStyle().foreground(basicColor(BrightCyan)).render(s[i + 1 ..< close])
        i = close + 1; continue
    result.add s[i]; inc i

proc renderMarkdown(md: string): string =
  var lines: seq[string]
  for raw in md.split('\n'):
    let line = raw.strip(trailing = true)
    if line.startsWith("# "):
      lines.add newStyle().bold.foreground(basicColor(BrightMagenta)).render(line[2 .. ^1])
    elif line.startsWith("## "):
      lines.add newStyle().bold.foreground(basicColor(BrightBlue)).render(line[3 .. ^1])
    elif line.startsWith("- "):
      lines.add "  • " & renderInline(line[2 .. ^1])
    else:
      lines.add renderInline(line)
  lines.join("\n")

type App = ref object of Model
  vp: Viewport

method update(m: App, msg: Msg): (Model, Cmd) =
  if msg of KeyPressMsg and KeyPressMsg(msg).key.matchString("q", "ctrl+c", "esc"):
    return (Model(m), Quit)
  m.vp.update(msg)
  (Model(m), nil)

method view(m: App): View =
  newView(m.vp.view & "\n↑/↓ scroll · q quit")

when isMainModule:
  var vp = newViewport(60, 16)
  vp.setContent(renderMarkdown(doc))
  discard newProgram(Model(App(vp: vp))).run()
