## Escape-sequence builders — consolidated port of the builders Bubble Tea uses
## from `x/ansi` (`cursor.go`, `screen.go`, `osc.go`, `title.go`, `kitty.go`,
## clipboard/notification/progress). Constant strings mirror the Go names so the
## renderer port reads 1:1.

import std/strutils
import std/base64
import ./c0
import ./color
import ./mode

# ---- cursor movement -------------------------------------------------------

proc cursorUp*(n: int): string =
  if n <= 0: "" else: CSI & $n & "A"
proc cursorDown*(n: int): string =
  if n <= 0: "" else: CSI & $n & "B"
proc cursorForward*(n: int): string =
  if n <= 0: "" else: CSI & $n & "C"
proc cursorBackward*(n: int): string =
  if n <= 0: "" else: CSI & $n & "D"

proc cursorPosition*(col, row: int): string =
  ## Move to 1-based (row, col). Bubble Tea calls with 0-based x,y and adds 1.
  CSI & $(row + 1) & ";" & $(col + 1) & "H"

proc moveTo*(x, y: int): string = cursorPosition(x, y)

const
  SaveCursor*       = ESC & "7"
  RestoreCursor*    = ESC & "8"
  CursorHomePos*    = CSI & "H"
  RequestCursorPositionReport* = CSI & "6n"

proc setCursorStyle*(style: int): string =
  ## DECSCUSR — `CSI Ps SP q`. 0/1 blink block, 2 steady block, etc.
  CSI & $style & " q"

# ---- erase / scroll --------------------------------------------------------

const
  EraseScreenBelow* = CSI & "0J"
  EraseScreenAbove* = CSI & "1J"
  EraseEntireScreen* = CSI & "2J"
  EraseLineRight*   = CSI & "0K"
  EraseLineLeft*    = CSI & "1K"
  EraseEntireLine*  = CSI & "2K"

proc insertLine*(n: int): string =
  if n <= 0: "" else: CSI & $n & "L"
proc deleteLine*(n: int): string =
  if n <= 0: "" else: CSI & $n & "M"
proc insertChar*(n: int): string =
  if n <= 0: "" else: CSI & $n & "@"
proc deleteChar*(n: int): string =
  if n <= 0: "" else: CSI & $n & "P"
proc eraseChar*(n: int): string =
  if n <= 0: "" else: CSI & $n & "X"
proc scrollUp*(n: int): string =
  if n <= 0: "" else: CSI & $n & "S"
proc scrollDown*(n: int): string =
  if n <= 0: "" else: CSI & $n & "T"

const SetTabEvery8Columns* = ESC & "H"  ## placeholder (per-column HTS done elsewhere)

# ---- modes (set/reset strings used verbatim by the renderer) ---------------

let
  SetModeTextCursorEnable*    = setMode(ModeTextCursorEnable)
  ResetModeTextCursorEnable*  = resetMode(ModeTextCursorEnable)
  SetModeBracketedPaste*      = setMode(ModeBracketedPaste)
  ResetModeBracketedPaste*    = resetMode(ModeBracketedPaste)
  SetModeFocusEvent*          = setMode(ModeFocusEvent)
  ResetModeFocusEvent*        = resetMode(ModeFocusEvent)
  SetModeMouseButtonEvent*    = setMode(ModeMouseButtonEvent)
  ResetModeMouseButtonEvent*  = resetMode(ModeMouseButtonEvent)
  SetModeMouseAnyEvent*       = setMode(ModeMouseAnyEvent)
  ResetModeMouseAnyEvent*     = resetMode(ModeMouseAnyEvent)
  SetModeMouseExtSgr*         = setMode(ModeMouseSgrExt)
  ResetModeMouseExtSgr*       = resetMode(ModeMouseSgrExt)
  SetModeAltScreenSaveCursor* = setMode(ModeAltScreenSaveCursor)
  ResetModeAltScreenSaveCursor* = resetMode(ModeAltScreenSaveCursor)
  SetModeSynchronizedOutput*  = setMode(ModeSynchronizedOutput)
  ResetModeSynchronizedOutput* = resetMode(ModeSynchronizedOutput)
  SetModeUnicodeCore*         = setMode(ModeUnicodeCore)
  ResetModeUnicodeCore*       = resetMode(ModeUnicodeCore)
  RequestModeSynchronizedOutput* = requestMode(ModeSynchronizedOutput)
  RequestModeUnicodeCore*     = requestMode(ModeUnicodeCore)

