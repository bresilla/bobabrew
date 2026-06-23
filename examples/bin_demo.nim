## A faithful fake of the `bin` binary-manager TUI, built on bobabrew with
## made-up data (no network, no installs). Mirrors bin/src/cmd/tui.go:
## a custom 3-line list delegate with solid alternating row backgrounds, an
## accent ┃ selection bar, fixed aligned columns, and a centered modal overlay.
##
##   ↑/↓ or j/k  move      u  update    r  check all   p  pin     o  open repo
##   d / x       remove    t  tag       /  filter      q  quit
##
## Run:  nim c -r examples/bin_demo.nim

import std/[strutils, times]
import ../src/boba
import ../src/boba/bubbles
import ../src/boba/uv/styled   # newStyledString + draw (for the overlay)
import ../src/boba/ansi/wrap   # truncate (width-aware, with ellipsis)

# ---- palette (mirrors bin/src/pkg/ui/styles.go) ----------------------------
let
  cPrimary = basicColor(1)        # accent
  cOK      = basicColor(2)
  cWarn    = basicColor(3)
  cErr     = basicColor(9)
  cTag     = basicColor(6)
  cMuted   = basicColor(8)
  cText    = basicColor(15)
  rowBg         = extendedColor(232)
  rowBgAlt      = extendedColor(235)
  rowBgSelected = extendedColor(237)

# ---- model -----------------------------------------------------------------
type
  Status = enum stOK, stUpdate, stMissing
  Bin = object
    name, cur, latest, repo, arch, libc: string
    size: int64
    tags: seq[string]
    desc, scope: string
    status: Status
    pinned: bool

  CheckDone = ref object of Msg

  App = ref object of Model
    bins: seq[Bin]
    cursor, offset: int
    scopes: seq[string]
    scopeIdx: int
    filter: TextInput
    filtering: bool
    confirm: bool
    confirmYes: bool
    status: string
    spin: Spinner
    busy: bool
    w, h: int

proc scope(m: App): string = m.scopes[m.scopeIdx]

proc visible(m: App): seq[int] =
  let q = m.filter.value.toLowerAscii
  for i, b in m.bins:
    if m.scope != "all" and m.scope notin b.tags: continue
    if q.len > 0 and q notin b.name.toLowerAscii: continue
    result.add i

# ---- helpers (mirror bin) --------------------------------------------------
proc dash(s: string): string = (if s.len == 0: "—" else: s)

proc humanSize(n: int64): string =
  if n <= 0: return "—"
  if n < 1024: return $n & "B"
  var d = 1024'i64
  var exp = 0
  var x = n div 1024
  while x >= 1024: (d *= 1024; inc exp; x = x div 1024)
  result = formatFloat(n.float / d.float, ffDecimal, 1) & "KMGT"[exp] & "B"

proc isNewer(cur, latest: string): bool = cur != latest

# ---- row rendering (port of binDelegate.Render) ----------------------------
proc rowBgFor(index: int, selected: bool): Color =
  if selected: rowBgSelected
  elif index mod 2 == 1: rowBgAlt
  else: rowBg

proc cell(bg, fg: Color, wdt: int, s: string, right = false, bold = false): string =
  let w = max(wdt, 1)
  var st = newStyle().background(bg).foreground(fg).width(w)
  if right: st = st.align(alRight)
  if bold: st = st.bold
  st.render(truncate(s, w, "…"))

