## A single-line text input component — port of the core of
## `charmbracelet/bubbles/textinput`.
##
## Embed it in your model, forward key messages via `update`, and render with
## `view`. Text is stored as runes so the cursor and editing are correct for
## multi-byte / wide characters.

import std/[unicode, strutils]
import ../tea/msg
import ../uv/key
import ../ansi/style
import ../ansi/c0

type
  TextInput* = object
    runes: seq[Rune]
    cursor*: int            ## rune index of the caret (0..len)
    placeholder*: string
    prompt*: string
    focused*: bool
    charLimit*: int         ## 0 = unlimited

proc newTextInput*(): TextInput =
  TextInput(cursor: 0, prompt: "> ", focused: true, charLimit: 0)

proc value*(t: TextInput): string =
  for r in t.runes: result.add $r

proc setValue*(t: var TextInput, s: string) =
  t.runes = toRunes(s)
  t.cursor = t.runes.len

proc clear*(t: var TextInput) =
  t.runes.setLen(0)
  t.cursor = 0

proc insertRune(t: var TextInput, r: Rune) =
  if t.charLimit > 0 and t.runes.len >= t.charLimit: return
  t.runes.insert(r, t.cursor)
  inc t.cursor

proc update*(t: var TextInput, m: Msg) =
  ## Apply a message (only key presses matter) to the input.
  if not t.focused: return
  if not (m of KeyPressMsg): return
  let k = KeyPressMsg(m).key

  # Editing keys.
  case k.code
  of KeyBackspace:
    if t.cursor > 0:
      t.runes.delete(t.cursor - 1)
      dec t.cursor
    return
  of KeyDelete:
    if t.cursor < t.runes.len:
      t.runes.delete(t.cursor)
    return
  of KeyLeft:
    if t.cursor > 0: dec t.cursor
    return
  of KeyRight:
    if t.cursor < t.runes.len: inc t.cursor
    return
  of KeyHome:
    t.cursor = 0
    return
  of KeyEnd:
    t.cursor = t.runes.len
    return
  else: discard

  # Common ctrl shortcuts.
  if modCtrl in k.mods:
    case k.code
    of int32('a'.ord): t.cursor = 0
    of int32('e'.ord): t.cursor = t.runes.len
    of int32('u'.ord): (t.runes = t.runes[t.cursor .. ^1]; t.cursor = 0)
    of int32('k'.ord): t.runes.setLen(t.cursor)
    else: discard
    return

  # Printable text (no modifiers other than shift).
  if k.text.len > 0 and (k.mods - {modShift}) == {}:
    for r in toRunes(k.text):
      t.insertRune(r)

proc view*(t: TextInput): string =
  ## Render prompt + text with a block caret (reverse video) at the cursor.
  if t.runes.len == 0 and t.placeholder.len > 0 and not t.focused:
    return t.prompt & EmptyStyle.faint.styled(t.placeholder)

  var body = ""
  let caret = EmptyStyle.reverse
  for i in 0 .. t.runes.len:
    if i == t.cursor and t.focused:
      let under = if i < t.runes.len: $t.runes[i] else: " "
      body.add caret.styled(under)
      if i < t.runes.len: continue  # the caret consumed this rune
    if i < t.runes.len:
      body.add $t.runes[i]
  result = t.prompt & body
