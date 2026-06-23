## DEC private modes and ANSI modes — port of the parts of `x/ansi/mode.go`
## that Bubble Tea uses. A mode is set with `CSI ? Pm h`, reset with
## `CSI ? Pm l`, and queried with `CSI ? Pm $ p` (DECRQM); the terminal replies
## with a DECRPM report carrying a `ModeSetting`.

import ./c0

type
  ModeSetting* = enum
    ## Values reported by DECRPM (`CSI ? Pm ; Ps $ y`).
    msNotRecognized = 0
    msSet = 1
    msReset = 2
    msPermanentlySet = 3
    msPermanentlyReset = 4

proc isNotRecognized*(m: ModeSetting): bool {.inline.} = m == msNotRecognized

# DEC private mode numbers used by Bubble Tea.
const
  ModeTextCursorEnable*   = 25     ## DECTCEM — cursor visibility
  ModeMouseX10*           = 9
  ModeMouseButtonEvent*   = 1002   ## cell-motion mouse tracking
  ModeMouseAnyEvent*      = 1003   ## all-motion mouse tracking
  ModeMouseSgrExt*        = 1006   ## SGR extended mouse encoding
  ModeFocusEvent*         = 1004
  ModeAltScreenSaveCursor* = 1049
  ModeBracketedPaste*     = 2004
  ModeSynchronizedOutput* = 2026
  ModeUnicodeCore*        = 2027

proc setMode*(n: int): string = CSI & "?" & $n & "h"
proc resetMode*(n: int): string = CSI & "?" & $n & "l"
proc requestMode*(n: int): string = CSI & "?" & $n & "$p"
