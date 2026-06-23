import std/unittest
import ../src/boba/tea/input
import ../src/boba/tea/msg
import ../src/boba/uv/key

proc bytesOf(s: string): seq[byte] =
  result = newSeq[byte](s.len)
  for i, c in s: result[i] = byte(c)

proc decodeOne(s: string, expired = false): tuple[n: int, msg: Msg] =
  decode(bytesOf(s), expired)

proc asKey(s: string, expired = false): Key =
  let (_, m) = decodeOne(s, expired)
  doAssert m != nil and m of KeyPressMsg, "expected KeyPressMsg for " & s
  KeyPressMsg(m).key

suite "input decoder":
  test "printable ascii":
    let k = asKey("a")
    check k.text == "a"
    check $k == "a"

  test "ctrl+c":
    check asKey("\x03").matchString("ctrl+c")

  test "ctrl+a":
    check asKey("\x01").matchString("ctrl+a")

  test "enter / tab / backspace":
    check asKey("\r").matchString("enter")
    check asKey("\t").matchString("tab")
    check asKey("\x7f").matchString("backspace")

  test "lone esc resolves only when expired":
    let (n0, m0) = decodeOne("\x1b", expired = false)
    check n0 == 0
    check m0 == nil
    check asKey("\x1b", expired = true).matchString("esc")

  test "arrow keys (CSI)":
    check asKey("\x1b[A").matchString("up")
    check asKey("\x1b[B").matchString("down")
    check asKey("\x1b[C").matchString("right")
    check asKey("\x1b[D").matchString("left")

  test "nav keys":
    check asKey("\x1b[H").matchString("home")
    check asKey("\x1b[F").matchString("end")
    check asKey("\x1b[3~").matchString("delete")
    check asKey("\x1b[5~").matchString("pgup")
    check asKey("\x1b[6~").matchString("pgdown")

  test "function keys (SS3 + CSI)":
    check asKey("\x1bOP").matchString("f1")
    check asKey("\x1bOQ").matchString("f2")
    check asKey("\x1b[15~").matchString("f5")
    check asKey("\x1b[24~").matchString("f12")

  test "alt+key":
    let k = asKey("\x1ba")
    check modAlt in k.mods

  test "utf-8 rune":
    let k = asKey("é")
    check k.text == "é"

  test "wide utf-8 rune":
    let k = asKey("世")
    check k.text == "世"

  test "incomplete CSI waits":
    let (n, m) = decodeOne("\x1b[")
    check n == 0
    check m == nil

  test "SGR mouse click":
    let (_, m) = decodeOne("\x1b[<0;10;5M")
    check m != nil
    check m of MouseClickMsg
    let mouse = MouseClickMsg(m).mouse
    check mouse.x == 9
    check mouse.y == 4
    check mouse.button == mbLeft

  test "SGR mouse release":
    let (_, m) = decodeOne("\x1b[<0;10;5m")
    check m of MouseReleaseMsg

  test "SGR mouse wheel up":
    let (_, m) = decodeOne("\x1b[<64;1;1M")
    check m of MouseWheelMsg
    check MouseWheelMsg(m).mouse.button == mbWheelUp

  test "modified arrow keys":
    let k = asKey("\x1b[1;5A")  # ctrl+up
    check k.code == KeyUp
    check modCtrl in k.mods
    let k2 = asKey("\x1b[1;2C")  # shift+right
    check modShift in k2.mods

  test "modified nav key":
    let k = asKey("\x1b[3;5~")  # ctrl+delete
    check k.code == KeyDelete
    check modCtrl in k.mods

  test "focus / blur events":
    let (_, f) = decodeOne("\x1b[I")
    check f of FocusMsg
    let (_, b) = decodeOne("\x1b[O")
    check b of BlurMsg

  test "bracketed paste coalesces content":
    let (n, m) = decodeOne("\x1b[200~hello world\x1b[201~")
    check m of PasteMsg
    check PasteMsg(m).content == "hello world"
    check n == "\x1b[200~hello world\x1b[201~".len

  test "incomplete paste waits":
    let (n, m) = decodeOne("\x1b[200~partial")
    check n == 0
    check m == nil

  test "kitty key press":
    let k = asKey("\x1b[97;5u")  # ctrl+a via kitty
    check k.code == int32('a'.ord)
    check modCtrl in k.mods

  test "kitty key release":
    let (_, m) = decodeOne("\x1b[97;1:3u")
    check m of KeyReleaseMsg
    check KeyReleaseMsg(m).key.code == int32('a'.ord)

  test "OSC 11 background color response (rgb:)":
    let (_, m) = decodeOne("\x1b]11;rgb:0000/0000/0000\x07")
    check m of BackgroundColorMsg
    check BackgroundColorMsg(m).isDark

  test "OSC 11 light background":
    let (_, m) = decodeOne("\x1b]11;rgb:ffff/ffff/ffff\x1b\\")  # ST-terminated
    check m of BackgroundColorMsg
    check not BackgroundColorMsg(m).isDark

  test "OSC 10 foreground color (#hex)":
    let (_, m) = decodeOne("\x1b]10;#ff8800\x07")
    check m of ForegroundColorMsg

  test "OSC 52 clipboard response":
    # base64("hi") == "aGk="
    let (_, m) = decodeOne("\x1b]52;c;aGk=\x07")
    check m of ClipboardMsg
    check ClipboardMsg(m).content == "hi"
    check ClipboardMsg(m).selection == 'c'

  test "incomplete OSC waits":
    let (n, m) = decodeOne("\x1b]11;rgb:00")
    check n == 0
    check m == nil

  test "extended function keys F13-F20":
    check asKey("\x1b[25~").matchString("f13")
    check asKey("\x1b[34~").matchString("f20")

  test "keypad keys via SS3":
    check asKey("\x1bOM").matchString("kpenter")
    check asKey("\x1bOp").matchString("kp0")
    check asKey("\x1bOy").matchString("kp9")
    check asKey("\x1bOk").matchString("kp+")

  test "primary device attributes":
    let (_, m) = decodeOne("\x1b[?64;1;2c")
    check m of PrimaryDeviceAttributesMsg
    check 64 in PrimaryDeviceAttributesMsg(m).attrs
    check 1 in PrimaryDeviceAttributesMsg(m).attrs

  test "XTVERSION (DCS) response":
    let (_, m) = decodeOne("\x1bP>|ghostty 1.0\x1b\\")
    check m of TerminalVersionMsg
    check TerminalVersionMsg(m).name == "ghostty 1.0"

  test "termcap (DCS) response":
    let (_, m) = decodeOne("\x1bP1+r5247=383838\x1b\\")
    check m of CapabilityMsg

  test "incomplete DCS waits":
    let (n, m) = decodeOne("\x1bP>|ghost")
    check n == 0
    check m == nil
