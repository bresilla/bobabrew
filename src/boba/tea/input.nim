## Input decoder — bytes from the terminal to `Msg`s.
##
## A first, robust port of the common paths in `ultraviolet/decoder.go`:
## C0 control keys, UTF-8 text, ESC-prefixed alt keys, CSI arrow/nav/function
## keys, SS3 function keys, and SGR mouse. The full Kitty/win32/DCS/OSC decoder
## is the M4 deepening task (see docs/PLAN.md).
##
## `decode` returns how many bytes it consumed and the message produced. It
## returns `(0, nil)` when the buffer holds an incomplete sequence and more
## bytes are needed; the caller passes `expired = true` once an inter-byte
## timeout elapses so a lone ESC resolves to the Escape key.

import std/[unicode, strutils, base64]
import ./msg
import ../uv/key
import ../ansi/color

proc parseIntSafe(s: string): int =
  for ch in s:
    if ch in '0' .. '9': result = result * 10 + (ord(ch) - ord('0'))
    else: return 0

proc decodeXtermMods(modParam: int): set[KeyMod] =
  ## XTerm/Kitty modifier param: `1 + bitmask`.
  if modParam <= 1: return {}
  let bits = modParam - 1
  if (bits and 1) != 0: result.incl modShift
  if (bits and 2) != 0: result.incl modAlt
  if (bits and 4) != 0: result.incl modCtrl
  if (bits and 8) != 0: result.incl modSuper
  if (bits and 16) != 0: result.incl modHyper
  if (bits and 32) != 0: result.incl modMeta
  if (bits and 64) != 0: result.incl modCapsLock
  if (bits and 128) != 0: result.incl modNumLock

proc ctrlKey(b: byte): KeyPressMsg =
  ## Map a C0 control byte to its key press.
  case b
  of 0x09: newKeyPress(Key(code: KeyTab))
  of 0x0d, 0x0a: newKeyPress(Key(code: KeyEnter))
  of 0x08, 0x7f: newKeyPress(Key(code: KeyBackspace))
  of 0x1b: newKeyPress(Key(code: KeyEscape))
  of 0x00: newKeyPress(Key(code: KeySpace, mods: {modCtrl}))
  else:
    # 0x01..0x1a => ctrl+a .. ctrl+z
    let letter = int32('a'.ord) + int32(b) - 1
    newKeyPress(Key(code: letter, mods: {modCtrl}))

proc finalByte(b: byte): bool = b >= 0x40 and b <= 0x7e

