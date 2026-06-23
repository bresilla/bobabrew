## Key model — port of `ultraviolet/key.go` + `key_table.go` (the subset needed
## for matching). Special keys use code points above the Unicode range so they
## never collide with real runes.

import std/[unicode, strutils]

type
  KeyMod* = enum
    modShift
    modAlt
    modCtrl
    modMeta
    modHyper
    modSuper
    modCapsLock
    modNumLock
    modScrollLock

  Key* = object
    code*: int32        ## key code: a rune, or one of the Key* specials below
    text*: string       ## printable text produced (empty for special keys)
    shiftedCode*: int32
    baseCode*: int32
    mods*: set[KeyMod]
    isRepeat*: bool

const keySpecialBase = 0x110000'i32  ## above Unicode's max (0x10FFFF)

# Special key codes.
const
  KeyNone*      = 0'i32
  KeyUp*        = keySpecialBase + 1
  KeyDown*      = keySpecialBase + 2
  KeyRight*     = keySpecialBase + 3
  KeyLeft*      = keySpecialBase + 4
  KeyBegin*     = keySpecialBase + 5
  KeyHome*      = keySpecialBase + 6
  KeyEnd*       = keySpecialBase + 7
  KeyPgUp*      = keySpecialBase + 8
  KeyPgDown*    = keySpecialBase + 9
  KeyInsert*    = keySpecialBase + 10
  KeyDelete*    = keySpecialBase + 11
  KeyEnter*     = keySpecialBase + 12
  KeyTab*       = keySpecialBase + 13
  KeyBackspace* = keySpecialBase + 14
  KeyEscape*    = keySpecialBase + 15
  KeySpace*     = int32(' ')
  KeyF1*  = keySpecialBase + 20
  KeyF2*  = keySpecialBase + 21
  KeyF3*  = keySpecialBase + 22
  KeyF4*  = keySpecialBase + 23
  KeyF5*  = keySpecialBase + 24
  KeyF6*  = keySpecialBase + 25
  KeyF7*  = keySpecialBase + 26
  KeyF8*  = keySpecialBase + 27
  KeyF9*  = keySpecialBase + 28
  KeyF10* = keySpecialBase + 29
  KeyF11* = keySpecialBase + 30
  KeyF12* = keySpecialBase + 31
  KeyF13* = keySpecialBase + 32
  KeyF14* = keySpecialBase + 33
  KeyF15* = keySpecialBase + 34
  KeyF16* = keySpecialBase + 35
  KeyF17* = keySpecialBase + 36
  KeyF18* = keySpecialBase + 37
  KeyF19* = keySpecialBase + 38
  KeyF20* = keySpecialBase + 39

  # Keypad keys (sent in application keypad mode / Kitty protocol).
  KeyKp0* = keySpecialBase + 50
  KeyKp1* = keySpecialBase + 51
  KeyKp2* = keySpecialBase + 52
  KeyKp3* = keySpecialBase + 53
  KeyKp4* = keySpecialBase + 54
  KeyKp5* = keySpecialBase + 55
  KeyKp6* = keySpecialBase + 56
  KeyKp7* = keySpecialBase + 57
  KeyKp8* = keySpecialBase + 58
  KeyKp9* = keySpecialBase + 59
  KeyKpEnter*    = keySpecialBase + 60
  KeyKpPlus*     = keySpecialBase + 61
  KeyKpMinus*    = keySpecialBase + 62
  KeyKpMultiply* = keySpecialBase + 63
  KeyKpDivide*   = keySpecialBase + 64
  KeyKpEqual*    = keySpecialBase + 65
  KeyKpDecimal*  = keySpecialBase + 66

proc specialName(code: int32): string =
  case code
  of KeyUp: "up"
  of KeyDown: "down"
  of KeyRight: "right"
  of KeyLeft: "left"
  of KeyBegin: "begin"
  of KeyHome: "home"
  of KeyEnd: "end"
  of KeyPgUp: "pgup"
  of KeyPgDown: "pgdown"
  of KeyInsert: "insert"
  of KeyDelete: "delete"
  of KeyEnter: "enter"
  of KeyTab: "tab"
  of KeyBackspace: "backspace"
  of KeyEscape: "esc"
  of int32(' '): "space"
  of KeyF1: "f1"
  of KeyF2: "f2"
  of KeyF3: "f3"
  of KeyF4: "f4"
  of KeyF5: "f5"
  of KeyF6: "f6"
  of KeyF7: "f7"
  of KeyF8: "f8"
  of KeyF9: "f9"
  of KeyF10: "f10"
  of KeyF11: "f11"
  of KeyF12: "f12"
  of KeyF13: "f13"
  of KeyF14: "f14"
  of KeyF15: "f15"
  of KeyF16: "f16"
  of KeyF17: "f17"
  of KeyF18: "f18"
  of KeyF19: "f19"
  of KeyF20: "f20"
  of KeyKp0: "kp0"
  of KeyKp1: "kp1"
  of KeyKp2: "kp2"
  of KeyKp3: "kp3"
  of KeyKp4: "kp4"
  of KeyKp5: "kp5"
  of KeyKp6: "kp6"
  of KeyKp7: "kp7"
  of KeyKp8: "kp8"
  of KeyKp9: "kp9"
  of KeyKpEnter: "kpenter"
  of KeyKpPlus: "kp+"
  of KeyKpMinus: "kp-"
  of KeyKpMultiply: "kp*"
  of KeyKpDivide: "kp/"
  of KeyKpEqual: "kp="
  of KeyKpDecimal: "kp."
  else: ""

proc keystroke*(k: Key): string =
  ## Modifier-prefixed key name, e.g. "ctrl+c", "alt+enter", "shift+up".
  ## Modifier order matches Bubble Tea: ctrl, alt, shift, meta, hyper, super.
  result = ""
  if modCtrl in k.mods: result.add "ctrl+"
  if modAlt in k.mods: result.add "alt+"
  if modShift in k.mods: result.add "shift+"
  if modMeta in k.mods: result.add "meta+"
  if modHyper in k.mods: result.add "hyper+"
  if modSuper in k.mods: result.add "super+"
  let sp = specialName(k.code)
  if sp.len > 0:
    result.add sp
  elif k.code != 0:
    result.add $Rune(k.code)

proc `$`*(k: Key): string =
  ## The textual representation used for matching. Prefers printable text;
  ## falls back to the keystroke form.
  if k.text.len > 0 and k.mods - {modShift} == {}:
    return k.text
  keystroke(k)

proc matchString*(k: Key, patterns: varargs[string]): bool =
  let s = $k
  for p in patterns:
    if s == p: return true
  result = false
