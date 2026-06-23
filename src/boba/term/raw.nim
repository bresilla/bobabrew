## Terminal raw-mode + size — port of the bits of `x/term`/`x/termios` Bubble Tea
## needs. POSIX uses `<termios.h>`/`<sys/ioctl.h>`; Windows uses the console API
## (mode flags + screen-buffer info). The Windows path is compile-verified via
## `nim check --os:windows` but is runtime-tested only on a real Windows host.

when defined(posix):
  import std/posix
  import std/termios

type
  TermState* = object
    ## Saved terminal attributes, for restoration.
    when defined(posix):
      saved: Termios
    elif defined(windows):
      savedInMode: uint32
      savedOutMode: uint32
      inHandle: int
      outHandle: int
    valid*: bool

  Winsize* = object
    rows*, cols*: int
    xpixel*, ypixel*: int

# ---- POSIX -----------------------------------------------------------------

when defined(posix):
  proc cfmakeraw(t: ptr Termios) {.importc, header: "<termios.h>".}

  var TIOCGWINSZ {.importc, header: "<sys/ioctl.h>".}: culong

  type IOWinSize {.importc: "struct winsize", header: "<sys/ioctl.h>".} = object
    ws_row: cushort
    ws_col: cushort
    ws_xpixel: cushort
    ws_ypixel: cushort

  proc ioctlWs(fd: cint, request: culong, ws: ptr IOWinSize): cint
    {.importc: "ioctl", header: "<sys/ioctl.h>", varargs.}

# ---- Windows ---------------------------------------------------------------

when defined(windows):
  type
    WHANDLE = int
    COORD {.bycopy.} = object
      x, y: int16
    SMALL_RECT {.bycopy.} = object
      left, top, right, bottom: int16
    CONSOLE_SCREEN_BUFFER_INFO {.bycopy.} = object
      dwSize: COORD
      dwCursorPosition: COORD
      wAttributes: uint16
      srWindow: SMALL_RECT
      dwMaximumWindowSize: COORD

  const
    STD_INPUT_HANDLE  = uint32(0xFFFFFFF6'u32)   # (DWORD)-10
    STD_OUTPUT_HANDLE = uint32(0xFFFFFFF5'u32)   # (DWORD)-11
    ENABLE_PROCESSED_INPUT = 0x0001'u32
    ENABLE_LINE_INPUT = 0x0002'u32
    ENABLE_ECHO_INPUT = 0x0004'u32
    ENABLE_VIRTUAL_TERMINAL_INPUT = 0x0200'u32
    ENABLE_VIRTUAL_TERMINAL_PROCESSING = 0x0004'u32

  proc getStdHandle(n: uint32): WHANDLE
    {.importc: "GetStdHandle", dynlib: "kernel32", stdcall.}
  proc getConsoleMode(h: WHANDLE, mode: var uint32): int32
    {.importc: "GetConsoleMode", dynlib: "kernel32", stdcall.}
  proc setConsoleMode(h: WHANDLE, mode: uint32): int32
    {.importc: "SetConsoleMode", dynlib: "kernel32", stdcall.}
  proc getConsoleScreenBufferInfo(h: WHANDLE, info: var CONSOLE_SCREEN_BUFFER_INFO): int32
    {.importc: "GetConsoleScreenBufferInfo", dynlib: "kernel32", stdcall.}

  proc stdHandleFor(fd: int): WHANDLE =
    getStdHandle(if fd == 0: STD_INPUT_HANDLE else: STD_OUTPUT_HANDLE)

# ---- API -------------------------------------------------------------------

proc isTerminal*(fd: int): bool =
  ## Whether the file descriptor refers to a terminal/console.
  when defined(posix):
    isatty(cint(fd)) == 1
  elif defined(windows):
    var mode: uint32
    getConsoleMode(stdHandleFor(fd), mode) != 0
  else:
    false

proc getSize*(fd: int): tuple[w, h: int] =
  ## Terminal size in cells. Returns (0,0) if it can't be determined.
  when defined(posix):
    var ws: IOWinSize
    if ioctlWs(cint(fd), TIOCGWINSZ, addr ws) == 0:
      return (int(ws.ws_col), int(ws.ws_row))
  elif defined(windows):
    var info: CONSOLE_SCREEN_BUFFER_INFO
    let h = getStdHandle(STD_OUTPUT_HANDLE)
    if getConsoleScreenBufferInfo(h, info) != 0:
      let w = int(info.srWindow.right) - int(info.srWindow.left) + 1
      let ht = int(info.srWindow.bottom) - int(info.srWindow.top) + 1
      return (max(w, 0), max(ht, 0))
  (0, 0)

proc getWinsize*(fd: int): Winsize =
  let (w, h) = getSize(fd)
  Winsize(rows: h, cols: w)

proc makeRaw*(fd: int): TermState =
  ## Put the terminal into raw mode, returning the prior state for restore.
  when defined(posix):
    var old: Termios
    if tcGetAttr(cint(fd), addr old) != 0:
      return TermState(valid: false)
    result.saved = old
    result.valid = true
    var raw = old
    cfmakeraw(addr raw)
    discard tcSetAttr(cint(fd), TCSAFLUSH, addr raw)
  elif defined(windows):
    let inH = getStdHandle(STD_INPUT_HANDLE)
    let outH = getStdHandle(STD_OUTPUT_HANDLE)
    var inMode, outMode: uint32
    if getConsoleMode(inH, inMode) == 0 or getConsoleMode(outH, outMode) == 0:
      return TermState(valid: false)
    result.savedInMode = inMode
    result.savedOutMode = outMode
    result.inHandle = inH
    result.outHandle = outH
    result.valid = true
    # Raw input: drop line/echo/processed, enable VT input so the console emits
    # ANSI sequences our decoder understands.
    let rawIn = (inMode and not (ENABLE_LINE_INPUT or ENABLE_ECHO_INPUT or
                 ENABLE_PROCESSED_INPUT)) or ENABLE_VIRTUAL_TERMINAL_INPUT
    discard setConsoleMode(inH, rawIn)
    # Enable VT output processing so our escape sequences are interpreted.
    discard setConsoleMode(outH, outMode or ENABLE_VIRTUAL_TERMINAL_PROCESSING)
  else:
    TermState(valid: false)

proc restore*(fd: int, state: TermState) =
  ## Restore terminal attributes saved by `makeRaw`.
  when defined(posix):
    if state.valid:
      var s = state.saved
      discard tcSetAttr(cint(fd), TCSAFLUSH, addr s)
  elif defined(windows):
    if state.valid:
      discard setConsoleMode(state.inHandle, state.savedInMode)
      discard setConsoleMode(state.outHandle, state.savedOutMode)