proc parseCsi(buf: openArray[byte]): tuple[n: int, msg: Msg] =
  ## buf[0]=ESC, buf[1]='['. Parse a CSI sequence.
  var i = 2
  let n = buf.len
  # parameter + intermediate bytes until a final byte.
  while i < n and not finalByte(buf[i]): inc i
  if i >= n: return (0, nil)   # incomplete
  let final = buf[i]
  var p = ""
  for j in 2 ..< i: p.add char(buf[j])
  let consumed = i + 1

  template press(c: int32, m: set[KeyMod] = {}): tuple[n: int, msg: Msg] =
    (consumed, Msg(newKeyPress(Key(code: c, mods: m))))

  # SGR mouse: ESC [ < b ; x ; y (M|m)
  if p.len > 0 and p[0] == '<':
    let body = p[1 .. ^1]
    var parts: seq[int]
    var cur = ""
    for ch in body:
      if ch == ';': (parts.add (if cur.len > 0: parseIntSafe(cur) else: 0); cur = "")
      else: cur.add ch
    if cur.len > 0: parts.add parseIntSafe(cur)
    if parts.len >= 3:
      let cb = parts[0]
      let mx = parts[1] - 1
      let my = parts[2] - 1
      let release = char(final) == 'm'
      var mouse = Mouse(x: mx, y: my)
      let lowbits = cb and 0b11
      if (cb and 64) != 0:
        mouse.button = if lowbits == 0: mbWheelUp else: mbWheelDown
        return (consumed, MouseWheelMsg(mouse: mouse))
      else:
        mouse.button = case lowbits
          of 0: mbLeft
          of 1: mbMiddle
          of 2: mbRight
          else: mbNone
        if (cb and 32) != 0:
          return (consumed, MouseMotionMsg(mouse: mouse))
        if release:
          return (consumed, MouseReleaseMsg(mouse: mouse))
        return (consumed, MouseClickMsg(mouse: mouse))
    return (consumed, nil)

  # Split params on ';'. A segment may carry ':'-subparams (Kitty).
  let segs = if p.len > 0: p.split(';') else: @[]
  proc segNum(idx: int): int =
    if idx < segs.len: parseIntSafe(segs[idx].split(':')[0]) else: 0
  let num = segNum(0)
  let modParam = if segs.len > 1: segNum(1) else: 1
  let mods = decodeXtermMods(modParam)

  # Focus events (bare CSI I / CSI O).
  if char(final) == 'I' and segs.len == 0: return (consumed, FocusMsg())
  if char(final) == 'O' and segs.len == 0: return (consumed, BlurMsg())

  # Primary device attributes response: CSI ? ... c
  if char(final) == 'c':
    var attrs: seq[int]
    for part in p.replace("?", "").split(';'):
      if part.len > 0: attrs.add parseIntSafe(part)
    return (consumed, PrimaryDeviceAttributesMsg(attrs: attrs))

  case char(final)
  of 'A': return press(KeyUp, mods)
  of 'B': return press(KeyDown, mods)
  of 'C': return press(KeyRight, mods)
  of 'D': return press(KeyLeft, mods)
  of 'H': return press(KeyHome, mods)
  of 'F': return press(KeyEnd, mods)
  of 'Z': return press(KeyTab, mods + {modShift})
  of 'u':
    # Kitty keyboard: CSI codepoint ; mods : event-type u
    if num == 0: return (consumed, nil)
    var eventType = 1
    if segs.len > 1:
      let sub = segs[1].split(':')
      if sub.len > 1: eventType = parseIntSafe(sub[1])
    let k = Key(code: int32(num), mods: mods)
    if eventType == 3:
      return (consumed, KeyReleaseMsg(key: k))
    return (consumed, newKeyPress(k))
  of '~':
    # Bracketed paste: collect content between 200~ and 201~.
    if num == 200:
      const term = "\x1b[201~"
      var k = consumed
      var content = ""
      while k < n:
        if k + term.len <= n:
          var matched = true
          for t in 0 ..< term.len:
            if buf[k + t] != byte(term[t]): (matched = false; break)
          if matched:
            return (k + term.len, PasteMsg(content: content))
        content.add char(buf[k])
        inc k
      return (0, nil)  # incomplete paste; wait for the terminator
    if num == 201: return (consumed, PasteEndMsg())
    case num
    of 1, 7: return press(KeyHome, mods)
    of 2: return press(KeyInsert, mods)
    of 3: return press(KeyDelete, mods)
    of 4, 8: return press(KeyEnd, mods)
    of 5: return press(KeyPgUp, mods)
    of 6: return press(KeyPgDown, mods)
    of 15: return press(KeyF5, mods)
    of 17: return press(KeyF6, mods)
    of 18: return press(KeyF7, mods)
    of 19: return press(KeyF8, mods)
    of 20: return press(KeyF9, mods)
    of 21: return press(KeyF10, mods)
    of 23: return press(KeyF11, mods)
    of 24: return press(KeyF12, mods)
    of 25: return press(KeyF13, mods)
    of 26: return press(KeyF14, mods)
    of 28: return press(KeyF15, mods)
    of 29: return press(KeyF16, mods)
    of 31: return press(KeyF17, mods)
    of 32: return press(KeyF18, mods)
    of 33: return press(KeyF19, mods)
    of 34: return press(KeyF20, mods)
    else: return (consumed, nil)
  else:
    return (consumed, nil)

proc parseSs3(buf: openArray[byte]): tuple[n: int, msg: Msg] =
  ## buf[0]=ESC, buf[1]='O'. SS3 function keys.
  if buf.len < 3: return (0, nil)
  let f = buf[2]
  template press(c: int32): tuple[n: int, msg: Msg] =
    (3, Msg(newKeyPress(Key(code: c))))
  case char(f)
  of 'P': press(KeyF1)
  of 'Q': press(KeyF2)
  of 'R': press(KeyF3)
  of 'S': press(KeyF4)
  of 'A': press(KeyUp)
  of 'B': press(KeyDown)
  of 'C': press(KeyRight)
  of 'D': press(KeyLeft)
  of 'H': press(KeyHome)
  of 'F': press(KeyEnd)
  # Application-keypad mode (SS3) keys.
  of 'M': press(KeyKpEnter)
  of 'j': press(KeyKpMultiply)
  of 'k': press(KeyKpPlus)
  of 'm': press(KeyKpMinus)
  of 'n': press(KeyKpDecimal)
  of 'o': press(KeyKpDivide)
  of 'X': press(KeyKpEqual)
  of 'p': press(KeyKp0)
  of 'q': press(KeyKp1)
  of 'r': press(KeyKp2)
  of 's': press(KeyKp3)
  of 't': press(KeyKp4)
  of 'u': press(KeyKp5)
  of 'v': press(KeyKp6)
  of 'w': press(KeyKp7)
  of 'x': press(KeyKp8)
  of 'y': press(KeyKp9)
  else: (3, nil)

proc hexByte(s: string): int =
  for ch in s:
    let v = case ch
      of '0' .. '9': ord(ch) - ord('0')
      of 'a' .. 'f': ord(ch) - ord('a') + 10
      of 'A' .. 'F': ord(ch) - ord('A') + 10
      else: 0
    result = result * 16 + v

