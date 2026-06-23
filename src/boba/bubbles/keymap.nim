## Key bindings + help rendering — port of the core of
## `charmbracelet/bubbles/key` and `help`.
##
## A `Binding` ties a set of key strings to a help label. `matches` tests a
## message against it; `shortHelp`/`fullHelp` render a help line.

import std/strutils
import ../tea/msg
import ../uv/key

type
  Binding* = object
    keys*: seq[string]      ## e.g. @["up", "k"]
    keyHelp*: string        ## e.g. "↑/k"
    descHelp*: string       ## e.g. "move up"
    enabled*: bool

proc newBinding*(keys: seq[string], keyHelp = "", descHelp = ""): Binding =
  Binding(keys: keys, keyHelp: keyHelp, descHelp: descHelp, enabled: true)

proc matches*(b: Binding, m: Msg): bool =
  if not b.enabled: return false
  if not (m of KeyPressMsg): return false
  let s = $KeyPressMsg(m).key
  s in b.keys

proc matchesAny*(m: Msg, bindings: varargs[Binding]): bool =
  for b in bindings:
    if b.matches(m): return true
  false

proc shortHelp*(bindings: openArray[Binding], sep = " • "): string =
  ## One-line help: "↑/k move up • q quit".
  var parts: seq[string]
  for b in bindings:
    if not b.enabled or b.keyHelp.len == 0: continue
    parts.add (if b.descHelp.len > 0: b.keyHelp & " " & b.descHelp else: b.keyHelp)
  parts.join(sep)

proc fullHelp*(columns: openArray[seq[Binding]], gap = "   "): string =
  ## Multi-column help. Each column is a list of bindings rendered as
  ## "key  desc" rows; columns are placed side by side.
  var cols: seq[seq[string]]
  var widths: seq[int]
  var maxRows = 0
  for col in columns:
    var rows: seq[string]
    for b in col:
      if not b.enabled or b.keyHelp.len == 0: continue
      rows.add b.keyHelp & "  " & b.descHelp
    cols.add rows
    var w = 0
    for r in rows: w = max(w, r.len)
    widths.add w
    maxRows = max(maxRows, rows.len)
  var outRows: seq[string]
  for r in 0 ..< maxRows:
    var line: seq[string]
    for c in 0 ..< cols.len:
      let cell = if r < cols[c].len: cols[c][r] else: ""
      line.add cell & spaces(max(widths[c] - cell.len, 0))
    outRows.add line.join(gap)
  outRows.join("\n")
