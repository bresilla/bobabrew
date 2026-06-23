## ANSI color model.
##
## Port of the colors used by `charmbracelet/x/ansi` plus the bits of
## `image/color` that Bubble Tea actually relies on. Terminals can only display
## one of four things, so we model color as a value-type variant instead of the
## open `image/color.Color` interface — this keeps equality and copying trivial
## while preserving full RGB fidelity.

type
  ColorKind* = enum
    ckNone       ## terminal default / reset (Go: nil color)
    ckBasic      ## one of the 16 ANSI colors (0..15)
    ckExtended   ## 256-color palette index (0..255)
    ckTrue       ## 24-bit RGB

  Color* = object
    case kind*: ColorKind
    of ckNone: discard
    of ckBasic: basic*: uint8       ## 0..15
    of ckExtended: index*: uint8    ## 0..255
    of ckTrue:
      r*, g*, b*: uint8

const
  NoColor* = Color(kind: ckNone)

# ANSI basic color indices (SGR 30-37 / 40-47, bright 90-97 / 100-107).
const
  Black*         = 0'u8
  Red*           = 1'u8
  Green*         = 2'u8
  Yellow*        = 3'u8
  Blue*          = 4'u8
  Magenta*       = 5'u8
  Cyan*          = 6'u8
  White*         = 7'u8
  BrightBlack*   = 8'u8
  BrightRed*     = 9'u8
  BrightGreen*   = 10'u8
  BrightYellow*  = 11'u8
  BrightBlue*    = 12'u8
  BrightMagenta* = 13'u8
  BrightCyan*    = 14'u8
  BrightWhite*   = 15'u8

proc basicColor*(n: uint8): Color =
  ## A 16-color ANSI color (0..15).
  Color(kind: ckBasic, basic: n and 0x0f)

proc extendedColor*(n: uint8): Color =
  ## A 256-color palette color (0..255).
  Color(kind: ckExtended, index: n)

proc trueColor*(r, g, b: uint8): Color =
  ## A 24-bit RGB color.
  Color(kind: ckTrue, r: r, g: g, b: b)

proc rgbColor*(rgb: uint32): Color =
  ## A 24-bit RGB color from a packed 0xRRGGBB value.
  trueColor(uint8((rgb shr 16) and 0xff), uint8((rgb shr 8) and 0xff),
            uint8(rgb and 0xff))

proc isNone*(c: Color): bool {.inline.} = c.kind == ckNone

proc `==`*(a, b: Color): bool =
  if a.kind != b.kind: return false
  case a.kind
  of ckNone: true
  of ckBasic: a.basic == b.basic
  of ckExtended: a.index == b.index
  of ckTrue: a.r == b.r and a.g == b.g and a.b == b.b

# ---- RGBA (image/color compatibility) -------------------------------------

const ansiHex: array[16, uint32] = [
  0x000000'u32, 0x800000, 0x008000, 0x808000, 0x000080, 0x800080, 0x008080,
  0xc0c0c0, 0x808080, 0xff0000, 0x00ff00, 0xffff00, 0x0000ff, 0xff00ff,
  0x00ffff, 0xffffff,
]

proc xterm256Hex*(i: uint8): uint32 =
  ## RGB value for a 256-color palette index, per the xterm specification.
  if i < 16:
    return ansiHex[i]
  if i >= 232:
    # Grayscale ramp: 24 steps from 8 to 238.
    let v = uint32(8 + 10 * (int(i) - 232))
    return (v shl 16) or (v shl 8) or v
  # 6x6x6 color cube.
  let
    n = int(i) - 16
    r = n div 36
    g = (n div 6) mod 6
    b = n mod 6
  proc step(v: int): uint32 = (if v == 0: 0'u32 else: uint32(55 + v * 40))
  (step(r) shl 16) or (step(g) shl 8) or step(b)

proc toRGB*(c: Color): tuple[r, g, b: uint8] =
  ## Resolve any color to concrete 8-bit RGB (default/none resolves to black).
  case c.kind
  of ckNone: (0'u8, 0'u8, 0'u8)
  of ckBasic:
    let h = ansiHex[c.basic]
    (uint8((h shr 16) and 0xff), uint8((h shr 8) and 0xff), uint8(h and 0xff))
  of ckExtended:
    let h = xterm256Hex(c.index)
    (uint8((h shr 16) and 0xff), uint8((h shr 8) and 0xff), uint8(h and 0xff))
  of ckTrue: (c.r, c.g, c.b)

proc hex*(c: Color): string =
  ## "#rrggbb" hex string (used for OSC cursor/fg/bg sequences).
  const digits = "0123456789abcdef"
  let (r, g, b) = c.toRGB()
  result = "#"
  for v in [r, g, b]:
    result.add digits[int(v shr 4)]
    result.add digits[int(v and 0x0f)]

# ---- SGR parameter encoding -----------------------------------------------

proc fgParams*(c: Color): string =
  ## SGR parameters that set this color as the foreground (no CSI/`m`).
  case c.kind
  of ckNone: "39"
  of ckBasic:
    if c.basic < 8: $(30 + int(c.basic)) else: $(90 + int(c.basic) - 8)
  of ckExtended: "38;5;" & $c.index
  of ckTrue: "38;2;" & $c.r & ";" & $c.g & ";" & $c.b

proc bgParams*(c: Color): string =
  ## SGR parameters that set this color as the background.
  case c.kind
  of ckNone: "49"
  of ckBasic:
    if c.basic < 8: $(40 + int(c.basic)) else: $(100 + int(c.basic) - 8)
  of ckExtended: "48;5;" & $c.index
  of ckTrue: "48;2;" & $c.r & ";" & $c.g & ";" & $c.b

proc adaptive*(light, dark: Color, isDark: bool): Color =
  ## Pick a color based on the terminal's background darkness (Lipgloss-style
  ## adaptive color). Combine with `BackgroundColorMsg.isDark`.
  if isDark: dark else: light

proc lerp*(a, b: Color, t: float): Color =
  ## Linear blend between two colors in RGB space (t in 0..1) → truecolor.
  let
    (ar, ag, ab) = a.toRGB()
    (br, bg, bb) = b.toRGB()
    tt = max(0.0, min(1.0, t))
  proc mix(x, y: uint8): uint8 = uint8(float(x) + (float(y) - float(x)) * tt + 0.5)
  trueColor(mix(ar, br), mix(ag, bg), mix(ab, bb))

proc gradient*(a, b: Color, steps: int): seq[Color] =
  ## `steps` colors evenly interpolated from `a` to `b` inclusive.
  if steps <= 1: return @[a]
  for i in 0 ..< steps:
    result.add lerp(a, b, i.float / (steps - 1).float)

proc underlineColorParams*(c: Color): string =
  ## SGR parameters that set the underline color (SGR 58/59).
  case c.kind
  of ckNone: "59"
  of ckBasic: "58;5;" & $c.basic
  of ckExtended: "58;5;" & $c.index
  of ckTrue: "58;2;" & $c.r & ";" & $c.g & ";" & $c.b