proc renderRow(m: App, b: Bin, index: int, selected: bool): string =
  let width = max(m.w - 4, 24)         # app Padding(1,2) → -4 horizontal
  let bg = rowBgFor(index, selected)
  let barTxt = if selected: "┃ " else: "  "
  let bar = newStyle().background(bg).foreground(cPrimary).render(barTxt)
  let inner = width - 2

  # line 1: ● name .................. version
  let statusFg = if b.status == stMissing: cErr else: cOK
  let nameFg = if selected: cPrimary else: cText
  var name = b.name
  if b.pinned: name &= " ★"
  var verTxt = dash(b.cur)
  var verFg = cMuted
  case b.status
  of stMissing: (verTxt = "missing"; verFg = cErr)
  of stUpdate:
    if isNewer(b.cur, b.latest): (verTxt = b.cur & " ↑ " & b.latest; verFg = cWarn)
  of stOK:
    if b.latest.len > 0: (verTxt = b.cur & " ✓"; verFg = cOK)
  let verCol = 28
  let nameCol = inner - 2 - verCol
  let line1 = bar & cell(bg, statusFg, 2, "●") &
    cell(bg, nameFg, nameCol, name, bold = true) &
    cell(bg, verFg, verCol, verTxt, right = true)

  # line 2: repo  arch  libc  size  tags
  let archCol = 8
  let libcCol = 8
  let sizeCol = 9
  let tagsCol = 18
  let repoCol = inner - archCol - libcCol - sizeCol - tagsCol
  let line2 = bar &
    cell(bg, cTag, repoCol, b.repo) &
    cell(bg, cMuted, archCol, dash(b.arch)) &
    cell(bg, cMuted, libcCol, dash(b.libc)) &
    cell(bg, cMuted, sizeCol, humanSize(b.size)) &
    cell(bg, cTag, tagsCol, b.tags.join(","))

  # line 3: italic muted description (or path)
  let line3 = bar & newStyle().background(bg).foreground(cMuted).italic
    .width(inner).render(truncate(dash(b.desc), inner, "…"))

  line1 & "\n" & line2 & "\n" & line3

# ---- whole list body -------------------------------------------------------
proc listBody(m: App): string =
  ## Produces exactly `m.h - 2` lines (the app Padding(1,2) adds the other 2),
  ## so the content fills the whole terminal and the status/help bar is pinned to
  ## the bottom regardless of how many entries there are.
  let ch = max(m.h - 2, 8)
  let title = newStyle().bold.foreground(cText).background(cPrimary)
    .render(" bin · " & m.scope & " ")

  let v = m.visible
  # Rows area = total height minus title(1) + blank(1) + status(1) + help(1).
  let rowsShown = max((ch - 4) div 3, 1)

  var lines: seq[string]
  lines.add title
  lines.add ""
  if v.len == 0:
    lines.add newStyle().foreground(cMuted).render("  no binaries match")
  else:
    let last = min(m.offset + rowsShown, v.len)
    for vi in m.offset ..< last:
      for ln in renderRow(m, m.bins[v[vi]], vi, vi == m.cursor).split('\n'):
        lines.add ln

  # Pad so the bottom two lines (status + help) sit at the very bottom.
  while lines.len < ch - 2:
    lines.add ""

  # status bar: "N binaries" + spinner + message (or the filter prompt)
  var statusLine: string
  if m.filtering:
    statusLine = "/" & m.filter.view
  else:
    let spin = if m.busy: m.spin.view & " " else: ""
    let count = newStyle().foreground(cText).background(cPrimary)
      .render(" " & $v.len & " binaries ")
    statusLine = count & "  " & spin & m.status

  let help = newStyle().foreground(cMuted).render(
    "↑/↓ move · u update · r check · p pin · d remove · t tag · / filter · q quit")

  lines.add statusLine
  lines.add help
  if lines.len > ch: lines = lines[0 ..< ch]   # never overflow the screen
  lines.join("\n")

# ---- overlay (port of ui.Dialog + ui.Dim + ui.Overlay) ---------------------
proc stripAnsi(s: string): string =
  var i = 0
  while i < s.len:
    if s[i] == '\x1b':
      if i + 1 < s.len and s[i + 1] == '[':
        i += 2
        while i < s.len and (s[i] < '\x40' or s[i] > '\x7e'): inc i
        if i < s.len: inc i
      elif i + 1 < s.len and s[i + 1] == ']':
        i += 2
        while i < s.len and s[i] != '\x07': inc i
        if i < s.len: inc i
      else: i += 2
    else: (result.add s[i]; inc i)