# ---- OSC: title, colors, clipboard, hyperlink, notification ---------------

proc setWindowTitle*(s: string): string = OSC & "2;" & s & BEL

proc setForegroundColor*(hex: string): string = OSC & "10;" & hex & BEL
proc setBackgroundColor*(hex: string): string = OSC & "11;" & hex & BEL
proc setCursorColor*(hex: string): string = OSC & "12;" & hex & BEL
const
  ResetForegroundColor* = OSC & "110" & BEL
  ResetBackgroundColor* = OSC & "111" & BEL
  ResetCursorColor*     = OSC & "112" & BEL
  RequestForegroundColor* = OSC & "10;?" & BEL
  RequestBackgroundColor* = OSC & "11;?" & BEL
  RequestCursorColor*     = OSC & "12;?" & BEL

proc setForegroundColor*(c: Color): string = setForegroundColor(c.hex)
proc setBackgroundColor*(c: Color): string = setBackgroundColor(c.hex)
proc setCursorColor*(c: Color): string = setCursorColor(c.hex)

proc setHyperlink*(url: string, id = ""): string =
  let params = if id.len > 0: "id=" & id else: ""
  OSC & "8;" & params & ";" & url & ST
const ResetHyperlink* = OSC & "8;;" & ST

proc setSystemClipboard*(s: string): string =
  OSC & "52;c;" & encode(s) & ST
proc setPrimaryClipboard*(s: string): string =
  OSC & "52;p;" & encode(s) & ST
const
  RequestSystemClipboard*  = OSC & "52;c;?" & ST
  RequestPrimaryClipboard* = OSC & "52;p;?" & ST

proc notify*(s: string): string = OSC & "9;" & s & BEL

# ---- progress bar (Windows Terminal OSC 9;4) ------------------------------

proc setProgressBar*(value: int): string = OSC & "9;4;1;" & $value & BEL
proc setErrorProgressBar*(value: int): string = OSC & "9;4;2;" & $value & BEL
const SetIndeterminateProgressBar* = OSC & "9;4;3;" & BEL
proc setWarningProgressBar*(value: int): string = OSC & "9;4;4;" & $value & BEL
const ResetProgressBar* = OSC & "9;4;0;" & BEL

# ---- device/terminal queries ----------------------------------------------

const
  RequestPrimaryDeviceAttributes* = CSI & "c"
  RequestSecondaryDeviceAttributes* = CSI & ">c"
  RequestNameVersion* = CSI & ">0q"   ## XTVERSION

proc requestTermcap*(cap: string): string =
  ## XTGETTCAP via DCS + q.
  var hexcap = ""
  for ch in cap:
    hexcap.add toHex(ord(ch), 2)
  DCS & "+q" & hexcap & ST

# ---- Kitty keyboard + XTerm modifyOtherKeys -------------------------------

const
  KittyReportEventTypes*          = 0b1000
  KittyReportAlternateKeys*       = 0b10000
  KittyReportAllKeysAsEscapeCodes* = 0b100000
  KittyReportAssociatedKeys*      = 0b1000000

proc kittyKeyboard*(flags, mode: int): string =
  CSI & "=" & $flags & ";" & $mode & "u"
const
  RequestKittyKeyboard* = CSI & "?u"
  SetModifyOtherKeys2*  = CSI & ">4;2m"
  ResetModifyOtherKeys* = CSI & ">4;0m"
