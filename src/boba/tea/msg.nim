## Bubble Tea messages — port of the `*Msg` types spread across the Go `tea`
## package (tea.go, key.go, mouse.go, screen.go, focus.go, paste.go, color.go,
## clipboard.go, environ.go, …).
##
## `Msg` is the open base type (Go's `Msg = uv.Event = interface{}`). Built-in
## and user-defined messages alike derive from it and are matched with `of`.

import std/tables
import ../uv/key
import ../colorprofile
import ../ansi/color

type
  Msg* = ref object of RootObj
    ## Base of all messages. User messages: `type Foo = ref object of Msg`.

  # ---- lifecycle ----
  QuitMsg* = ref object of Msg
  InterruptMsg* = ref object of Msg
  SuspendMsg* = ref object of Msg
  ResumeMsg* = ref object of Msg

  # ---- window / environment ----
  WindowSizeMsg* = ref object of Msg
    width*, height*: int
  ColorProfileMsg* = ref object of Msg
    profile*: Profile
  EnvMsg* = ref object of Msg
    env*: Table[string, string]

  # ---- keyboard ----
  KeyPressMsg* = ref object of Msg
    key*: Key
  KeyReleaseMsg* = ref object of Msg
    key*: Key

  # ---- mouse ----
  MouseButton* = enum
    mbNone, mbLeft, mbMiddle, mbRight,
    mbWheelUp, mbWheelDown, mbWheelLeft, mbWheelRight,
    mbBackward, mbForward
  Mouse* = object
    x*, y*: int
    button*: MouseButton
    mods*: set[KeyMod]
  MouseClickMsg* = ref object of Msg
    mouse*: Mouse
  MouseReleaseMsg* = ref object of Msg
    mouse*: Mouse
  MouseWheelMsg* = ref object of Msg
    mouse*: Mouse
  MouseMotionMsg* = ref object of Msg
    mouse*: Mouse

  # ---- focus / paste ----
  FocusMsg* = ref object of Msg
  BlurMsg* = ref object of Msg
  PasteMsg* = ref object of Msg
    content*: string
  PasteStartMsg* = ref object of Msg
  PasteEndMsg* = ref object of Msg

  # ---- terminal queries / reports ----
  CursorPositionMsg* = ref object of Msg
    x*, y*: int
  ClipboardMsg* = ref object of Msg
    content*: string
    selection*: char
  ForegroundColorMsg* = ref object of Msg
    color*: Color
  BackgroundColorMsg* = ref object of Msg
    color*: Color
  CursorColorMsg* = ref object of Msg
    color*: Color
  TerminalVersionMsg* = ref object of Msg
    name*: string
  CapabilityMsg* = ref object of Msg
    content*: string
  PrimaryDeviceAttributesMsg* = ref object of Msg
    attrs*: seq[int]

  # ---- internal control messages ----
  clearScreenMsg* = ref object of Msg
  printLineMessage* = ref object of Msg
    body*: string
  windowSizeReqMsg* = ref object of Msg
  setClipboardMsg* = ref object of Msg
    content*: string
    primary*: bool
  readClipboardMsg* = ref object of Msg
    primary*: bool
  reqBackgroundColorMsg* = ref object of Msg
  reqForegroundColorMsg* = ref object of Msg
  reqCursorColorMsg* = ref object of Msg
  rawMsg* = ref object of Msg
    body*: string
  ExecMsg* = ref object of Msg
    ## Run an external process, suspending the program until it exits.
    command*: string
    args*: seq[string]
    callback*: proc (exitCode: int): Msg {.gcsafe.}

proc key*(m: KeyPressMsg): Key {.inline.} = m.key
proc `$`*(m: KeyPressMsg): string = $m.key
proc `$`*(m: KeyReleaseMsg): string = $m.key

proc newKeyPress*(k: Key): KeyPressMsg = KeyPressMsg(key: k)
proc newWindowSize*(w, h: int): WindowSizeMsg =
  WindowSizeMsg(width: w, height: h)

proc isDark*(c: Color): bool =
  ## Whether a color is "dark" by perceptual luminance (< 0.5).
  let (r, g, b) = c.toRGB()
  let lum = (0.299 * float(r) + 0.587 * float(g) + 0.114 * float(b)) / 255.0
  lum < 0.5

proc isDark*(m: BackgroundColorMsg): bool = m.color.isDark
proc isDark*(m: ForegroundColorMsg): bool = m.color.isDark