proc confirmDialog(m: App): string =
  let name = m.bins[m.visible[m.cursor]].name
  let bar = newStyle().bold.foreground(cText).background(cPrimary).render(" Remove binary ")
  let yes = (if m.confirmYes: newStyle().bold.foreground(cText).background(cPrimary)
             else: newStyle().foreground(cMuted)).render("  Yes  ")
  let no = (if not m.confirmYes: newStyle().bold.foreground(cText).background(cPrimary)
            else: newStyle().foreground(cMuted)).render("  No  ")
  let body = "Remove " & newStyle().foreground(cErr).bold.render(name) & " from disk?\n\n" &
             yes & "   " & no
  let footer = newStyle().foreground(cMuted).render("←/→ choose · enter confirm · esc cancel")
  newStyle().padding(1, 2).foreground(cPrimary).withBorder(roundedBorder())
    .render(bar & "\n\n" & body & "\n\n" & footer)

proc overlay(m: App, base: string): string =
  let width = max(m.w, 1)
  let height = max(m.h, 1)
  # dimmed backdrop: strip color, recolor muted
  let dimmed = newStyle().foreground(cMuted).render(stripAnsi(base))
  var buf = newBuffer(width, height)
  newStyledString(dimmed).draw(buf)
  let dialog = confirmDialog(m)
  let dl = dialog.split('\n')
  var dw = 0
  for l in dl: dw = max(dw, stringWidth(l))
  var dbuf = newBuffer(dw, dl.len)
  newStyledString(dialog).draw(dbuf)
  buf.blit(dbuf, max((width - dw) div 2, 0), max((height - dl.len) div 2, 0))
  buf.render.replace("\r\n", "\n")

# ---- update ----------------------------------------------------------------
proc clamp(m: App) =
  let v = m.visible
  if v.len == 0: (m.cursor = 0; m.offset = 0; return)
  m.cursor = max(0, min(m.cursor, v.high))
  let rowsArea = max(m.h - 2 - 5, 3)
  let rowsShown = max(rowsArea div 3, 1)
  if m.cursor < m.offset: m.offset = m.cursor
  elif m.cursor >= m.offset + rowsShown: m.offset = m.cursor - rowsShown + 1

proc checkCmd(): Cmd =
  Tick(initDuration(milliseconds = 1000), proc (t: Time): Msg = CheckDone())

method update(m: App, msg: Msg): (Model, Cmd) =
  if msg of WindowSizeMsg:
    m.w = WindowSizeMsg(msg).width
    m.h = WindowSizeMsg(msg).height
    m.clamp()
    return (Model(m), nil)
  if msg of CheckDone:
    m.busy = false
    m.status = newStyle().foreground(cOK).render("check complete")
    return (Model(m), nil)
  if m.busy:
    return (Model(m), m.spin.update(msg))

  if msg of KeyPressMsg:
    let k = KeyPressMsg(msg).key

    if m.confirm:
      if k.matchString("left", "right", "h", "l", "tab"):
        m.confirmYes = not m.confirmYes
      elif k.matchString("y"):
        let nm = m.bins[m.visible[m.cursor]].name
        m.bins.delete(m.visible[m.cursor]); m.confirm = false; m.clamp()
        m.status = "removed " & nm
      elif k.matchString("n", "esc"):
        m.confirm = false; m.status = "remove cancelled"
      elif k.code == KeyEnter:
        if m.confirmYes:
          let nm = m.bins[m.visible[m.cursor]].name
          m.bins.delete(m.visible[m.cursor]); m.clamp(); m.status = "removed " & nm
        else: m.status = "remove cancelled"
        m.confirm = false
      return (Model(m), nil)

    if m.filtering:
      if k.code == KeyEscape: (m.filtering = false; m.filter.clear(); m.clamp())
      elif k.code == KeyEnter: m.filtering = false
      else: (m.filter.update(msg); m.clamp())
      return (Model(m), nil)

    if k.matchString("q", "ctrl+c"): return (Model(m), Quit)
    if k.matchString("down", "j"): (m.cursor.inc; m.clamp())
    elif k.matchString("up", "k"): (m.cursor.dec; m.clamp())
    elif k.matchString("t", "tab"):
      m.scopeIdx = (m.scopeIdx + 1) mod m.scopes.len
      m.cursor = 0; m.offset = 0; m.status = "scope: " & m.scope
    elif k.matchString("/"): (m.filtering = true; m.filter.focused = true)
    elif k.matchString("r"):
      m.busy = true; m.status = "checking " & $m.bins.len & " binaries…"
      return (Model(m), Batch(m.spin.tickCmd(), checkCmd()))
    elif m.visible.len > 0:
      let idx = m.visible[m.cursor]
      if k.matchString("u"):
        if m.bins[idx].pinned: m.status = m.bins[idx].name & " is pinned (p to unpin)"
        elif m.bins[idx].status == stUpdate:
          m.bins[idx].cur = m.bins[idx].latest; m.bins[idx].status = stOK
          m.status = newStyle().foreground(cOK).render("updated " & m.bins[idx].name)
        else: m.status = m.bins[idx].name & " already up to date"
      elif k.matchString("p"):
        m.bins[idx].pinned = not m.bins[idx].pinned
        m.status = (if m.bins[idx].pinned: "pinned " else: "unpinned ") & m.bins[idx].name
      elif k.matchString("o"):
        m.status = "opening " & m.bins[idx].repo
      elif k.matchString("d", "x"):
        m.confirm = true; m.confirmYes = false
  (Model(m), nil)

