## A selectable, scrolling list — port of the core of `charmbracelet/bubbles/list`
## (simplified: title/description items, keyboard navigation, cursor-following
## scroll, selection highlight).

import std/strutils
import ../tea/msg
import ../uv/key
import ../ansi/style
import ../ansi/color

type
  ListItem* = object
    title*, desc*: string

  List* = object
    items*: seq[ListItem]
    cursor*: int           ## selected index
    height*: int           ## visible rows
    offset*: int           ## first visible index
    showDesc*: bool

proc item*(title: string, desc = ""): ListItem =
  ListItem(title: title, desc: desc)

proc newList*(items: seq[ListItem], height = 10): List =
  List(items: items, cursor: 0, height: max(height, 1), offset: 0, showDesc: false)

proc selected*(l: List): ListItem =
  if l.cursor >= 0 and l.cursor < l.items.len: l.items[l.cursor]
  else: ListItem()

proc clampScroll(l: var List) =
  if l.cursor < l.offset:
    l.offset = l.cursor
  elif l.cursor >= l.offset + l.height:
    l.offset = l.cursor - l.height + 1
  if l.offset < 0: l.offset = 0

proc moveUp*(l: var List) =
  if l.cursor > 0: dec l.cursor
  l.clampScroll()
proc moveDown*(l: var List) =
  if l.cursor < l.items.len - 1: inc l.cursor
  l.clampScroll()
proc gotoTop*(l: var List) = (l.cursor = 0; l.clampScroll())
proc gotoBottom*(l: var List) =
  l.cursor = max(l.items.len - 1, 0); l.clampScroll()

proc update*(l: var List, m: Msg) =
  if not (m of KeyPressMsg): return
  let k = KeyPressMsg(m).key
  if k.matchString("up", "k"): l.moveUp()
  elif k.matchString("down", "j"): l.moveDown()
  elif k.matchString("g") or k.code == KeyHome: l.gotoTop()
  elif k.matchString("G") or k.code == KeyEnd: l.gotoBottom()

proc view*(l: List): string =
  var rows: seq[string]
  let last = min(l.offset + l.height, l.items.len)
  for i in l.offset ..< last:
    let it = l.items[i]
    if i == l.cursor:
      let sel = EmptyStyle.withFg(basicColor(BrightCyan)).bold
      rows.add sel.styled("> " & it.title)
    else:
      rows.add "  " & it.title
    if l.showDesc and it.desc.len > 0:
      rows.add "    " & EmptyStyle.faint.styled(it.desc)
  result = rows.join("\n")