proc parseColorSpec(s: string): Color =
  ## Parse "rgb:RRRR/GGGG/BBBB", "rgb:RR/GG/BB" or "#RRGGBB".
  if s.startsWith("rgb:"):
    let parts = s[4 .. ^1].split('/')
    if parts.len == 3:
      proc chan(h: string): uint8 =
        # Use the high byte for 4-digit (16-bit) channels.
        if h.len >= 2: uint8(hexByte(h[0 ..< 2])) else: uint8(hexByte(h))
      return trueColor(chan(parts[0]), chan(parts[1]), chan(parts[2]))
  elif s.startsWith("#") and s.len >= 7:
    return trueColor(uint8(hexByte(s[1 ..< 3])), uint8(hexByte(s[3 ..< 5])),
                     uint8(hexByte(s[5 ..< 7])))
  NoColor

proc parseOsc(buf: openArray[byte], expired: bool): tuple[n: int, msg: Msg] =
  ## buf[0]=ESC, buf[1]=']'. Parse OSC color (10/11/12) and clipboard (52)
  ## responses, terminated by BEL or ST.
  let n = buf.len
  var j = 2
  var body = ""
  var consumed = 0
  while j < n:
    if buf[j] == 0x07:  # BEL
      consumed = j + 1; break
    if buf[j] == 0x1b and j + 1 < n and buf[j + 1] == byte('\\'):  # ST
      consumed = j + 2; break
    body.add char(buf[j])
    inc j
  if consumed == 0:
    return (0, nil)  # no terminator yet
  let semi = body.find(';')
  if semi < 0: return (consumed, nil)
  let ps = body[0 ..< semi]
  let pt = body[semi + 1 .. ^1]
  case ps
  of "10": return (consumed, ForegroundColorMsg(color: parseColorSpec(pt)))
  of "11": return (consumed, BackgroundColorMsg(color: parseColorSpec(pt)))
  of "12": return (consumed, CursorColorMsg(color: parseColorSpec(pt)))
  of "52":
    # Pt = "<selection>;<base64>"
    let sc = pt.split(';')
    if sc.len >= 2:
      var content = ""
      try: content = decode(sc[1]) except CatchableError: content = ""
      return (consumed, ClipboardMsg(content: content,
              selection: (if sc[0].len > 0: sc[0][0] else: 'c')))
    return (consumed, nil)
  else: return (consumed, nil)

proc parseDcs(buf: openArray[byte]): tuple[n: int, msg: Msg] =
  ## buf[0]=ESC, buf[1]='P'. DCS string terminated by ST. Recognizes XTVERSION
  ## (`>|name`) and XTGETTCAP (`1+r...`) responses.
  let n = buf.len
  var j = 2
  var body = ""
  var consumed = 0
  while j < n:
    if buf[j] == 0x1b and j + 1 < n and buf[j + 1] == byte('\\'):
      consumed = j + 2; break
    body.add char(buf[j])
    inc j
  if consumed == 0: return (0, nil)
  if body.startsWith(">|"):
    return (consumed, TerminalVersionMsg(name: body[2 .. ^1]))
  if body.startsWith("1+r") or body.startsWith("0+r"):
    return (consumed, CapabilityMsg(content: body[3 .. ^1]))
  (consumed, nil)

proc decode*(buf: openArray[byte], expired: bool): tuple[n: int, msg: Msg] =
  ## Decode one event from the front of `buf`.
  if buf.len == 0: return (0, nil)
  let b0 = buf[0]

  if b0 == 0x1b:  # ESC
    if buf.len == 1:
      if expired:
        return (1, newKeyPress(Key(code: KeyEscape)))
      return (0, nil)  # wait for more
    case char(buf[1])
    of '[': return parseCsi(buf)
    of 'O': return parseSs3(buf)
    of ']': return parseOsc(buf, expired)
    of 'P': return parseDcs(buf)
    else:
      # ESC + key => alt+key. Decode the remainder, add modAlt.
      let (rn, rmsg) = decode(buf[1 .. ^1], expired)
      if rn == 0: return (0, nil)
      if rmsg != nil and rmsg of KeyPressMsg:
        var k = KeyPressMsg(rmsg).key
        k.mods.incl modAlt
        return (rn + 1, newKeyPress(k))
      return (rn + 1, rmsg)

  if b0 < 0x20 or b0 == 0x7f:
    return (1, ctrlKey(b0))

  if b0 == 0x20:
    return (1, newKeyPress(Key(code: KeySpace, text: " ")))

  # Printable: decode one UTF-8 rune.
  if b0 < 0x80:
    return (1, newKeyPress(Key(code: int32(b0), text: $char(b0))))

  # Multibyte UTF-8.
  var s = newString(buf.len)
  for i in 0 ..< buf.len: s[i] = char(buf[i])
  var r: Rune
  var i = 0
  fastRuneAt(s, i, r, true)
  if i > buf.len: return (0, nil)  # incomplete multibyte
  return (i, newKeyPress(Key(code: int32(r), text: $r)))
