## Renderer — a first, correct implementation of the default ("cursed")
## renderer. It paints `View`s in either inline or alt-screen mode, redrawing
## changed lines and managing cursor visibility/position, altscreen entry/exit,
## mouse/paste/focus modes, and window title.
##
## This is the line-granular version. The cell-level minimal-diff renderer with
## scroll optimization (uv.TerminalRenderer) is the M5 deepening task; the public
## surface here is stable so the upgrade is internal.

import std/[options, strutils]
import ./view
import ../ansi/sequences
import ../ansi/c0
import ../uv/buffer
import ../uv/styled
import ../uv/renderer as uvr

type
  Renderer* = object
    output*: File
    width*, height*: int
    disabled*: bool          ## nilRenderer behavior
    started: bool
    lastCount: int           ## lines painted last inline frame
    last: View
    haveLast: bool
    cells: uvr.TerminalRenderer  ## cell-diff renderer for alt-screen mode
    cellsReady: bool

proc newRenderer*(output: File, width, height: int, disabled = false): Renderer =
  Renderer(output: output, width: width, height: height, disabled: disabled)

proc w(r: var Renderer, s: string) =
  if s.len > 0: r.output.write(s)

proc applyModes(r: var Renderer, v: View) =
  ## Emit set/reset sequences for view state that changed since last frame.
  let first = not r.haveLast
  template changedBool(field: untyped, onSeq, offSeq: string) =
    if first or r.last.field != v.field:
      if v.field: r.w(onSeq) else: (if not first: r.w(offSeq))

  # bracketed paste (on unless disabled)
  if first or r.last.disableBracketedPaste != v.disableBracketedPaste:
    if not v.disableBracketedPaste: r.w(SetModeBracketedPaste)
    elif not first: r.w(ResetModeBracketedPaste)

  changedBool(reportFocus, SetModeFocusEvent, ResetModeFocusEvent)

  if first or r.last.mouseMode != v.mouseMode:
    case v.mouseMode
    of mmNone:
      if not first and r.last.mouseMode != mmNone:
        r.w(ResetModeMouseButtonEvent & ResetModeMouseAnyEvent & ResetModeMouseExtSgr)
    of mmCellMotion:
      r.w(SetModeMouseButtonEvent & SetModeMouseExtSgr)
    of mmAllMotion:
      r.w(SetModeMouseAnyEvent & SetModeMouseExtSgr)

  if first or r.last.windowTitle != v.windowTitle:
    if v.windowTitle.len > 0 or not first:
      r.w(setWindowTitle(v.windowTitle))

proc paintInline(r: var Renderer, lines: seq[string]) =
  if r.started:
    r.w("\r")
    if r.lastCount > 1: r.w(cursorUp(r.lastCount - 1))
  for i, ln in lines:
    r.w(ln & EraseLineRight)
    if i < lines.high: r.w("\r\n")
  r.w(EraseScreenBelow)
  r.lastCount = lines.len
  r.started = true

proc paintAlt(r: var Renderer, content: string) =
  ## Alt-screen paint via the cell-level diff renderer: only changed cells are
  ## rewritten between frames.
  let w = max(r.width, 1)
  let h = max(r.height, 1)
  if not r.cellsReady or r.cells.width != w or r.cells.height != h:
    r.cells = uvr.newTerminalRenderer(w, h)
    r.cellsReady = true
  var b = newBuffer(w, h)
  newStyledString(content).draw(b)
  r.w(r.cells.render(b))

proc render*(r: var Renderer, v: View) =
  if r.disabled: return

  # Hide cursor for the duration of the repaint to avoid flicker.
  r.w(ResetModeTextCursorEnable)

  # Enter/exit alt screen if it changed.
  let wasAlt = r.haveLast and r.last.altScreen
  if v.altScreen and (not r.haveLast or not wasAlt):
    r.w(SetModeAltScreenSaveCursor)
    r.cellsReady = false   # entering altscreen: force a full first paint
  elif (not v.altScreen) and r.haveLast and wasAlt:
    r.w(ResetModeAltScreenSaveCursor)
    r.started = false

  r.applyModes(v)

  if v.altScreen:
    r.paintAlt(v.content)
  else:
    r.paintInline(v.content.split('\n'))

  # Cursor: place + show if requested, else leave hidden.
  if v.cursor.isSome:
    let c = v.cursor.get
    r.w(moveTo(c.x, c.y))
    r.w(SetModeTextCursorEnable)

  r.last = v
  r.haveLast = true
  r.output.flushFile()

proc clearScreen*(r: var Renderer) =
  if r.disabled: return
  r.w(CursorHomePos & EraseEntireScreen)
  r.output.flushFile()

proc insertAbove*(r: var Renderer, s: string) =
  ## Print unmanaged lines above the program (inline mode only).
  if r.disabled or s.len == 0: return
  r.w("\r")
  if r.lastCount > 1: r.w(cursorUp(r.lastCount - 1))
  for ln in s.split('\n'):
    r.w(ln & EraseLineRight & "\r\n")
  r.started = false
  r.haveLast = false
  r.output.flushFile()

proc start*(r: var Renderer) = discard

proc release*(r: var Renderer) =
  ## Temporarily hand the terminal back (used around Exec): leave altscreen,
  ## reset modes, show the cursor — but keep enough state to repaint on return.
  if r.disabled: return
  if r.haveLast:
    let v = r.last
    if v.altScreen: r.w(ResetModeAltScreenSaveCursor)
    if not v.disableBracketedPaste: r.w(ResetModeBracketedPaste)
    if v.reportFocus: r.w(ResetModeFocusEvent)
    if v.mouseMode != mmNone:
      r.w(ResetModeMouseButtonEvent & ResetModeMouseAnyEvent & ResetModeMouseExtSgr)
  r.w(SetModeTextCursorEnable)
  r.output.flushFile()

proc forceRepaint*(r: var Renderer) =
  ## Discard cached frame state so the next render repaints from scratch.
  r.haveLast = false
  r.started = false
  r.cellsReady = false

proc finish*(r: var Renderer) =
  ## Restore the terminal: leave altscreen, reset modes, show cursor.
  if r.disabled: return
  if r.haveLast:
    let v = r.last
    if v.altScreen:
      r.w(ResetModeAltScreenSaveCursor)
    else:
      r.w("\r\n")
    if not v.disableBracketedPaste: r.w(ResetModeBracketedPaste)
    if v.reportFocus: r.w(ResetModeFocusEvent)
    if v.mouseMode != mmNone:
      r.w(ResetModeMouseButtonEvent & ResetModeMouseAnyEvent & ResetModeMouseExtSgr)
    if v.windowTitle.len > 0: r.w(setWindowTitle(""))
  r.w(SetModeTextCursorEnable)
  r.output.flushFile()