method view(m: App): View =
  let base = newStyle().padding(1, 2).render(listBody(m))
  result = newView(if m.confirm: overlay(m, base) else: base)
  result.altScreen = true

# ---- sample data -----------------------------------------------------------
proc sampleBins(): seq[Bin] = @[
  Bin(name: "ripgrep", cur: "14.1.0", latest: "14.1.1", repo: "github.com/BurntSushi/ripgrep", arch: "amd64", libc: "gnu", size: 5_400_000, tags: @["cli"], status: stUpdate, desc: "recursively search directories for a regex"),
  Bin(name: "fzf", cur: "0.54.0", latest: "0.54.0", repo: "github.com/junegunn/fzf", arch: "amd64", libc: "gnu", size: 3_200_000, tags: @["cli"], status: stOK, desc: "a command-line fuzzy finder"),
  Bin(name: "bat", cur: "0.24.0", latest: "0.24.0", repo: "github.com/sharkdp/bat", arch: "amd64", libc: "musl", size: 6_100_000, tags: @["cli"], status: stOK, pinned: true, desc: "a cat clone with wings"),
  Bin(name: "lazygit", cur: "0.42.0", latest: "0.44.1", repo: "github.com/jesseduffield/lazygit", arch: "amd64", libc: "gnu", size: 8_900_000, tags: @["git"], status: stUpdate, desc: "simple terminal UI for git commands"),
  Bin(name: "gh", cur: "2.55.0", latest: "2.55.0", repo: "github.com/cli/cli", arch: "amd64", libc: "gnu", size: 12_300_000, tags: @["git"], status: stOK, desc: "GitHub's official command line tool"),
  Bin(name: "terraform", cur: "1.9.2", latest: "1.9.5", repo: "github.com/hashicorp/terraform", arch: "amd64", libc: "gnu", size: 78_000_000, tags: @["ops"], status: stUpdate, desc: "infrastructure as code"),
  Bin(name: "vault", cur: "", latest: "1.17.2", repo: "github.com/hashicorp/vault", arch: "—", libc: "—", size: 0, tags: @["ops"], status: stMissing, desc: "manage secrets and protect sensitive data"),
  Bin(name: "k9s", cur: "0.32.5", latest: "0.32.5", repo: "github.com/derailed/k9s", arch: "amd64", libc: "musl", size: 19_000_000, tags: @["ops"], status: stOK, desc: "kubernetes CLI to manage your clusters in style"),
  Bin(name: "glow", cur: "1.5.1", latest: "2.0.0", repo: "github.com/charmbracelet/glow", arch: "amd64", libc: "gnu", size: 7_700_000, tags: @["cli"], status: stUpdate, desc: "render markdown on the CLI, with pizzazz"),
]

when isMainModule:
  var f = newTextInput()
  f.prompt = ""
  f.placeholder = "filter…"
  let app = App(
    bins: sampleBins(),
    scopes: @["all", "cli", "git", "ops"],
    filter: f,
    spin: newSpinner(),
    status: "ready",
    w: 80, h: 24)
  discard newProgram(Model(app)).run()
