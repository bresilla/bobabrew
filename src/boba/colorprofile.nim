## Terminal color profile detection and degradation — port of
## `charmbracelet/colorprofile`.
##
## A `Profile` describes how many colors a terminal can show. `detect` infers it
## from environment variables; `convert` degrades a `Color` to the closest color
## the profile supports (TrueColor → 256 → 16 → none).

import std/[strutils, tables]
import ./ansi/color

type
  Profile* = enum
    NoTTY      ## not a terminal; strip all color
    Ascii      ## no color (monochrome)
    ANSI       ## 16 colors
    ANSI256    ## 256 colors
    TrueColor  ## 24-bit color

proc `$`*(p: Profile): string =
  case p
  of NoTTY: "NoTTY"
  of Ascii: "Ascii"
  of ANSI: "ANSI"
  of ANSI256: "ANSI256"
  of TrueColor: "TrueColor"

# ---- detection -------------------------------------------------------------

proc envColorProfile(env: Table[string, string]): Profile =
  ## Profile implied purely by environment, ignoring TTY-ness.
  if env.getOrDefault("NO_COLOR", "").len > 0:
    return Ascii
  let colorTerm = env.getOrDefault("COLORTERM", "").toLowerAscii()
  if colorTerm in ["truecolor", "24bit", "yes", "true"]:
    return TrueColor
  let term = env.getOrDefault("TERM", "").toLowerAscii()
  if term.len == 0:
    return Ascii
  if "truecolor" in term or "direct" in term:
    return TrueColor
  if "256color" in term or "256" in term:
    return ANSI256
  if term == "dumb":
    return Ascii
  if "color" in term or "ansi" in term or "xterm" in term or
     "screen" in term or "tmux" in term or "rxvt" in term or "vt100" in term:
    return ANSI
  result = ANSI

proc detect*(isTTY: bool, env: Table[string, string]): Profile =
  ## Detect the color profile. When not a TTY the profile is `NoTTY`.
  if not isTTY:
    return NoTTY
  result = envColorProfile(env)

proc envToTable*(env: openArray[string]): Table[string, string] =
  ## Convert a `KEY=VALUE` slice (os.environ form) to a lookup table.
  result = initTable[string, string]()
  for entry in env:
    let i = entry.find('=')
    if i > 0:
      result[entry[0 ..< i]] = entry[i + 1 .. ^1]

# ---- degradation -----------------------------------------------------------

proc dist(a, b: tuple[r, g, b: uint8]): int =
  ## Squared Euclidean distance in RGB space (good enough for palette mapping).
  let
    dr = int(a.r) - int(b.r)
    dg = int(a.g) - int(b.g)
    db = int(a.b) - int(b.b)
  dr * dr + dg * dg + db * db

proc nearestExtended(rgb: tuple[r, g, b: uint8]): uint8 =
  ## Closest xterm-256 palette index to an RGB color.
  var best = 0
  var bestD = high(int)
  for i in 0 .. 255:
    let h = xterm256Hex(uint8(i))
    let c = (uint8((h shr 16) and 0xff), uint8((h shr 8) and 0xff),
             uint8(h and 0xff))
    let d = dist(rgb, c)
    if d < bestD:
      bestD = d
      best = i
  result = uint8(best)

proc nearestBasic(rgb: tuple[r, g, b: uint8]): uint8 =
  ## Closest of the 16 ANSI colors to an RGB color.
  var best = 0
  var bestD = high(int)
  for i in 0 .. 15:
    let h = xterm256Hex(uint8(i))
    let c = (uint8((h shr 16) and 0xff), uint8((h shr 8) and 0xff),
             uint8(h and 0xff))
    let d = dist(rgb, c)
    if d < bestD:
      bestD = d
      best = i
  result = uint8(best)

proc convert*(p: Profile, c: Color): Color =
  ## Degrade `c` to the nearest color this profile can display.
  if c.isNone: return c
  case p
  of TrueColor:
    c
  of ANSI256:
    case c.kind
    of ckTrue: extendedColor(nearestExtended((c.r, c.g, c.b)))
    else: c
  of ANSI:
    case c.kind
    of ckBasic: c
    of ckExtended:
      if c.index < 16: basicColor(c.index)
      else: basicColor(nearestBasic(c.toRGB()))
    of ckTrue: basicColor(nearestBasic((c.r, c.g, c.b)))
    of ckNone: c
  of Ascii, NoTTY:
    NoColor
